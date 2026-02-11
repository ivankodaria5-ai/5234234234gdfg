-- Murder Mystery 2 Auto Server Hop
-- Загружает MM2 скрипт и переподключается каждую минуту

local PLACE_ID = 142823291 -- Murder Mystery 2
local MM2_SCRIPT_URL = "https://raw.githubusercontent.com/Azura83/Murder-Mystery-2/refs/heads/main/Script.lua"
local HOP_INTERVAL = 60 -- 1 минута

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

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

-- Функция переподключения на новый сервер
local function serverHop()
    print("[MM2 AutoHop] Поиск нового сервера...")
    
    -- Сохраняем скрипт для автозагрузки на новом сервере
    queue_on_teleport([[
        repeat task.wait() until game:IsLoaded()
        task.wait(3)
        
        loadstring(game:HttpGet("https://raw.githubusercontent.com/ivankodaria5-ai/5234234234gdfg/refs/heads/main/server_hopper.lua"))()
    ]])
    
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
    serverHop()
end)

-- Запуск таймера переподключения
print(string.format("[MM2 AutoHop] Автоматическое переподключение каждые %d секунд", HOP_INTERVAL))

task.spawn(function()
    while true do
        task.wait(HOP_INTERVAL)
        serverHop()
    end
end)

print("[MM2 AutoHop] Скрипт активен!")
