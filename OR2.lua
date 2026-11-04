-- ==========================================================
-- Upgraded Pocket Geo Scanner: 2D Top-Down Ore Radar
-- Supports: Create, Mekanism & Vanilla Ores (MC 1.21.1)
-- ==========================================================

-- 1. Detect Geo Scanner Peripheral
local scanner = peripheral.find("geo_scanner") or peripheral.find("geoScanner")
if not scanner then
    for _, side in ipairs(peripheral.getNames()) do
        if side:find("geo") or peripheral.hasType(side, "geo_scanner") or peripheral.hasType(side, "geoScanner") then
            scanner = peripheral.wrap(side)
            break
        end
    end
end

if not scanner then
    error("Geo Scanner not found! Use an Advanced Geo Pocket Computer.", 0)
end

-- 2. Ore Database (Priority: Higher = Renders on top)
-- cat: "mod" (Create/Mekanism), "rare" (High-value Vanilla), "common" (Basic Vanilla)
local ORE_DB = {
    -- Mekanism
    { match = "uranium",        color = colors.lime,      label = "Uranium (Mek)",  prio = 11, cat = "mod" },
    { match = "osmium",         color = colors.cyan,      label = "Osmium (Mek)",   prio = 10, cat = "mod" },
    { match = "fluorite",       color = colors.pink,      label = "Fluorite (Mek)", prio = 8,  cat = "mod" },
    { match = "lead_ore",       color = colors.purple,    label = "Lead (Mek)",     prio = 7,  cat = "mod" },
    { match = "deepslate_lead", color = colors.purple,    label = "Lead (Mek)",     prio = 7,  cat = "mod" },
    { match = "tin_ore",        color = colors.lightGray, label = "Tin (Mek)",      prio = 6,  cat = "mod" },
    { match = "deepslate_tin",  color = colors.lightGray, label = "Tin (Mek)",      prio = 6,  cat = "mod" },

    -- Create
    { match = "zinc",           color = colors.lightBlue, label = "Zinc (Create)",  prio = 9,  cat = "mod" },

    -- Rare Vanilla
    { match = "ancient_debris", color = colors.brown,     label = "Ancient Debris", prio = 12, cat = "rare" },
    { match = "diamond",        color = colors.blue,      label = "Diamond",        prio = 11, cat = "rare" },
    { match = "emerald",        color = colors.green,     label = "Emerald",        prio = 10, cat = "rare" },
    { match = "gold",           color = colors.yellow,    label = "Gold",           prio = 7,  cat = "rare" },
    { match = "lapis",          color = colors.blue,      label = "Lapis",          prio = 5,  cat = "rare" },
    { match = "quartz",         color = colors.white,     label = "Quartz",         prio = 5,  cat = "rare" },

    -- Common Vanilla
    { match = "redstone",       color = colors.red,       label = "Redstone",       prio = 4,  cat = "common" },
    { match = "iron",           color = colors.orange,    label = "Iron",           prio = 3,  cat = "common" },
    { match = "copper",         color = colors.orange,    label = "Copper",         prio = 2,  cat = "common" },
    { match = "coal",           color = colors.gray,      label = "Coal",           prio = 1,  cat = "common" },
}

-- Filter Modes
local FILTERS = { "ALL", "RARE", "MODS" }
local filterIdx = 1
local scanRadius = 8 -- Toggles between 8 and 16

local w, h = term.getSize()
local centerX = math.floor(w / 2)
local centerY = 9 -- Centered in the 2..16 map viewport

local mapGrid = {}
local rawBlocks = {}
local totalOres = 0
local selectedTitle = "Tap any dot to inspect"
local selectedDirs  = "^Up vDown =Lvl | @=You"

local function setCol(fg, bg)
    if term.isColor() then
        if fg then term.setTextColor(fg) end
        if bg then term.setBackgroundColor(bg) end
    end
end

-- Identify block and check against active filter
local function classifyOre(block)
    local name = (block.name or ""):lower()
    local isOre = name:find("ore") ~= nil or name:find("ancient_debris") ~= nil

    if not isOre and type(block.tags) == "table" then
        for _, t in ipairs(block.tags) do
            if tostring(t):lower():find("ores") then
                isOre = true
                break
            end
        end
    end
    if not isOre then return nil end

    local style = nil
    for _, entry in ipairs(ORE_DB) do
        if name:find(entry.match) then
            style = entry
            break
        end
    end

    if not style then
        local short = name:match(":(.+)") or name
        style = { color = colors.magenta, label = short, prio = 6, cat = "mod" }
    end

    local mode = FILTERS[filterIdx]
    if mode == "RARE" and style.cat == "common" then return nil end
    if mode == "MODS" and style.cat ~= "mod" then return nil end

    return style
end

-- Convert raw scan data into the 2D grid based on current filter & zoom
local function rebuildGrid()
    mapGrid = {}
    totalOres = 0
    local scale = (scanRadius > 8) and 2 or 1

    for _, b in ipairs(rawBlocks) do
        local style = classifyOre(b)
        if style then
            totalOres = totalOres + 1
            local rx = math.floor(b.x or 0)
            local ry = math.floor(b.y or 0)
            local rz = math.floor(b.z or 0)

            local sx = centerX + math.floor(rx / scale)
            local sy = centerY + math.floor(rz / scale)

            if sx >= 2 and sx <= (w - 1) and sy >= 2 and sy <= (h - 4) then
                local key = sx .. "," .. sy
                local cur = mapGrid[key]

                if not cur or (style.prio > cur.style.prio) or
                   (style.prio == cur.style.prio and math.abs(ry) < math.abs(cur.ry)) then
                    mapGrid[key] = {
                        sx = sx, sy = sy,
                        rx = rx, ry = ry, rz = rz,
                        style = style
                    }
                end
            end
        end
    end
