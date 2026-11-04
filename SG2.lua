-- ==========================================================
-- J.A.R.V.I.S. - Smart Glasses Overlay HUD & AI Assistant
-- Advanced Peripherals (Minecraft 1.21.1 NeoForge)
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S."
local HOME_FILE = "ai_home.txt"
local hudVisible = true
local hudX, hudY = 8, 8

-- 1. Universal Module & Peripheral Finder
local function findDevice(keyword)
    local keyLow = keyword:lower()
    if smartglasses and type(smartglasses.modules) == "table" then
        for k, v in pairs(smartglasses.modules) do
            if tostring(k):lower():find(keyLow) then
                return v
            end
        end
    end
    for _, name in ipairs(peripheral.getNames()) do
        if name:lower():find(keyLow) then
            return peripheral.wrap(name)
        end
        local pType = peripheral.getType(name)
        if pType and tostring(pType):lower():find(keyLow) then
            return peripheral.wrap(name)
        end
    end
    return nil
end

local overlay  = findDevice("overlay")
local nvModule = findDevice("night_vision")
local scanner  = findDevice("geo_scanner") or findDevice("geoscanner")
local chatBox  = findDevice("chat_box") or findDevice("chatbox")
local detector = findDevice("player_detector") or findDevice("playerdetector")

-- 2. Load / Save Home Waypoint
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

-- 3. Overlay HUD Manager
local hudLines = {}

local function clearOverlay()
    if overlay and overlay.clear then
        pcall(overlay.clear)
    end
    hudLines = {}
end

local function createTextObject(x, y, text, color)
    if not overlay or not overlay.createObject then return nil end

    -- Try full namespace ID first, then short ID (no gui=true so it renders on main HUD)
    local ok, obj = pcall(function()
        return overlay.createObject("advancedperipherals:text", {
            x = x, y = y, text = text, color = color
        })
    end)
    if ok and obj then return obj end

    local ok2, obj2 = pcall(function()
        return overlay.createObject("text", {
            x = x, y = y, text = text, color = color
        })
    end)
    if ok2 and obj2 then return obj2 end

    return nil
end

local function initHud()
    clearOverlay()
    if not overlay then return false end

    hudLines.header  = createTextObject(hudX, hudY,      "[" .. AI_NAME .. "] Booting...", 0x00FFFF)
    hudLines.stats   = createTextObject(hudX, hudY + 11, "POS: -- | HP: --",               0x55FF55)
    hudLines.scanner = createTextObject(hudX, hudY + 22, "SCAN: Ready",                    0xFFFF55)
    hudLines.speech  = createTextObject(hudX, hudY + 33, "> Online! Type 'help' or '$help'", 0xFFFFFF)

    return hudLines.header ~= nil
end

local function updateLine(key, yOffset, newText, color)
    if not overlay or not hudVisible then return end
    local obj = hudLines[key]

    if obj and obj.setText then
        local ok = pcall(function()
            obj.setText(newText)
            if color and obj.setColor then obj.setColor(color) end
        end)
        if ok then return end
    end

    -- Fallback: recreate if object reference was lost
    if obj and obj.remove then pcall(obj.remove) end
    hudLines[key] = createTextObject(hudX, hudY + yOffset, newText, color or 0xFFFFFF)
end

-- 4. Owner Position & Status Reader
local ownerName = nil

local function getOwnerData()
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
                maxHealth = data.maxHealth or 20
            }
        end
    end

    if detector then
        if not ownerName and detector.getOnlinePlayers then
            local ok, list = pcall(detector.getOnlinePlayers)
            if ok and type(list) == "table" and #list > 0 then ownerName = list[1] end
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
                    maxHealth = pos.maxHealth or 20
                }
            end
        end
    end

    return { name = ownerName or "Boss", x = 0, y = 0, z = 0 }
end

