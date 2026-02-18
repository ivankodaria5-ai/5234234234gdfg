-- MM2 Auto Server Hop
local PLACE_ID = 142823291
local MM2_SCRIPT_URL = "https://raw.githubusercontent.com/Azura83/Murder-Mystery-2/refs/heads/main/Script.lua"
local SCRIPT_URL = "https://raw.githubusercontent.com/ivankodaria5-ai/5234234234gdfg/refs/heads/main/server_hopper.lua"
local HOP_INTERVAL = 1800

-- Сервисы
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- КЛЮЧЕВОЕ: определяем queueFunc и scriptQueued (как в tools.lua)
local queueFunc = queueonteleport
local scriptQueued = false

print("[MM2] Запуск скрипта | JobId: " .. game.JobId)

-- Загружаем MM2 скрипт
print("[MM2] Загрузка MM2 скрипта...")
task.wait(3)

pcall(function()
    loadstring(game:HttpGet(MM2_SCRIPT_URL .. "?t=" .. tick()))()
    print("[MM2] MM2 скрипт загружен!")
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
    
    if #servers > 0 then
        return servers[math.random(1, #servers)]
    end
    return nil
end

-- Функция serverHop (ТОЧНО как в tools.lua)
local function serverHop()
    print("[MM2] Начинаю поиск нового сервера...")
    
    local serverId = findRandomServer()
    
    if serverId then
        print("[MM2] Найден сервер: " .. serverId)
        
        -- КЛЮЧЕВОЕ: ставим скрипт в очередь ОДИН РАЗ (как в tools.lua)
        local teleportSuccess = pcall(function()
            if not scriptQueued then
                queueFunc('loadstring(game:HttpGet("' .. SCRIPT_URL .. '?t=' .. tick() .. '"))()')
                scriptQueued = true
                print("[MM2] Скрипт поставлен в очередь")
            end
            TeleportService:TeleportToPlaceInstance(PLACE_ID, serverId, player)
        end)
        
        if teleportSuccess then
            print("[MM2] Телепортация запущена")
            return true
        else
            print("[MM2] Ошибка телепортации")
        end
    else
        print("[MM2] Серверы не найдены, случайная телепортация...")
        
        pcall(function()
            if not scriptQueued then
                queueFunc('loadstring(game:HttpGet("' .. SCRIPT_URL .. '?t=' .. tick() .. '"))()')
                scriptQueued = true
                print("[MM2] Скрипт поставлен в очередь")
            end
            TeleportService:Teleport(PLACE_ID, player)
        end)
    end
    
    return false
end

-- Ждем и переподключаемся
print("[MM2] Ожидание " .. HOP_INTERVAL .. " секунд...")
task.wait(HOP_INTERVAL)

print("[MM2] Переподключение...")
serverHop()
