-- ==================== SERVER HOPPER WITH AUTO-INJECT ====================
-- Automatically loads your script and hops between servers
-- 
-- SETUP INSTRUCTIONS:
-- 1. Upload this file to your GitHub
-- 2. Replace MAIN_SCRIPT_URL below with your Murder Mystery 2 script URL
-- 3. Adjust MIN_PLAYERS, MAX_PLAYERS, and WAIT_TIME as needed
-- 4. Execute this script in Roblox

-- ==================== CONFIGURATION ====================
local MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/Azura83/Murder-Mystery-2/refs/heads/main/Script.lua"  -- ← ВСТАВЬТЕ СЮДА ССЫЛКУ НА ВАШ ОСНОВНОЙ СКРИПТ
local PLACE_ID = game.PlaceId  -- Automatically gets current game ID
local MIN_PLAYERS = 5          -- Минимум игроков на сервере
local MAX_PLAYERS_ALLOWED = 50 -- Максимум игроков на сервере
local WAIT_TIME = 300          -- Время ожидания перед хопом (в секундах, 300 = 5 минут)

-- ==================== SERVICES ====================
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- ==================== HTTP REQUEST SETUP ====================
local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request
local queueFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport) or function() 
    warn("[HOPPER] Queue not supported on this executor!") 
end

-- ==================== SCRIPT LOADER ====================
local function loadMainScript()
    print("[HOPPER] Loading main script from: " .. MAIN_SCRIPT_URL)
    
    local MAX_ATTEMPTS = 10  -- Попыток загрузки
    local DELAY_BETWEEN = 2  -- Секунд между попытками
    local successCount = 0
    
    for attempt = 1, MAX_ATTEMPTS do
        print("[HOPPER] Injection attempt " .. attempt .. "/" .. MAX_ATTEMPTS)
        
        local success, err = pcall(function()
            local scriptContent = game:HttpGet(MAIN_SCRIPT_URL)
            if scriptContent and #scriptContent > 100 then  -- Проверка что скрипт загрузился
                local loadFunc = loadstring(scriptContent)
                if loadFunc then
                    loadFunc()
                    successCount = successCount + 1
                    print("[HOPPER] ✓ Injection #" .. attempt .. " SUCCESS!")
                    return true
                else
                    warn("[HOPPER] ✗ Failed to compile script on attempt " .. attempt)
                end
            else
                warn("[HOPPER] ✗ Script content too short or empty on attempt " .. attempt)
            end
        end)
        
        if not success then
            warn("[HOPPER] ✗ Error on attempt " .. attempt .. ": " .. tostring(err))
        end
        
        -- Задержка между попытками (кроме последней)
        if attempt < MAX_ATTEMPTS then
            task.wait(DELAY_BETWEEN)
        end
    end
    
    print("[HOPPER] ========================================")
    print("[HOPPER] Injection complete: " .. successCount .. "/" .. MAX_ATTEMPTS .. " successful")
    print("[HOPPER] ========================================")
    
    if successCount == 0 then
        warn("[HOPPER] WARNING: All injection attempts failed!")
    end
end

-- ==================== SERVER HOP FUNCTION ====================
local function serverHop()
    print("[HOPPER] Starting server hop...")
    print("[HOPPER] Looking for servers with " .. MIN_PLAYERS .. "-" .. MAX_PLAYERS_ALLOWED .. " players")
    
    local cursor = ""
    local hopped = false
    
    while not hopped do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            PLACE_ID,
            cursor ~= "" and "&cursor=" .. cursor or ""
        )
        
        local success, response = pcall(function()
            return httprequest({Url = url})
        end)
        
        if not success or not response then
            warn("[HOPPER] HTTP request failed, retrying in 5s...")
            task.wait(5)
            cursor = ""
            continue
        end
        
        local bodySuccess, body = pcall(function() 
            return HttpService:JSONDecode(response.Body) 
        end)
        
        if bodySuccess and body and body.data then
            local servers = {}
            
            -- Collect suitable servers
            for _, server in pairs(body.data) do
                if server.id ~= game.JobId 
                    and server.playing >= MIN_PLAYERS 
                    and server.playing <= MAX_PLAYERS_ALLOWED then
                    table.insert(servers, server)
                end
            end
            
            -- Sort by player count (more players first)
            table.sort(servers, function(a, b) 
                return (a.playing or 0) > (b.playing or 0) 
            end)
            
            if #servers > 0 then
                print("[HOPPER] Found " .. #servers .. " suitable servers")
                
                for _, selected in ipairs(servers) do
                    local playing = selected.playing or "?"
                    local maxP = selected.maxPlayers or "?"
                    print("[HOPPER] Attempting to join server " .. selected.id .. " (" .. playing .. "/" .. maxP .. ")")
                    
                    -- Queue this hopper script to run again after teleport
                    local queueScript = string.format(
                        'task.wait(2); loadstring(game:HttpGet("%s"))()',
                        "https://raw.githubusercontent.com/ivankodaria5-ai/5234234234gdfg/refs/heads/main/server_hopper.lua"  -- ← ЗАМЕНИТЕ ЭТО НА ССЫЛКУ GITHUB ЭТОГО ФАЙЛА (server_hopper.lua)
                    )
                    queueFunc(queueScript)
                    
                    -- Attempt teleport
                    local tpOk, err = pcall(function()
                        TeleportService:TeleportToPlaceInstance(PLACE_ID, selected.id, player)
                    end)
                    
                    if tpOk then
                        print("[HOPPER] Teleport initiated! Waiting for transition...")
                        hopped = true
                        task.wait(15)  -- Wait for teleport to complete
                        break
                    else
                        warn("[HOPPER] Teleport failed: " .. tostring(err) .. " - trying next server...")
                        task.wait(1)
                    end
                end
            else
                print("[HOPPER] No suitable servers on this page")
            end
            
            -- Check next page if available
            if body.nextPageCursor and not hopped then
                cursor = body.nextPageCursor
                print("[HOPPER] Checking next page...")
                task.wait(1)
            else
                if not hopped then
                    warn("[HOPPER] No suitable servers found. Retrying in 10s...")
                    task.wait(10)
                    cursor = ""
                end
            end
        else
            warn("[HOPPER] Failed to parse response, retrying in 5s...")
            task.wait(5)
            cursor = ""
        end
    end
end

-- ==================== MAIN EXECUTION ====================
print("========================================")
print("    SERVER HOPPER - AUTO INJECT")
print("========================================")
print("[HOPPER] Place ID: " .. PLACE_ID)
print("[HOPPER] Current Server: " .. game.JobId)
print("[HOPPER] Players in server: " .. #Players:GetPlayers())
print("========================================")

-- Wait for character to load
if not player.Character then
    print("[HOPPER] Waiting for character...")
    player.CharacterAdded:Wait()
    task.wait(2)
end

-- Load the main script
loadMainScript()

-- Wait before hopping
print("[HOPPER] Main script is running...")
print("[HOPPER] Will hop to another server in " .. WAIT_TIME .. " seconds (" .. math.floor(WAIT_TIME/60) .. " minutes)")
task.wait(WAIT_TIME)

-- Hop to another server
print("[HOPPER] Time's up! Hopping to another server...")
serverHop()

print("[HOPPER] Script finished")

