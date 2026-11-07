-- ==========================================================
-- J.A.R.V.I.S. T.A.C. V11 - SISTEMA DE COMANDO MILITAR
-- Modulo de IA Substituido por Telemetria Orbital/Climatica
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S. T.A.C."
local OWNER = "redgames132"
local ALLY = "cadipadi"

local TEAM = { [OWNER] = true, [ALLY] = true }

-- Perifericos
local mon = peripheral.find("monitor")
if not mon then error("ERRO: Monitor ausente. Abortando boot.", 0) end
local detector = peripheral.find("playerDetector") or peripheral.find("player_detector")
local scanner  = peripheral.find("geoScanner") or peripheral.find("geo_scanner")
local chatBox  = peripheral.find("chatBox") or peripheral.find("chat_box")
local envSens  = peripheral.find("environmentDetector") or peripheral.find("environment_detector")

-- Configuracao do Ecra (Matriz 4x3)
mon.setTextScale(0.5)
local w, h = mon.getSize()

-- Sistema de Abas (7 Abas Taticas)
local TABS = {"RADAR", "SCAN", "EQUIPE", "CORE", "COMMS", "BASE", "ORBITAL"}
local activeTab = 1
local tabZones = {}

-- Estado Global
local logs = { "[SYS]: Modulo T.A.C. V11 Operacional.", "[ORBITAL]: Enlace de satelite estabelecido." }
local chatHistory = { "[INTERCETADOR]: Escuta de radio ativa." }

local maxLogs = h - 10
local uptime = 0
local lockdownMode = false
local knownIntruders = {}
local threatLevel = "DEFCON 5"

-- Estado dos Modulos
local scanResults = {}
local scanStatus = "PRONTO PARA EXTRACAO"
local scanCooldown = 0
local R_RANGES = {16, 32, 64, 128, 256}
local rIdx = 2
local rsStates = { top = false, bottom = false, left = false, right = false }

-- ==========================================================
-- MOTOR DE RENDERIZACAO MILITAR (UI)
-- ==========================================================
local function drawText(x, y, txt, fg, bg)
    mon.setCursorPos(x, y)
    if fg then mon.setTextColor(fg) end
    if bg then mon.setBackgroundColor(bg) else mon.setBackgroundColor(colors.black) end
    mon.write(txt)
end

local function drawBox(x, y, bw, bh, title, frameColor, isAlert)
    local fCol = isAlert and colors.orange or frameColor or colors.gray
    local hLine = string.rep("-", bw - 2)
    drawText(x, y, "+" .. hLine .. "+", fCol)
    drawText(x, y + bh - 1, "+" .. hLine .. "+", fCol)
    for i = 1, bh - 2 do
        drawText(x, y + i, "|", fCol)
        drawText(x + bw - 1, y + i, "|", fCol)
    end
    if title then drawText(x + 2, y, "-[ " .. title .. " ]-", colors.white, colors.black) end
end

local function drawProgressBar(x, y, width, val, maxVal, color)
    local fill = math.floor((val / maxVal) * width)
    if fill > width then fill = width end
    if fill < 0 then fill = 0 end
    local empty = width - fill
    
    drawText(x, y, "[", colors.gray)
    if fill > 0 then drawText(x + 1, y, string.rep("=", fill), color) end
    if empty > 0 then drawText(x + 1 + fill, y, string.rep("-", empty), colors.gray) end
    drawText(x + width + 1, y, "]", colors.gray)
end

local function aiLog(msg)
    table.insert(logs, 1, msg)
    if #logs > maxLogs then table.remove(logs, #logs) end
end

local function getPlayerStats(playerName)
    if not detector then return nil end
    local ok, pos = pcall(function() return detector.getPlayerPos(playerName) end)
    if ok and type(pos) == "table" and pos.health then return pos end
    return nil
end

-- ==========================================================
-- LOGICA DOS SENSORES E CONTROLES
-- ==========================================================
local function updateThreatLevel()
    local isNight = (os.time() < 6 or os.time() >= 18.5)
    if lockdownMode then threatLevel = "DEFCON 1 (COMBATE)"
    elseif #knownIntruders > 0 then threatLevel = "DEFCON 2 (INTRUSO)"
    elseif isNight then threatLevel = "DEFCON 3 (NOTURNO)"
    else threatLevel = "DEFCON 5 (SEGURO)" end
end

local function checkIntruders()
    if not detector then return end
    local ok, players = pcall(detector.getOnlinePlayers)
    if ok and type(players) == "table" then
        local currentIntruders = {}
        for _, p in ipairs(players) do
            if not TEAM[p] then
                table.insert(currentIntruders, p)
                local isNew = true
                for _, old in ipairs(knownIntruders) do if old == p then isNew = false break end end
                if isNew then aiLog("[ALERTA]: Hostil detectado -> " .. p) end
            end
        end
        knownIntruders = currentIntruders
        updateThreatLevel()
    end