end

-- Trigger hardware scan
local function performScan()
    if scanner.getScanCooldown then
        local ok, cd = pcall(scanner.getScanCooldown)
        if ok and type(cd) == "number" and cd > 0 then return false end
    end

    local ok, res = pcall(function() return scanner.scan(scanRadius) end)
    if ok and type(res) == "table" then
        rawBlocks = res
        rebuildGrid()
        return true
    end
    return false
end

-- Format cardinal digging directions
local function formatDirections(rx, ry, rz)
    local ew = rx > 0 and (rx .. "E") or (rx < 0 and (math.abs(rx) .. "W") or "0E")
    local ns = rz > 0 and (rz .. "S") or (rz < 0 and (math.abs(rz) .. "N") or "0N")
    local ud = ry > 0 and (ry .. " Up") or (ry < 0 and (math.abs(ry) .. " Down") or "Level")
    return string.format("Dig: %s, %s, %s", ew, ns, ud)
end

-- Render the UI
local function drawUI()
    setCol(colors.white, colors.black)
    term.clear()

    -- Top Bar: Title + Filter Button + Radius Button
    term.setCursorPos(1, 1)
    setCol(colors.white, colors.gray)
    term.clearLine()
    term.write(" RADAR")

    -- Filter Button (Cols 12..18)
    local modeName = FILTERS[filterIdx]
    term.setCursorPos(11, 1)
    setCol(colors.black, colors.yellow)
    term.write(string.format("[%-4s]", modeName))

    -- Radius Button (Cols 19..25)
    term.setCursorPos(18, 1)
    setCol(colors.white, colors.blue)
    term.write(string.format("[R:%-2d]", scanRadius))

    -- Draw Radar Background Dots
    setCol(colors.gray, colors.black)
    for y = 2, h - 4 do
        for x = 2, w - 1 do
            if math.abs(x - centerX) <= 8 and math.abs(y - centerY) <= 7 then
                term.setCursorPos(x, y)
                term.write(".")
            end
        end
    end

    -- Draw Compass Markers
    setCol(colors.yellow, colors.black)
    term.setCursorPos(centerX, 2)     term.write("N")
    term.setCursorPos(centerX, h - 4) term.write("S")
    term.setCursorPos(2, centerY)     term.write("W")
    term.setCursorPos(w - 1, centerY) term.write("E")

    -- Draw Ores
    for _, node in pairs(mapGrid) do
        term.setCursorPos(node.sx, node.sy)
        setCol(colors.black, node.style.color)
        local sym = "="
        if node.ry > 1 then sym = "^"
        elseif node.ry < -1 then sym = "v" end
        term.write(sym)
    end

    -- Draw Player Marker in Center
    term.setCursorPos(centerX, centerY)
    setCol(colors.white, colors.black)
    term.write("@")

    -- Bottom Status Bar (3 Lines)
    term.setCursorPos(1, h - 3)
    setCol(colors.gray, colors.black)
    term.write(string.rep("-", w))

    term.setCursorPos(1, h - 2)
    setCol(colors.cyan, colors.black)      term.write("Osm ")
    setCol(colors.lime, colors.black)      term.write("Ura ")
    setCol(colors.lightBlue, colors.black) term.write("Znc ")
    setCol(colors.blue, colors.black)      term.write("Dia ")
    setCol(colors.lightGray, colors.black) term.write("#" .. tostring(totalOres))

    term.setCursorPos(1, h - 1)
    setCol(colors.yellow, colors.black)
    term.write(selectedTitle:sub(1, w))

    term.setCursorPos(1, h)
    setCol(colors.white, colors.black)
    term.write(selectedDirs:sub(1, w))
end

-- Main Loop
local function main()
    performScan()
    drawUI()
    local timerId = os.startTimer(2.1)

    while true do
        local ev, p1, p2, p3 = os.pullEvent()

        if ev == "timer" and p1 == timerId then
            performScan()
            drawUI()
            timerId = os.startTimer(2.1)

        elseif ev == "mouse_click" then
            local cx, cy = p2, p3

            -- Top Bar Button Clicks
            if cy == 1 then
                if cx >= 11 and cx <= 16 then
                    -- Cycle Filter Mode immediately without waiting for next scan
                    filterIdx = (filterIdx % #FILTERS) + 1
                    rebuildGrid()
                    selectedTitle = "Filter: " .. FILTERS[filterIdx]
                    drawUI()
                elseif cx >= 18 and cx <= 24 then
                    -- Toggle Radius (8 or 16)
                    scanRadius = (scanRadius == 8) and 16 or 8
                    selectedTitle = "Scan Radius: " .. scanRadius .. "m"
                    performScan()
                    drawUI()
                end
            else
                -- Check if an Ore Dot was tapped
                local node = mapGrid[cx .. "," .. cy]
                if node then
                    selectedTitle = node.style.label
                    selectedDirs  = formatDirections(node.rx, node.ry, node.rz)
                    drawUI()
                end
            end
        end
    end
end

main()
