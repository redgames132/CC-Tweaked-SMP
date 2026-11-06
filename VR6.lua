-- ==========================================================
-- J.A.R.V.I.S. Pro - Smart Glasses HUD & AI Assistant
-- Otimizado para Advanced Peripherals (Minecraft 1.21.1)
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S."
local HOME_FILE = "ai_home.txt"
local hudVisible = true

-- Posição do HUD (Debaixo do Minimapa)
local hudX, hudY = 6, 148

-- 1. Deteta módulos dos Smart Glasses e Periféricos
local overlay = nil
local nvModule = nil

if smartglasses and smartglasses.modules then
    overlay  = smartglasses.modules["advancedperipherals:overlay"] or smartglasses.modules.overlay
    nvModule = smartglasses.modules["advancedperipherals:night_vision"] or smartglasses.modules.night_vision
end

if not overlay then
    overlay = peripheral.find("overlay") or peripheral.find("advancedperipherals:overlay")
end

local scanner  = peripheral.find("geo_scanner") or peripheral.find("geoScanner")
local chatBox  = peripheral.find("chat_box") or peripheral.find("chatBox")
local detector = peripheral.find("player_detector") or peripheral.find("playerDetector")

-- 2. Sistema de Waypoint (Casa)
local homePos = nil
if fs.exists(HOME_FILE) then
    local f = fs.open(HOME_FILE, "r")
    local data = textutils.unserialize(f.readAll())
    f.close()
    if type(data) == "table" then homePos = data end
end

local function saveHome(x, y, z)
    homePos = { x = math.floor(x), y = math.floor(y), z = math.floor(z) }
    local f = fs.open(HOME_FILE, "w")
    f.write(textutils.serialize(homePos))
    f.close()
end

-- 3. Gestor Gráfico do HUD (Overlay Module)
local hudObjects = {}

local function clearHud()
    if overlay and overlay.clear then pcall(overlay.clear) end
    for _, obj in pairs(hudObjects) do
        if obj and obj.remove then pcall(obj.remove) end
    end
    hudObjects = {}
end

local function makeGuiText(x, y, str, hexColor)
    if not overlay or not overlay.createObject then return nil end
    local ok, obj = pcall(function()
        return overlay.createObject("advancedperipherals:text", {
            text = str, x = x, y = y, color = hexColor or 0xFFFFFF, gui = true, enabled = true
        })
    end)
    if ok and obj then
        if obj.setGui then pcall(function() obj.setGui(true) end) end
        if obj.setEnabled then pcall(function() obj.setEnabled(true) end) end
        return obj
    end
    return nil
end

local function initHud()
    clearHud()
    if not overlay then return false end
    hudObjects.header  = makeGuiText(hudX, hudY,      "[" .. AI_NAME .. "] A iniciar...", 0x00FFFF)
    hudObjects.stats   = makeGuiText(hudX, hudY + 11, "XYZ: -- | HP: --",               0x55FF55)
    hudObjects.scanner = makeGuiText(hudX, hudY + 22, "SCAN: A procurar minerios...",   0xFFFF55)
    hudObjects.speech  = makeGuiText(hudX, hudY + 33, "> Escreve 'help' para ajuda",    0xFFFFFF)
    return hudObjects.header ~= nil
end

local function setLine(key, offsetY, textStr, hexColor)
    if not overlay or not hudVisible then return end
    local obj = hudObjects[key]
    if obj and obj.setText then
        local ok = pcall(function()
            obj.setText(textStr)
            if hexColor and obj.setColor then obj.setColor(hexColor) end
            if obj.setX then obj.setX(hudX) end
            if obj.setY then obj.setY(hudY + offsetY) end
        end)
        if ok then return end
    end
    hudObjects[key] = makeGuiText(hudX, hudY + offsetY, textStr, hexColor)
end

-- 4. Leitura de dados do utilizador
local ownerName = nil

local function getOwnerData()
    if smartglasses and smartglasses.getOwner then
        local ok, data = pcall(smartglasses.getOwner)
        if ok and type(data) == "table" then
            if data.name then ownerName = data.name end
            local px = data.x or (data.pos and data.pos.x) or 0
            local py = data.y or (data.pos and data.pos.y) or 0
            local pz = data.z or (data.pos and data.pos.z) or 0
            return {
                name = data.name or ownerName or "Boss",
                x = math.floor(px), y = math.floor(py), z = math.floor(pz),
                health = data.health, maxHealth = data.maxHealth or 20
            }
        end
    end
    return { name = ownerName or "Boss", x = 0, y = 0, z = 0 }
end

-- 5. Sistema de Voz e Alertas da IA
local function aiSay(msg, isAlert)
    local col = isAlert and 0xFF5555 or 0xFFFFFF
    setLine("speech", 33, "> " .. msg, col)

    if term.isColor() then term.setTextColor(isAlert and colors.red or colors.cyan) end
    print("[" .. AI_NAME .. "] " .. msg)
    if term.isColor() then term.setTextColor(colors.white) end

    if chatBox then
        local info = getOwnerData()
        local target = (info.name ~= "Boss") and info.name or nil
        pcall(function()
            chatBox.sendMessage("&b" .. msg, { player = target, prefix = AI_NAME, brackets = "[]" })
        end)
    end
