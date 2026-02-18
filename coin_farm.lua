-- MM2 Farm Hub | Mobile GUI | Delta Android Compatible
-- Lua 5.1 совместимый синтаксис (без continue, без +=, pairs() везде)

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local LocalPlayer  = Players.LocalPlayer

-- ── Настройки ──────────────────────────────────────────────
local CFG = {
    FlySpeed    = 28,
    FlingForce  = 75,
    CombatRange = 65,
    CombatDelay = 0.35,
    MinDelay    = 0.08,
    MaxDelay    = 0.18,
}

-- ── Состояние ──────────────────────────────────────────────
local State = {
    CoinFarm = true,
    Combat   = true,
    NoClip   = true,
    Running  = true,
}

local Stats = {
    Coins  = 0,
    Flings = 0,
    Rounds = 0,
}

-- ── Утилиты ────────────────────────────────────────────────
local function getChar()
    return LocalPlayer.Character
end

local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChild("Humanoid")
end

local function isAlive()
    local h = getHum()
    return h and h.Health > 0
end

local function rnd(a, b)
    return a + math.random() * (b - a)
end

local function getRole(plr)
    local c  = plr.Character
    local bp = plr:FindFirstChild("Backpack")
    if not c then return "Innocent" end
    if c:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then return "Murderer" end
    if c:FindFirstChild("Gun")   or (bp and bp:FindFirstChild("Gun"))   then return "Sheriff" end
    return "Innocent"
end

local function myRole()
    return getRole(LocalPlayer)
end

local function nearestCoin()
    local root = getRoot()
    if not root then return nil, 0 end
    local best  = nil
    local bestD = math.huge
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Coin" and obj:IsA("BasePart") then
            local d = (root.Position - obj.Position).Magnitude
            if d < bestD then
                best  = obj
                bestD = d
            end
        end
    end
    return best, bestD
end

local function findTarget()
    local root = getRoot()
    if not root then return nil end
    local role  = myRole()
    local best  = nil
    local bestD = math.huge
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local tr = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                local d  = (root.Position - tr.Position).Magnitude
                local pr = getRole(plr)
                local valid = (role == "Murderer") or
                              (role == "Sheriff"  and pr == "Murderer") or
                              (role == "Innocent" and pr == "Murderer")
                if valid and d < CFG.CombatRange and d < bestD then
                    best  = plr
                    bestD = d
                end
            end
        end
    end
    return best
end

-- ── NoClip ─────────────────────────────────────────────────
local noClipConn = nil

