-- Автоматическое переподключение к серверам с загрузкой скрипта
-- Скрипт автоматически перезагружается после каждого телепорта
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

-- Функция для сохранения скрипта на выполнение после телепорта
local queueFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport) or (getgenv and getgenv().queue_on_teleport) or function(code)
    print("⚠️ queueonteleport не поддерживается, используем альтернативный метод")
end

-- URL скрипта для автоматической загрузки
local SCRIPT_URL = "https://raw.githubusercontent.com/ivankodaria5-ai/5234234234gdfg/refs/heads/main/server_hopper.lua"

-- Сохраняем скрипт в getgenv() для автоматической загрузки после телепорта
local function saveScriptForAutoLoad()
    if not getgenv().AutoLoadScript then
        getgenv().AutoLoadScript = SCRIPT_URL
        print("💾 Скрипт сохранен для автоматической загрузки")
    end
end

-- Функция автоматической загрузки скрипта при запуске (для мобильных)
local function autoLoadScriptOnStart()
    -- Проверяем, нужно ли загрузить скрипт
    if getgenv().AutoLoadScript and getgenv().AutoLoadScript == SCRIPT_URL then
        local lastJobId = getgenv().LastJobId
        local currentJobId = game.JobId
        
        -- Если JobId изменился или это первый запуск после телепорта
        if lastJobId and lastJobId ~= currentJobId then
            print("🔄 Обнаружена смена сервера! Загружаю скрипт автоматически...")
            spawn(function()
                wait(2) -- Небольшая задержка для стабильности
                
                local success, script = pcall(function()
                    return game:HttpGet(SCRIPT_URL, true)
                end)
                
                if success and script and #script > 100 then
                    print("✅ Скрипт получен, перезагружаю...")
                    -- Сбрасываем флаги
                    getgenv().ServerHopperActive = false
                    getgenv().ReconnectLoopRunning = false
                    getgenv().MainScriptLoaded = false
                    -- Загружаем скрипт
                    local func, loadErr = loadstring(script)
                    if func then
                        func()
                        return
                    else
                        print("❌ Ошибка компиляции: " .. tostring(loadErr))
                    end
                else
                    print("⚠️ Не удалось загрузить скрипт с GitHub")
                end
            end)
        end
    end
end

-- Сохраняем скрипт для автоматической загрузки
saveScriptForAutoLoad()

-- Интервал переподключения в секундах (можно изменить)
local RECONNECT_INTERVAL = 10 -- 10 секунд для тестирования (было 300 = 5 минут)

-- Проверяем доступность getgenv
if not getgenv then
    local errorMsg = "❌ КРИТИЧЕСКАЯ ОШИБКА: getgenv не доступен! Убедитесь, что используете правильный executor."
    print(errorMsg)
    warn(errorMsg)
    error(errorMsg)
end

-- Проверяем, был ли телепорт (через сохраненные данные и JobId)
local teleportData = TeleportService:GetLocalPlayerTeleportData()
local currentJobId = game.JobId
local wasTeleported = false

-- Проверяем через сохраненные данные
if teleportData and teleportData.ServerHopper == true then
    wasTeleported = true
    print("🔄 Обнаружен телепорт через TeleportData")
end

-- Проверяем через сохраненный JobId (если JobId изменился, значит был телепорт)
if getgenv().LastJobId and getgenv().LastJobId ~= currentJobId then
    wasTeleported = true
    print("🔄 JobId изменился: " .. tostring(getgenv().LastJobId) .. " -> " .. tostring(currentJobId))
end

-- Проверяем через workspace (резервный метод для мобильных)
local workspaceStorage = workspace:FindFirstChild("ServerHopperStorage")
if workspaceStorage and workspaceStorage.Value == SCRIPT_URL then
    if getgenv().LastJobId and getgenv().LastJobId ~= currentJobId then
        wasTeleported = true
        print("🔄 Обнаружен телепорт через workspace storage")
    end
end

-- Сохраняем текущий JobId
getgenv().LastJobId = currentJobId

-- Флаг для предотвращения множественных запусков (только если не был телепорт)
if not wasTeleported then
    if getgenv().ServerHopperActive then
        print("⚠️ Скрипт уже запущен!")
        return
    end
    getgenv().ServerHopperActive = true
