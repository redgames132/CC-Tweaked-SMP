-- ==========================================================
-- Ore Radar - Modo de Diagnóstico (Raio 12 + Forçar Tudo)
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

local radius = 12 -- Aumentado para 12 blocos para testar
local w, h = term.getSize()
local cx, cy = math.floor(w / 2), math.floor((h - 3) / 2) + 1
local grid, statusMsg = {}, "A varrer minérios..."

local function scanOres()
    local ok, list = pcall(function() return scanner.scan(radius) end)
    if not ok or type(list) ~= "table" then
        statusMsg = "Erro no scan ou sem energia!"
        return
    end
    
    grid = {}
    local totalFound = 0

    for _, b in ipairs(list) do
        local name = (b.name or ""):lower()
        -- DETETAR QUALQUER BLOCO QUE CONTENHA "ORE" OU "DEBRIS" OU "STONE" (para teste)
        if name:find("ore") or name:find("debris") or name:find("stone") then
            totalFound = totalFound + 1
            local rx = math.floor(b.x or 0)
            local ry = math.floor(b.y or 0)
            local rz = math.floor(b.z or 0)
            local sx, sy = cx + rx, cy + rz

            if sx >= 2 and sx <= w - 1 and sy >= 2 and sy <= h - 3 then
                local k = sx .. "," .. sy
                -- Cor padrão magenta para qualquer minério detetado
                grid[k] = { sx = sx, sy = sy, rx = rx, ry = ry, rz = rz, name = name }
            end
        end
    end
    statusMsg = "Total blocos detetados: " .. totalFound
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Barra Superior
    term.setCursorPos(1, 1)
    if term.isColor() then term.setBackgroundColor(colors.gray) term.setTextColor(colors.white) end
    term.clearLine()
    term.write(" RADAR (DIAGNOSTICO)")
    
    term.setCursorPos(cx, 1)
    if term.isColor() then term.setTextColor(colors.yellow) end
    term.write("N")

    -- Grelha do Mapa
    if term.isColor() then term.setBackgroundColor(colors.black) end
    for y = 2, h - 4 do
        for x = 2, w - 1 do
            if math.abs(x - cx) <= 12 and math.abs(y - cy) <= 7 then
                term.setCursorPos(x, y)
                if term.isColor() then term.setTextColor(colors.gray) end
                term.write(".")
            end
        end
    end

    -- Minérios
    for _, n in pairs(grid) do
        term.setCursorPos(n.sx, n.sy)
        if term.isColor() then term.setBackgroundColor(colors.magenta) term.setTextColor(colors.black) end
        term.write("o")
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

    term.setCursorPos(1, h)
    if term.isColor() then term.setTextColor(colors.lightGray) end
    term.write("Modo de Teste (Mostra tudo com 'ore')")
end

local tid = os.startTimer(1.0)
scanOres()
drawUI()

while true do
    local ev, p1 = os.pullEvent()
    if ev == "timer" and p1 == tid then
        scanOres()
        drawUI()
        tid = os.startTimer(1.0)
    end
end
