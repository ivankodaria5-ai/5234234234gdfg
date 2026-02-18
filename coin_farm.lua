-- MM2 Farm Hub v3 | Mobile GUI | Based on real MM2 structure
-- Compatible with Delta Android (no continue, no +=, pairs() everywhere)

if not game:IsLoaded() then
    game.Loaded:Wait()
end

if _G.MM2HubLoaded then return end
_G.MM2HubLoaded = true

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local UIS           = game:GetService("UserInputService")
local RS            = game:GetService("ReplicatedStorage")
local LocalPlayer   = Players.LocalPlayer

-- ── Настройки ──────────────────────────────────────────────
local FLY_SPEED        = 26    -- скорость тween к монете
local TP_DISTANCE      = 180   -- дистанция при которой телепортируем а не tweenim
local FLING_FORCE      = 80
local COMBAT_RANGE     = 60
local COMBAT_DELAY     = 0.4

-- ── Состояние ──────────────────────────────────────────────
local State = {
    CoinFarm = true,
    Combat   = true,
    NoClip   = true,
    AutoReset = true,   -- убивать себя когда сумка полная
}

local Stats = {
    Coins  = 0,
    Flings = 0,
    Rounds = 0,
}

local farmActive    = false
local activeTween   = nil
local noClipConn    = nil
local lastCombat    = 0

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
    return h ~= nil and h.Health > 0
end

local function rnd(a, b)
    return a + math.random() * (b - a)
end

-- ── Поиск CoinContainer в активной карте ───────────────────
local function getCoinContainer()
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChild("CoinContainer") then
            return v:FindFirstChild("CoinContainer")
        end
    end
    return nil
end

-- ── Поиск ближайшей монеты (проверяем TouchInterest) ───────
local function nearestCoin()
    local root = getRoot()
    if not root then return nil, 0 end
    local container = getCoinContainer()
    if not container then return nil, 0 end

    local best  = nil
    local bestD = math.huge

    for _, coin in pairs(container:GetChildren()) do
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

-- ── Определение роли ───────────────────────────────────────
local function getRole(plr)
    local c  = plr.Character
    local bp = plr:FindFirstChild("Backpack")
    if not c then return "Innocent" end
    if c:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then
        return "Murderer"
    end
    if c:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun")) then
        return "Sheriff"
    end
    return "Innocent"
end

local function myRole()
    return getRole(LocalPlayer)
end

-- ── Цель для боёвки ────────────────────────────────────────
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
                local d   = (root.Position - tr.Position).Magnitude
                local pr  = getRole(plr)
                local ok  = (role == "Murderer") or
                            (role == "Sheriff"  and pr == "Murderer") or
                            (role == "Innocent" and pr == "Murderer")
                if ok and d < COMBAT_RANGE and d < bestD then
                    best  = plr
                    bestD = d
                end
            end
        end
    end

    return best
end

-- ── NoClip ─────────────────────────────────────────────────
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

-- ── Полёт к монете + firetouchinterest ─────────────────────
local function goToCoin(coin)
    if not coin or not coin.Parent then return end
    local root = getRoot()
    if not root then return end

    local dist = (root.Position - coin.Position).Magnitude

    if dist >= TP_DISTANCE then
        -- Далеко — сначала телепортируемся ближе
        pcall(function()
            root.CFrame = CFrame.new(coin.Position + Vector3.new(0, 3, 0))
        end)
        task.wait(0.05)
    end

    -- Плавный tween к монете
    if activeTween then
        activeTween:Cancel()
        activeTween = nil
    end

    dist = (root.Position - coin.Position).Magnitude
    local dur  = math.max(0.1, dist / FLY_SPEED)
    local info = TweenInfo.new(dur, Enum.EasingStyle.Linear)
    local goal = { CFrame = CFrame.new(coin.Position + Vector3.new(0, 2, 0)) }

    activeTween = TweenService:Create(root, info, goal)
    activeTween:Play()

    -- firetouchinterest регистрирует сбор монеты на сервере
    pcall(function()
        firetouchinterest(root, coin, 0)
    end)

    activeTween.Completed:Wait()
    activeTween = nil

    -- Повторно кидаем touch на случай если первый не сработал
    pcall(function()
        firetouchinterest(root, coin, 0)
    end)