end

-- 6. Scanner Automático de Minérios (Create, Mekanism e Raros)
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

    if not best then return "MINERIO: Nenhum por perto (8m)" end
    local ew = best.x >= 0 and (best.x .. "E") or (math.abs(best.x) .. "W")
    local ns = best.z >= 0 and (best.z .. "S") or (math.abs(best.z) .. "N")
    local ud = best.y >= 0 and (best.y .. "Cima") or (math.abs(best.y) .. "Baixo")

    return string.format("MINERIO: %s (%s %s %s) [+%d]", best.name, ew, ns, ud, total)
end

-- 7. Atualização Contínua do HUD
local function refreshHud()
    local t = os.time()
    local phase = (t >= 6 and t < 18.5) and "Dia" or "Noite"
    setLine("header", 1, string.format("[%s] %s (%s)", AI_NAME, textutils.formatTime(t, false), phase), 0x00FFFF)

    local info = getOwnerData()
    local hpStr = info.health and string.format(" | HP:%d", math.floor(info.health)) or ""
    local homeStr = ""
    if homePos then
        local dx, dz = homePos.x - info.x, homePos.z - info.z
        homeStr = string.format(" | Casa:%dm", math.floor(math.sqrt(dx*dx + dz*dz)))
    end
    setLine("stats", 2, string.format("XYZ: %d, %d, %d%s%s", info.x, info.y, info.z, hpStr, homeStr), 0x55FF55)

    local scanRes = scanNearbyOres()
    if scanRes then
        local col = scanRes:find("Nenhum") and 0xAAAAAA or 0xFFFF55
        setLine("scanner", 3, scanRes, col)
    end
end

-- 8. Processador de Comandos
local function processCommand(rawText)
    local cmd = rawText:lower():gsub("^%$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local info = getOwnerData()

    if cmd == "help" then
        aiSay("Cmds: status, ores, nv, set home, home, pos topo, pos mapa, hud")
    elseif cmd == "status" or cmd == "oi" then
        aiSay(string.format("Sistemas operacionais, %s! Pos: %d, %d, %d", info.name, info.x, info.y, info.z))
    elseif cmd == "ores" or cmd == "scan" then
        aiSay(scanNearbyOres() or "A arrefecer scanner...")
    elseif cmd == "nv" then
        if not nvModule then aiSay("Sem modulo de Visao Noturna!", true)
        else
            local _, cur = pcall(nvModule.isNightVisionEnabled)
            pcall(function() nvModule.enableNightVision(not cur) end)
            aiSay("Visao Noturna alternada com sucesso!")
        end
    elseif cmd == "set home" then
        saveHome(info.x, info.y, info.z)
        aiSay(string.format("Casa guardada em %d, %d, %d!", info.x, info.y, info.z))
    elseif cmd == "home" then
        if not homePos then aiSay("Usa 'set home' primeiro na tua base!", true)
        else
            local dx, dz = homePos.x - info.x, homePos.z - info.z
            aiSay(string.format("Base a %dm (X:%d Z:%d)", math.floor(math.sqrt(dx*dx + dz*dz)), homePos.x, homePos.z))
        end
    elseif cmd == "pos mapa" then
        hudX, hudY = 6, 148
        clearHud()
        refreshHud()
        aiSay("HUD reposicionado debaixo do minimapa.")
    elseif cmd == "pos topo" then
        hudX, hudY = 300, 8
        clearHud()
        refreshHud()
        aiSay("HUD reposicionado no canto superior direito.")
    elseif cmd == "hud" then
        hudVisible = not hudVisible
        if not hudVisible then clearHud() else initHud() refreshHud() end
        aiSay("Visibilidade do HUD alterada.")
    else
        aiSay("Comando nao reconhecido. Escreve 'help'.")
    end
end

-- Inicialização
clearHud()
initHud()
refreshHud()
aiSay("J.A.R.V.I.S. online e pronto a ajudar!")

-- Loops principais em background
local function loopTimer()
    local warnedHp = false
    local warnedNight = false
    while true do
        sleep(2.0)
        refreshHud()

        local info = getOwnerData()
        -- Alerta de vida crítica
        if info.health and info.health > 0 and info.health <= 6 and not warnedHp then
            aiSay("ALERTA: Vida critica (" .. math.floor(info.health) .. " HP)! Come algo!", true)
            warnedHp = true
        elseif info.health and info.health > 10 then
            warnedHp = false
        end

        -- Alerta de anoitecer
        local t = os.time()
        if t >= 18.0 and t <= 18.5 and not warnedNight then
            aiSay("Aviso: A noite esta a cair! Prepara as luzes.", true)
            warnedNight = true
        elseif t < 18.0 and t > 6.0 then
            warnedNight = false
        end
    end
end

local function loopTerm()
    while true do
        write("J.A.R.V.I.S. > ")
        local inp = read()
        if inp and #inp > 0 then processCommand(inp) end
    end
end

parallel.waitForAny(loopTimer, loopTerm)
