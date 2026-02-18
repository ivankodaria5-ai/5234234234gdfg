-- MM2 Farm Hub v6 | Human-like + Server Hop | Anti-detect
-- request() loader only, ASCII only

if not game:IsLoaded() then game.Loaded:Wait() end
if _G.MM2HubLoaded then return end
_G.MM2HubLoaded = true

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UIS              = game:GetService("UserInputService")
local RS               = game:GetService("ReplicatedStorage")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local LP               = Players.LocalPlayer

-- Settings
local CFG = {
    WalkSpeed    = 16,
    SpeedJitter  = 3,
    MinPause     = 0.3,
    MaxPause     = 0.8,
    TpDist       = 120,
    FlingForce   = 80,
    CombatRange  = 60,
    CombatDelay  = 0.5,
    -- Server hop
    PlaceId      = 142823291,
    HopInterval  = 1800,   -- seconds between auto-hops (30 min)
    ScriptUrl    = "https://raw.githubusercontent.com/ivankodaria5-ai/5234234234gdfg/refs/heads/main/coin_farm.lua",
}

local State = {
    CoinFarm   = true,
    Combat     = true,
    NoClip     = true,
    AutoReset  = true,
    ServerHop  = true,
    AntiFling  = true,
}

local Stats = {
    Coins  = 0,
    Flings = 0,
    Rounds = 0,
}

local farmOn      = false
local curTween    = nil
local ncConn      = nil
local lastCmb     = 0
local resetting   = false
local hopQueued   = false
local hopStart    = tick()
local hopTimerLbl = nil
local roundActive  = false   -- true only during active round
local roundEndDone = false   -- flag: already reset this round end

-- Utility
local function getChar() return LP.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChild("Humanoid")
end
local function alive()
    local h = getHum()
    return h ~= nil and h.Health > 0
end
local function rnd(a, b) return a + math.random() * (b - a) end
local function rndInt(a, b) return math.random(a, b) end

-- Human-like random offset to never go exactly to coin center
local function humanOffset()
    return Vector3.new(rnd(-1.2, 1.2), rnd(0.5, 2.5), rnd(-1.2, 1.2))
end

-- Find CoinContainer in active map
local function getCoinBox()
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChild("CoinContainer") then
            return v:FindFirstChild("CoinContainer")
        end
    end
    return nil
end

-- Find nearest untouched coin (checks TouchInterest = coin exists)
local function nearestCoin()
    local root = getRoot()
    if not root then return nil, 0 end
    local box = getCoinBox()
    if not box then return nil, 0 end
    local best  = nil
    local bestD = math.huge
    for _, coin in pairs(box:GetChildren()) do
        if coin:IsA("BasePart") and coin:FindFirstChild("TouchInterest") then
            local d = (root.Position - coin.Position).Magnitude
            if d < bestD then best = coin bestD = d end
        end
    end
    return best, bestD
end

-- Roles
local function getRole(plr)
    local c  = plr.Character
    local bp = plr:FindFirstChild("Backpack")
    if not c then return "I" end
    if c:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then return "M" end
    if c:FindFirstChild("Gun")   or (bp and bp:FindFirstChild("Gun"))   then return "S" end
    return "I"
end
local function myRole() return getRole(LP) end

-- Combat target
local function findTarget()
    local root = getRoot()
    if not root then return nil end
    local role = myRole()
    local best = nil
    local bestD = math.huge
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LP then
            local tr = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                local d  = (root.Position - tr.Position).Magnitude
                local pr = getRole(plr)
                local ok = (role == "M") or (role == "S" and pr == "M") or (role == "I" and pr == "M")
                if ok and d < CFG.CombatRange and d < bestD then best = plr bestD = d end
            end
        end
    end
    return best
end

