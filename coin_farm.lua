-- MM2 Farm Hub v4 | Mobile GUI | Delta Android
-- ASCII only, no unicode, no cyrillic, Lua 5.1 compatible

if not game:IsLoaded() then game.Loaded:Wait() end
if _G.MM2HubLoaded then return end
_G.MM2HubLoaded = true

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local RS           = game:GetService("ReplicatedStorage")
local LP           = Players.LocalPlayer

local FLY_SPEED    = 26
local TP_DIST      = 180
local FLING_F      = 80
local CMB_RANGE    = 60
local CMB_DELAY    = 0.4

local State = {
    CoinFarm  = true,
    Combat    = true,
    NoClip    = true,
    AutoReset = true,
}

local Stats = {
    Coins  = 0,
    Flings = 0,
    Rounds = 0,
}

local farmOn     = false
local curTween   = nil
local ncConn     = nil
local lastCmb    = 0

local function getChar()
    return LP.Character
end

local function getRoot()
    local c = getChar()
    if c then return c:FindFirstChild("HumanoidRootPart") end
    return nil
end

local function getHum()
    local c = getChar()
    if c then return c:FindFirstChild("Humanoid") end
    return nil
end

local function alive()
    local h = getHum()
    return h ~= nil and h.Health > 0
end

local function rnd(a, b)
    return a + math.random() * (b - a)
end

local function getCoinContainer()
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChild("CoinContainer") then
            return v:FindFirstChild("CoinContainer")
        end
    end
    return nil
end

local function nearestCoin()
    local root = getRoot()
    if not root then return nil, 0 end
    local box = getCoinContainer()
    if not box then return nil, 0 end
    local best  = nil
    local bestD = math.huge
    for _, coin in pairs(box:GetChildren()) do
        if coin:IsA("BasePart") and coin:FindFirstChild("TouchInterest") then
            local d = (root.Position - coin.Position).Magnitude
            if d < bestD then
                best  = coin
                bestD = d
            end
        end
    end
    return best, bestD
end

local function getRole(plr)
    local c  = plr.Character
    local bp = plr:FindFirstChild("Backpack")
    if not c then return "I" end
    if c:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then return "M" end
    if c:FindFirstChild("Gun")   or (bp and bp:FindFirstChild("Gun"))   then return "S" end
    return "I"
end

local function myRole()
    return getRole(LP)
end

local function findTarget()
    local root = getRoot()
    if not root then return nil end
    local role  = myRole()
    local best  = nil
    local bestD = math.huge
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LP then
            local tr = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                local d  = (root.Position - tr.Position).Magnitude
                local pr = getRole(plr)
                local ok = (role == "M") or
                           (role == "S" and pr == "M") or
                           (role == "I" and pr == "M")
                if ok and d < CMB_RANGE and d < bestD then
                    best  = plr
                    bestD = d
                end
            end
        end
    end
    return best
end

local function enableNC()
    if ncConn then return end
    ncConn = RunService.Stepped:Connect(function()
        if State.NoClip then
            local c = getChar()
            if c then
                for _, p in pairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.CanCollide = false
                    end
                end
            end
        end
    end)
end

local function disableNC()
    if ncConn then
        ncConn:Disconnect()
        ncConn = nil
    end
    local c = getChar()
    if c then
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = true
            end
        end
    end
end

local function goToCoin(coin)
    if not coin or not coin.Parent then return end
    local root = getRoot()
    if not root then return end

    local dist = (root.Position - coin.Position).Magnitude

    if dist >= TP_DIST then
        pcall(function()
            root.CFrame = CFrame.new(coin.Position + Vector3.new(0, 4, 0))
        end)
        task.wait(0.05)
    end

    if curTween then
        curTween:Cancel()
        curTween = nil
    end

    dist = (root.Position - coin.Position).Magnitude
    local dur  = math.max(0.1, dist / FLY_SPEED)
    local info = TweenInfo.new(dur, Enum.EasingStyle.Linear)
    local goal = { CFrame = CFrame.new(coin.Position + Vector3.new(0, 2, 0)) }

    curTween = TweenService:Create(root, info, goal)
    curTween:Play()

    pcall(function()
        firetouchinterest(root, coin, 0)
    end)

    curTween.Completed:Wait()
    curTween = nil

    pcall(function()
        firetouchinterest(root, coin, 0)
    end)
