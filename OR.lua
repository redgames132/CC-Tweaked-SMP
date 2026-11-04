-- ==========================================================
-- Pocket Geo Scanner: 2D Top-Down Ore Radar
-- Supports: Create, Mekanism, and Vanilla Ores (MC 1.21.1)
-- ==========================================================

local SCAN_RADIUS = 8 -- Default free radius is 8 (Increase to 16 if fueled/configured)

-- 1. Find the Geo Scanner peripheral (usually on "back" for Pocket Computers)
local scanner = peripheral.find("geo_scanner") or peripheral.find("geoScanner")
if not scanner then
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.hasType(side, "geo_scanner") or peripheral.hasType(side, "geoScanner") then
            scanner = peripheral.wrap(side)
            break
        end
    end
end

if not scanner then
    error("Geo Scanner not found! Make sure you are using an Advanced Geo Pocket Computer.", 0)
end

-- 2. Ore Color & Priority Table
-- Higher priority ores render on top if multiple ores share the same X/Z column
local ORE_STYLES = {
    -- Mekanism Ores
    { match = "uranium",  color = colors.lime,      label = "Uranium (Mek)",  prio = 10 },
    { match = "osmium",   color = colors.cyan,      label = "Osmium (Mek)",   prio = 9  },
    { match = "fluorite", color = colors.pink,      label = "Fluorite (Mek)", prio = 8  },
    { match = "tin_ore",  color = colors.lightGray, label = "Tin (Mek)",      prio = 6  },
    { match = "lead_ore", color = colors.purple,    label = "Lead (Mek)",     prio = 7  },

    -- Create Ores
    { match = "zinc",     color = colors.lightBlue, label = "Zinc (Create)",  prio = 8  },

    -- High-Value Vanilla Ores
    { match = "ancient_debris", color = colors.brown,  label = "Debris",  prio = 11 },
    { match = "diamond",        color = colors.blue,   label = "Diamond", prio = 10 },
    { match = "emerald",        color = colors.green,  label = "Emerald", prio = 10 },
    { match = "gold",           color = colors.yellow, label = "Gold",    prio = 7  },
    { match = "redstone",       color = colors.red,    label = "Redstone",prio = 5  },
    { match = "iron",           color = colors.orange, label = "Iron",    prio = 4  },
    { match = "copper",         color = colors.orange, label = "Copper",  prio = 3  },
    { match = "coal",           color = colors.gray,   label = "Coal",    prio = 2  },
}

-- Identify if a block is an ore from Vanilla, Create, or Mekanism
local function classifyOre(block)
    local name = (block.name or ""):lower()

    -- Must contain "ore" or "ancient_debris", or have an ores tag
    local isOre = name:find("ore") ~= nil or name:find("ancient_debris") ~= nil
    if not isOre and type(block.tags) == "table" then
        for _, tag in ipairs(block.tags) do
            local t = tostring(tag):lower()
            if t:find("ores") then
                isOre = true
                break
            end
        end
    end

    if not isOre then return nil end

    for _, style in ipairs(ORE_STYLES) do
        if name:find(style.match) then
            return style
        end
    end

    -- Fallback for any other modded ore
    if name:find("create:") or name:find("mekanism:") or name:find("ore") then
        local shortName = name:match(":(.+)") or name
        return { color = colors.magenta, label = shortName, prio = 5 }
    end

    return nil
end

-- Screen dimensions (Pocket computer is typically 26 wide x 20 tall)
local w, h = term.getSize()
local centerX = math.floor(w / 2)
local centerY = math.floor((h - 3) / 2) + 1

local mapGrid = {}     -- Stores highest-priority ore at each screen coordinate
local selectedInfo = "Tap any dot to inspect ore"

-- Perform scan and populate 2D map grid
local function scanOres()
    local cd = 0
    if scanner.getScanCooldown then
        local ok, res = pcall(scanner.getScanCooldown)
        if ok and type(res) == "number" then cd = res end
    end
    if cd > 0 then return false end

    local ok, blocks = pcall(function() return scanner.scan(SCAN_RADIUS) end)
    if not ok or type(blocks) ~= "table" then return false end

    mapGrid = {}

    for _, b in ipairs(blocks) do
        local style = classifyOre(b)
        if style then
            -- Geo Scanner returns relative coordinates (player is at 0, 0, 0)
            local rx = math.floor(b.x or 0)
            local ry = math.floor(b.y or 0)
            local rz = math.floor(b.z or 0)

            local screenX = centerX + rx
            local screenY = centerY + rz

            if screenX >= 2 and screenX <= (w - 1) and screenY >= 2 and screenY <= (h - 4) then
                local key = screenX .. "," .. screenY
                local existing = mapGrid[key]

                -- Prefer higher priority ore, or closer in Y level if tied
                if not existing or (style.prio > existing.style.prio) or
                   (style.prio == existing.style.prio and math.abs(ry) < math.abs(existing.ry)) then
                    mapGrid[key] = {
                        screenX = screenX,
                        screenY = screenY,
                        rx = rx,
                        ry = ry,
                        rz = rz,
                        style = style
                    }
                end
            end
        end
    end
    return true
end

-- Draw Radar UI
local function drawRadar()
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Top Header & Compass
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.gray)
    term.setTextColor
