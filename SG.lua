-- ==========================================================
-- J.A.R.V.I.S. - Personal AI Assistant for Smart Glasses
-- Advanced Peripherals (Minecraft 1.21.1 NeoForge)
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S."
local HOME_FILE = "ai_home.txt"
local voiceEnabled = false

-- 1. Detect Peripherals & Smart Glasses Modules
local chatBox = peripheral.find("chat_box") or peripheral.find("chatBox")
local scanner = peripheral.find("geo_scanner") or peripheral.find("geoScanner")
local detector = peripheral.find("player_detector") or peripheral.find("playerDetector")
local env = peripheral.find("environment_detector") or peripheral.find("environmentDetector")

local nvModule = nil
local overlayModule = nil
if smartglasses and smartglasses.modules then
    nvModule = smartglasses.modules["advancedperipherals:night_vision"]
    overlayModule = smartglasses.modules["advancedperipherals:overlay"]
end

-- 2. Load / Save Waypoint Data
local homePos = nil
if fs.exists(HOME_FILE) then
    local f = fs.open(HOME_FILE, "r")
    local data = textutils.unserialize(f.readAll())
    f.close()
    if type(data) == "table" then homePos = data end
end

local function saveHome(x, y, z)
    homePos = { x = math.floor(x), y = math.floor(y), z = math.floor(z) }
    local f = fs.open(HOME_FILE, "w")
    f.write(textutils.serialize(homePos))
    f.close()
end

-- 3. Get Wearer / Owner Info (Position, Health, Name)
local ownerName = nil

local function getOwnerData()
    -- Method A: Native Smart Glasses 0.8+ API
    if smartglasses and smartglasses.getOwner then
        local ok, data = pcall(smartglasses.getOwner)
        if ok and type(data) == "table" then
            if data.name then ownerName = data.name end
            return {
                name = data.name or ownerName or "Boss",
                x = math.floor(data.x or (data.pos and data.pos.x) or 0),
                y = math.floor(data.y or (data.pos and data.pos.y) or 0),
                z = math.floor(data.z or (data.pos and data.pos.z) or 0),
                health = data.health,
                maxHealth = data.maxHealth or 20,
                food = data.foodLevel or data.hunger,
                dimension = data.dimension or "Overworld"
            }
        end
    end

    -- Method B: Player Detector Fallback
    if detector then
        if not ownerName and detector.getOnlinePlayers then
            local ok, list = pcall(detector.getOnlinePlayers)
            if ok and type(list) == "table" and #list > 0 then
                ownerName = list[1]
            end
        end
        if ownerName and detector.getPlayerPos then
            local ok, pos = pcall(function() return detector.getPlayerPos(ownerName) end)
            if ok and type(pos) == "table" and pos.x then
                return {
                    name = ownerName,
                    x = math.floor(pos.x),
                    y = math.floor(pos.y),
                    z = math.floor(pos.z),
                    health = pos.health,
                    maxHealth = pos.maxHealth or 20,
                    dimension = pos.dimension or "Unknown"
                }
            end
        end
    end

    return { name = ownerName or "Boss", x = 0, y = 0, z = 0 }
end

-- 4. AI Output (Terminal + Private Chat + Toast + Optional TTS Voice)
local hudTextObj = nil
if overlayModule and overlayModule.createObject then
    pcall(function()
        hudTextObj = overlayModule.createObject("advancedperipherals:text", {
            text = "[" .. AI_NAME .. "] Online",
            x = 6, y = 6, color = 0x00FFFF, gui = true
        })
    end)
end

local function aiReply(msg, isAlert)
    -- Print to Smart Glasses Interface Terminal
    if term.isColor() then
        term.setTextColor(isAlert and colors.red or colors.cyan)
    end
    print("[" .. AI_NAME .. "] " .. msg)
    if term.isColor() then term.setTextColor(colors.white) end

    -- Update HUD Overlay if Overlay Module is installed
    if hudTextObj and hudTextObj.setText then
        pcall(function() hudTextObj.setText("[" .. AI_NAME .. "] " .. msg:sub(1, 42)) end)
    end

    -- Send to In-Game Chat & Toast via Chat Box
    if chatBox then
        local info = getOwnerData()
        local target = ownerName or info.name

        pcall(function()
            -- AP 0.8+ syntax
            local ok = chatBox.sendMessage("&b" .. msg, {
                player = (target ~= "Boss") and target or nil,
                prefix = AI_NAME,
                brackets = "[]",
                bracketsColor = isAlert and "&c" or "&b"
            })
            -- Fallback for AP 0.7 syntax
            if not ok and chatBox.sendMessageToPlayer and target ~= "Boss" then
                chatBox.sendMessageToPlayer(msg, target, AI_NAME, "[]", "&b")
            end
        end)

        if isAlert and chatBox.sendToast then
            pcall(function()
                chatBox.sendToast({
                    title = AI_NAME .. " Alert",
                    message = msg,
                    player = (target ~= "Boss") and target or nil
                })
            end)
        end

        if voiceEnabled and chatBox.narrateMessage then
            pcall(function()
                chatBox.narrateMessage(msg, {
                    player = (target ~= "Boss") and target or nil
                })
            end)
        end
    end