end

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

pcall(function()
    local rem = RS:WaitForChild("Remotes", 5)
    if not rem then return end
    local gp = rem:WaitForChild("Gameplay", 5)
    if not gp then return end

    local rsEv = gp:FindFirstChild("RoundStart")
    if rsEv then
        rsEv.OnClientEvent:Connect(function()
            farmOn = true
            print("[Hub] Round start - farming")
        end)
    end

    local reEv = gp:FindFirstChild("RoundEndFade")
    if reEv then
        reEv.OnClientEvent:Connect(function()
            farmOn = false
            if curTween then curTween:Cancel() curTween = nil end
            Stats.Rounds = Stats.Rounds + 1
        end)
    end

    local ccEv = gp:FindFirstChild("CoinCollected")
    if ccEv then
        ccEv.OnClientEvent:Connect(function(_, current, maxC)
            Stats.Coins = tonumber(current) or Stats.Coins
            if State.AutoReset and tonumber(current) == tonumber(maxC) then
                farmOn = false
                task.wait(0.5)
                pcall(function()
                    local h = getHum()
                    if h then h.Health = 0 end
                end)
            end
        end)
    end
end)

local function buildGUI()
    local old = LP.PlayerGui:FindFirstChild("MM2Hub")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "MM2Hub"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = LP.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size                   = UDim2.new(0, 230, 0, 305)
    frame.Position               = UDim2.new(0, 10, 0.25, 0)
    frame.BackgroundColor3       = Color3.fromRGB(14, 14, 20)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel        = 0
    frame.Parent                 = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local hdr = Instance.new("Frame")
    hdr.Size             = UDim2.new(1, 0, 0, 40)
    hdr.BackgroundColor3 = Color3.fromRGB(25, 110, 245)
    hdr.BorderSizePixel  = 0
    hdr.Parent           = frame
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 12)

    local hdrFix = Instance.new("Frame")
    hdrFix.Size             = UDim2.new(1, 0, 0, 12)
    hdrFix.Position         = UDim2.new(0, 0, 1, -12)
    hdrFix.BackgroundColor3 = Color3.fromRGB(25, 110, 245)
    hdrFix.BorderSizePixel  = 0
    hdrFix.Parent           = hdr

    local titleL = Instance.new("TextLabel")
    titleL.Size             = UDim2.new(1, -50, 1, 0)
    titleL.Position         = UDim2.new(0, 12, 0, 0)
    titleL.BackgroundTransparency = 1
    titleL.Text             = "MM2 Farm Hub"
    titleL.TextColor3       = Color3.new(1, 1, 1)
    titleL.TextSize         = 15
    titleL.Font             = Enum.Font.GothamBold
    titleL.TextXAlignment   = Enum.TextXAlignment.Left
    titleL.Parent           = hdr

    local xBtn = Instance.new("TextButton")
    xBtn.Size             = UDim2.new(0, 32, 0, 32)
    xBtn.Position         = UDim2.new(1, -36, 0, 4)
    xBtn.BackgroundColor3 = Color3.fromRGB(210, 45, 45)
    xBtn.Text             = "X"
    xBtn.TextColor3       = Color3.new(1, 1, 1)
    xBtn.TextSize         = 14
    xBtn.Font             = Enum.Font.GothamBold
    xBtn.BorderSizePixel  = 0
    xBtn.Parent           = hdr
    Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, 6)
    xBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    local drag = false
    local dSt  = nil
    local dPos = nil

    hdr.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or
           inp.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dSt  = inp.Position
            dPos = frame.Position
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
                frame.Position = UDim2.new(
                    dPos.X.Scale, dPos.X.Offset + d.X,
                    dPos.Y.Scale, dPos.Y.Offset + d.Y
                )
            end
        end
    end)

    local sf = Instance.new("Frame")
    sf.Size             = UDim2.new(1, -16, 0, 78)
    sf.Position         = UDim2.new(0, 8, 0, 48)
    sf.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    sf.BorderSizePixel  = 0
    sf.Parent           = frame
    Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 8)

    local function mkL(txt, y)
        local l = Instance.new("TextLabel")
        l.Size             = UDim2.new(1, -10, 0, 22)
        l.Position         = UDim2.new(0, 8, 0, y)
        l.BackgroundTransparency = 1
        l.Text             = txt
        l.TextColor3       = Color3.fromRGB(200, 200, 200)
        l.TextSize         = 13
        l.Font             = Enum.Font.Gotham
        l.TextXAlignment   = Enum.TextXAlignment.Left
        l.Parent           = sf
        return l
    end

    local lC = mkL("Coins:  0",   4)
    local lF = mkL("Flings: 0",  27)
    local lR = mkL("Role:   ?",  50)

    local function mkBtn(lbl, key, y, cOn, cOff)
        local b = Instance.new("TextButton")
        b.Size             = UDim2.new(1, -16, 0, 48)
        b.Position         = UDim2.new(0, 8, 0, y)
        b.BorderSizePixel  = 0
        b.Font             = Enum.Font.GothamBold
        b.TextSize         = 14
        b.TextColor3       = Color3.new(1, 1, 1)
        b.Parent           = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

        local function upd()
            if State[key] then
                b.BackgroundColor3 = cOn
                b.Text = lbl .. "  [ON]"
            else
                b.BackgroundColor3 = cOff
                b.Text = lbl .. "  [OFF]"
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

    mkBtn("FARM COINS", "CoinFarm",  134, Color3.fromRGB(28,155,55),  Color3.fromRGB(65,65,65))
    mkBtn("COMBAT",     "Combat",    190, Color3.fromRGB(195,55,55),  Color3.fromRGB(65,65,65))
    mkBtn("NOCLIP",     "NoClip",    246, Color3.fromRGB(95,55,200),  Color3.fromRGB(65,65,65))

    task.spawn(function()
        while sg and sg.Parent do
            task.wait(0.5)
            pcall(function()
                lC.Text = "Coins:  " .. tostring(Stats.Coins)
                lF.Text = "Flings: " .. tostring(Stats.Flings)
                local r = myRole()
                if r == "M" then
                    lR.Text      = "Role: Murderer"
                    lR.TextColor3 = Color3.fromRGB(255, 75, 75)
                elseif r == "S" then
                    lR.Text      = "Role: Sheriff"
                    lR.TextColor3 = Color3.fromRGB(75, 135, 255)
                else
                    lR.Text      = "Role: Innocent"
                    lR.TextColor3 = Color3.fromRGB(75, 215, 75)
                end
            end)
        end
    end)
