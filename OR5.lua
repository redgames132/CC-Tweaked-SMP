-- ==========================================================
-- Ore Radar Pro (Auto-Refresh) - Pocket Computer
-- ==========================================================

local scanner = peripheral.find("geo_scanner") or peripheral.find("geoScanner")
if not scanner then
    for _, s in ipairs(peripheral.getNames()) do
        if s:find("geo") or peripheral.hasType(s, "geo_scanner") then
            scanner = peripheral.wrap(s) break
        end
    end
end
if not scanner then error("Geo Scanner nao encontrado!", 0) end

local ORES = {
    { m = "ancient_debris", c = colors.brown,     l = "Debris",   p = 12, cat = "rare" },
    { m = "uranium",        c = colors.lime,      l = "Uranium",  p = 11, cat = "mod" },
    { m = "diamond",        c = colors.blue,      l = "Diamond",  p = 11, cat = "rare" },
    { m = "emerald",        c = colors.green,     l = "Emerald",  p = 10, cat = "rare" },
    { m = "osmium",         c = colors.cyan,      l = "Osmium",   p = 10, cat = "mod" },
    { m = "zinc",           c = colors.lightBlue, l = "Zinc",     p = 9,  cat = "mod" },
    { m = "fluorite",       c = colors.pink,      l = "Fluorite", p = 8,  cat = "mod" },
    { m = "lead_ore",       c = colors.purple,    l = "Lead",     p = 7,  cat = "mod" },
    { m = "deepslate_lead", c = colors.purple,    l = "Lead",     p = 7,  cat = "mod" },
    { m = "gold",           c = colors.yellow,    l = "Gold",     p = 7,  cat = "rare" },
    { m = "tin_ore",        c = colors.lightGray, l = "Tin",      p = 6,  cat = "mod" },
    { m = "deepslate_tin",  c = colors.lightGray, l = "Tin",      p = 6,  cat = "mod" },
    { m = "redstone",       c = colors.red,       l = "Redstone", p = 4,  cat = "com" },
    { m = "iron",           c = colors.orange,    l = "Iron",     p = 3,  cat = "com" },
    { m = "copper",         c = colors.orange,    l = "Copper",   p = 2,  cat = "com" },
    { m = "coal",           c = colors.gray,      l = "Coal",     p = 1,  cat = "com" },
}

local FILTERS = {"TUDO", "RAROS/MODS", "COMUNS"}
local fIdx = 1
local radius = 8

local w, h = term.getSize()
local cx, cy = math.floor(w / 2), math.floor((h - 3) / 2) + 1
local grid, statusMsg = {}, "Radar ativo (Auto-Refresh)"

local function getOreStyle(name)
    local n = (name or ""):lower()
    for _, o in ipairs(ORES) do
        if n:find(o.m) then return o end
    end
    if n:find("ore") or n:find("debris") then
        return { c = colors.magenta, l = n:match(":(.+)") or n, p = 5, cat = "mod" }
    end
    return nil
end

local function scanOres()
    local ok, list = pcall(function() return scanner.scan(radius) end)
    if not ok or type(list) ~= "table" then return end
    
    grid = {}
    local mode = FILTERS[fIdx]

    for _, b in ipairs(list) do
        local st = getOreStyle(b.name)
        if st then
            local pass = true
            if mode == "RAROS/MODS" and st.cat == "com" then pass = false end
            if mode == "COMUNS" and st.cat == "rare" then pass = false end

            if pass then
                local rx = math.floor(b.x or 0)
                local ry = math.floor(b.y or 0)
                local rz = math.floor(b.z or 0)
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
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Barra Superior
    term.setCursorPos(1, 1)
    if term.isColor() then term.setBackgroundColor(colors.gray) term.setTextColor(colors.white) end
    term.clearLine()
    term.write(" RADAR")
    term.setCursorPos(w - string.len(FILTERS[fIdx]) - 2, 1)
    term.write("[" .. FILTERS[fIdx] .. "]")
    
    term.setCursorPos(cx, 1)
    if term.isColor() then term.setTextColor(colors.yellow) end
    term.write("N")

    -- Grelha do Mapa
    if term.isColor() then term.setBackgroundColor(colors.black) end
    for y = 2, h - 4 do
        for x = 2, w - 1 do
            if math.abs(x - cx) <= 8 and math.abs(y - cy) <= 7 then
                term.setCursorPos(x, y)
                if term.isColor() then term.setTextColor(colors.gray) end
                term.write(".")
            end
        end
    end

    -- Minérios
    for _, n in pairs(grid) do
        term.setCursorPos(n.sx, n.sy)
        if term.isColor() then term.setBackgroundColor(n.st.c) term.setTextColor(colors.black) end
        local sym = "="
        if n.ry > 1 then sym = "^"
        elseif n.ry < -1 then sym = "v" end
        term.write(sym)
    end

    -- Jogador
    term.setCursorPos(cx, cy)
    if term.isColor() then term.setBackgroundColor(colors.black) term.setTextColor(colors.white) end
    term.write("@")

    -- Rodapé
    term.setCursorPos(1, h - 3)
    if term.isColor() then term.setTextColor(colors.gray) end
    term.write(string.rep("-", w))

    term.setCursorPos(1, h - 2)
    if term.isColor() then term.setTextColor(colors.yellow) end
    term.write(statusMsg:sub(1, w))

    term.setCursorPos(1, h - 1)
    if term.isColor() then term.setTextColor(colors.cyan) end
    term.write("Osm Ura Znc Dia Debris")
    
    term.setCursorPos(1, h)
    if term.isColor() then term.setTextColor(colors.lightGray) end
    term.write("^Acima vAbaixo =Nivel (Clica topo p/ filtro)")
end

-- Ciclo Principal com Atualização Automática (1.0 segundo)
local REFRESH_TIME = 1.0
local tid = os.startTimer(REFRESH_TIME)

while true do
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "timer" and p1 == tid then
        scanOres()
        drawUI()
        tid = os.startTimer(REFRESH_TIME)

    elseif ev == "mouse_click" then
        if p3 == 1 then
            -- Clicar no topo muda o filtro
            fIdx = (fIdx % #FILTERS) + 1
            scanOres()
            drawUI()
        else
            -- Clicar num minério mostra os dados
            local n = grid[p2 .. "," .. p3]
            if n then
                local ud = n.ry > 0 and (n.ry .. " Acima") or (n.ry < 0 and (math.abs(n.ry) .. " Abaixo") or "No Nivel")
                statusMsg = string.format("%s | X:%d Z:%d (%s)", n.st.l, n.rx, n.rz, ud)
                drawUI()
            end
        end
    end
end