end

-- 5. AI Brain & Command Processor
local RARE_ORES = {
    "ancient_debris", "uranium", "osmium", "diamond",
    "emerald", "fluorite", "zinc", "gold", "lead_ore", "tin_ore"
}

local function scanNearbyOres()
    if not scanner then
        return "No Geo Scanner is installed on your glasses."
    end

    local scanFn = scanner.scanBlocks or scanner.scan
    if not scanFn then
        return "Geo Scanner method unavailable."
    end

    local ok, blocks = pcall(function() return scanFn(8) end)
    if not ok or type(blocks) ~= "table" then
        return "Scanner is cooling down. Wait 2 seconds and try again."
    end

    local bestOre = nil
    local bestDist = 999
    local counts = {}

    for _, b in ipairs(blocks) do
        local name = (b.name or ""):lower()
        for _, key in ipairs(RARE_ORES) do
            if name:find(key) then
                local clean = key:gsub("_ore", ""):gsub("^%l", string.upper)
                counts[clean] = (counts[clean] or 0) + 1
                local dist = math.abs(b.x or 0) + math.abs(b.y or 0) + math.abs(b.z or 0)
                if dist < bestDist then
                    bestDist = dist
                    bestOre = { name = clean, x = b.x or 0, y = b.y or 0, z = b.z or 0 }
                end
                break
            end
        end
    end

    if not bestOre then
        return "No high-value or modded ores detected within 8 blocks."
    end

    local summary = {}
    for k, v in pairs(counts) do table.insert(summary, v .. "x " .. k) end

    local ew = bestOre.x > 0 and (bestOre.x .. "E") or (bestOre.x < 0 and (math.abs(bestOre.x) .. "W") or "0E")
    local ns = bestOre.z > 0 and (bestOre.z .. "S") or (bestOre.z < 0 and (math.abs(bestOre.z) .. "N") or "0N")
    local ud = bestOre.y > 0 and (bestOre.y .. " Up") or (bestOre.y < 0 and (math.abs(bestOre.y) .. " Down") or "Level")

    return string.format("Found: %s. Closest is %s (%s, %s, %s).",
        table.concat(summary, ", "), bestOre.name, ew, ns, ud)
end