end

task.spawn(function()
    task.wait(3)
    buildGUI()
    enableNC()
    antiAFK()
    farmOn = true
    print("[Hub] MM2 Farm Hub loaded!")

    while true do
        task.wait(rnd(0.05, 0.12))

        if State.Combat and alive() then
            local now = tick()
            if now - lastCmb >= CMB_DELAY then
                local tgt = findTarget()
                if tgt and tgt.Character then
                    local tr = tgt.Character:FindFirstChild("HumanoidRootPart")
                    if tr then
                        pcall(function()
                            local f = FLING_F
                            tr.AssemblyLinearVelocity = Vector3.new(
                                rnd(-f, f), f * 1.3, rnd(-f, f)
                            )
                        end)
                        Stats.Flings = Stats.Flings + 1
                        lastCmb = now
                    end
                end
            end
        end

        if State.CoinFarm and farmOn and alive() then
            local coin, dist = nearestCoin()
            if coin then
                goToCoin(coin)
            else
                task.wait(1)
            end
        end
    end
end)

LP.CharacterRemoving:Connect(function()
    if curTween then curTween:Cancel() curTween = nil end
    disableNC()
end)

LP.CharacterAdded:Connect(function()
    task.wait(1.5)
    farmOn = true
    if State.NoClip then enableNC() end
    print("[Hub] Respawned.")
end)

print("[Hub] Loaded.")
