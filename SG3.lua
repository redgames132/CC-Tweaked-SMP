-- ==========================================================
-- J.A.R.V.I.S. - HUD Universal & Auto-Diagnostico (MC 1.21.1)
-- Posicionado em X=6, Y=148 (Abaixo do Minimapa)
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S."
local HOME_FILE = "ai_home.txt"
local hudX, hudY = 6, 148 -- Zona livre entre o Minimapa e o Jetpack

-- 1. Procura profunda pelo Modulo de Overlay
local overlay = nil
local nvModule = nil
local foundMethod = "nenhum"

local function findOverlayModule()
    -- Tentativa A: Tabela smartglasses.modules
    if smartglasses and smartglasses.modules then
        local ok, mod = pcall(function()
            return smartglasses.modules["advancedperipherals:overlay"]
                or smartglasses.modules["overlay"]
                or smartglasses.modules.overlay
        end)
        if ok and mod then
            foundMethod = "smartglasses.modules"
            return mod
        end
    end

    -- Tentativa B: Funcao smartglasses.getModule / getModules
    if smartglasses and smartglasses.getModule then
        local ok, mod = pcall(function()
            return smartglasses.getModule("advancedperipherals:overlay")
                or smartglasses.getModule("overlay")
        end)
        if ok and mod then
            foundMethod = "smartglasses.getModule"
            return mod
        end
    end

    -- Tentativa C: Perifericos ligados ao computador dos oculos
    for _, side in ipairs(peripheral.getNames()) do
        local pType = tostring(peripheral.getType(side) or ""):lower()
        if side:lower():find("overlay") or pType:find("overlay") or pType:find("glasses") or pType:find("ar_") then
            foundMethod = "peripheral (" .. side .. ")"
            return peripheral.wrap(side)
        end
    end

    -- Tentativa D: O proprio global smartglasses tem funcoes de desenho
    if smartglasses and (smartglasses.createObject or smartglasses.addText or smartglasses.canvas) then
        foundMethod = "smartglasses (global)"
        return smartglasses
    end

    return nil
end

overlay = findOverlayModule()

if smartglasses and smartglasses.modules then
    pcall(function()
        nvModule = smartglasses.modules["advancedperipherals:night_vision"] or smartglasses.modules.night_vision
    end)
end

local scanner  = peripheral.find("geo_scanner") or peripheral.find("geoScanner")
local chatBox  = peripheral.find("chat_box") or peripheral.find("chatBox")
local detector = peripheral.find("player_detector") or peripheral.find("playerDetector")

-- 2. Diagnostico no Terminal dos Oculos
term.clear()
term.setCursorPos(1, 1)
if term.isColor() then term.setTextColor(colors.yellow) end
print("=== DIAGNOSTICO DOS SMART GLASSES ===")
if overlay then
    if term.isColor() then term.setTextColor(colors.lime) end
    print("[OK] Overlay encontrado via: " .. foundMethod)
    local funcs = {}
    for k, _ in pairs(overlay) do table.insert(funcs, tostring(k)) end
    print("Funcoes: " .. table.concat(funcs, ", "):sub(1, 48))
else
    if term.isColor() then term.setTextColor(colors.red) end
    print("[ERRO] Nenhum modulo de Overlay encontrado!")
    print("Perifericos vistos: " .. table.concat(peripheral.getNames(), ", "))
end
print("-------------------------------------")

-- 3. Motor de Renderizacao Compativel com todas as builds 1.21.1
local hudLines = {}
local canvasRef = nil

if overlay and overlay.canvas then
    local ok, c = pcall(overlay.canvas)
    if ok and c then canvasRef = c end
end

local function clearHud()
    if overlay then
        if overlay.clear then pcall(overlay.clear) end
        if canvasRef and canvasRef.clear then pcall(canvasRef.clear) end
    end
    hudLines = {}
end

