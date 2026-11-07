-- ==========================================================
-- J.A.R.V.I.S. T.A.C. V8 - SISTEMA DE COMANDO MILITAR
-- Tema Avermelhado, UI Tatica, Rastreio de Racoes, DEFCON.
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

-- Configuracao do Ecra (Matriz 4x3)
mon.setTextScale(0.5)
local w, h = mon.getSize()

-- Sistema de Abas (Nomenclatura Militar)
local TABS = {"RADAR", "SCANNER", "ESQUADRAO", "NUCLEO", "COMMS", "PERIMETRO"}
local activeTab = 1
local tabZones = {}

-- Estado Global e Telemetria
local logs = { "[SYS]: J.A.R.V.I.S. T.A.C. Online.", "[SYS]: Sensores balisticos calibrados." }
local chatHistory = { "[COMMS]: Intercetador de frequencias ativo." }
local maxLogs = h - 10
local uptime = 0
local lockdownMode = false
local knownIntruders = {}
local threatLevel = "DEFCON 5 (SEGURO)"
local threatColor = colors.gray

-- Estado do Scanner Tatico
local scanResults = {}
local scanStatus = "PRONTO PARA EXTRACAO"
local scanCooldown = 0

-- Estado do Radar (Sweep)
local R_RANGES = {16, 32, 64, 128, 256}
local rIdx = 2

-- Estado do Perimetro (Redstone Militar)
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
    
    -- Bordas Taticas
    drawText(x, y, "+" .. hLine .. "+", fCol)
    drawText(x, y + bh - 1, "+" .. hLine .. "+", fCol)
    for i = 1, bh - 2 do
        drawText(x, y + i, "|", fCol)
        drawText(x + bw - 1, y + i, "|", fCol)
    end
    
    if title then
        drawText(x + 2, y, "-[ " .. title .. " ]-", colors.white, colors.black)
    end
end

local function drawButton(x, y, txt, fg, bg)
    drawText(x, y, "[" .. txt .. "]", fg, bg)
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