-- 5. AI Speech Output (Overlay HUD + Terminal + Optional Chat)
local function aiSay(msg, isAlert)
    local colorHex = isAlert and 0xFF5555 or 0xFFFFFF
    updateLine("speech", 33, "> " .. msg, colorHex)

    if term.isColor() then
        term.setTextColor(isAlert and colors.red or colors.cyan)
    end
    print("[" .. AI_NAME .. "] " .. msg)
    if term.isColor() then term.setTextColor(colors.white) end

    if chatBox then
        local info = getOwnerData()
        local target = (info.name ~= "Boss") and info.name or nil
        pcall(function()
            chatBox.sendMessage("&b" .. msg, {
                player = target, prefix = AI_NAME, brackets = "[]"
            })
        end)
    end
end

-- 6. Ore Scanner (Mekanism, Create, and Rare Vanilla)
local RARE_ORES = {
    "ancient_debris", "uranium", "osmium", "diamond",
    "emerald", "fluorite", "zinc", "gold", "lead_ore", "tin_ore"
}

local function scanNearbyOres()
    if not scanner then return "No Geo Scanner module installed" end
    local scanFn = scanner.scanBlocks or scanner.scan
    if not scanFn then return "Scanner unavailable" end

    local ok, blocks = pcall(function() return scanFn(8) end)
    if not ok or type(blocks) ~= "table" then return nil end -- Cooldown active

    local best = nil
    local bestDist = 999
    local total = 0

    for _, b in ipairs(blocks) do
        local name = (b.name or ""):lower()
        for _, key in ipairs(RARE_ORES) do
            if name:find(key) then
                total = total + 1
                local clean = key:gsub("_ore", ""):gsub("^%l", string.upper)
                local dist = math.abs(b.x or 0) + math.abs(b.y or 0) + math.abs(b.z or 0)
                if dist < bestDist then
                    bestDist = dist
                    best = { name = clean, x = math.floor(b.x or 0), y = math.floor(b.y or 0), z = math.floor(b.z or 0) }
                end
                break
            end
        end
    end

    if not best then return "SCAN: No rare/mod ores within 8m" end

    local ew = best.x > 0 and (best.x .. "E") or (best.x < 0 and (math.abs(best.x) .. "W") or "0E")
    local ns = best.z > 0 and (best.z .. "S") or (best.z < 0 and (math.abs(best.z) .. "N") or "0N")
    local ud = best.y > 0 and (best.y .. "Up") or (best.y < 0 and (math.abs(best.y) .. "Dn") or "Lvl")

    return string.format("SCAN: %s (%s, %s, %s) [+%d]", best.name, ew, ns, ud, total)
end

-- 7. Refresh Live HUD Data
local function refreshHud()
    if not overlay or not hudVisible then return end

    local t = os.time()
    local timeStr = textutils.formatTime(t, false)
    local phase = (t >= 6 and t < 18.5) and "Day" or "Night"
    updateLine("header", 0, string.format("[%s] %s (%s)", AI_NAME, timeStr, phase), 0x00FFFF)

    local info = getOwnerData()
    local hpStr = info.health and string.format("HP:%d/%d", math.floor(info.health), info.maxHealth) or ""
    local homeStr = ""
    if homePos then
        local dx, dz = homePos.x - info.x, homePos.z - info.z
        local dist = math.floor(math.sqrt(dx * dx + dz * dz))
        homeStr = string.format(" | Home:%dm", dist)
    end
    updateLine("stats", 11, string.format("XYZ: %d, %d, %d %s%s", info.x, info.y, info.z, hpStr, homeStr), 0x55FF55)

    local scanResult = scanNearbyOres()
    if scanResult then
        local col = scanResult:find("No rare") and 0xAAAAAA or 0xFFFF55
        updateLine("scanner", 22, scanResult, col)
    end
end

