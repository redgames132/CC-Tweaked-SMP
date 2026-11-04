-- ==========================================================
-- Radar & Team Manager for Advanced Peripherals (MC 1.21.1)
-- Supports: "player_detector" (1.21.1+) & "playerDetector"
-- ==========================================================

local PASSWORD = "9441"
local TEAM_FILE = "team.txt"

-- 1. Auto-detect the Player Detector on ANY side
local detector = peripheral.find("player_detector") or peripheral.find("playerDetector")
if not detector then
    -- Fallback: scan all sides manually for detector methods
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.hasType(side, "player_detector") or peripheral.hasType(side, "playerDetector") then
            detector = peripheral.wrap(side)
            break
        end
    end
end

if not detector then
    error("ERROR: Could not find Player Detector on any side! Make sure it touches the computer.", 0)
end

-- 2. Auto-detect Monitor (and draw on BOTH Monitor and Computer)
local mon = peripheral.find("monitor")
local disp = term.current()

if mon then
    mon.setTextScale(0.5)
    disp = mon
    term.clear()
    term.setCursorPos(1, 1)
    print("Radar is running on the attached Monitor!")
    print("Keep this computer window open when typing the password.")
end

-- 3. Load & Save Team Data
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

-- 4. Fetch Players and Coordinates safely
local function fetchPlayerData()
    local results = {}
    local names = {}

    -- Get all online players
    local ok, list = pcall(function() return detector.getOnlinePlayers() end)
    if ok and type(list) == "table" then
        names = list
    end

    -- Fallback if getOnlinePlayers is empty
    if #names == 0 then
        local okRange, inRange = pcall(function() return detector.getPlayersInRange(100) end)
        if okRange and type(inRange) == "table" then
            names = inRange
        end
    end

    for _, entry in ipairs(names) do
        local name = type(entry) == "table" and (entry.name or entry.username) or tostring(entry)
        local x, y, z = nil, nil, nil

        -- Try getPlayerPos(name) first, then getPlayer(name)
        local posOk, pos = pcall(function()
            if detector.getPlayerPos then
                return detector.getPlayerPos(name)
            elseif detector.getPlayer then
                return detector.getPlayer(name)
            end
        end)

        if posOk and type(pos) == "table" and pos.x then
            x = math.floor(pos.x)
            y = math.floor(pos.y)
            z = math.floor(pos.z)
        elseif type(entry) == "table" and entry.x then
            x = math.floor(entry.x)
            y = math.floor(entry.y)
            z = math.floor(entry.z)
        end

        table.insert(results, { name = name, x = x, y = y, z = z })
    end

    return results
end

-- 5. Draw UI on Screen/Monitor
local clickTargets = {}

local function drawUI(playerList)
    clickTargets = {}
    disp.setBackgroundColor(colors.black)
    disp.clear()

    disp.setCursorPos(1, 1)
    if disp.isColor() then disp.setTextColor(colors.yellow) end
    disp.write(string.format("%-13s %-17s %-8s %s", "PLAYER", "COORDS (X Y Z)", "STATUS", "TEAM"))

    disp.setCursorPos(1, 2)
    if disp.isColor() then disp.setTextColor(colors.gray) end
    disp.write(string.rep("-", 50))

    local line = 3
    for _, p in ipairs(playerList) do
        local isAlly = team[p.name] == true
        local coordStr = (p.x and p.y and p.z)
            and string.format("%d, %d, %d", p.x, p.y, p.z)
            or "Out of Range/Cfg"

        disp.setCursorPos(1, line)
        if disp.isColor() then
            disp.setTextColor(isAlly and colors.lime or colors.red)
        end

        disp.write(string.format("%-13s %-17s %-8s ", p.name:sub(1, 12), coordStr, isAlly and "[ALLY]" or "[ENEMY]"))

        -- Draw Button
        if disp.isColor() then
            disp.setBackgroundColor(isAlly and colors.red or colors.green)
            disp.setTextColor(colors.white)
        end
        disp.write(isAlly and " [REMOVE] " or " [+TEAM] ")

        if disp.isColor() then
            disp.setBackgroundColor(colors.black)
        end

        clickTargets[line] = p.name
        line = line + 1
    end

    if #playerList == 0 then
        disp.setCursorPos(1, 3)
        if disp.isColor() then disp.setTextColor(colors.orange) end
        disp.write("No players detected.")
    end
end

-- 6. Password Prompt (Uses Keyboard on the Computer)
local function promptPassword(playerName)
    disp.setBackgroundColor(colors.black)
    disp.clear()
    disp.setCursorPos(2, 2)
    if disp.isColor() then disp.setTextColor(colors.yellow) end
    disp.write("Change Team for: " .. playerName)

    disp.setCursorPos(2, 4)
    if disp.isColor() then disp.setTextColor(colors.white) end
    disp.write("Type password in Computer terminal (9441)...")

    -- Prompt inside the computer terminal
    term.clear()
    term.setCursorPos(1, 1)
    print("=== TEAM AUTHENTICATION ===")
    print("Target Player: " .. playerName)
    write("Enter Password: ")

    local input = read("*")
    if input == PASSWORD then
        if team[playerName] then
            team[playerName] = nil
        else
            team[playerName] = true
        end
        saveTeam()
        print("Success! Updated " .. playerName)
        disp.setCursorPos(2, 6)
        if disp.isColor() then disp.setTextColor(colors.lime) end
        disp.write("ACCESS GRANTED - Status Changed!")
    else
        print("Wrong Password!")
        disp.setCursorPos(2, 6)
        if disp.isColor() then disp.setTextColor(colors.red) end
        disp.write("ACCESS DENIED - Wrong Password!")
    end
    sleep(1.2)
end

-- 7. Main Loop
local function main()
    local timerId = os.startTimer(0.1)

    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "timer" and p1 == timerId then
            local players = fetchPlayerData()
            drawUI(players)
            timerId = os.startTimer(1.0)

        elseif (event == "monitor_touch" and mon) or (event == "mouse_click" and not mon) then
            local clickY = p3
            local clickedPlayer = clickTargets[clickY]
            if clickedPlayer then
                promptPassword(clickedPlayer)
                timerId = os.startTimer(0.1)
            end
        end
    end
end

main()