end

local function runScan()
    if scanCooldown > 0 then return end
    scanResults = {}
    scanStatus = "CALIBRANDO SISMOGRAFOS..."
    
    if not scanner then scanStatus = "ERRO: SENSOR OFFLINE"; return end
    local ok, blocks = pcall(function() return scanner.scan(16) end)
    if not ok or type(blocks) ~= "table" then scanStatus = "EM ARREFECIMENTO"; return end
    
    local RARE = {"ancient_debris", "uranium", "osmium", "diamond", "emerald", "fluorite", "zinc", "gold"}
    for _, b in ipairs(blocks) do
        local raw = (b.name or ""):lower()
        for _, r in ipairs(RARE) do
            if raw:find(r) then
                local dist = math.floor(math.sqrt((b.x or 0)^2 + (b.y or 0)^2 + (b.z or 0)^2))
                local clean = raw:match(":(.+)") or raw
                clean = clean:gsub("_ore", ""):gsub("deepslate_", ""):upper()
                table.insert(scanResults, { name = clean, d = dist, y = math.floor(b.y or 0) })
                break
            end
        end
    end
    table.sort(scanResults, function(a, b) return a.d < b.d end)
    scanStatus = #scanResults > 0 and ("ALVOS DETECTADOS: " .. #scanResults) or "NENHUM ALVO (16m)"
    scanCooldown = 5
end

local function toggleRedstone(side)
    rsStates[side] = not rsStates[side]
    rs.setOutput(side, rsStates[side])
    aiLog(string.format("[SYS]: Circuito '%s' %s.", side, rsStates[side] and "ATIVO" or "CORTADO"))
end