local function addChat(msg)
    table.insert(chatHistory, 1, msg)
    if #chatHistory > maxLogs then table.remove(chatHistory, #chatHistory) end
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
    local t = os.time()
    local isNight = (t < 6 or t >= 18.5)
    local hasIntruders = (#knownIntruders > 0)
    
    if lockdownMode then
        threatLevel = "DEFCON 1 (COMBATE ATIVO)"
        threatColor = colors.red
    elseif hasIntruders then
        threatLevel = "DEFCON 2 (INTRUSO NO PERIMETRO)"
        threatColor = colors.orange
    elseif isNight then
        threatLevel = "DEFCON 3 (AMEACA NOTURNA)"
        threatColor = colors.yellow
    else
        threatLevel = "DEFCON 5 (SEGURO)"
        threatColor = colors.gray
    end
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
    aiLog("[SYS]: Iniciando extracao de dados do terreno.")
    
    if not scanner then scanStatus = "ERRO: SENSOR GEOLOGICO OFFLINE"; return end
    local ok, blocks = pcall(function() return scanner.scan(16) end)
    if not ok or type(blocks) ~= "table" then scanStatus = "SENSORES EM ARREFECIMENTO"; return end
    
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
    scanStatus = #scanResults > 0 and ("ALVOS DETECTADOS: " .. #scanResults) or "NENHUM ALVO VALIOSO (16m)"
    scanCooldown = 5
end

local function toggleRedstone(side)
    rsStates[side] = not rsStates[side]
    rs.setOutput(side, rsStates[side])
    aiLog(string.format("[SYS]: Circuito '%s' %s.", side, rsStates[side] and "ATIVO" or "CORTADO"))
end

-- ==========================================================
-- DESENHO DAS ABAS
-- ==========================================================
local function drawTopBar()
    local theme = lockdownMode and colors.red or colors.gray
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

-- ABA 1: RADAR CARMESIM
local function drawTabRadar()
    local bx, by = 2, 4
    local bw, bh = w - 2, h - 4
    drawBox(bx, by, bw, bh, "RADAR TATICO [360]", colors.red, lockdownMode)
    
    local cx, cy = bx + math.floor(bw/2), by + math.floor(bh/2)
    local range = R_RANGES[rIdx]

    -- Malha vermelha
    for i = bx + 1, bx + bw - 2 do drawText(i, cy, "-", colors.red) end
    for i = by + 1, by + bh - 2 do drawText(cx, i, "|", colors.red) end
    drawText(cx, cy, "X", colors.white)

    for iy = by + 1, by + bh - 2 do
        for ix = bx + 1, bx + bw - 2 do
            local rx, ry = (ix - cx) / (bw/2 - 1), (iy - cy) / (bh/2 - 1) * 2.0
            local dist = math.sqrt(rx*rx + ry*ry)
            if math.abs(dist - 0.33) < 0.05 or math.abs(dist - 0.66) < 0.05 or math.abs(dist - 0.99) < 0.05 then
                if ix ~= cx and iy ~= cy then drawText(ix, iy, ".", colors.red) end
            end
        end
    end

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
    
    drawButton(4, h - 2, " - ", colors.white, colors.gray)
    drawText(11, h - 2, string.format("RAIO: %03dm", range), colors.white)
    drawButton(24, h - 2, " + ", colors.white, colors.gray)
end

-- ABA 2: SCANNER (EXTRACAO)
local function drawTabScanner()
    local cW = math.floor((w - 4) / 2)
    drawBox(2, 4, cW, h - 4, "MODULO DE MINERACAO TATICA", colors.red, lockdownMode)
    
    drawText(4, 6, "Telemetria do Subsolo:", colors.lightGray)
    drawText(4, 7, "> " .. scanStatus, colors.white)
    
    local btnTxt = scanCooldown > 0 and ("AGUARDE " .. scanCooldown .. "s") or "INICIAR EXTRACAO"
    local btnCol = scanCooldown > 0 and colors.gray or colors.red
    drawButton(4 + math.floor((cW - #btnTxt - 4)/2), 11, " " .. btnTxt .. " ", colors.white, btnCol)
    
    drawBox(3 + cW, 4, cW, h - 4, "ALVOS IDENTIFICADOS", colors.gray, lockdownMode)
    if #scanResults == 0 then
        drawText(5 + cW, 6, "Sem alvos rastreados.", colors.gray)
    else
        drawText(5 + cW, 5, " MATERIA PRIMA  DISTANCIA  EIXO-Y", colors.red)
        for i = 1, math.min(#scanResults, h - 8) do
            local res = scanResults[i]
            local ud = res.y > 0 and "^" or (res.y < 0 and "v" or "=")
            local line = string.format(" %-14s %-10s %s", res.name:sub(1,12), res.d.."m", ud)
            drawText(5 + cW, 6 + i, line, colors.white)
        end
    end
end

-- ABA 3: ESQUADRAO (VIDA E COMIDA)
local function drawTabTeam()
    local cW = math.floor((w - 4) / 2)
    drawBox(2, 4, cW, h - 4, "TELEMETRIA DO ESQUADRAO", colors.red, lockdownMode)
    
    local function renderSoldier(name, yPos, title)
        local p = getPlayerStats(name)
        drawText(4, yPos, title .. name, colors.white)
        if p then
            drawText(cW - 10, yPos, "[ EM CAMPO ]", colors.lime)
            local hp = math.floor(p.health)
            local food = math.floor(p.foodLevel or p.hunger or 20) -- Tenta ler a fome
            
            drawText(4, yPos+1, string.format("HP: %02d/%02d", hp, p.maxHealth), colors.lightGray)
            drawProgressBar(14, yPos+1, cW - 16, hp, p.maxHealth, hp <= 6 and colors.red or colors.yellow)
            
            drawText(4, yPos+2, string.format("RACAO: %02d", food), colors.lightGray)
            drawProgressBar(14, yPos+2, cW - 16, food, 20, food <= 6 and colors.orange or colors.orange)
        else
            drawText(cW - 13, yPos, "[ SINAL M.I.A ]", colors.gray)
            drawText(4, yPos+1, "Comunicacao cortada.", colors.gray)
        end
    end
    
    renderSoldier(OWNER, 6, "LIDER: ")
    renderSoldier(ALLY, 11, "SOLDADO: ")

    drawBox(3 + cW, 4, cW, h - 4, "CONTROLE DE HOSTIS", colors.orange, lockdownMode)
    if #knownIntruders == 0 then
        drawText(5 + cW, 6, "Setor livre de ameacas.", colors.gray)
    else
        drawText(5 + cW, 6, "HOSTIS NO SETOR:", colors.red)
        for i, inv in ipairs(knownIntruders) do drawText(5 + cW, 7 + i, "-> " .. inv, colors.white) end
    end
    
    local lkTxt = lockdownMode and " DESATIVAR PROTOCOLO DE COMBATE " or " ATIVAR PROTOCOLO DE COMBATE (LOCKDOWN) "
    drawButton(3 + cW + math.floor((cW - #lkTxt - 2)/2), h - 2, lkTxt, colors.white, lockdownMode and colors.orange or colors.red)
end

-- ABA 4: NUCLEO (SISTEMA)
local function drawTabSystem()
    local bx, by = 2, 4
    local bw = math.floor(w / 3)
    
    drawBox(bx, by, bw, h - 4, "DIAGNOSTICO DO NUCLEO", colors.red, lockdownMode)
    local t = os.time()
    
    drawText(bx + 2, by + 2, "Relogio Tatico:", colors.gray)
    drawText(bx + 2, by + 3, textutils.formatTime(t, false), colors.white)
    
    -- Simulacao de CPU/Memoria para visual militar
    local simCpu = math.random(12, 35) + (lockdownMode and 50 or 0)
    local simRam = math.random(40, 45) + (lockdownMode and 20 or 0)
    
    drawText(bx + 2, by + 6, "Processamento (CPU):", colors.gray)
    drawProgressBar(bx + 2, by + 7, bw - 6, simCpu, 100, colors.red)
    
    drawText(bx + 2, by + 9, "Memoria (RAM):", colors.gray)
    drawProgressBar(bx + 2, by + 10, bw - 6, simRam, 100, colors.orange)
    
    drawText(bx + 2, by + 13, "Tempo de Operacao:", colors.lightGray)
    drawText(bx + 2, by + 14, uptime .. " ciclos", colors.white)
    
    local lx = bx + bw + 1
    drawBox(lx, by, w - lx, h - 4, "REGISTOS OFICIAIS DE BORDO", colors.gray, lockdownMode)
    for i, msg in ipairs(logs) do
        if i <= maxLogs then
            local col = (i == 1) and colors.white or colors.gray
            drawText(lx + 2, by + 1 + i, ((i==1) and "> " or "  ") .. msg, col)
        end
    end
end

-- ABA 5: COMMS
local function drawTabComms()
    drawBox(2, 4, w - 2, h - 4, "TERMINAL DE INTERCETACAO DE RADIO", colors.gray, lockdownMode)
    for i, msg in ipairs(chatHistory) do
        if i <= maxLogs then
            local col = (i == 1) and colors.white or colors.gray
            drawText(4, 5 + i, msg, col)
        end
    end
    if chatBox then
        drawButton(4, h - 2, " EMITIR ALERTA DE ESQUADRAO (BROADCAST) ", colors.white, colors.red)
    else
        drawText(4, h - 2, "Modulo transmissor (Chat Box) nao instalado.", colors.red)
    end
end

-- ABA 6: PERIMETRO (BASE)
local function drawTabBase()
    drawBox(2, 4, w - 2, h - 4, "CONTROLE DE DEFESA DE PERIMETRO", colors.red, lockdownMode)
    
    drawText(4, 6, "Gerenciamento de circuitos fisicos da base.", colors.gray)
    
    local function renderSwitch(label, side, y)
        local state = rsStates[side]
        drawText(4, y, label .. ":", colors.white)
        drawButton(26, y, state and " ENERGIZADO " or " CORTADO    ", state and colors.red or colors.gray, colors.black)
    end
    
    renderSwitch("Defesa Anti-Aerea (Cima)", "top", 10)
    renderSwitch("Portao Subterraneo (Baixo)", "bottom", 12)
    renderSwitch("Alarmes Externos (Esquerda)", "left", 14)
    renderSwitch("Iluminacao Tatica (Direita)", "right", 16)
end

-- ==========================================================
-- GESTOR DO ECRÃ E MAIN LOOP
-- ==========================================================
local function updateScreen()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    updateThreatLevel()
    drawTopBar()
    
    if activeTab == 1 then drawTabRadar()
    elseif activeTab == 2 then drawTabScanner()
    elseif activeTab == 3 then drawTabTeam()
    elseif activeTab == 4 then drawTabSystem()
    elseif activeTab == 5 then drawTabComms()
    elseif activeTab == 6 then drawTabBase()
    end
end

term.clear()
print("J.A.R.V.I.S. T.A.C. V8 Iniciado.")
checkIntruders()
updateScreen()

while true do
    local tid = os.startTimer(1.0)
    local ev, p1, p2, p3, p4 = os.pullEvent()
    
    if ev == "timer" and p1 == tid then
        uptime = uptime + 1
        if scanCooldown > 0 then scanCooldown = scanCooldown - 1 end
        if uptime % 2 == 0 then checkIntruders() end
        updateScreen()
        
    elseif ev == "chat" then
        local sender, msg = p1, p2
        if type(p2) == "string" and p2:find("%-") then sender, msg = p2, p3 end
        if type(msg) == "string" then
            addChat("[" .. tostring(sender) .. "]: " .. msg)
            if activeTab == 5 then updateScreen() end
        end
        
    elseif ev == "monitor_touch" then
        local tx, ty = p2, p3
        
        -- CLIQUE NA BARRA DE TABS
        if ty == 2 then
            for i, zone in ipairs(tabZones) do
                if tx >= zone.startX and tx <= zone.endX then
                    activeTab = i; updateScreen(); break
                end
            end
        else
            -- AÇÕES POR ABA
            if activeTab == 1 then -- RADAR ZOOM
                if ty == h - 2 then
                    if tx >= 4 and tx <= 8 and rIdx > 1 then rIdx = rIdx - 1; updateScreen()
                    elseif tx >= 24 and tx <= 28 and rIdx < #R_RANGES then rIdx = rIdx + 1; updateScreen() end
                end
            elseif activeTab == 2 then -- SCANNER
                local cW = math.floor((w - 4) / 2)
                if ty == 11 and tx < cW and scanCooldown == 0 then runScan(); updateScreen() end
            elseif activeTab == 3 then -- LOCKDOWN
                local cW = math.floor((w - 4) / 2)
                if ty == h - 2 and tx > cW + 3 then
                    lockdownMode = not lockdownMode
                    aiLog(lockdownMode and "[COMANDO]: DEFESA ATIVADA." or "[COMANDO]: Standby.")
                    updateScreen()
                end
            elseif activeTab == 5 then -- COMMS
                if ty == h - 2 and tx >= 4 and tx <= 45 and chatBox then
                    chatBox.sendMessage("&c[J.A.R.V.I.S. T.A.C.]: &fEsquadrao, reportar status. Acao imediata requerida.")
                    addChat("[SYS]: Transmissao de alerta enviada.")
                    updateScreen()
                end
            elseif activeTab == 6 then -- REDSTONE BASE
                if tx >= 26 and tx <= 38 then
                    if ty == 10 then toggleRedstone("top"); updateScreen()
                    elseif ty == 12 then toggleRedstone("bottom"); updateScreen()
                    elseif ty == 14 then toggleRedstone("left"); updateScreen()
                    elseif ty == 16 then toggleRedstone("right"); updateScreen()
                    end
                end
            end
        end
    end
end