-- NoClip (only walls, keep floor collision for natural gravity)
local function enableNC()
    if ncConn then return end
    ncConn = RunService.Stepped:Connect(function()
        if not State.NoClip then return end
        local c = getChar()
        if not c then return end
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end
local function disableNC()
    if ncConn then ncConn:Disconnect() ncConn = nil end
    local c = getChar()
    if c then
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

-- Human-like movement to coin
-- Uses Humanoid WalkSpeed + TweenService so it looks like walking
local function walkToCoin(coin)
    if not coin or not coin.Parent then return false end
    local root = getRoot()
    local hum  = getHum()
    if not root or not hum then return false end

    local target = coin.Position + humanOffset()
    local dist   = (root.Position - target).Magnitude

    -- If very far, fly at higher speed first to get closer
    if dist >= CFG.TpDist then
        if curTween then curTween:Cancel() curTween = nil end
        local midpoint = root.Position:Lerp(target, 0.6) + humanOffset()
        local fastDur  = math.max(0.3, dist / (CFG.WalkSpeed * 3))
        local fastInfo = TweenInfo.new(fastDur, Enum.EasingStyle.Linear)
        curTween = TweenService:Create(root, fastInfo, { CFrame = CFrame.new(midpoint) })
        curTween:Play()
        curTween.Completed:Wait()
        curTween = nil
        dist = (root.Position - target).Magnitude
    end

    -- Set humanlike walkspeed with small jitter
    local spd = CFG.WalkSpeed + rnd(-CFG.SpeedJitter, CFG.SpeedJitter)
    spd = math.clamp(spd, 10, 22)
    pcall(function() hum.WalkSpeed = spd end)

    -- Tween movement - mimics walking speed, looks human
    if curTween then curTween:Cancel() curTween = nil end
    local dur  = math.max(0.2, dist / spd)
    local info = TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local goal = { CFrame = CFrame.new(target) }

    curTween = TweenService:Create(root, info, goal)
    curTween:Play()

    -- Fire touch as we approach (not at start - more realistic)
    task.delay(dur * 0.7, function()
        pcall(function()
            firetouchinterest(root, coin, 0)
        end)
    end)

    curTween.Completed:Wait()
    curTween = nil

    -- Final touch fire at actual arrival
    pcall(function()
        firetouchinterest(root, coin, 0)
    end)

    -- Human-like pause between coins
    task.wait(rnd(CFG.MinPause, CFG.MaxPause))
    return true
end


-- Fling murderer off the map hard (used when bag full + we are innocent/sheriff)
local function superFlingMurderer()
    local murderer = nil
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            if getRole(plr) == "M" then murderer = plr break end
        end
    end
    if not murderer or not murderer.Character then return end
    print("[Hub] Bag full - flinging murderer!")
    -- Fling hard 15 times over 3 seconds to make sure they fly off
    task.spawn(function()
        for i = 1, 15 do
            if not murderer.Character then break end
            local tr = murderer.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                pcall(function()
                    tr.AssemblyLinearVelocity = Vector3.new(
                        rnd(-1000, 1000), 2000, rnd(-1000, 1000)
                    )
                    tr.AssemblyAngularVelocity = Vector3.new(
                        rnd(-50, 50), rnd(-50, 50), rnd(-50, 50)
                    )
                end)
            end
            task.wait(0.2)
        end
        print("[Hub] Murderer flung!")
    end)
end

-- Safe reset (respawn character)
local function safeReset(reason)
    if resetting then return end
    resetting = true
    if curTween then curTween:Cancel() curTween = nil end
    farmOn = false
    print("[Hub] Reset: " .. tostring(reason))
    task.wait(rnd(0.3, 0.7))
    pcall(function()
        local h = getHum()
        if h then h.Health = 0 end
    end)
    task.wait(0.8)
    resetting = false
end

-- Anti-fling: protect our character from being launched
local antiFlingConn   = nil
local afOtherConns    = {}

local function clearAFOtherConns()
    for _, c in pairs(afOtherConns) do
        pcall(function() c:Disconnect() end)
    end
    afOtherConns = {}
end

-- NoCollision with other players so they cant push us
local function hookOtherPlayer(plr)
    if plr == LP then return end
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not plr.Character then return end
        local root = plr.Character:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function()
                root.CanCollide = false
            end)
        end
    end)
    table.insert(afOtherConns, conn)
end

local function startAntiFling()
    if antiFlingConn then return end

    -- Hook all existing players
    for _, plr in pairs(Players:GetPlayers()) do
        hookOtherPlayer(plr)
    end
    -- Hook new players as they join
    Players.PlayerAdded:Connect(hookOtherPlayer)

    -- Protect own character: only anti-ragdoll, no velocity changes
    antiFlingConn = RunService.Heartbeat:Connect(function()
        local hum = getHum()
        if not hum then return end
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,    false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end)
    end)
    print("[Hub] Anti-fling active")
end

local function stopAntiFling()
    if antiFlingConn then
        antiFlingConn:Disconnect()
        antiFlingConn = nil
    end
    clearAFOtherConns()
end