end

-- ── AntiAFK ────────────────────────────────────────────────
local function antiAFK()
    local ok = pcall(function()
        local GC = getconnections or get_signal_cons
        if GC then
            for _, v in pairs(GC(LocalPlayer.Idled)) do
                if v.Disable then
                    v:Disable()
                elseif v.Disconnect then
                    v:Disconnect()
                end
            end
        end
    end)
    if not ok then
        pcall(function()
            local VU = cloneref(game:GetService("VirtualUser"))
            LocalPlayer.Idled:Connect(function()
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
            end)
        end)
    end
end

-- ── Слушаем события MM2 ────────────────────────────────────
pcall(function()
    local remotes = RS:WaitForChild("Remotes", 5)
    if not remotes then return end
    local gameplay = remotes:WaitForChild("Gameplay", 5)
    if not gameplay then return end

    -- Раунд начался
    local rsEvent = gameplay:FindFirstChild("RoundStart")
    if rsEvent then
        rsEvent.OnClientEvent:Connect(function()
            farmActive = true
            print("[MM2Hub] Round started - farming!")
        end)
    end

    -- Раунд закончился
    local reEvent = gameplay:FindFirstChild("RoundEndFade")
    if reEvent then
        reEvent.OnClientEvent:Connect(function()
            farmActive = false
            if activeTween then
                activeTween:Cancel()
                activeTween = nil
            end
            Stats.Rounds = Stats.Rounds + 1
            print("[MM2Hub] Round ended.")
        end)
    end

    -- Монета собрана (отслеживаем реальный счётчик)
    local ccEvent = gameplay:FindFirstChild("CoinCollected")
    if ccEvent then
        ccEvent.OnClientEvent:Connect(function(coinType, current, maxCoins)
            Stats.Coins = tonumber(current) or Stats.Coins
            -- Сумка полная — убиваем себя для сброса
            if State.AutoReset and tonumber(current) == tonumber(maxCoins) then
                farmActive = false
                print("[MM2Hub] Bag full! Resetting...")
                task.wait(0.5)
                pcall(function()
                    local h = getHum()
                    if h then h.Health = 0 end
                end)
            end
        end)
    end
end)