-- ==========================================================
-- DESENHO DAS ABAS E TELA
-- ==========================================================
local function drawTopBar()
    drawText(1, 1, string.rep(" ", w), colors.white, colors.gray)
    drawText(1, 2, string.rep(" ", w), colors.white, colors.gray)
    drawText(2, 1, string.format(" %s // %s ", AI_NAME, threatLevel), colors.white, colors.black)
    
    tabZones = {}
    local currentX = 2
    for i, tabName in ipairs(TABS) do
        local isSelected = (i == activeTab)
        local bg = isSelected and colors.red or colors.black
        local fg = isSelected and colors.white or colors.lightGray
        local txt = " " .. tabName .. " "
        drawText(currentX, 2, txt, fg, bg)
        tabZones[i] = { startX = currentX, endX = currentX + #txt - 1 }
        currentX = currentX + #txt + 1
    end
end

local function updateScreen()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    updateThreatLevel()
    drawTopBar()
    
    if activeTab == 1 then
        -- RADAR
        local bx, by, bw, bh = 2, 4, w - 2, h - 4
        drawBox(bx, by, bw, bh, "RADAR TATICO", colors.red, lockdownMode)
        local cx, cy = bx + math.floor(bw/2), by + math.floor(bh/2)
        local range = R_RANGES[rIdx]
        
        for i = bx + 1, bx + bw - 2 do drawText(i, cy, "-", colors.red) end
        for i = by + 1, by + bh - 2 do drawText(cx, i, "|", colors.red) end
        drawText(cx, cy, "X", colors.white)

        local refPos = getPlayerStats(OWNER) or getPlayerStats(ALLY)
        if refPos and detector then
            local ok, players = pcall(detector.getOnlinePlayers)
            if ok and type(players) == "table" then
                for _, p in ipairs(players) do
                    local st = getPlayerStats(p)
                    if st then
                        local px = cx + math.floor(((st.x - refPos.x) / range) * (bw/2 - 2))
                        local py = cy + math.floor(((st.z - refPos.z) / range) * (bh/2 - 2))
                        if px > bx and px < bx + bw - 1 and py > by and py < by + bh - 1 then
                            local char, col = "!", colors.orange
                            if p == OWNER then char = "@"; col = colors.white
                            elseif p == ALLY then char = "+"; col = colors.yellow end
                            drawText(px, py, char, col, colors.black)
                        end
                    end
                end
            end
        end
        drawText(4, h - 2, "[ - ]", colors.white, colors.gray)
        drawText(11, h - 2, string.format("RAIO: %03dm", range), colors.white)
        drawText(24, h - 2, "[ + ]", colors.white, colors.gray)

    elseif activeTab == 2 then
        -- SCANNER
        local cW = math.floor((w - 4) / 2)
        drawBox(2, 4, cW, h - 4, "MODULO DE MINERACAO TATICA", colors.red, lockdownMode)
        drawText(4, 6, "> " .. scanStatus, colors.white)
        local btnTxt = scanCooldown > 0 and ("AGUARDE " .. scanCooldown .. "s") or "INICIAR EXTRACAO"
        drawText(4 + math.floor((cW - #btnTxt - 4)/2), 11, "[" .. btnTxt .. "]", colors.white, scanCooldown > 0 and colors.gray or colors.red)
        
        drawBox(3 + cW, 4, cW, h - 4, "ALVOS IDENTIFICADOS", colors.gray, lockdownMode)
        if #scanResults > 0 then
            drawText(5 + cW, 5, " MATERIA PRIMA  DISTANCIA", colors.red)
            for i = 1, math.min(#scanResults, h - 8) do
                local r = scanResults[i]
                local ud = r.y > 0 and "^" or (r.y < 0 and "v" or "=")
                drawText(5 + cW, 6 + i, string.format(" %-14s %s [%s]", r.name:sub(1,12), r.d.."m", ud), colors.white)
            end
        end

    elseif activeTab == 3 then
        -- EQUIPE E DEFESA
        local cW = math.floor((w - 4) / 2)
        drawBox(2, 4, cW, h - 4, "TELEMETRIA DO ESQUADRAO", colors.red, lockdownMode)
        
        local function renderS(name, yPos, title)
            local p = getPlayerStats(name)
            drawText(4, yPos, title .. name, colors.white)
            if p then
                local hp = math.floor(p.health)
                drawText(4, yPos+1, string.format("HP: %02d/%02d", hp, p.maxHealth), colors.lightGray)
                drawProgressBar(14, yPos+1, cW - 16, hp, p.maxHealth, hp <= 6 and colors.red or colors.yellow)
            else drawText(4, yPos+1, "[ SINAL M.I.A ]", colors.gray) end
        end
        renderS(OWNER, 6, "LIDER: ")
        renderS(ALLY, 10, "SOLDADO: ")

        drawBox(3 + cW, 4, cW, h - 4, "CONTROLE DE HOSTIS", colors.orange, lockdownMode)
        if #knownIntruders > 0 then
            for i, inv in ipairs(knownIntruders) do drawText(5 + cW, 6 + i, "-> " .. inv, colors.red) end
        end
        local lkTxt = lockdownMode and " DESATIVAR COMBATE " or " ATIVAR PROTOCOLO COMBATE "
        drawText(3 + cW + math.floor((cW - #lkTxt - 2)/2), h - 2, "["..lkTxt.."]", colors.white, lockdownMode and colors.orange or colors.red)

    elseif activeTab == 4 then
        -- CORE (SISTEMA)
        local bx, by, bw = 2, 4, math.floor(w / 3)
        drawBox(bx, by, bw, h - 4, "DIAGNOSTICO DE NUCLEO", colors.red, lockdownMode)
        drawText(bx + 2, by + 2, "Relogio: " .. textutils.formatTime(os.time(), false), colors.white)
        drawText(bx + 2, by + 5, "CPU:", colors.gray)
        drawProgressBar(bx + 2, by + 6, bw - 6, math.random(20,50), 100, colors.red)
        drawText(bx + 2, by + 8, "RAM:", colors.gray)
        drawProgressBar(bx + 2, by + 9, bw - 6, math.random(30,60), 100, colors.orange)
        
        local lx = bx + bw + 1
        drawBox(lx, by, w - lx, h - 4, "REGISTOS OFICIAIS DE BORDO", colors.gray, lockdownMode)
        for i, msg in ipairs(logs) do
            if i <= maxLogs then drawText(lx + 2, by + 1 + i, ((i==1) and "> " or "  ") .. msg, (i==1) and colors.white or colors.gray) end
        end

    elseif activeTab == 5 then
        -- COMMS (ESCUTA DE RADIO)
        drawBox(2, 4, w - 2, h - 4, "ESCUTA TÁTICA DE FREQUENCIAS", colors.gray, lockdownMode)
        for i, msg in ipairs(chatHistory) do
            if i <= maxLogs then drawText(4, 5 + i, msg, (i==1) and colors.white or colors.gray) end
        end

    elseif activeTab == 6 then
        -- BASE (REDSTONE)
        drawBox(2, 4, w - 2, h - 4, "PERIMETRO E HARDWARE", colors.red, lockdownMode)
        local function rSw(label, side, y)
            drawText(4, y, label .. ":", colors.white)
            drawText(26, y, rsStates[side] and "[ ENERGIZADO ]" or "[ CORTADO    ]", rsStates[side] and colors.red or colors.gray, colors.black)
        end
        rSw("Defesa Anti-Aerea (Cima)", "top", 8)
        rSw("Portao Subterraneo (Baixo)", "bottom", 10)
        rSw("Alarmes Externos (Esq)", "left", 12)
        rSw("Iluminacao Tatica (Dir)", "right", 14)

    elseif activeTab == 7 then
        -- NOVO: ORBITAL (SATELITE E CLIMA)
        drawBox(2, 4, w - 2, h - 4, "ENLACE DE SATELITE ORBITAL", colors.blue, lockdownMode)
        
        if not envSens then
            drawText(4, 7, "[ALERTA]: Sensor Ambiental Offline.", colors.red)
            drawText(4, 8, "Conecte um 'Environment Detector' a base.", colors.gray)
        else
            -- Clima e Condicoes
            local isRain = false
            local isThun = false
            local rad = 0
            
            pcall(function() isRain = envSens.isRaining() end)
            pcall(function() isThun = envSens.isThunder() end)
            pcall(function() rad = envSens.getRadiation() end)
            
            drawText(4, 6, "Condicoes Atmosfericas:", colors.gray)
            if isThun then drawText(4, 7, "TEMPESTADE SEVERA (Risco de Raios)", colors.red)
            elseif isRain then drawText(4, 7, "CHUVA (Visibilidade Reduzida)", colors.orange)
            else drawText(4, 7, "CEU LIMPO (Condicoes Ideais)", colors.lime) end
            
            drawText(4, 11, "Nivel de Radiacao Local (Mekanism):", colors.gray)
            drawText(4, 12, string.format("%.4f Sv/h", rad or 0), (rad and rad > 0.01) and colors.red or colors.lime)
        end
        
        -- Deducao de Risco Noturno
        local time = os.time()
        drawText(4, 16, "Analise de Risco da Superficie:", colors.gray)
        if time >= 18.5 or time < 6 then
            drawText(4, 17, "ATIVIDADE HOSTIL ALTA (Noite)", colors.red)
        else
            drawText(4, 17, "ATIVIDADE HOSTIL BAIXA (Dia)", colors.yellow)
        end
    end
end

-- ==========================================================
-- LOOP PRINCIPAL (UNIFICADO)
-- ==========================================================
term.clear()
print("J.A.R.V.I.S. T.A.C. V11 Online.")
checkIntruders()
updateScreen()

while true do
    local tid = os.startTimer(1.0)
    local ev, p1, p2, p3 = os.pullEvent()
    
    if ev == "timer" and p1 == tid then
        uptime = uptime + 1
        if scanCooldown > 0 then scanCooldown = scanCooldown - 1 end
        if uptime % 2 == 0 then checkIntruders() end
        updateScreen()
        
    elseif ev == "chat" then
        -- Escutar para a aba COMMS
        local sender, msg = p1, p2
        if type(p2) == "string" and p2:find("%-") then sender, msg = p2, p3 end
        if type(msg) == "string" then
            table.insert(chatHistory, 1, "[" .. tostring(sender) .. "]: " .. msg)
            if #chatHistory > maxLogs then table.remove(chatHistory, #chatHistory) end
            if activeTab == 5 then updateScreen() end
        end
        
    elseif ev == "monitor_touch" then
        local tx, ty = p2, p3
        if ty == 2 then
            for i, zone in ipairs(tabZones) do
                if tx >= zone.startX and tx <= zone.endX then
                    activeTab = i; updateScreen(); break
                end
            end
        else
            if activeTab == 1 then
                if ty == h - 2 then
                    if tx >= 4 and tx <= 8 and rIdx > 1 then rIdx = rIdx - 1; updateScreen()
                    elseif tx >= 24 and tx <= 28 and rIdx < #R_RANGES then rIdx = rIdx + 1; updateScreen() end
                end
            elseif activeTab == 2 then
                local cW = math.floor((w - 4) / 2)
                if ty == 11 and tx < cW and scanCooldown == 0 then runScan(); updateScreen() end
            elseif activeTab == 3 then
                local cW = math.floor((w - 4) / 2)
                if ty == h - 2 and tx > cW + 3 then
                    lockdownMode = not lockdownMode
                    aiLog(lockdownMode and "[COMANDO]: DEFESA ATIVADA." or "[COMANDO]: Standby.")
                    updateScreen()
                end
            elseif activeTab == 6 then
                if tx >= 26 and tx <= 40 then
                    if ty == 8 then toggleRedstone("top"); updateScreen()
                    elseif ty == 10 then toggleRedstone("bottom"); updateScreen()
                    elseif ty == 12 then toggleRedstone("left"); updateScreen()
                    elseif ty == 14 then toggleRedstone("right"); updateScreen()
                    end
                end
            end
        end
    end
end
