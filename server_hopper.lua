-- Автоматическое переподключение к серверам с загрузкой скрипта
-- Скрипт автоматически перезагружается после каждого телепорта
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Интервал переподключения в секундах (можно изменить)
local RECONNECT_INTERVAL = 300 -- 5 минут (300 секунд)

-- Флаг для предотвращения множественных запусков
if getgenv().ServerHopperActive then
    return
end
getgenv().ServerHopperActive = true

-- Сохраняем данные для переподключения после телепорта
TeleportService:SetTeleportData({ServerHopper = true})

-- Функция переподключения к серверам
local function ReconnectToServer()
    local localPlayer = Players.LocalPlayer
    
    if not localPlayer then
        return
    end
    
    local placeId = game.PlaceId
    local jobId = game.JobId
    
    print("Ищу новый сервер для переподключения...")
    
    -- Получаем список серверов
    local success, servers = pcall(function()
        return TeleportService:GetGameInstancesAsync(placeId)
    end)
    
    if success and servers and #servers > 0 then
        -- Ищем сервер с игроками (но не текущий)
        for _, server in ipairs(servers) do
            if server.JobId ~= jobId and server.Playing > 0 then
                print("Переподключаюсь на сервер: " .. server.JobId)
                TeleportService:TeleportToPlaceInstance(placeId, server.JobId, localPlayer)
                return
            end
        end
        
        -- Если не нашли подходящий сервер, переподключаемся на новый
        print("Создаю новый сервер...")
        TeleportService:Teleport(placeId)
    else
        -- Если нет серверов или ошибка, просто переподключаемся
        print("Создаю новый сервер...")
        TeleportService:Teleport(placeId)
    end
end

-- Загружаем и выполняем ваш скрипт с GitHub
local function LoadMainScript()
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Azura83/Murder-Mystery-2/refs/heads/main/Script.lua"))()
    end)
    
    if not success then
        warn("Ошибка загрузки скрипта: " .. tostring(err))
    else
        print("Основной скрипт успешно загружен!")
    end
end

-- Загружаем основной скрипт сразу
LoadMainScript()

-- Экспортируем функцию переподключения
getgenv().ReconnectToServer = ReconnectToServer

-- Функция запуска цикла переподключения
local function StartReconnectLoop()
    if getgenv().ReconnectLoopRunning then
        return
    end
    getgenv().ReconnectLoopRunning = true
    
    spawn(function()
        while true do
            wait(RECONNECT_INTERVAL)
            
            print("Время переподключения! Интервал: " .. RECONNECT_INTERVAL .. " секунд (" .. math.floor(RECONNECT_INTERVAL / 60) .. " минут)")
            
            -- Переподключаемся к другому серверу
            ReconnectToServer()
        end
    end)
end

-- Ожидаем загрузки игрока после телепорта
local localPlayer = Players.LocalPlayer
if localPlayer then
    -- Загружаем скрипт сразу если персонаж уже есть
    if localPlayer.Character then
        spawn(function()
            wait(2)
            LoadMainScript()
        end)
    end
    
    -- Загружаем скрипт после каждого телепорта и перезапускаем цикл
    localPlayer.CharacterAdded:Connect(function()
        wait(3) -- Ждем полной загрузки персонажа
        LoadMainScript()
        
        -- Сбрасываем флаг и перезапускаем цикл переподключения после телепорта
        getgenv().ReconnectLoopRunning = false
        wait(2)
        StartReconnectLoop()
        
        -- Автоматически перезагружаем скрипт с GitHub для продолжения работы после телепорта
        spawn(function()
            wait(5)
            -- Проверяем, не загружали ли уже скрипт (чтобы избежать рекурсии)
            if not getgenv().ServerHopperReloading then
                getgenv().ServerHopperReloading = true
                local success, script = pcall(function()
                    return game:HttpGet("https://raw.githubusercontent.com/ivankodaria5-ai/5234234234gdfg/refs/heads/main/server_hopper.lua")
                end)
                if success and script then
                    -- Сбрасываем флаг перед загрузкой, чтобы новый экземпляр мог работать
                    getgenv().ServerHopperActive = false
                    getgenv().ServerHopperReloading = false
                    loadstring(script)()
                else
                    getgenv().ServerHopperReloading = false
                end
            end
        end)
    end)
end

-- Запускаем цикл переподключения сразу
StartReconnectLoop()

print("Скрипт переподключения активирован. Интервал: " .. RECONNECT_INTERVAL .. " секунд (" .. math.floor(RECONNECT_INTERVAL / 60) .. " минут)")
print("Скрипт будет автоматически перезагружаться после каждого телепорта!")