-- Server hop: find a random server with free slots
local function findServer()
    local servers = {}
    local cursor  = ""
    local tries   = 0
    repeat
        tries = tries + 1
        local url = "https://games.roblox.com/v1/games/" .. CFG.PlaceId ..
                    "/servers/Public?sortOrder=Desc&limit=100&cursor=" .. cursor
        local ok, data = pcall(function()
            local res = request({ Url = url, Method = "GET" })
            return HttpService:JSONDecode(res.Body)
        end)
        if ok and data and data.data then
            for _, sv in pairs(data.data) do
                if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                    table.insert(servers, sv.id)
                end
            end
            cursor = data.nextPageCursor or ""
        else
            break
        end
    until cursor == "" or #servers >= 50 or tries >= 3
    if #servers > 0 then
        return servers[math.random(1, #servers)]
    end
    return nil
end

-- Queue our script to auto-run on the new server after teleport
local function queueScript()
    if hopQueued then return end
    hopQueued = true
    local loader = 'loadstring(request({Url="' .. CFG.ScriptUrl .. '",Method="GET"}).Body)()'
    pcall(function()
        local qf = queueonteleport or syn and syn.queue_on_teleport
        if qf then
            qf(loader)
            print("[Hub] Script queued for next server")
        end
    end)
end

local function doServerHop()
    print("[Hub] Looking for server to hop...")
    local serverId = findServer()
    queueScript()
    pcall(function()
        if serverId then
            print("[Hub] Hopping to: " .. serverId)
            TeleportService:TeleportToPlaceInstance(CFG.PlaceId, serverId, LP)
        else
            print("[Hub] No server found, random teleport")
            TeleportService:Teleport(CFG.PlaceId, LP)
        end
    end)
end

-- Server hop timer loop
local function startHopTimer()
    task.spawn(function()
        while true do
            task.wait(1)
            if not State.ServerHop then continue end
            local elapsed = tick() - hopStart
            local left    = CFG.HopInterval - elapsed
            -- Update GUI timer label
            if hopTimerLbl then
                if left > 0 then
                    local m = math.floor(left / 60)
                    local s = math.floor(left % 60)
                    hopTimerLbl.Text = "Hop in: " .. m .. "m " .. s .. "s"
                    hopTimerLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
                else
                    hopTimerLbl.Text = "Hopping..."
                    hopTimerLbl.TextColor3 = Color3.fromRGB(255, 200, 50)
                end
            end
            -- Time to hop
            if left <= 0 then
                hopStart = tick()
                hopQueued = false
                doServerHop()
            end
        end
    end)
end

-- AntiAFK
local function antiAFK()
    pcall(function()
        local GC = getconnections or get_signal_cons
        if GC then
            for _, v in pairs(GC(LP.Idled)) do
                if v.Disable then v:Disable()
                elseif v.Disconnect then v:Disconnect() end
            end
        else
            local VU = cloneref(game:GetService("VirtualUser"))
            LP.Idled:Connect(function()
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
            end)
        end
    end)
end

-- MM2 events
pcall(function()
    local rem = RS:WaitForChild("Remotes", 5)
    if not rem then return end
    local gp = rem:WaitForChild("Gameplay", 5)
    if not gp then return end

    local rsEv = gp:FindFirstChild("RoundStart")
    if rsEv then
        rsEv.OnClientEvent:Connect(function()
            roundActive  = true
            roundEndDone = false
            farmOn       = true
            print("[Hub] Round started - farming!")
        end)
    end

    local reEv = gp:FindFirstChild("RoundEndFade")
    if reEv then
        reEv.OnClientEvent:Connect(function()
            if roundEndDone then return end  -- prevent double fire
            roundEndDone = true
            roundActive  = false
            farmOn       = false
            if curTween then curTween:Cancel() curTween = nil end
            Stats.Rounds = Stats.Rounds + 1
            -- ONE reset after round ends, then wait for next RoundStart
            task.spawn(function()
                task.wait(rnd(1.0, 2.0))
                safeReset("round ended")
                print("[Hub] Waiting for next round...")
            end)
        end)
    end

    local ccEv = gp:FindFirstChild("CoinCollected")
    if ccEv then
        ccEv.OnClientEvent:Connect(function(_, current, maxC)
            Stats.Coins = tonumber(current) or Stats.Coins
            if tonumber(current) == tonumber(maxC) then
                farmOn = false
                print("[Hub] Bag full!")
                local role = myRole()
                if role == "I" then
                    -- Innocent with no gun: fling murderer off map
                    superFlingMurderer()
                    task.wait(rnd(1.0, 1.5))
                    -- Then reset to start next bag cycle
                    if State.AutoReset then
                        pcall(function()
                            local h = getHum()
                            if h then h.Health = 0 end
                        end)
                    end
                elseif role == "S" then
                    -- Sheriff: try to shoot murderer (fling as backup)
                    superFlingMurderer()
                    task.wait(rnd(0.8, 1.2))
                    if State.AutoReset then
                        pcall(function()
                            local h = getHum()
                            if h then h.Health = 0 end
                        end)
                    end
                else
                    -- Murderer: just reset for next bag
                    if State.AutoReset then
                        task.wait(rnd(0.5, 1.0))
                        pcall(function()
                            local h = getHum()
                            if h then h.Health = 0 end
                        end)
                    end
                end
            end
        end)
    end
end)

-- GUI
local function buildGUI()
    local old = LP.PlayerGui:FindFirstChild("MM2Hub")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "MM2Hub"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = LP.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 230, 0, 470)
    frame.Position = UDim2.new(0, 10, 0.15, 0)
    frame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local hdr = Instance.new("Frame")
    hdr.Size = UDim2.new(1, 0, 0, 40)
    hdr.BackgroundColor3 = Color3.fromRGB(25, 110, 245)
    hdr.BorderSizePixel = 0
    hdr.Parent = frame
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 12)

    local hdrFix = Instance.new("Frame")
    hdrFix.Size = UDim2.new(1, 0, 0, 12)
    hdrFix.Position = UDim2.new(0, 0, 1, -12)
    hdrFix.BackgroundColor3 = Color3.fromRGB(25, 110, 245)
    hdrFix.BorderSizePixel = 0
    hdrFix.Parent = hdr

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -50, 1, 0)
    titleL.Position = UDim2.new(0, 12, 0, 0)
    titleL.BackgroundTransparency = 1
    titleL.Text = "MM2 Farm Hub"
    titleL.TextColor3 = Color3.new(1, 1, 1)
    titleL.TextSize = 15
    titleL.Font = Enum.Font.GothamBold
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = hdr

    local xBtn = Instance.new("TextButton")
    xBtn.Size = UDim2.new(0, 32, 0, 32)
    xBtn.Position = UDim2.new(1, -36, 0, 4)
    xBtn.BackgroundColor3 = Color3.fromRGB(210, 45, 45)
    xBtn.Text = "X"
    xBtn.TextColor3 = Color3.new(1, 1, 1)
    xBtn.TextSize = 14
    xBtn.Font = Enum.Font.GothamBold
    xBtn.BorderSizePixel = 0
    xBtn.Parent = hdr
    Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, 6)
    xBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    local drag = false
    local dSt  = nil
    local dPos = nil
    hdr.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or
           inp.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true dSt = inp.Position dPos = frame.Position
        end
    end)
    hdr.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or
           inp.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if drag then
            if inp.UserInputType == Enum.UserInputType.Touch or
               inp.UserInputType == Enum.UserInputType.MouseMove then
                local d = inp.Position - dSt
                frame.Position = UDim2.new(dPos.X.Scale, dPos.X.Offset + d.X,
                                           dPos.Y.Scale, dPos.Y.Offset + d.Y)
            end
        end
    end)

    local sf = Instance.new("Frame")
    sf.Size = UDim2.new(1, -16, 0, 100)
    sf.Position = UDim2.new(0, 8, 0, 48)
    sf.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    sf.BorderSizePixel = 0
    sf.Parent = frame
    Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 8)

    local function mkL(txt, y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -10, 0, 22)
        l.Position = UDim2.new(0, 8, 0, y)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = Color3.fromRGB(200, 200, 200)
        l.TextSize = 13
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = sf
        return l
    end
    local lC = mkL("Coins:  0",  4)
    local lF = mkL("Flings: 0", 27)
    local lR = mkL("Role:   ?", 50)
    local lH = mkL("Hop in: --",73)
    hopTimerLbl = lH

    local function mkBtn(lbl, key, y, cOn, cOff)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -16, 0, 48)
        b.Position = UDim2.new(0, 8, 0, y)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        local function upd()
            if State[key] then
                b.BackgroundColor3 = cOn
                b.Text = lbl .. " [ON]"
            else
                b.BackgroundColor3 = cOff
                b.Text = lbl .. " [OFF]"
            end
        end
        upd()
        b.MouseButton1Click:Connect(function()
            State[key] = not State[key]
            if key == "NoClip" then
                if State.NoClip then enableNC() else disableNC() end
            end
            upd()
        end)
    end
    mkBtn("FARM COINS",  "CoinFarm",  156, Color3.fromRGB(28,155,55),  Color3.fromRGB(65,65,65))
    mkBtn("COMBAT",      "Combat",    212, Color3.fromRGB(195,55,55),  Color3.fromRGB(65,65,65))
    mkBtn("NOCLIP",      "NoClip",    268, Color3.fromRGB(95,55,200),  Color3.fromRGB(65,65,65))
    mkBtn("SERVER HOP",  "ServerHop", 324, Color3.fromRGB(200,130,20), Color3.fromRGB(65,65,65))

    -- Anti-fling button with custom toggle logic
    local afBtn = Instance.new("TextButton")
    afBtn.Size = UDim2.new(1, -16, 0, 48)
    afBtn.Position = UDim2.new(0, 8, 0, 380)
    afBtn.BorderSizePixel = 0
    afBtn.Font = Enum.Font.GothamBold
    afBtn.TextSize = 14
    afBtn.TextColor3 = Color3.new(1, 1, 1)
    afBtn.Parent = frame
    Instance.new("UICorner", afBtn).CornerRadius = UDim.new(0, 8)
    local function updAF()
        if State.AntiFling then
            afBtn.BackgroundColor3 = Color3.fromRGB(20, 160, 160)
            afBtn.Text = "ANTI-FLING  [ON]"
        else
            afBtn.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
            afBtn.Text = "ANTI-FLING  [OFF]"
        end
    end
    updAF()
    afBtn.MouseButton1Click:Connect(function()
        State.AntiFling = not State.AntiFling
        if State.AntiFling then startAntiFling() else stopAntiFling() end
        updAF()
    end)

    -- Manual hop button
    local hopNowBtn = Instance.new("TextButton")
    hopNowBtn.Size = UDim2.new(1, -16, 0, 34)
    hopNowBtn.Position = UDim2.new(0, 8, 0, 428)
    hopNowBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    hopNowBtn.Text = "HOP NOW"
    hopNowBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
    hopNowBtn.TextSize = 13
    hopNowBtn.Font = Enum.Font.GothamBold
    hopNowBtn.BorderSizePixel = 0
    hopNowBtn.Parent = frame
    Instance.new("UICorner", hopNowBtn).CornerRadius = UDim.new(0, 8)
    hopNowBtn.MouseButton1Click:Connect(function()
        hopQueued = false
        hopStart  = tick() - CFG.HopInterval
        print("[Hub] Manual hop triggered")
    end)

    task.spawn(function()
        while sg and sg.Parent do
            task.wait(0.5)
            pcall(function()
                lC.Text = "Coins:  " .. tostring(Stats.Coins)
                lF.Text = "Flings: " .. tostring(Stats.Flings)
                local r = myRole()
                if r == "M" then
                    lR.Text = "Role: Murderer"
                    lR.TextColor3 = Color3.fromRGB(255, 75, 75)
                elseif r == "S" then
                    lR.Text = "Role: Sheriff"
                    lR.TextColor3 = Color3.fromRGB(75, 135, 255)
                else
                    lR.Text = "Role: Innocent"
                    lR.TextColor3 = Color3.fromRGB(75, 215, 75)
                end
            end)
        end
    end)
