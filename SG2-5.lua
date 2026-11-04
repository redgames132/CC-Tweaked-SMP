-- ==========================================================
-- J.A.R.V.I.S. - Smart Glasses HUD & Assistente de IA
-- Corrigido para Advanced Peripherals 0.8+ (MC 1.21.1)
-- Layout adaptado para não sobrepor Minimapa nem Jetpack
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S."
local HOME_FILE = "ai_home.txt"
local hudVisible = true

-- Posição padrão: Debaixo do minimapa à esquerda (X=6, Y=148)
local hudX, hudY = 6, 148

-- 1. Detetar Módulos dos Smart Glasses (Acesso Direto AP 0.8)
local overlay = nil
local nvModule = nil

if smartglasses and smartglasses.modules then
    overlay  = smartglasses.modules["advancedperipherals:overlay"] or smartglasses.modules.overlay
    nvModule = smartglasses.modules["advancedperipherals:night_vision"] or smartglasses.modules.night_vision
end

-- Fallback caso esteja ligado como periférico
if not overlay then
    overlay = peripheral.find("overlay") or peripheral.find("advancedperipherals:overlay")
end

local scanner  = peripheral.find("geo_scanner") or peripheral.find("geoScanner")
local chatBox  = peripheral.find("chat_box") or peripheral.find("chatBox")
local detector = peripheral.find("player_detector") or peripheral.find("playerDetector")

-- 2. Carregar / Guardar Coordenadas de Casa (Home)
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

-- 3. Gestor de Objetos do Overlay Module (Com gui = true)
local hudObjects = {}

local function clearHud()
    if overlay and overlay.clear then
        pcall(overlay.clear)
    end
    for _, obj in pairs(hudObjects) do
        if obj and obj.remove then pcall(obj.remove) end
    end
    hudObjects = {}
end

local function makeGuiText(x, y, str, hexColor)
    if not overlay or not overlay.createObject then return nil end

    local props = {
        text = str,
        x = x,
        y = y,
        color = hexColor or 0xFFFFFF,
        gui = true,
        enabled = true
    }

    local ok, obj = pcall(function()
        return overlay.createObject("advancedperipherals:text", props)
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

    -- Painel Tático (Debaixo do Minimapa à esquerda)
    hudObjects.header  = makeGuiText(hudX, hudY,      "[" .. AI_NAME .. "] Online",   0x00FFFF)
    hudObjects.stats   = makeGuiText(hudX, hudY + 11, "XYZ: -- | HP: --",             0x55FF55)
    hudObjects.scanner = makeGuiText(hudX, hudY + 22, "SCAN: A aguardar...",          0xFFFF55)
    hudObjects.speech  = makeGuiText(hudX, hudY + 33, "> Escreve 'help' ou '$help'",  0xFFFFFF)

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
            if obj.setGui then obj.setGui(true) end
        end)
        if ok then return end
    end

    -- Recria o elemento caso tenha perdido a referência
    hudObjects[key] = makeGuiText(hudX, hudY + offsetY, textStr, hexColor)
end

-- 4. Obter Dados do Utilizador dos Óculos
local ownerName = nil

local function getOwnerData()
    if smartglasses and smartglasses.getOwner then
        local ok, data = pcall(smartglasses.getOwner)
        if ok and type(data) == "table" then
            if data.name then ownerName = data.name end
            local px = data.x or (data.pos and data.pos.x) or (data.position and data.position.x) or 0
            local py = data.y or (data.pos and data.pos.y) or (data.position and data.position.y) or 0
            local pz = data.z or (data.pos and data.pos.z) or (data.position and data.position.z) or 0
            return {
                name = data.name or ownerName or "Boss",
                x = math.floor(px),
                y = math.floor(py),
                z = math.floor(pz),
                health = data.health,
                maxHealth = data.maxHealth or 20
            }
        end
    end

    if detector then
        if not ownerName and detector.getOnlinePlayers then
            local ok, list = pcall(detector.getOnlinePlayers)
            if ok and type(list) == "table" and #list > 0 then ownerName = list[1] end
        end
        if ownerName and detector.getPlayerPos then
            local ok, pos = pcall(function() return detector.getPlayerPos(ownerName) end)
            if ok and type(pos) == "table" and pos.x then
                return {
                    name = ownerName,
                    x = math.floor(pos.x),
                    y = math.floor(pos.y),
                    z = math.floor(pos.z),
                    health = pos.health,
                    maxHealth = pos.maxHealth or 20
                }
            end
        end
    end

    return { name = ownerName or "Boss", x = 0, y = 0, z = 0 }