-- 8. Command Processor
local function processCommand(rawText, sender)
    if sender and sender ~= "" and sender ~= "[say]" then ownerName = sender end
    local cmd = rawText:lower():gsub("^%$", ""):gsub("^ai%s+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local info = getOwnerData()

    if cmd == "help" or cmd == "?" then
        aiSay("Cmds: status, ores, nv, set home, home, hud, move <x> <y>, joke")

    elseif cmd == "status" or cmd:find("hi") == 1 or cmd:find("hello") == 1 then
        aiSay(string.format("All systems nominal, %s! Pos: %d, %d, %d", info.name, info.x, info.y, info.z))

    elseif cmd:find("ore") or cmd:find("scan") then
        local res = scanNearbyOres() or "Scanner cooling down (wait 2s)."
        updateLine("scanner", 22, res, 0xFFFF55)
        aiSay(res)

    elseif cmd == "nv" or cmd:find("night") then
        if not nvModule then
            aiSay("Night Vision Module not installed in glasses!", true)
        else
            local ok, cur = pcall(nvModule.isNightVisionEnabled)
            local nextState = not (ok and cur)
            pcall(function() nvModule.enableNightVision(nextState) end)
            aiSay("Night Vision: " .. (nextState and "ENABLED" or "DISABLED"))
        end

    elseif cmd == "set home" or cmd == "sethome" then
        saveHome(info.x, info.y, info.z)
        aiSay(string.format("Home saved at %d, %d, %d!", info.x, info.y, info.z))

    elseif cmd == "home" or cmd == "base" then
        if not homePos then
            aiSay("No home saved! Use 'set home' first.", true)
        else
            local dx, dz = homePos.x - info.x, homePos.z - info.z
            local dist = math.floor(math.sqrt(dx * dx + dz * dz))
            local ew = dx > 0 and (dx .. "E") or (math.abs(dx) .. "W")
            local ns = dz > 0 and (dz .. "S") or (math.abs(dz) .. "N")
            aiSay(string.format("Base is %dm away (%s, %s, Y:%d)", dist, ew, ns, homePos.y))
        end

    elseif cmd == "hud" then
        hudVisible = not hudVisible
        if not hudVisible then
            clearOverlay()
        else
            initHud()
            refreshHud()
        end
        print("HUD visibility: " .. tostring(hudVisible))

    elseif cmd:find("^move ") then
        local nx, ny = cmd:match("^move%s+(%d+)%s+(%d+)")
        if nx and ny then
            hudX, hudY = tonumber(nx), tonumber(ny)
            initHud()
            refreshHud()
            aiSay("HUD moved to X:" .. hudX .. " Y:" .. hudY)
        end

    elseif cmd:find("joke") then
        local jokes = {
            "Why did the Creeper cross the road? To get to the other SSSSS-side!",
            "I scanned for intelligent life... only found Nitwit Villagers.",
            "Powered by Mekanism Osmium and Create rotational force!"
        }
        aiSay(jokes[math.random(#jokes)])

    else
        aiSay("Unknown command '" .. cmd .. "'. Type 'help' for options.")
    end
end

-- 9. Main Loops
local function backgroundLoop()
    local timerId = os.startTimer(1.0)
    local warnedLowHp = false

    while true do
        local ev, p1, p2, p3, p4 = os.pullEvent()

        if ev == "timer" and p1 == timerId then
            refreshHud()
            local info = getOwnerData()
            if info.health and info.health > 0 and info.health <= 6 and not warnedLowHp then
                aiSay("WARNING: Critical HP (" .. math.floor(info.health) .. ")! Heal up!", true)
                warnedLowHp = true
            elseif info.health and info.health > 10 then
                warnedLowHp = false
            end
            timerId = os.startTimer(2.2)

        elseif ev == "chat" then
            local sender, message, isHidden
            if type(p1) == "string" and p1:find("%-") and type(p3) == "string" then
                sender, message, isHidden = p2, p3, p4
            else
                sender, message, isHidden = p1, p2, p4
            end
            if type(message) == "string" then
                if isHidden or message:sub(1, 1) == "$" or message:lower():sub(1, 3) == "ai " then
                    processCommand(message, sender)
                end
            end
        end
    end
end

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

-- Boot Sequence
term.clear()
term.setCursorPos(1, 1)
if not overlay then
    if term.isColor() then term.setTextColor(colors.red) end
    print("[!] Overlay Module NOT detected in Smart Glasses!")
    print("Install an 'Overlay Module' in your glasses to see the on-screen HUD.")
else
    local ok = initHud()
    refreshHud()
    aiSay(ok and "Overlay HUD active on your screen!" or "Overlay found, initializing...")
end

parallel.waitForAny(backgroundLoop, terminalLoop)