local function processCommand(rawText, sender)
    if sender and sender ~= "" and sender ~= "[say]" then
        ownerName = sender
    end

    local cmd = rawText:lower():gsub("^%$", ""):gsub("^ai%s+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local info = getOwnerData()

    if cmd == "help" or cmd == "?" then
        aiReply("Commands: status, ores, nv (night vision), set home, home, players, time, voice, joke")

    elseif cmd:find("hi") == 1 or cmd:find("hello") == 1 or cmd == "status" then
        local hpStr = info.health and string.format(" | HP: %d/%d", math.floor(info.health), info.maxHealth) or ""
        aiReply(string.format("Online, %s! Pos: %d, %d, %d%s", info.name, info.x, info.y, info.z, hpStr))

    elseif cmd:find("ore") or cmd:find("scan") or cmd:find("mine") then
        aiReply(scanNearbyOres())

    elseif cmd == "nv" or cmd:find("night") or cmd:find("light") then
        if not nvModule then
            aiReply("Night Vision Module is not installed in your Smart Glasses.")
        else
            local ok, current = pcall(nvModule.isNightVisionEnabled)
            local nextState = not (ok and current)
            pcall(function() nvModule.enableNightVision(nextState) end)
            aiReply("Night Vision turned " .. (nextState and "ON." or "OFF."))
        end

    elseif cmd == "set home" or cmd == "sethome" then
        saveHome(info.x, info.y, info.z)
        aiReply(string.format("Home waypoint saved at X:%d Y:%d Z:%d.", info.x, info.y, info.z))

    elseif cmd == "home" or cmd == "base" then
        if not homePos then
            aiReply("No home set yet! Use '$set home' at your base first.")
        else
            local dx = homePos.x - info.x
            local dy = homePos.y - info.y
            local dz = homePos.z - info.z
            local dist = math.floor(math.sqrt(dx * dx + dz * dz))
            local dirX = dx > 0 and (dx .. " East") or (math.abs(dx) .. " West")
            local dirZ = dz > 0 and (dz .. " South") or (math.abs(dz) .. " North")
            aiReply(string.format("Home is %d blocks away (%s, %s | Y:%d).", dist, dirX, dirZ, homePos.y))
        end

    elseif cmd:find("player") or cmd:find("radar") or cmd:find("who") then
        if not detector then
            aiReply("No Player Detector attached to scan for players.")
        else
            local ok, list = pcall(detector.getOnlinePlayers)
            if ok and type(list) == "table" then
                aiReply("Online players (" .. #list .. "): " .. table.concat(list, ", "))
            else
                aiReply("Could not retrieve online player list.")
            end
        end

    elseif cmd:find("time") or cmd:find("day") then
        local t = os.time()
        local formatted = textutils.formatTime(t, false)
        local phase = (t >= 6 and t < 18.5) and "Daytime (Safe)" or "Nighttime (Monsters spawning!)"
        aiReply("Current world time is " .. formatted .. " - " .. phase)

    elseif cmd == "voice" or cmd == "tts" then
        voiceEnabled = not voiceEnabled
        aiReply("Voice Narration turned " .. (voiceEnabled and "ON." or "OFF."))

    elseif cmd:find("joke") then
        local jokes = {
            "Why did the Creeper cross the road? To get to the other SSSSSS-side!",
            "I scanned for intelligent life, Boss... all I found were Nitwit Villagers.",
            "My circuits run on Mekanism Osmium and Create rotational force!"
        }
        aiReply(jokes[math.random(#jokes)])

    else
        aiReply("Unknown command '" .. cmd .. "'. Type 'help' for a list of commands.")
    end
end

-- 6. Loop 1: Listen for In-Game Chat & Proactive Health/Time Alerts
local function backgroundLoop()
    local timerId = os.startTimer(4)
    local warnedNight = false
    local warnedLowHp = false

    while true do
        local ev, p1, p2, p3, p4 = os.pullEvent()

        if ev == "chat" then
            -- Compatible with both AP 0.8 (uuid, name, msg, isHidden) and AP 0.7 (name, msg, uuid, isHidden)
            local sender, message, isHidden
            if type(p1) == "string" and p1:find("%-") and type(p3) == "string" then
                sender, message, isHidden = p2, p3, p4
            else
                sender, message, isHidden = p1, p2, p4
            end

            if type(message) == "string" then
                local low = message:lower()
                -- Trigger if message starts with "$" (hidden) or "ai "
                if isHidden or message:sub(1, 1) == "$" or low:sub(1, 3) == "ai " then
                    processCommand(message, sender)
                end
            end

        elseif ev == "timer" and p1 == timerId then
            local info = getOwnerData()

            -- Low Health Warning
            if info.health and info.health > 0 and info.health <= 6 then
                if not warnedLowHp then
                    aiReply("WARNING: Critical health (" .. math.floor(info.health) .. " HP)! Eat or retreat!", true)
                    warnedLowHp = true
                end
            elseif info.health and info.health > 10 then
                warnedLowHp = false
            end

            -- Dusk Warning
            local t = os.time()
            if t >= 18.0 and t <= 18.5 and not warnedNight then
                aiReply("Heads up: Night is falling! Make sure your area is lit or toggle '$nv'.", true)
                warnedNight = true
            elseif t < 18.0 and t > 6.0 then
                warnedNight = false
            end

            timerId = os.startTimer(4)
        end
    end
end

-- 7. Loop 2: Direct Terminal Input inside Smart Glasses Interface
local function terminalLoop()
    while true do
        if term.isColor() then term.setTextColor(colors.yellow) end
        write("Ask AI > ")
        if term.isColor() then term.setTextColor(colors.white) end
        local input = read()
        if input and #input > 0 then
            processCommand(input, ownerName)
        end
    end
end

-- Boot Screen
term.clear()
term.setCursorPos(1, 1)
aiReply("Systems initialized! Type 'help' below or '$help' in game chat.")
parallel.waitForAny(backgroundLoop, terminalLoop)
