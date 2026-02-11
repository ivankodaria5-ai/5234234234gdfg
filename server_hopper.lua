-- Murder Mystery 2 Auto Server Hop
-- Загружает MM2 скрипт и переподключается каждую минуту

local PLACE_ID = 142823291 -- Murder Mystery 2
local MM2_SCRIPT_URL = "https://raw.githubusercontent.com/Azura83/Murder-Mystery-2/refs/heads/main/Script.lua"
local HOP_INTERVAL = 60 -- 1 минута

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Загружаем MM2 скрипт
print("[MM2 AutoHop] Загрузка скрипта Murder Mystery 2...")
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