else
    -- Если был телепорт, сбрасываем флаг для нового экземпляра
    getgenv().ServerHopperActive = false
    getgenv().ReconnectLoopRunning = false
    getgenv().MainScriptLoaded = false
    print("🔄 Обнаружен телепорт! Перезагружаю скрипт...")
    
    -- Автоматически загружаем скрипт с GitHub
    spawn(function()
        wait(2)
        local success, script = pcall(function()
            return game:HttpGet(SCRIPT_URL, true)
        end)
        
        if success and script and #script > 100 then
            print("✅ Скрипт получен с GitHub, перезагружаю...")
            local func, loadErr = loadstring(script)
            if func then
                func()
                return
            else
                print("❌ Ошибка компиляции: " .. tostring(loadErr))
                getgenv().ServerHopperActive = true
            end
        else
            print("⚠️ Не удалось загрузить скрипт, продолжаю работу...")
            getgenv().ServerHopperActive = true
        end
    end)
    
    -- Ждем загрузки скрипта
    wait(3)
    if not getgenv().ServerHopperActive then
        return -- Скрипт загрузился, прерываем выполнение
    end
end

print("✅ Скрипт инициализирован успешно!")

-- Создаем GUI для отображения статуса и ошибок
local function CreateDebugGUI()
    local success, screenGui = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "ServerHopperDebug"
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.ResetOnSpawn = false
        gui.Parent = CoreGui
        return gui
    end)
    
    if not success then
        print("⚠️ Не удалось создать GUI (возможно, мобильное устройство). Используется только консоль.")
        return nil
    end
    
    local screenGui = screenGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 350, 0, 200)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    title.BorderSizePixel = 0
    title.Text = "🔧 Server Hopper Debug"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = title
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, -20, 0, 100)
    statusLabel.Position = UDim2.new(0, 10, 0, 40)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Статус: Загрузка..."
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextYAlignment = Enum.TextYAlignment.Top
    statusLabel.TextWrapped = true
    statusLabel.Parent = mainFrame
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 100, 0, 30)
    closeBtn.Position = UDim2.new(1, -110, 1, -40)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "Закрыть"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.Gotham
    closeBtn.Parent = mainFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Функция для обновления статуса
    local function UpdateStatus(text, color)
        statusLabel.Text = text
        statusLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    end
    
    getgenv().UpdateDebugStatus = UpdateStatus
    return screenGui
end

-- Создаем GUI
local debugGUI = CreateDebugGUI()
if debugGUI then
    getgenv().UpdateDebugStatus("✅ Скрипт запущен! Проверяю подключение...", Color3.fromRGB(100, 255, 100))
    print("🔧 Server Hopper Debug GUI создан!")
else
    print("🔧 Server Hopper запущен (GUI недоступен, используйте консоль executor'а)")
end

-- Сохраняем данные для переподключения после телепорта
local teleportSuccess, teleportErr = pcall(function()
    TeleportService:SetTeleportData({ServerHopper = true})
end)
if not teleportSuccess then
    print("⚠️ Предупреждение при сохранении данных телепорта: " .. tostring(teleportErr))
end