local function enableNoclip()
    if noClipConn then return end
    noClipConn = RunService.Stepped:Connect(function()
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

local function disableNoclip()
    if noClipConn then
        noClipConn:Disconnect()
        noClipConn = nil
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

-- ── Плавный полёт к монете ─────────────────────────────────
local activeTween = nil

local function flyToCoin(targetPos)
    if activeTween then
        activeTween:Cancel()
        activeTween = nil
    end
    local root = getRoot()
    if not root then return end
    local dist     = (root.Position - targetPos).Magnitude
    local duration = dist / CFG.FlySpeed
    local goal     = { CFrame = CFrame.new(targetPos + Vector3.new(0, 2.5, 0)) }
    local info     = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    activeTween    = TweenService:Create(root, info, goal)
    activeTween:Play()
    activeTween.Completed:Wait()
    activeTween = nil
end

-- ── GUI ────────────────────────────────────────────────────
local function buildGUI()
    local old = LocalPlayer.PlayerGui:FindFirstChild("MM2FarmHub")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "MM2FarmHub"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = LocalPlayer.PlayerGui

    local frame = Instance.new("Frame")
    frame.Name                 = "Main"
    frame.Size                 = UDim2.new(0, 230, 0, 290)
    frame.Position             = UDim2.new(0, 12, 0.3, 0)
    frame.BackgroundColor3     = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel      = 0
    frame.Parent               = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local titleBar = Instance.new("Frame")
    titleBar.Size             = UDim2.new(1, 0, 0, 38)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
    titleBar.BorderSizePixel  = 0
    titleBar.Parent           = frame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

    local fixCorner = Instance.new("Frame")
    fixCorner.Size             = UDim2.new(1, 0, 0, 12)
    fixCorner.Position         = UDim2.new(0, 0, 1, -12)
    fixCorner.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
    fixCorner.BorderSizePixel  = 0
    fixCorner.Parent           = titleBar

    local title = Instance.new("TextLabel")
    title.Size               = UDim2.new(1, -12, 1, 0)
    title.Position           = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text               = "MM2 Farm Hub"
    title.TextColor3         = Color3.new(1, 1, 1)
    title.TextSize           = 15
    title.Font               = Enum.Font.GothamBold
    title.TextXAlignment     = Enum.TextXAlignment.Left
    title.Parent             = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size             = UDim2.new(0, 30, 0, 30)
    closeBtn.Position         = UDim2.new(1, -34, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    closeBtn.Text             = "X"
    closeBtn.TextColor3       = Color3.new(1, 1, 1)
    closeBtn.TextSize         = 14
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.BorderSizePixel  = 0
    closeBtn.Parent           = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)

    local dragging  = false
    local dragStart = nil
    local startPos  = nil

    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or
           inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            startPos  = frame.Position
        end
    end)

    titleBar.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or
           inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UIS.InputChanged:Connect(function(inp)
        if dragging then
            if inp.UserInputType == Enum.UserInputType.Touch or
               inp.UserInputType == Enum.UserInputType.MouseMove then
                local delta = inp.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end
    end)

    local statsFrame = Instance.new("Frame")
    statsFrame.Size             = UDim2.new(1, -16, 0, 75)
    statsFrame.Position         = UDim2.new(0, 8, 0, 46)
    statsFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    statsFrame.BorderSizePixel  = 0
    statsFrame.Parent           = frame
    Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 8)

    local function makeLbl(text, posY)
        local lbl = Instance.new("TextLabel")
        lbl.Size             = UDim2.new(1, -10, 0, 22)
        lbl.Position         = UDim2.new(0, 8, 0, posY)
        lbl.BackgroundTransparency = 1
        lbl.Text             = text
        lbl.TextColor3       = Color3.fromRGB(210, 210, 210)
        lbl.TextSize         = 13
        lbl.Font             = Enum.Font.Gotham
        lbl.TextXAlignment   = Enum.TextXAlignment.Left
        lbl.Parent           = statsFrame
        return lbl
    end

    local lblCoins  = makeLbl("Монет:   0",  4)
    local lblFlings = makeLbl("Флингов: 0", 27)
    local lblRole   = makeLbl("Роль:    —", 50)

    local function makeToggle(labelText, stateKey, yPos, clrOn, clrOff)
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(1, -16, 0, 48)
        btn.Position         = UDim2.new(0, 8, 0, yPos)
        btn.BorderSizePixel  = 0
        btn.Font             = Enum.Font.GothamBold
        btn.TextSize         = 14
        btn.TextColor3       = Color3.new(1, 1, 1)
        btn.Parent           = frame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        local function refresh()
            if State[stateKey] then
                btn.BackgroundColor3 = clrOn
                btn.Text = labelText .. "  [ВКЛ]"
            else
                btn.BackgroundColor3 = clrOff
                btn.Text = labelText .. "  [ВЫКЛ]"
            end
        end
        refresh()

        btn.MouseButton1Click:Connect(function()
            State[stateKey] = not State[stateKey]
            if stateKey == "NoClip" then
                if State.NoClip then enableNoclip() else disableNoclip() end
            end
            refresh()
        end)

        return btn
    end

    makeToggle("FARM COINS", "CoinFarm", 130, Color3.fromRGB(30,160,60),  Color3.fromRGB(75,75,75))
    makeToggle("COMBAT",     "Combat",   186, Color3.fromRGB(200,60,60),  Color3.fromRGB(75,75,75))
    makeToggle("NOCLIP",     "NoClip",   242, Color3.fromRGB(100,60,200), Color3.fromRGB(75,75,75))

    task.spawn(function()
        while sg and sg.Parent do
            task.wait(0.5)
            pcall(function()
                lblCoins.Text  = "Монет:   " .. tostring(Stats.Coins)
                lblFlings.Text = "Флингов: " .. tostring(Stats.Flings)
                local r = myRole()
                if r == "Murderer" then
                    lblRole.Text      = "Роль: Убийца"
                    lblRole.TextColor3 = Color3.fromRGB(255, 80, 80)
                elseif r == "Sheriff" then
                    lblRole.Text      = "Роль: Шериф"
                    lblRole.TextColor3 = Color3.fromRGB(80, 140, 255)
                else
                    lblRole.Text      = "Роль: Невин."
                    lblRole.TextColor3 = Color3.fromRGB(80, 220, 80)
                end
            end)
        end
    end)
end

-- ── Главный цикл ───────────────────────────────────────────
local lastCombat = 0

task.spawn(function()
    task.wait(3)
    print("[MM2Hub] Started!")
    buildGUI()
    enableNoclip()

    while State.Running do
        task.wait(rnd(CFG.MinDelay, CFG.MaxDelay))

        if isAlive() then
            local root = getRoot()
            if root then
                if State.Combat then
                    local now = tick()
                    if now - lastCombat >= CFG.CombatDelay then
                        local target = findTarget()
                        if target and target.Character then
                            local tr = target.Character:FindFirstChild("HumanoidRootPart")
                            if tr then
                                pcall(function()
                                    local f = CFG.FlingForce
                                    tr.AssemblyLinearVelocity = Vector3.new(
                                        rnd(-f, f), f * 1.2, rnd(-f, f)
                                    )
                                end)
                                Stats.Flings = Stats.Flings + 1
                                lastCombat   = now
                            end
                        end
                    end
                end

                if State.CoinFarm then
                    local coin, dist = nearestCoin()
                    if coin then
                        if dist > 3 then
                            flyToCoin(coin.Position)
                        else
                            task.wait(rnd(0.1, 0.2))
                        end
                        Stats.Coins = Stats.Coins + 1
                    end
                end
            end
        else
            task.wait(1)
        end
    end
end)

LocalPlayer.CharacterRemoving:Connect(function()
    if activeTween then
        activeTween:Cancel()
        activeTween = nil
    end
    disableNoclip()
    Stats.Rounds = Stats.Rounds + 1
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if State.NoClip then enableNoclip() end
end)

print("[MM2Hub] Loaded.")
