-- ==================== НАСТРОЙКИ ====================
-- ИЗМЕНИТЕ ЭТИ ПАРАМЕТРЫ ПОД ВАШУ ИГРУ
local CONFIG = {
    -- ID игры (найдите в URL: roblox.com/games/PLACE_ID/)
    PLACE_ID = 142823291,  -- ЗАМЕНИТЕ НА ID ВАШЕЙ ИГРЫ
    
    -- Параметры сервера для server hop
    MIN_PLAYERS = 5,        -- Минимум игроков на сервере
    MAX_PLAYERS = 30,       -- Максимум игроков на сервере
    
    -- Текст для отправки в чат
    CHAT_MESSAGE = "S3ll ur Godlie with R B L X. PW",  -- ВАШЕ СООБЩЕНИЕ
    
    -- Интервалы (в секундах)
    MESSAGE_INTERVAL = 5,   -- Интервал между сообщениями
    TIME_BEFORE_HOP = 10,   -- Время работы перед сменой сервера (5 минут)
    
    -- URL скрипта для автозагрузки после телепорта
    -- Если нужна автозагрузка - замени на свою ссылку с GitHub
    -- Если не нужна - оставь nil или закомментируй
    SCRIPT_URL = "https://raw.githubusercontent.com/ivankodaria5-ai/5234234234gdfg/refs/heads/main/server_hopper.lua"  -- ЗАМЕНИ НА СВОЮ ССЫЛКУ или оставь nil
}

-- ==================== СЕРВИСЫ ====================
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- HTTP и Queue функции для разных эксплойтов
local httprequest = (syn and syn.request) or 
                    (http and http.request) or 
                    http_request or 
                    (fluxus and fluxus.request) or 
                    request

local queueFunc = queueonteleport or 
                  queue_on_teleport or 
                  (syn and syn.queue_on_teleport) or 
                  function() warn("[HOP] Queue not supported!") end

-- ==================== ФУНКЦИЯ ОТПРАВКИ В ЧАТ ====================
local function sendChat(message)
    print("[CHAT] Отправка: " .. message)
    
    -- Попытка отправить через TextChatService (новый чат)
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local success = pcall(function()
            local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if channel then
                channel:SendAsync(message)
            end
        end)
        if success then return end
    end
    
    -- Попытка отправить через Legacy Chat (старый чат)
    local success = pcall(function()
        local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if chatEvents then
            local sayMessage = chatEvents:FindFirstChild("SayMessageRequest")
            if sayMessage then
                sayMessage:FireServer(message, "All")
            end
        end
    end)
end