-- Если был телепорт, но скрипт не загрузился через queueonteleport (резервный метод)
if wasTeleported then
    print("📥 Обнаружен телепорт! Проверяю, загрузился ли скрипт через queueonteleport...")
    spawn(function()
        wait(3) -- Даем время queueonteleport выполниться
        
        -- Если скрипт не загрузился автоматически, загружаем вручную
        if not getgenv().ServerHopperActive then
            print("✅ Скрипт уже загружен через queueonteleport!")
            return
        end
        
        print("⚠️ Скрипт не загрузился автоматически, загружаю вручную...")
        local success, script = pcall(function()
            return game:HttpGet("https://raw.githubusercontent.com/ivankodaria5-ai/5234234234gdfg/refs/heads/main/server_hopper.lua", true)
        end)
        
        if success and script and #script > 100 then
            print("✅ Скрипт получен с GitHub, длина: " .. #script .. " символов")
            print("🔄 Перезагружаю скрипт...")
            
            -- Сбрасываем флаги перед загрузкой
            getgenv().ServerHopperActive = false
            getgenv().ReconnectLoopRunning = false
            getgenv().MainScriptLoaded = false
            getgenv().ServerHopperReloading = false
            
            -- Загружаем и выполняем скрипт
            local func, loadErr = loadstring(script)
            if func then
                func()
            else
                print("❌ Ошибка компиляции при перезагрузке: " .. tostring(loadErr))
                -- Если не удалось загрузить, продолжаем работу текущего экземпляра
                getgenv().ServerHopperActive = true
            end
        else
            print("⚠️ Не удалось загрузить скрипт с GitHub, продолжаю работу текущего экземпляра...")
            if not success then
                print("❌ Ошибка: " .. tostring(script))
            end
            -- Продолжаем работу текущего экземпляра
            getgenv().ServerHopperActive = true
        end
    end)
end

-- Функция переподключения к серверам (упрощенная версия для мобильных)
local function ReconnectToServer()
    local localPlayer = Players.LocalPlayer
    
    if not localPlayer then
        local errorMsg = "❌ Ошибка: Игрок не найден при переподключении"
        print(errorMsg)
        if getgenv().UpdateDebugStatus then
            getgenv().UpdateDebugStatus(errorMsg, Color3.fromRGB(255, 100, 100))
        end
        return false
    end
    
    local placeId = game.PlaceId
    
    local statusMsg = "🔄 Переподключаюсь на новый сервер..."
    print(statusMsg)
    if getgenv().UpdateDebugStatus then
        getgenv().UpdateDebugStatus(statusMsg, Color3.fromRGB(100, 200, 255))
    end
    
    -- МЕТОД 1: Пробуем queueonteleport (если поддерживается)
    print("💾 Сохраняю скрипт для автоматической загрузки после телепорта...")
    local queueCode = 'loadstring(game:HttpGet("' .. SCRIPT_URL .. '", true))()'
    
    local queueSuccess, queueErr = pcall(function()
        queueFunc(queueCode)
    end)
    
    if queueSuccess then
        print("✅ Скрипт сохранен через queueonteleport!")
    else
        print("⚠️ queueonteleport не поддерживается, используем альтернативный метод")
    end
    
    -- МЕТОД 2: Сохраняем в getgenv() для автоматической проверки при следующем запуске
    saveScriptForAutoLoad()
    
    -- МЕТОД 3: Сохраняем через workspace (резервный метод)
    spawn(function()
        local success, err = pcall(function()
            local storage = workspace:FindFirstChild("ServerHopperStorage") or Instance.new("StringValue")
            storage.Name = "ServerHopperStorage"
            storage.Value = SCRIPT_URL
            storage.Parent = workspace
            print("✅ Скрипт сохранен в workspace")
        end)
        if not success then
            print("⚠️ Не удалось сохранить в workspace: " .. tostring(err))
        end
    end)
    
    -- МЕТОД 4: Сохраняем через CoreGui (если доступно)
    spawn(function()
        local success, err = pcall(function()
            local storage = CoreGui:FindFirstChild("ServerHopperStorage") or Instance.new("StringValue")
            storage.Name = "ServerHopperStorage"
            storage.Value = SCRIPT_URL
            storage.Parent = CoreGui
            print("✅ Скрипт сохранен в CoreGui")
        end)
        if not success then
            print("⚠️ Не удалось сохранить в CoreGui: " .. tostring(err))
        end
    end)
    
    -- Упрощенный метод для мобильных - просто создаем новый сервер
    local success, err = pcall(function()
        TeleportService:Teleport(placeId, localPlayer)
    end)
    
    if not success then
        local errorMsg = "❌ Ошибка телепорта: " .. tostring(err)
        print(errorMsg)
        if getgenv().UpdateDebugStatus then
            getgenv().UpdateDebugStatus(errorMsg, Color3.fromRGB(255, 100, 100))
        end
        return false
    end
    
    print("✅ Телепорт инициирован!")
    print("📱 Для jjsploit: Скрипт автоматически загрузится при следующем запуске через getgenv()")
    return true
end

-- Загружаем и выполняем ваш скрипт с GitHub
local function LoadMainScript()
    if getgenv().UpdateDebugStatus then
        getgenv().UpdateDebugStatus("📥 Загружаю основной скрипт с GitHub...", Color3.fromRGB(255, 255, 100))
    end
    print("📥 Загружаю основной скрипт с GitHub...")
    
    -- Проверяем, не загружен ли уже скрипт (чтобы избежать повторной загрузки)
    if getgenv().MainScriptLoaded then
        print("ℹ️ Основной скрипт уже загружен, пропускаю...")
        return true
    end
    
    local success, err = pcall(function()
        -- Пробуем загрузить скрипт (пробуем разные методы)
        print("📡 Отправляю запрос к GitHub...")
        local scriptContent
        
        -- Метод 1: game:HttpGet
        local httpSuccess, httpErr = pcall(function()
            scriptContent = game:HttpGet("https://raw.githubusercontent.com/Azura83/Murder-Mystery-2/refs/heads/main/Script.lua", true)
        end)
        
        -- Метод 2: game.HttpGet (альтернативный синтаксис)
        if not httpSuccess or not scriptContent then
            print("⚠️ Метод 1 не сработал, пробую альтернативный...")
            httpSuccess, httpErr = pcall(function()
                scriptContent = game.HttpGet(game, "https://raw.githubusercontent.com/Azura83/Murder-Mystery-2/refs/heads/main/Script.lua", true)
            end)
        end
        
        -- Метод 3: HttpService
        if not httpSuccess or not scriptContent then
            print("⚠️ Метод 2 не сработал, пробую HttpService...")
            local HttpService = game:GetService("HttpService")
            httpSuccess, httpErr = pcall(function()
                scriptContent = HttpService:GetAsync("https://raw.githubusercontent.com/Azura83/Murder-Mystery-2/refs/heads/main/Script.lua", true)
            end)
        end
        
        if not httpSuccess then
            error("Не удалось загрузить скрипт. Ошибка: " .. tostring(httpErr))
        end
        
        if not scriptContent then
            error("Не удалось получить скрипт (scriptContent = nil)")
        elseif scriptContent == "" then
            error("Скрипт пустой")
        elseif #scriptContent < 100 then
            error("Скрипт слишком короткий, возможно ошибка загрузки. Длина: " .. #scriptContent)
        end
        
        print("✅ Скрипт получен, длина: " .. #scriptContent .. " символов")
        print("🔄 Выполняю скрипт...")
        
        -- Выполняем скрипт (пробуем разные методы)
        local func, loadErr
        if loadstring then
            func, loadErr = loadstring(scriptContent)
        elseif load then
            func, loadErr = load(scriptContent)
        else
            error("loadstring и load недоступны!")
        end
        
        if not func then
            error("Ошибка компиляции: " .. tostring(loadErr))
        end
        
        -- Выполняем функцию
        local execSuccess, execErr = pcall(func)
        if not execSuccess then
            error("Ошибка выполнения: " .. tostring(execErr))
        end
        
        -- Помечаем как загруженный
        getgenv().MainScriptLoaded = true
        print("✅ Скрипт выполнен успешно!")
    end)
    
    if not success then
        local errorMsg = "❌ Ошибка загрузки скрипта: " .. tostring(err)
        warn(errorMsg)
        print(errorMsg)
        if getgenv().UpdateDebugStatus then
            getgenv().UpdateDebugStatus(errorMsg, Color3.fromRGB(255, 100, 100))
        end
        return false
    else
        local successMsg = "✅ Основной скрипт успешно загружен и выполнен!"
        print(successMsg)
        if getgenv().UpdateDebugStatus then
            getgenv().UpdateDebugStatus(successMsg, Color3.fromRGB(100, 255, 100))
        end
        return true
    end
end

-- Проверяем подключение к игре
local localPlayer = Players.LocalPlayer
if not localPlayer then
    local errorMsg = "❌ Ошибка: Игрок не найден! Убедитесь, что вы в игре."
    print(errorMsg)
    warn(errorMsg)
    if getgenv().UpdateDebugStatus then
        getgenv().UpdateDebugStatus(errorMsg, Color3.fromRGB(255, 100, 100))
    end
    return
end

print("✅ Игрок найден: " .. tostring(localPlayer.Name))
print("📍 PlaceId: " .. tostring(game.PlaceId))
print("🆔 JobId: " .. tostring(game.JobId))

if getgenv().UpdateDebugStatus then
    getgenv().UpdateDebugStatus("✅ Игрок: " .. tostring(localPlayer.Name) .. "\n📥 Загружаю основной скрипт...", Color3.fromRGB(100, 255, 100))
end

-- Проверяем доступность HttpGet
print("🔍 Проверяю доступность game:HttpGet...")
local httpGetTest = pcall(function()
    return game.HttpGet
end)
if not httpGetTest then
    print("⚠️ game:HttpGet может быть недоступен, пробую альтернативные методы...")
end

-- Загружаем основной скрипт с небольшой задержкой, чтобы избежать лагов
print("⏳ Жду 2 секунды перед загрузкой основного скрипта (чтобы избежать лагов)...")
spawn(function()
    wait(2)
    print("🚀 Начинаю загрузку основного скрипта...")
    LoadMainScript()
end)

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
            
            local reconnectMsg = "⏰ Время переподключения!\n⏱ Интервал: " .. RECONNECT_INTERVAL .. " сек (" .. math.floor(RECONNECT_INTERVAL / 60) .. " мин)"
            print(reconnectMsg)
            if getgenv().UpdateDebugStatus then
                getgenv().UpdateDebugStatus(reconnectMsg, Color3.fromRGB(255, 200, 100))
            end
            
            -- Переподключаемся к другому серверу
            ReconnectToServer()
        end
    end)
end

-- Ожидаем загрузки игрока после телепорта
if localPlayer then
    -- Загружаем скрипт сразу если персонаж уже есть (с задержкой)
    if localPlayer.Character then
        spawn(function()
            wait(3) -- Увеличиваем задержку для стабильности
            getgenv().MainScriptLoaded = false -- Сбрасываем флаг
            LoadMainScript()
        end)
    end
    
    -- Загружаем скрипт после каждого телепорта и перезапускаем цикл
    localPlayer.CharacterAdded:Connect(function()
        print("👤 Персонаж загружен!")
        
        -- Проверяем, был ли телепорт (через JobId)
        local currentJobId = game.JobId
        local lastJobId = getgenv().LastJobId
        
        -- Сбрасываем флаги для нового сервера
        getgenv().MainScriptLoaded = false
        getgenv().ReconnectLoopRunning = false
        
        -- Если JobId изменился, значит был телепорт
        if lastJobId and lastJobId ~= currentJobId then
            print("🔄 Обнаружена смена сервера через CharacterAdded!")
            print("📥 Загружаю скрипт переподключения с GitHub...")
            
            spawn(function()
                wait(2) -- Задержка для стабильности
                
                local success, script = pcall(function()
                    return game:HttpGet(SCRIPT_URL, true)
                end)
                
                if success and script and #script > 100 then
                    print("✅ Скрипт получен, перезагружаю...")
                    
                    -- Сбрасываем флаги
                    getgenv().ServerHopperActive = false
                    getgenv().ReconnectLoopRunning = false
                    getgenv().MainScriptLoaded = false
                    getgenv().LastJobId = currentJobId
                    
                    -- Загружаем и выполняем скрипт
                    local func, loadErr = loadstring(script)
                    if func then
                        func()
                        return
                    else
                        print("❌ Ошибка компиляции: " .. tostring(loadErr))
                    end
                else
                    print("⚠️ Не удалось загрузить скрипт с GitHub")
                end
                
                -- Если не удалось загрузить, продолжаем работу текущего экземпляра
                getgenv().ServerHopperActive = true
                wait(2)
                LoadMainScript()
                wait(2)
                StartReconnectLoop()
            end)
        else
            -- Если телепорта не было, просто загружаем основной скрипт
            print("ℹ️ Телепорта не было, загружаю только основной скрипт...")
            spawn(function()
                wait(2)
                LoadMainScript()
                wait(2)
                StartReconnectLoop()
            end)
        end
    end)
end

-- Запускаем цикл переподключения сразу
StartReconnectLoop()

local successMsg = "✅ Скрипт переподключения активирован!\n⏱ Интервал: " .. RECONNECT_INTERVAL .. " сек (" .. math.floor(RECONNECT_INTERVAL / 60) .. " мин)\n🔄 Автоперезагрузка включена"
print(successMsg)
print("📱 ВАЖНО для jjsploit:")
print("📱 После телепорта скрипт автоматически загрузится через CharacterAdded")
print("📱 Если скрипт не загрузился, запустите его вручную - он определит смену сервера и загрузится автоматически")
if getgenv().UpdateDebugStatus then
    getgenv().UpdateDebugStatus(successMsg .. "\n\n📱 Для jjsploit: Скрипт загрузится автоматически после телепорта", Color3.fromRGB(100, 255, 100))
end