local function syncOverlay()
    if not overlay then return end
    if overlay.update then pcall(overlay.update) end
    if overlay.sync then pcall(overlay.sync) end
    if overlay.flush then pcall(overlay.flush) end
end

local function createOrUpdateLine(key, index, textStr, rgbHex)
    if not overlay then return false end
    local yPos = hudY + ((index - 1) * 11)
    local rgbaHex = rgbHex * 0x100 + 0xFF -- Formato 0xRRGGBBAA caso use canal Alpha no fim
    local argbHex = 0xFF000000 + rgbHex   -- Formato 0xAARRGGBB com 100% opacidade

    local existing = hudLines[key]
    if existing then
        local ok = pcall(function()
            if existing.setText then existing.setText(textStr) end
            if existing.setPosition then existing.setPosition(hudX, yPos) end
            if existing.setX then existing.setX(hudX) end
            if existing.setY then existing.setY(yPos) end
            if existing.update then existing.update() end
        end)
        if ok then
            syncOverlay()
            return true
        end
    end

    -- Metodo 1: createObject (AP 0.8 Padrao)
    if overlay.createObject then
        for _, objType in ipairs({"advancedperipherals:text", "text"}) do
            local ok, obj = pcall(function()
                return overlay.createObject(objType, {
                    text = textStr,
                    x = hudX,
                    y = yPos,
                    color = rgbHex,
                    gui = true,
                    enabled = true
                })
            end)
            if ok and obj then
                pcall(function()
                    if obj.setGui then obj.setGui(true) end
                    if obj.setEnabled then obj.setEnabled(true) end
                    if obj.setColor then obj.setColor(rgbHex) end
                    if obj.update then obj.update() end
                end)
                hudLines[key] = obj
                syncOverlay()
                return true
            end
        end
    end

    -- Metodo 2: addText no Canvas ou direto no Overlay
    local target = canvasRef or overlay
    if target.addText then
        local ok, obj = pcall(function()
            return target.addText({ x = hudX, y = yPos }, textStr, rgbaHex, 1.0)
        end)
        if not ok or not obj then
            ok, obj = pcall(function()
                return target.addText(hudX, yPos, textStr, argbHex)
            end)
        end
        if ok and obj then
            hudLines[key] = obj
            syncOverlay()
            return true
        end
    end

    return false
end

-- 4. Guardar / Carregar Casa
local homePos = nil
if fs.exists(HOME_FILE) then
    local f = fs.open(HOME_FILE, "r")
    homePos = textutils.unserialize(f.readAll())
    f.close()
end

local function saveHome(x, y, z)
    homePos = { x = math.floor(x), y = math.floor(y), z = math.floor(z) }
    local f = fs.open(HOME_FILE, "w")
    f.write(textutils.serialize(homePos))
    f.close()
end

-- 5. Dados do Jogador e Scanner
local ownerName = nil

local function getOwnerData()
    if smartglasses and smartglasses.getOwner then
        local ok, d = pcall(smartglasses.getOwner)
        if ok and type(d) == "table" then
            if d.name then ownerName = d.name end
            local px = d.x or (d.pos and d.pos.x) or 0
            local py = d.y or (d.pos and d.pos.y) or 0
            local pz = d.z or (d.pos and d.pos.z) or 0
            return {
                name = d.name or ownerName or "Boss",
                x = math.floor(px), y = math.floor(py), z = math.floor(pz),
                health = d.health, maxHealth = d.maxHealth or 20
            }
        end
    end
    return { name = ownerName or "Boss", x = 0, y = 0, z = 0 }
end

local RARE_ORES = {
    "ancient_debris", "uranium", "osmium", "diamond",
    "emerald", "fluorite", "zinc", "gold", "lead_ore", "tin_ore"
}

