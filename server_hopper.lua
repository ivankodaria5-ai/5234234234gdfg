-- Murder Mystery 2 Auto Server Hop
-- Загружает MM2 скрипт и переподключается каждую минуту

local PLACE_ID = 142823291 -- Murder Mystery 2
local MM2_SCRIPT_URL = "https://raw.githubusercontent.com/Azura83/Murder-Mystery-2/refs/heads/main/Script.lua"
local SCRIPT_URL = "https://raw.githubusercontent.com/ivankodaria5-ai/5234234234gdfg/refs/heads/main/server_hopper.lua"
local HOP_INTERVAL = 60 -- 1 минута

-- Проверяем, не запущен ли уже скрипт
if _G.MM2AutoHopRunning then
    warn("[MM2 AutoHop] Скрипт уже запущен!")
    return
end
_G.MM2AutoHopRunning = true

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("[MM2 AutoHop] v1.0 - Запуск скрипта...")

-- Функция клика по кнопке выбора устройства
local function clickDeviceButton()
    print("[MM2 AutoHop] Поиск кнопки выбора устройства...")
    
    task.wait(2) -- Ждем загрузки GUI
    
    local playerGui = player:WaitForChild("PlayerGui", 10)
    if not playerGui then return false end
    
    -- Ищем GUI с выбором устройства
    for _, gui in pairs(playerGui:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local text = gui.Text or ""
            local name = gui.Name or ""
            
            -- Проверяем на наличие ключевых слов
            if text:lower():find("телефон") or text:lower():find("phone") or 
               name:lower():find("phone") or name:lower():find("mobile") then
                print("[MM2 AutoHop] Найдена кнопка устройства, кликаем...")
                
                -- Симулируем клик
                for _, connection in pairs(getconnections(gui.MouseButton1Click)) do
                    connection:Fire()
                end
                
                task.wait(1)
                return true
            end
        end
    end
    
    -- Если не нашли по тексту, пробуем кликнуть по позиции (правее от центра)
    local screenGui = playerGui:FindFirstChild("ScreenGui") or playerGui:GetChildren()[1]
    if screenGui then
        for _, gui in pairs(screenGui:GetDescendants()) do
            if gui:IsA("GuiButton") and gui.Visible then
                local pos = gui.AbsolutePosition
                local size = gui.AbsoluteSize
                local screenSize = workspace.CurrentCamera.ViewportSize
                
                -- Проверяем, что кнопка правее центра и в центре по вертикали
                if pos.X > screenSize.X * 0.5 and pos.Y > screenSize.Y * 0.3 and pos.Y < screenSize.Y * 0.7 then
                    print("[MM2 AutoHop] Кликаем по кнопке справа...")
                    for _, connection in pairs(getconnections(gui.MouseButton1Click)) do
                        connection:Fire()
                    end
                    task.wait(1)
                    return true
                end
            end
        end
    end
    
    return false
end

-- Загружаем MM2 скрипт после клика
local function loadMM2Script()
    print("[MM2 AutoHop] Загрузка скрипта Murder Mystery 2...")
    
    -- Сначала кликаем по кнопке выбора устройства
    clickDeviceButton()
    
    task.wait(2) -- Даем время на выбор устройства
    
    -- Затем загружаем MM2 скрипт
    task.spawn(function()
        local success, err = pcall(function()
            loadstring(game:HttpGet(MM2_SCRIPT_URL))()
        end)
        if success then
            print("[MM2 AutoHop] Скрипт MM2 успешно загружен!")
        else
            warn("[MM2 AutoHop] Ошибка загрузки скрипта MM2:", err)
        end
    end)
end

-- Запускаем при первом заходе
loadMM2Script()

-- Функция поиска случайного сервера
local function findRandomServer()
    local servers = {}
    local cursor = ""
    
    repeat
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&cursor=%s",
            PLACE_ID,
            cursor
        )
        
        local success, response = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        
        if success and response.data then
            for _, server in ipairs(response.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    table.insert(servers, server.id)
                end
            end
            cursor = response.nextPageCursor or ""
        else
            break
        end
    until cursor == "" or #servers >= 50
    
    return servers[math.random(1, #servers)]
end

-- Переменная для отслеживания времени последнего хопа
_G.MM2LastHopTime = tick()

-- Функция переподключения на новый сервер
local function serverHop()
    print("[MM2 AutoHop] Поиск нового сервера...")
    
    _G.MM2LastHopTime = tick()
    
    -- Пробуем несколько методов автозагрузки для совместимости с разными executor'ами
    local autoloadScript = string.format([[
        repeat task.wait() until game:IsLoaded()
        repeat task.wait() until game.Players.LocalPlayer
        task.wait(3)
        
        print("[MM2 AutoHop] Автозагрузка на новом сервере...")
        
        local success, err = pcall(function()
            loadstring(game:HttpGet("%s?t=" .. tick()))()
        end)
        
        if not success then
            warn("[MM2 AutoHop] Ошибка автозагрузки:", err)
        end
    ]], SCRIPT_URL)
    
    -- Метод 1: queue_on_teleport (работает в большинстве executor'ов)
    local queueSuccess = pcall(function()
        if queue_on_teleport then
            queue_on_teleport(autoloadScript)
            print("[MM2 AutoHop] queue_on_teleport установлен")
        end
    end)
    
    -- Метод 2: syn.queue_on_teleport (для Synapse X)
    pcall(function()
        if syn and syn.queue_on_teleport then
            syn.queue_on_teleport(autoloadScript)
            print("[MM2 AutoHop] syn.queue_on_teleport установлен")
        end
    end)
    
    -- Метод 3: Fluxus queue_on_teleport
    pcall(function()
        if fluxus and fluxus.queue_on_teleport then
            fluxus.queue_on_teleport(autoloadScript)
            print("[MM2 AutoHop] fluxus.queue_on_teleport установлен")
        end
    end)
    
    local serverId = findRandomServer()
    
    if serverId then
        print("[MM2 AutoHop] Найден сервер! Переподключение...")
        TeleportService:TeleportToPlaceInstance(PLACE_ID, serverId, player)
    else
        print("[MM2 AutoHop] Серверы не найдены, обычный телепорт...")
        TeleportService:Teleport(PLACE_ID, player)
    end
end

-- Обработка ошибок телепортации
TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
    warn("[MM2 AutoHop] Ошибка телепортации:", errorMessage)
    task.wait(5)
    
    -- Пробуем снова
    pcall(function()
        serverHop()
    end)
end)

-- Сохраняем состояние в файл (если executor поддерживает)
pcall(function()
    if writefile and readfile then
        writefile("mm2_autohop_active.txt", "true")
        print("[MM2 AutoHop] Состояние сохранено в файл")
    end
end)

-- Защита от краша - автоматический перезапуск (watchdog)
task.spawn(function()
    while task.wait(10) do
        if _G.MM2LastHopTime and tick() - _G.MM2LastHopTime > HOP_INTERVAL + 30 then
            warn("[MM2 AutoHop] Watchdog: Скрипт завис более " .. (HOP_INTERVAL + 30) .. " секунд, попытка перезапуска...")
            pcall(serverHop)
        end
    end
end)

-- Запуск таймера переподключения
print(string.format("[MM2 AutoHop] Автоматическое переподключение каждые %d секунд", HOP_INTERVAL))

task.spawn(function()
    while true do
        task.wait(HOP_INTERVAL)
        
        if _G.MM2AutoHopRunning then
            print("[MM2 AutoHop] Время переподключения!")
            pcall(serverHop)
        else
            print("[MM2 AutoHop] Скрипт остановлен")
            break
        end
    end
end)

print("[MM2 AutoHop] Скрипт активен! JobId: " .. game.JobId)
