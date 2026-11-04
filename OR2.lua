-- Compact Ore Radar (Create, Mekanism, Vanilla)
local RADIUS = 8
local scanner = peripheral.find("geo_scanner") or peripheral.find("geoScanner")
if not scanner then
    for _, s in ipairs(peripheral.getNames()) do
        if s:find("geo") or peripheral.hasType(s, "geo_scanner") then
            scanner = peripheral.wrap(s) break
        end
    end
end
if not scanner then error("No Geo Scanner found!", 0) end

local ORES = {
    { m = "ancient_debris", c = colors.brown,     l = "Debris",   p = 11 },
    { m = "uranium",        c = colors.lime,      l = "Uranium",  p = 10 },
    { m = "diamond",        c = colors.blue,      l = "Diamond",  p = 10 },
    { m = "emerald",        c = colors.green,     l = "Emerald",  p = 10 },
    { m = "osmium",         c = colors.cyan,      l = "Osmium",   p = 9  },
    { m = "fluorite",       c = colors.pink,      l = "Fluorite", p = 8  },
    { m = "zinc",           c = colors.lightBlue, l = "Zinc",     p = 8  },
    { m = "lead_ore",       c = colors.purple,    l = "Lead",     p = 7  },
    { m = "gold",           c = colors.yellow,    l = "Gold",     p = 7  },
    { m = "tin_ore",        c = colors.lightGray, l = "Tin",      p = 6  },
    { m = "redstone",       c = colors.red,       l = "Redstone", p = 5  },
    { m = "iron",           c = colors.orange,    l = "Iron",     p = 4  },
    { m = "copper",         c = colors.orange,    l = "Copper",   p = 3  },
    { m = "coal",           c = colors.gray,      l = "Coal",     p = 2  },
}

local function getStyle(b)
    local n = (b.name or ""):lower()
    if not (n:find("ore") or n:find("debris")) then return nil end
    for _, o in ipairs(ORES) do
        if n:find(o.m) then return o end
    end
    return { c = colors.magenta, l = n:match(":(.+)") or n, p = 5 }
end

local w, h = term.getSize()
local cx, cy = math.floor(w / 2), math.floor((h - 3) / 2) + 1
local grid, info = {}, "Tap any ore marker"

local function setCol(fg, bg)
    if term.isColor() then
        if fg then term.setTextColor(fg) end
        if bg then term.setBackgroundColor(bg) end
    end
end

local function scan()
    local ok, list = pcall(function() return scanner.scan(RADIUS) end)
    if not ok or type(list) ~= "table" then return end
    grid = {}
    for _, b in ipairs(list) do
        local st = getStyle(b)
        if st then
            local rx, ry, rz = math.floor(b.x or 0), math.floor(b.y or 0), math.floor(b.z or 0)
            local sx, sy = cx + rx, cy + rz
            if sx >= 2 and sx <= w - 1 and sy >= 2 and sy <= h - 3 then
                local k = sx .. "," .. sy
                local cur = grid[k]
                if not cur or st.p > cur.st.p or (st.p == cur.st.p and math.abs(ry) < math.abs(cur.ry)) then
                    grid[k] = { sx = sx, sy = sy, rx = rx, ry = ry, rz = rz, st = st }
                end
            end
        end
    end
end

local function draw()
    setCol(colors.white, colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    setCol(colors.white, colors.gray)
    term.clearLine()
    term.write(" ORE RADAR")
    term.setCursorPos(cx, 1)
    setCol(colors.yellow, colors.gray)
    term.write("N")

    for _, n in pairs(grid) do
        term.setCursorPos(n.sx, n.sy)
        setCol(colors.black, n.st.c)
        term.write(n.ry > 1 and "^" or (n.ry < -1 and "v" or "="))
    end

    term.setCursorPos(cx, cy)
    setCol(colors.white, colors.black)
    term.write("@")

    term.setCursorPos(1, h - 1)
    setCol(colors.yellow, colors.black)
    term.write(info:sub(1, w))
    term.setCursorPos(1, h)
    setCol(colors.lightGray, colors.black)
    term.write("^Up vDown =Lvl | Tap dot")
end

local tid = os.startTimer(0.1)
while true do
    local ev, p1, p2, p3 = os.pullEvent()
    if ev == "timer" and p1 == tid then
        scan()
        draw()
        tid = os.startTimer(2.2)
    elseif ev == "mouse_click" then
        local n = grid[p2 .. "," .. p3]
        if n then
            info = string.format("%s X:%d Y:%d Z:%d", n.st.l, n.rx, n.ry, n.rz)
            draw()
        end
    end
end
