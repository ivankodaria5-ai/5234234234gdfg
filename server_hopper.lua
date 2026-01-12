-- Автоматическое переподключение к серверам с загрузкой скрипта
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Интервал переподключения в секундах (можно изменить)
local RECONNECT_INTERVAL = 300 -- 5 минут (300 секунд)

-- Функция переподключения к серверам
local function ReconnectToServer()
    local localPlayer = Players.LocalPlayer
    
    if not localPlayer then
        return
    end
    
    local placeId = game.PlaceId
    local jobId = game.JobId
    
    -- Получаем список серверов
    local success, servers = pcall(function()
        return TeleportService:GetGameInstancesAsync(placeId)
    end)
    
    if success and servers and #servers > 0 then
        -- Ищем сервер с игроками (но не текущий)
        for _, server in ipairs(servers) do
            if server.JobId ~= jobId and server.Playing > 0 then
                TeleportService:TeleportToPlaceInstance(placeId, server.JobId, localPlayer)
                return
            end
        end
        
        -- Если не нашли подходящий сервер, переподключаемся на новый
        TeleportService:Teleport(placeId)
    else
        -- Если нет серверов или ошибка, просто переподключаемся
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
    end
end

-- Загружаем основной скрипт сразу
LoadMainScript()

-- Экспортируем функцию переподключения
getgenv().ReconnectToServer = ReconnectToServer

-- Автоматическое переподключение через заданный интервал
spawn(function()
    while true do
        wait(RECONNECT_INTERVAL)
        
        -- Переподключаемся к другому серверу
        ReconnectToServer()
        
        -- После переподключения загружаем скрипт снова
        wait(5) -- Ждем немного после телепорта
        LoadMainScript()
    end
end)

print("Скрипт переподключения активирован. Интервал: " .. RECONNECT_INTERVAL .. " секунд")
