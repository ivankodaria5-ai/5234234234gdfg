-- Murder Mystery 2 Auto Server Hop v2.0
local PLACE_ID = 142823291
local MM2_SCRIPT_URL = "https://raw.githubusercontent.com/Azura83/Murder-Mystery-2/refs/heads/main/Script.lua"
local SCRIPT_URL = "https://raw.githubusercontent.com/ivankodaria5-ai/5234234234gdfg/refs/heads/main/server_hopper.lua"
local HOP_INTERVAL = 60

-- Проверка на повторный запуск
if _G.MM2AutoHopRunning then
    warn("[MM2] Скрипт уже запущен!")
    return
end
_G.MM2AutoHopRunning = true

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Определяем функцию queue (как в tools.lua)
local queueFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

print("[MM2] Запуск v2.0 | JobId: " .. game.JobId)

-- Загрузка MM2 скрипта
print("[MM2] Загрузка MM2 скрипта...")
task.wait(3) -- Ждем загрузки игры

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

-- Функция server hop (по образцу tools.lua)
local function serverHop()
    print("[MM2] Начинаю поиск нового сервера...")
    
    -- Ставим скрипт в очередь для автозагрузки (как в tools.lua)
    if queueFunc then
        queueFunc('loadstring(game:HttpGet("' .. SCRIPT_URL .. '?t=' .. tick() .. '"))()')
        print("[MM2] Скрипт поставлен в очередь автозагрузки")
    else
        warn("[MM2] queue_on_teleport недоступен!")
    end
    
    -- Поиск случайного сервера
    local serverId = findRandomServer()
    
    if serverId then
        print("[MM2] Найден сервер " .. serverId .. ", телепортация...")
        TeleportService:TeleportToPlaceInstance(PLACE_ID, serverId, player)
    else
        print("[MM2] Случайная телепортация...")
        TeleportService:Teleport(PLACE_ID, player)
    end
end

-- Таймер переподключения
print("[MM2] Ожидание " .. HOP_INTERVAL .. " секунд до переподключения...")
task.wait(HOP_INTERVAL)

-- Переподключение
print("[MM2] Время вышло, переподключаюсь...")
serverHop()