end

-- Main loop
task.spawn(function()
    task.wait(3)
    buildGUI()
    enableNC()
    antiAFK()
    startHopTimer()
    if State.AntiFling then startAntiFling() end
    print("[Hub] Loaded - waiting for RoundStart!")

    while true do
        task.wait(rnd(0.05, 0.1))

        -- Combat
        if State.Combat and alive() then
            local now = tick()
            if now - lastCmb >= CFG.CombatDelay then
                local tgt = findTarget()
                if tgt and tgt.Character then
                    local tr = tgt.Character:FindFirstChild("HumanoidRootPart")
                    if tr then
                        pcall(function()
                            local f = CFG.FlingForce
                            tr.AssemblyLinearVelocity = Vector3.new(rnd(-f,f), f*1.3, rnd(-f,f))
                        end)
                        Stats.Flings = Stats.Flings + 1
                        lastCmb = now
                    end
                end
            end
        end

        -- Farm
        if State.CoinFarm and farmOn and alive() then
            local coin = nearestCoin()
            if coin then
                walkToCoin(coin)
            else
                task.wait(1)
            end
        end
    end
end)

LP.CharacterRemoving:Connect(function()
    if curTween then curTween:Cancel() curTween = nil end
    disableNC()
    pcall(function()
        local h = getHum()
        if h then h.WalkSpeed = 16 end
    end)
end)

LP.CharacterAdded:Connect(function()
    task.wait(1.5)
    if State.NoClip then enableNC() end
    -- Never auto-start farming on respawn
    -- Only RoundStart event enables farming
    farmOn = false
    print("[Hub] Respawned - waiting for next round")
end)

print("[Hub] Loaded.")
