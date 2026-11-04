-- ==========================================================
-- Advanced Peripherals: Player Tracker
-- Supports: Team tagging & Multi-display (Terminal/Monitor)
-- ==========================================================

-- 1. TEAM ROSTER
-- Add your teammates here (case-sensitive)
local team = {
    ["YourUsername"] = true,
    ["Teammate1"]    = true,
    ["Teammate2"]    = true,
}

local REFRESH_RATE = 1.0 -- Update interval in seconds

-- Find the Player Detector peripheral
local detector = peripheral.find("playerDetector")
if not detector then
    error("No Player Detector found! Place one adjacent to the computer or connect via wired modem.", 0)
end

-- Setup Display: Use attached monitor if present, otherwise computer screen
local termTarget = term
local mon = peripheral.find("monitor")
if mon then
    mon.setTextScale(0.5)
    termTarget = mon
end

local function drawHeader()
    termTarget.clear()
    termTarget.setCursorPos(1, 1)

    if termTarget.isColor() then
        termTarget.setTextColor(colors.yellow)
    end
    termTarget.write(string.format("%-16s %-18s %-8s", "PLAYER", "X, Y, Z", "STATUS"))

    termTarget.setCursorPos(1, 2)
    termTarget.write(string.rep("-", 48))
end

local function updateRadar()
    while true do
        drawHeader()

        -- getPlayersInRange fetches coordinates for entities within range
        -- (Uses a huge radius fallback if no unbounded query method exists)
        local players = {}
        local success, result = pcall(function()
            -- Some versions support detector.getOnlinePlayers(),
            -- but detector.getPlayersInRange(radius) returns coordinate tables
            return detector.getPlayersInRange(1000000)
        end)

        if success and type(result) == "table" then
            players = result
        end

        local line = 3

        for _, p in ipairs(players) do
            local name = p.name or p.username or "Unknown"
            local isAlly = team[name] == true

            -- Format coordinates (rounded to nearest block)
            local x = math.floor(p.x or 0)
            local y = math.floor(p.y or 0)
            local z = math.floor(p.z or 0)
            local coords = string.format("%d, %d, %d", x, y, z)

            termTarget.setCursorPos(1, line)

            if termTarget.isColor() then
                if isAlly then
                    termTarget.setTextColor(colors.lime)
                else
                    termTarget.setTextColor(colors.red)
                end
            end

            local status = isAlly and "[ALLY]" or "[ENEMY]"
            termTarget.write(string.format("%-16s %-18s %-8s", name, coords, status))

            line = line + 1
        end

        if #players == 0 then
            termTarget.setCursorPos(1, 3)
            if termTarget.isColor() then
                termTarget.setTextColor(colors.gray)
            end
            termTarget.write("No players detected in range.")
        end

        sleep(REFRESH_RATE)
    end
end

updateRadar()