local function scanNearbyOres()
    if not scanner then return "SCAN: Sem Geo Scanner" end
    local scanFn = scanner.scanBlocks or scanner.scan
    if not scanFn then return "SCAN: Indisponivel" end

    local ok, blocks = pcall(function() return scanFn(8) end)
    if not ok or type(blocks) ~= "table" then return nil end

    local best, bestDist, total = nil, 999, 0
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

    if not best then return "SCAN: Sem minerios raros (8m)" end
    local ew = best.x >= 0 and (best.x .. "E") or (math.abs(best.x) .. "W")
    local ns = best.z >= 0 and (best.z .. "S") or (math.abs(best.z) .. "N")
    local ud = best.y >= 0 and (best.y .. "Up") or (math.abs(best.y) .. "Dn")
    return string.format("MINERIO: %s (%s %s %s) [+%d]", best.name, ew, ns, ud, total)
end

-- 6. Atualizar HUD e Fala
local function aiSay(msg, isAlert)
    createOrUpdateLine("speech", 4, "> " .. msg, isAlert and 0xFF5555 or 0xFFFFFF)
    if term.isColor() then term.setTextColor(isAlert and colors.red or colors.cyan) end
    print("[" .. AI_NAME .. "] " .. msg)
    if term.isColor() then term.setTextColor(colors.white) end
end

local function refreshHud()
    local t = os.time()
    local phase = (t >= 6 and t < 18.5) and "Dia" or "Noite"
    createOrUpdateLine("header", 1, string.format("[%s] %s (%s)", AI_NAME, textutils.formatTime(t, false), phase), 0x00FFFF)

    local info = getOwnerData()
    local hpStr = info.health and string.format(" HP:%d", math.floor(info.health)) or ""
    createOrUpdateLine("stats", 2, string.format("XYZ: %d, %d, %d%s", info.x, info.y, info.z, hpStr), 0x55FF55)

    local scanRes = scanNearbyOres()
    if scanRes then
        createOrUpdateLine("scanner", 3, scanRes, 0xFFFF55)
    end
end

-- 7. Comandos Interativos
local function processCommand(rawText)
    local cmd = rawText:lower():gsub("^%$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local info = getOwnerData()

    if cmd == "help" then
        aiSay("Cmds: status, ores, nv, set home, home, move <x> <y>")
    elseif cmd == "status" or cmd == "oi" then
        aiSay(string.format("Online! Pos: %d, %d, %d", info.x, info.y, info.z))
    elseif cmd == "ores" or cmd == "scan" then
        aiSay(scanNearbyOres() or "A arrefecer scanner (2s)...")
    elseif cmd == "nv" then
        if not nvModule then aiSay("Sem modulo Night Vision!", true)
        else
            local _, cur = pcall(nvModule.isNightVisionEnabled)
            pcall(function() nvModule.enableNightVision(not cur) end)
            aiSay("Visao Noturna alternada!")
        end
    elseif cmd == "set home" then
        saveHome(info.x, info.y, info.z)
        aiSay("Casa guardada!")
    elseif cmd == "home" then
        if not homePos then aiSay("Usa 'set home' primeiro!", true)
        else
            local dx, dz = homePos.x - info.x, homePos.z - info.z
            aiSay(string.format("Casa a %dm (X:%d Z:%d)", math.floor(math.sqrt(dx*dx + dz*dz)), homePos.x, homePos.z))
        end
    elseif cmd:find("^move ") then
        local nx, ny = cmd:match("^move%s+(%d+)%s+(%d+)")
        if nx and ny then
            hudX, hudY = tonumber(nx), tonumber(ny)
            clearHud()
            refreshHud()
            aiSay("HUD movido para " .. hudX .. ", " .. hudY)
        end
    else
        aiSay("Escreve 'help' para ver os comandos.")
    end
end

clearHud()
refreshHud()
aiSay("Sistemas prontos!")

local function loopTimer()
    while true do
        sleep(2.2)
        refreshHud()
    end
end

local function loopTerm()
    while true do
        write("AI > ")
        local inp = read()
        if inp and #inp > 0 then processCommand(inp) end
    end
end

parallel.waitForAny(loopTimer, loopTerm)