-- ── GUI ────────────────────────────────────────────────────
local function buildGUI()
    local old = LocalPlayer.PlayerGui:FindFirstChild("MM2FarmHub")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "MM2FarmHub"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = LocalPlayer.PlayerGui

    -- Главный фрейм
    local frame = Instance.new("Frame")
    frame.Size                   = UDim2.new(0, 235, 0, 310)
    frame.Position               = UDim2.new(0, 10, 0.25, 0)
    frame.BackgroundColor3       = Color3.fromRGB(14, 14, 20)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel        = 0
    frame.Parent                 = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    -- Заголовок
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

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size             = UDim2.new(1, -50, 1, 0)
    titleLbl.Position         = UDim2.new(0, 12, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text             = "MM2 Farm Hub"
    titleLbl.TextColor3       = Color3.new(1, 1, 1)
    titleLbl.TextSize         = 15
    titleLbl.Font             = Enum.Font.GothamBold
    titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
    titleLbl.Parent           = hdr

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size             = UDim2.new(0, 32, 0, 32)
    closeBtn.Position         = UDim2.new(1, -36, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(215, 45, 45)
    closeBtn.Text             = "X"
    closeBtn.TextColor3       = Color3.new(1, 1, 1)
    closeBtn.TextSize         = 14
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.BorderSizePixel  = 0
    closeBtn.Parent           = hdr
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)

    -- Drag
    local dragging  = false
    local dragStart = nil
    local startPos  = nil

    hdr.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or
           inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            startPos  = frame.Position
        end
    end)

    hdr.InputEnded:Connect(function(inp)
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
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end
    end)

    -- Блок статы
    local sf = Instance.new("Frame")
    sf.Size             = UDim2.new(1, -16, 0, 78)
    sf.Position         = UDim2.new(0, 8, 0, 48)
    sf.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    sf.BorderSizePixel  = 0
    sf.Parent           = frame
    Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 8)

    local function mkLbl(txt, y)
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

    local lCoins  = mkLbl("Монет:   0",  4)
    local lFlings = mkLbl("Флингов: 0", 27)
    local lRole   = mkLbl("Роль:    —", 50)

    -- Кнопки
    local function mkBtn(label, key, y, cOn, cOff)
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
                b.Text = label .. "  [ON]"
            else
                b.BackgroundColor3 = cOff
                b.Text = label .. "  [OFF]"
            end
        end
        upd()

        b.MouseButton1Click:Connect(function()
            State[key] = not State[key]
            if key == "NoClip" then
                if State.NoClip then enableNoclip() else disableNoclip() end
            end
            upd()
        end)
    end

    mkBtn("FARM COINS",  "CoinFarm",   134, Color3.fromRGB(28,155,55),  Color3.fromRGB(70,70,70))
    mkBtn("COMBAT",      "Combat",     190, Color3.fromRGB(195,55,55),  Color3.fromRGB(70,70,70))
    mkBtn("NOCLIP",      "NoClip",     246, Color3.fromRGB(95,55,200),  Color3.fromRGB(70,70,70))

    -- Обновление статы
    task.spawn(function()
        while sg and sg.Parent do
            task.wait(0.5)
            pcall(function()
                lCoins.Text  = "Монет:   " .. tostring(Stats.Coins)
                lFlings.Text = "Флингов: " .. tostring(Stats.Flings)
                local r = myRole()
                if r == "Murderer" then
                    lRole.Text      = "Роль: Убийца"
                    lRole.TextColor3 = Color3.fromRGB(255, 75, 75)
                elseif r == "Sheriff" then
                    lRole.Text      = "Роль: Шериф"
                    lRole.TextColor3 = Color3.fromRGB(75, 135, 255)
                else
                    lRole.Text      = "Роль: Невин."
                    lRole.TextColor3 = Color3.fromRGB(75, 215, 75)
                end
            end)
        end
    end)
end

-- ── Главный цикл ───────────────────────────────────────────
task.spawn(function()
    task.wait(3)
    buildGUI()
    enableNoclip()
    antiAFK()
    farmActive = true   -- начинаем сразу, не ждём события
    print("[MM2Hub] Started!")

    while true do
        task.wait(rnd(0.05, 0.15))

        -- Боёвка
        if State.Combat and isAlive() then
            local now = tick()
            if now - lastCombat >= COMBAT_DELAY then
                local tgt = findTarget()
                if tgt and tgt.Character then
                    local tr = tgt.Character:FindFirstChild("HumanoidRootPart")
                    if tr then
                        pcall(function()
                            local f = FLING_FORCE
                            tr.AssemblyLinearVelocity = Vector3.new(
                                rnd(-f, f), f * 1.3, rnd(-f, f)
                            )
                        end)
                        Stats.Flings = Stats.Flings + 1
                        lastCombat = now
                    end
                end
            end
        end

        -- Фарм
        if State.CoinFarm and farmActive and isAlive() then
            local coin, dist = nearestCoin()
            if coin then
                goToCoin(coin)
            else
                -- Монет нет — ждём
                task.wait(1)
            end
        end
    end
end)

-- Ресспавн
LocalPlayer.CharacterRemoving:Connect(function()
    if activeTween then
        activeTween:Cancel()
        activeTween = nil
    end
    disableNoclip()
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    farmActive = true
    if State.NoClip then enableNoclip() end
    print("[MM2Hub] Respawned, continuing...")
end)

print("[MM2Hub] Loaded. GUI in 3s.")