end

-- 5. Fala da IA (HUD + Terminal + Chat)
local function aiSay(msg, isAlert)
    local col = isAlert and 0xFF5555 or 0xFFFFFF
    setLine("speech", 33, "> " .. msg, col)

    if term.isColor() then
        term.setTextColor(isAlert and colors.red or colors.cyan)
    end
    print("[" .. AI_NAME .. "] " .. msg)
    if term.isColor() then term.setTextColor(colors.white) end

    if chatBox then
        local info = getOwnerData()
        local target = (info.name ~= "Boss") and info.name or nil
        pcall(function()
            chatBox.sendMessage("&b" .. msg, {
                player = target, prefix = AI_NAME, brackets = "[]"
            })
        end)
    end
end

-- 6. Scanner de Minérios (Mekanism, Create e Vanilla Raros)
local RARE_ORES = {
    "ancient_debris", "uranium", "osmium", "diamond",
    "emerald", "fluorite", "zinc", "gold", "lead_ore", "tin_ore"
}

local function scanNearbyOres()
    if not scanner then return "SCAN: Sem Geo Scanner nos oculos" end
    local scanFn = scanner.scanBlocks or scanner.scan
    if not scanFn then return "SCAN: Indisponivel" end

    local ok, blocks = pcall(function() return scanFn(8) end)
    if not ok or type(blocks) ~= "table" then return nil end

    local best = nil
    local bestDist = 999
    local total = 0

    for _, b in ipairs(blocks) do
        local name = (b.name or ""):lower()
        for _, key in ipairs(RARE_ORES) do
            if name:find(key) then
                total = total + 1
                local clean = key:gsub("_ore", ""):gsub("^%l", string.upper)
                local dist = math.abs(b.x or 0) + math.abs(b.y or 0) + math.abs(b.z or 0)
                if dist < bestDist then
                    bestDist = dist
                    best = {
                        name = clean,
                        x = math.floor(b.x or 0),
                        y = math.floor(b.y or 0),
                        z = math.floor(b.z or 0)
                    }
                end
                break
            end
        end
    end

    if not best then return "SCAN: Nenhum minerio raro (8m)" end

    local ew = best.x > 0 and (best.x .. "E") or (best.x < 0 and (math.abs(best.x) .. "W") or "0E")
    local ns = best.z > 0 and (best.z .. "S") or (best.z < 0 and (math.abs(best.z) .. "N") or "0N")
    local ud = best.y > 0 and (best.y .. "Cima") or (best.y < 0 and (math.abs(best.y) .. "Baixo") or "Nivel")

    return string.format("MINERIO: %s (%s, %s, %s) [+%d]", best.name, ew, ns, ud, total)
end

-- 7. Atualização Automática do HUD
local function refreshHud()
    if not overlay or not hudVisible then return end

    local t = os.time()
    local timeStr = textutils.formatTime(t, false)
    local phase = (t >= 6 and t < 18.5) and "Dia" or "Noite"
    setLine("header", 0, string.format("[%s] %s (%s)", AI_NAME, timeStr, phase), 0x00FFFF)

    local info = getOwnerData()
    local hpStr = info.health and string.format(" | HP:%d/%d", math.floor(info.health), info.maxHealth) or ""
    local homeStr = ""
    if homePos then
        local dx, dz = homePos.x - info.x, homePos.z - info.z
        local dist = math.floor(math.sqrt(dx * dx + dz * dz))
        homeStr = string.format(" | Casa:%dm", dist)
    end
    setLine("stats", 11, string.format("XYZ: %d, %d, %d%s%s", info.x, info.y, info.z, hpStr, homeStr), 0x55FF55)

    local scanRes = scanNearbyOres()
    if scanRes then
        local col = scanRes:find("Nenhum") and 0xAAAAAA or 0xFFFF55
        setLine("scanner", 22, scanRes, col)
    end
end

