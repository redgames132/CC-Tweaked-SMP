-- ==========================================================
-- Interactive Radar with Team Management & Password Toggle
-- Advanced Peripherals (1.21.1 NeoForge)
-- ==========================================================

local PASSWORD = "9441"
local TEAM_FILE = "team.txt"

-- Wrap the detector directly on top, or search for it
local detector = peripheral.wrap("top") or peripheral.find("playerDetector")
if not detector then
    error("Player Detector not detected! Ensure it is placed directly on top.", 0)
end

-- Screen setup: supports mouse clicks on both Computer and Monitors
local termTarget = term
local mon = peripheral.find("monitor")
if mon then
    mon.setTextScale(0.5)
    termTarget = mon
end

-- Load / Save Team Members
local team = {}

local function loadTeam()
    team = {}
    if fs.exists(TEAM_FILE) then
        local f = fs.open(TEAM_FILE, "r")
        local line = f.readLine()
        while line do
            line = line:gsub("%s+", "")
            if #line > 0 then team[line] = true end
            line = f.readLine()
        end
        f.close()
    end
end

local function saveTeam()
    local f = fs.open(TEAM_FILE, "w")
    for name, isAlly in pairs(team) do
        if isAlly then f.writeLine(name) end
    end
    f.close()
end

loadTeam()

-- Get list of tracked player tables: { name, x, y, z }
local function fetchPlayerData()
    local results = {}
    local rawNames = {}

    -- Attempt to fetch online players list
    pcall(function()
        if detector.getOnlinePlayers then
            rawNames = detector.getOnlinePlayers()
        end
    end)

    -- If getOnlinePlayers isn't available or returns empty, try range scan
    if not rawNames or #rawNames == 0 then
        pcall(function()
            if detector.getPlayersInRange then
                local inRange = detector.getPlayersInRange(1000000)
                for _, p in ipairs(inRange) do
                    if type(p) == "string" then
                        table.insert(rawNames, p)
                    elseif type(p) == "table" and (p.name or p.username) then
                        table.insert(rawNames, p.name or p.username)
                    end
                end
            end
        end)
    end

    -- Query position for each detected name
    for _, name in ipairs(rawNames) do
        local x, y, z = 0, 0, 0
        local ok, pos = pcall(function()
            return detector.getPlayerPos(name)
        end)

        if ok and type(pos) == "table" then
            x = math.floor(pos.x or 0)
            y = math.floor(pos.y or 0)
            z = math.floor(pos.z or 0)
        end

        table.insert(results, { name = name, x = x, y = y, z = z })
    end

    return results
end

-- Active click buttons on screen: { y = lineNum, name = playerName }
local clickTargets = {}

local function drawUI(playerList)
    clickTargets = {}
    termTarget.clear()
    
    -- Header
    termTarget.setCursorPos(1, 1)
    if termTarget.isColor() then termTarget.setTextColor(colors.yellow) end
    termTarget.write(string.format("%-14s %-16s %-8s %s", "NAME", "COORDINATES", "ROLE", "ACTION"))

    termTarget.setCursorPos(1, 2)
    termTarget.setTextColor(colors.gray)
    termTarget.write(string.rep("-", 50))

    local line = 3
    for _, p in ipairs(playerList) do
        local isAlly = team[p.name] == true
        local coords = string.format("%d, %d, %d", p.x, p.y, p.z)

        -- Print Name & Coords
        termTarget.setCursorPos(1, line)
        if termTarget.isColor() then
            termTarget.setTextColor(isAlly and colors.lime or colors.red)
        end
        termTarget.write(string.format("%-14s %-16s ", p.name:sub(1, 13), coords))

        -- Print Status
        termTarget.write(string.format("%-8s ", isAlly and "[ALLY]" or "[ENEMY]"))

        -- Print Clickable Button
        if termTarget.isColor() then
            termTarget.setBackgroundColor(isAlly and colors.red or colors.green)
            termTarget.setTextColor(colors.white)
        end
        termTarget.write(isAlly and " [DEMOTE] " or " [SET TEAM] ")

        if termTarget.isColor() then
            termTarget.setBackgroundColor(colors.black)
        end

        clickTargets[line] = p.name
        line = line + 1
    end

    if #playerList == 0 then
        termTarget.setCursorPos(1, 3)
        termTarget.setTextColor(colors.gray)
        termTarget.write("Scanning for players...")
    end
end

-- Prompt for password to change team status
local function handleToggle(playerName)
    termTarget.clear()
    termTarget.setCursorPos(2, 2)
    termTarget.setTextColor(colors.yellow)
    termTarget.write("Modify Team Status: " .. playerName)

    termTarget.setCursorPos(2, 4)
    termTarget.setTextColor(colors.white)
    termTarget.write("Enter Password: ")

    local input = read("*")
    if input == PASSWORD then
        if team[playerName] then
            team[playerName] = nil
        else
            team[playerName] = true
        end
        saveTeam()
        termTarget.setCursorPos(2, 6)
        termTarget.setTextColor(colors.green)
        termTarget.write("Success! Status updated.")
    else
        termTarget.setCursorPos(2, 6)
        termTarget.setTextColor(colors.red)
        termTarget.write("Incorrect Password!")
    end
    sleep(1.2)
end

-- Main event loop
local function main()
    local timerId = os.startTimer(0.1)

    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "timer" and p1 == timerId then
            local currentPlayers = fetchPlayerData()
            drawUI(currentPlayers)
            timerId = os.startTimer(1.5)

        elseif event == "mouse_click" or event == "monitor_touch" then
            local clickY = (event == "mouse_click") and p3 or p3
            local clickedPlayer = clickTargets[clickY]

            if clickedPlayer then
                handleToggle(clickedPlayer)
                timerId = os.startTimer(0.1) -- Refresh immediately
            end
        end
    end
end

main()
