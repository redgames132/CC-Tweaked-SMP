-- Modern Advanced Peripherals coordinate reader
local function fetchPlayerData()
    local results = {}
    local rawList = {}

    -- Query players within a wide detection radius
    local ok, res = pcall(function()
        if detector.getPlayersInRange then
            return detector.getPlayersInRange(10000)
        elseif detector.getPlayersInCoords then
            -- Fallback centered on 0,0,0
            return detector.getPlayersInCoords({x = 0, y = 64, z = 0}, 10000)
        end
    end)

    if ok and type(res) == "table" then
        rawList = res
    end

    for _, entry in ipairs(rawList) do
        local playerName = nil
        local x, y, z = 0, 0, 0

        if type(entry) == "table" then
            -- Extract player username
            playerName = entry.name or entry.username or entry.player

            -- Extract coordinates (handles {x,y,z} or {1,2,3})
            x = math.floor(entry.x or entry[1] or 0)
            y = math.floor(entry.y or entry[2] or 0)
            z = math.floor(entry.z or entry[3] or 0)
        elseif type(entry) == "string" then
            playerName = entry
        end

        if playerName then
            table.insert(results, {
                name = playerName,
                x = x,
                y = y,
                z = z
            })
        end
    end

    return results
end