-- 8. Processador de Comandos da IA
local function processCommand(rawText, sender)
    if sender and sender ~= "" and sender ~= "[say]" then ownerName = sender end
    local cmd = rawText:lower():gsub("^%$", ""):gsub("^ai%s+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local info = getOwnerData()

    if cmd == "help" or cmd == "?" then
        aiSay("Cmds: status, ores, nv, set home, home, pos topo, pos mapa, move <x> <y>, hud")

    elseif cmd == "status" or cmd:find("oi") == 1 or cmd:find("hi") == 1 then
        aiSay(string.format("Sistemas a 100%%, %s! Pos: %d, %d, %d", info.name, info.x, info.y, info.z))

    elseif cmd:find("ore") or cmd:find("scan") or cmd:find("minerio") then
        local res = scanNearbyOres() or "Scanner em arrefecimento (aguarda 2s)."
        setLine("scanner", 22, res, 0xFFFF55)
        aiSay(res)

    elseif cmd == "nv" or cmd:find("night") or cmd:find("luz") then
        if not nvModule then
            aiSay("Modulo de Visao Noturna nao detetado nos oculos!", true)
        else
            local ok, cur = pcall(nvModule.isNightVisionEnabled)
            local nextState = not (ok and cur)
            pcall(function() nvModule.enableNightVision(nextState) end)
            aiSay("Visao Noturna: " .. (nextState and "ATIVADA" or "DESATIVADA"))
        end

    elseif cmd == "set home" or cmd == "sethome" then
        saveHome(info.x, info.y, info.z)
        aiSay(string.format("Casa guardada em %d, %d, %d!", info.x, info.y, info.z))

    elseif cmd == "home" or cmd == "casa" then
        if not homePos then
            aiSay("Usa 'set home' primeiro para guardar a base!", true)
        else
            local dx, dz = homePos.x - info.x, homePos.z - info.z
            local dist = math.floor(math.sqrt(dx * dx + dz * dz))
            local ew = dx > 0 and (dx .. "E") or (math.abs(dx) .. "W")
            local ns = dz > 0 and (dz .. "S") or (math.abs(dz) .. "N")
            aiSay(string.format("Casa a %dm (%s, %s | Y:%d)", dist, ew, ns, homePos.y))
        end

    elseif cmd == "pos mapa" then
        hudX, hudY = 6, 148
        refreshHud()
        aiSay("HUD posicionado debaixo do Minimapa (6, 148).")

    elseif cmd == "pos topo" then
        hudX, hudY = 300, 8
        refreshHud()
        aiSay("HUD posicionado no Canto Superior Direito (300, 8).")

    elseif cmd:find("^move ") then
        local nx, ny = cmd:match("^move%s+(%d+)%s+(%d+)")
        if nx and ny then
            hudX, hudY = tonumber(nx), tonumber(ny)
            refreshHud()
            aiSay("HUD movido para X:" .. hudX .. " Y:" .. hudY)
        end

    elseif cmd == "hud" then
        hudVisible = not hudVisible
        if not hudVisible then clearHud() else initHud() refreshHud() end
        print("Visibilidade do HUD: " .. tostring(hudVisible))

    else
        aiSay("Comando desconhecido. Escreve 'help' para ver a lista.")
    end
end

-- 9. Loops Principais
local function backgroundLoop()
    local timerId = os.startTimer(0.5)
    local warnedLowHp = false

    while true do
        local ev, p1, p2, p3, p4 = os.pullEvent()

        if ev == "timer" and p1 == timerId then
            refreshHud()
            local info = getOwnerData()
            if info.health and info.health > 0 and info.health <= 6 and not warnedLowHp then
                aiSay("ALERTA: Vida critica (" .. math.floor(info.health) .. " HP)!", true)
                warnedLowHp = true
            elseif info.health and info.health > 10 then
                warnedLowHp = false
            end
            timerId = os.startTimer(2.0)

        elseif ev == "chat" then
            local sender, message, isHidden
            if type(p1) == "string" and p1:find("%-") and type(p3) == "string" then
                sender, message, isHidden = p2, p3, p4
            else
                sender, message, isHidden = p1, p2, p4
            end
            if type(message) == "string" then
                if isHidden or message:sub(1, 1) == "$" or message:lower():sub(1, 3) == "ai " then
                    processCommand(message, sender)
                end
            end
        end
    end
end

local function terminalLoop()
    while true do
        if term.isColor() then term.setTextColor(colors.yellow) end
        write("J.A.R.V.I.S. > ")
        if term.isColor() then term.setTextColor(colors.white) end
        local input = read()
        if input and #input > 0 then
            processCommand(input, ownerName)
        end
    end
end

-- Inicialização e Diagnóstico
term.clear()
term.setCursorPos(1, 1)

if not overlay then
    if term.isColor() then term.setTextColor(colors.red) end
    print("[ERRO] Modulo 'advancedperipherals:overlay' nao encontrado!")
    print("Verifica se colocaste o 'Overlay Module' dentro dos teus Smart Glasses.")
else
    local created = initHud()
    refreshHud()
    if created then
        aiSay("HUD ativo debaixo do teu minimapa!")
    else
        print("[AVISO] Overlay detetado, mas createObject falhou.")
    end
end

parallel.waitForAny(backgroundLoop, terminalLoop)