-- ==================== ФУНКЦИЯ СМЕНЫ СЕРВЕРА ====================
local function serverHop()
    print("[HOP] Начинаем поиск нового сервера...")
    
    local cursor = ""
    local hopped = false
    
    while not hopped do
        -- Формируем URL для получения списка серверов
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            CONFIG.PLACE_ID,
            cursor ~= "" and "&cursor=" .. cursor or ""
        )
        
        -- Запрос к API Roblox
        local success, response = pcall(function()
            return httprequest({Url = url, Method = "GET"})
        end)
        
        if not success or not response then
            warn("[HOP] Ошибка HTTP запроса, повтор через 5 сек...")
            task.wait(5)
            cursor = ""
            continue
        end
        
        -- Парсим ответ
        local bodySuccess, body = pcall(function() 
            return HttpService:JSONDecode(response.Body) 
        end)
        
        if bodySuccess and body and body.data then
            local servers = {}
            
            -- Фильтруем серверы по параметрам
            for _, server in pairs(body.data) do
                if server.id ~= game.JobId 
                    and server.playing >= CONFIG.MIN_PLAYERS 
                    and server.playing <= CONFIG.MAX_PLAYERS then
                    table.insert(servers, server)
                end
            end
            
            -- Сортируем по количеству игроков (больше игроков = лучше)
            table.sort(servers, function(a, b) 
                return (a.playing or 0) > (b.playing or 0) 
            end)
            
            if #servers > 0 then
                print("[HOP] Найдено " .. #servers .. " подходящих серверов")
                
                -- Пробуем телепортироваться на первый подходящий сервер
                for _, server in ipairs(servers) do
                    local playing = server.playing or "?"
                    local maxPlayers = server.maxPlayers or "?"
                    print("[HOP] Подключение к серверу " .. server.id .. " (" .. playing .. "/" .. maxPlayers .. ")")
                    
                    -- Ставим скрипт в очередь для автозагрузки (если указан URL)
                    if CONFIG.SCRIPT_URL and CONFIG.SCRIPT_URL ~= "" then
                        print("[HOP] Автозагрузка включена: " .. CONFIG.SCRIPT_URL)
                        queueFunc('loadstring(game:HttpGet("' .. CONFIG.SCRIPT_URL .. '"))()')
                    else
                        print("[HOP] Автозагрузка отключена (SCRIPT_URL не указан)")
                    end
                    
                    -- Телепортируемся
                    local tpSuccess, tpError = pcall(function()
                        TeleportService:TeleportToPlaceInstance(
                            CONFIG.PLACE_ID, 
                            server.id, 
                            player
                        )
                    end)
                    
                    if tpSuccess then
                        print("[HOP] Телепортация начата! До встречи...")
                        hopped = true
                        task.wait(15)  -- Ждем телепортацию
                        break
                    else
                        warn("[HOP] Ошибка телепортации: " .. tostring(tpError))
                        task.wait(1)
                    end
                end
            else
                print("[HOP] На этой странице нет подходящих серверов")
            end
            
            -- Переход на следующую страницу
            if body.nextPageCursor and not hopped then
                cursor = body.nextPageCursor
                print("[HOP] Проверяем следующую страницу...")
            else
                if not hopped then
                    warn("[HOP] Подходящих серверов не найдено. Повтор через 10 сек...")
                    task.wait(10)
                    cursor = ""
                end
            end
        else
            warn("[HOP] Ошибка парсинга ответа, повтор через 5 сек...")
            task.wait(5)
            cursor = ""
        end
    end
end

-- ==================== ОСНОВНАЯ ЛОГИКА ====================
local function main()
    print("=== ЧАТ-БОТ С АВТОСМЕНОЙ СЕРВЕРОВ ===")
    print("=== Place ID: " .. CONFIG.PLACE_ID .. " ===")
    print("=== Сообщение: '" .. CONFIG.CHAT_MESSAGE .. "' ===")
    
    -- Ждем загрузки персонажа
    if not player.Character then
        print("[MAIN] Ожидание загрузки персонажа...")
        player.CharacterAdded:Wait()
        task.wait(2)
    end
    
    print("[MAIN] Старт работы бота!")
    
    local startTime = tick()
    local messageCount = 0
    
    -- Основной цикл: отправляем сообщения
    while true do
        -- Проверяем, не пора ли менять сервер
        local elapsedTime = tick() - startTime
        if elapsedTime >= CONFIG.TIME_BEFORE_HOP then
            print("[MAIN] Время истекло (" .. math.floor(elapsedTime) .. " сек)")
            print("[MAIN] Отправлено сообщений: " .. messageCount)
            print("[MAIN] Переключаемся на другой сервер...")
            serverHop()
            break
        end
        
        -- Отправляем сообщение в чат
        sendChat(CONFIG.CHAT_MESSAGE)
        messageCount = messageCount + 1
        
        -- Информация о прогрессе
        local remaining = CONFIG.TIME_BEFORE_HOP - elapsedTime
        print(string.format(
            "[MAIN] Сообщений: %d | До смены сервера: %d сек", 
            messageCount, 
            math.floor(remaining)
        ))
        
        -- Ждем до следующего сообщения
        task.wait(CONFIG.MESSAGE_INTERVAL)
    end
    
    print("=== БОТ ЗАВЕРШЕН ===")
end

-- ==================== ЗАПУСК ====================
-- Запускаем основную функцию с защитой от ошибок
local success, error = pcall(main)
if not success then
    warn("[ERROR] Критическая ошибка: " .. tostring(error))
end

