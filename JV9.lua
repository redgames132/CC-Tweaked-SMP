-- ==========================================================
-- J.A.R.V.I.S. OS V7 - ULTIMATE BROWSER EDITION (4x3)
-- 6 Abas, UI Remasterizada, Smart Home e Intercetacao de Chat
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S. OS"
local OWNER = "redgames132"
local ALLY = "cadipadi"

local TEAM = { [OWNER] = true, [ALLY] = true }

-- Perifericos
local mon = peripheral.find("monitor")
if not mon then error("ERRO: Nenhum monitor ligado!", 0) end
local detector = peripheral.find("playerDetector") or peripheral.find("player_detector")
local scanner  = peripheral.find("geoScanner") or peripheral.find("geo_scanner")
local chatBox  = peripheral.find("chatBox") or peripheral.find("chat_box")

-- Configuracao do Ecra
mon.setTextScale(0.5)
local w, h = mon.getSize()

-- Sistema de Abas (Tabs)
local TABS = {"RADAR", "SCANNER", "EQUIPA", "SISTEMA", "COMMS", "BASE"}
local activeTab = 1
local tabZones = {}

-- Estado Global
local logs = { "J.A.R.V.I.S. OS V7 Carregado.", "Modulos de defesa e base online." }
local chatHistory = { "[SISTEMA]: Intercetador de rádio ativo." }
local maxLogs = h - 10
local uptime = 0
local lockdownMode = false
local knownIntruders = {}

-- Estado do Scanner
local scanResults = {}
local scanStatus = "PRONTO PARA VARREDURA"
local scanCooldown = 0

-- Estado do Radar
local R_RANGES = {16, 32, 64, 128, 256}
local rIdx = 2

-- Estado da Base (Redstone)
local rsStates = { top = false, bottom = false, left = false, right = false }

-- ==========================================================
-- FUNCOES DE DESENHO BASE (UI MELHORADA)
-- ==========================================================
local function drawText(x, y, txt, fg, bg)
    mon.setCursorPos(x, y)
    if fg then mon.setTextColor(fg) end
    if bg then mon.setBackgroundColor(bg) else mon.setBackgroundColor(colors.black) end
    mon.write(txt)
end

local function drawBox(x, y, bw, bh, title, color, alertMode)
    local col = alertMode and colors.red or color
    local hLine = string.rep("-", bw - 2)
    
    -- Topo e Base
    drawText(x, y, "+" .. hLine .. "+", col)
    drawText(x, y + bh - 1, "+" .. hLine .. "+", col)
    
    -- Lados
    for i = 1, bh - 2 do
        drawText(x, y + i, "|", col)
        drawText(x + bw - 1, y + i, "|", col)
    end
    
    -- Titulo
    if title then
        local tStr = " " .. title .. " "
        drawText(x + 2, y, tStr, colors.white, alertMode and colors.red or colors.gray)
    end
end

local function drawButton(x, y, txt, fg, bg)
    drawText(x, y, "[ " .. txt .. " ]", fg, bg)
end

local function drawProgressBar(x, y, width, val, maxVal, color)
    local fill = math.floor((val / maxVal) * width)
    if fill > width then fill = width end
    if fill < 0 then fill = 0 end
    local empty = width - fill
    drawText(x, y, "[", colors.lightGray)
    if fill > 0 then drawText(x + 1, y, string.rep("=", fill), color) end
    if empty > 0 then drawText(x + 1 + fill, y, string.rep(".", empty), colors.gray) end
    drawText(x + width + 1, y, "]", colors.lightGray)
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
                if isNew then aiLog("ALERTA: Intruso -> " .. p) end
            end
        end
        knownIntruders = currentIntruders
    end
end

local function runScan()
    if scanCooldown > 0 then return end
    scanResults = {}
    scanStatus = "PROCESSANDO DADOS SISMICOS..."
    aiLog("Varredura geologica em andamento.")
    
    if not scanner then scanStatus = "ERRO: SCANNER AUSENTE"; return end
    
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
    scanStatus = #scanResults > 0 and ("ENCONTRADOS " .. #scanResults .. " RECURSOS") or "NENHUM RECURSO VALIOSO (16m)"
    scanCooldown = 5
end

local function toggleRedstone(side)
    rsStates[side] = not rsStates[side]
    rs.setOutput(side, rsStates[side])
    aiLog("Energia (" .. side .. "): " .. (rsStates[side] and "LIGADA" or "DESLIGADA"))
end

-- ==========================================================
-- DESENHO DAS ABAS E MENUS
-- ==========================================================
local function drawTopBar()
    local theme = lockdownMode and colors.red or colors.cyan
    drawText(1, 1, string.rep(" ", w), colors.white, colors.gray)
    drawText(1, 2, string.rep(" ", w), colors.white, colors.gray)
    drawText(2, 1, string.format(" %s // STATUS: %s ", AI_NAME, lockdownMode and "LOCKDOWN" or "SEGURO"), colors.white, theme)
    
    tabZones = {}
    local currentX = 2
    for i, tabName in ipairs(TABS) do
        local isSelected = (i == activeTab)
        local bg = isSelected and colors.blue or colors.lightGray
        local fg = isSelected and colors.white or colors.gray
        if lockdownMode and isSelected then bg = colors.red end
        
        local txt = " " .. tabName .. " "
        drawText(currentX, 2, txt, fg, bg)
        tabZones[i] = { startX = currentX, endX = currentX + #txt - 1 }
        currentX = currentX + #txt + 1
    end
end

-- ABA 1: RADAR TATICO
local function drawTabRadar()
    local bx, by = 2, 4
    local bw, bh = w - 2, h - 4
    drawBox(bx, by, bw, bh, "RADAR TATICO (360)", colors.cyan, lockdownMode)
    
    local cx, cy = bx + math.floor(bw/2), by + math.floor(bh/2)
    local range = R_RANGES[rIdx]

    for i = bx + 1, bx + bw - 2 do drawText(i, cy, "-", colors.lightBlue) end
    for i = by + 1, by + bh - 2 do drawText(cx, i, "|", colors.lightBlue) end
    drawText(cx, cy, "+", colors.white)

    for iy = by + 1, by + bh - 2 do
        for ix = bx + 1, bx + bw - 2 do
            local rx, ry = (ix - cx) / (bw/2 - 1), (iy - cy) / (bh/2 - 1) * 2.0
            local dist = math.sqrt(rx*rx + ry*ry)
            if math.abs(dist - 0.33) < 0.05 or math.abs(dist - 0.66) < 0.05 or math.abs(dist - 0.99) < 0.05 then
                if ix ~= cx and iy ~= cy then drawText(ix, iy, ".", colors.blue) end
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
                        local char, col = "!", colors.red
                        if p == OWNER then char = "@"; col = colors.lime
                        elseif p == ALLY then char = "+"; col = colors.lime end
                        drawText(px, py, char, col, colors.black)
                    end
                end
            end
        end
    end
    
    drawButton(4, h - 2, "-", colors.yellow, colors.gray)
    drawText(11, h - 2, string.format("ZOOM: %03dm", range), colors.white)
    drawButton(24, h - 2, "+", colors.yellow, colors.gray)
end

-- ABA 2: GEO SCANNER
local function drawTabScanner()
    local cW = math.floor((w - 4) / 2)
    drawBox(2, 4, cW, h - 4, "SISTEMA DE ESCANEAMENTO", colors.orange, lockdownMode)
    
    drawText(4, 6, "Status do Módulo:", colors.gray)
    drawText(4, 7, scanStatus, colors.white)
    
    local btnTxt = scanCooldown > 0 and ("AGUARDE " .. scanCooldown .. "s") or "INICIAR VARREDURA"
    local btnCol = scanCooldown > 0 and colors.gray or colors.blue
    drawButton(4 + math.floor((cW - #btnTxt - 4)/2), 11, btnTxt, colors.white, btnCol)
    
    drawBox(3 + cW, 4, cW, h - 4, "RESULTADOS", colors.yellow, lockdownMode)
    if #scanResults == 0 then
        drawText(5 + cW, 6, "Sem dados. Execute um scan.", colors.gray)
    else
        drawText(5 + cW, 5, " MINÉRIO      DISTÂNCIA   NÍVEL", colors.cyan)
        for i = 1, math.min(#scanResults, h - 8) do
            local res = scanResults[i]
            local ud = res.y > 0 and "^" or (res.y < 0 and "v" or "=")
            drawText(5 + cW, 6 + i, string.format(" %-12s %-11s %s", res.name:sub(1,10), res.d.."m", ud), colors.white)
        end
    end
end

-- ABA 3: EQUIPA
local function drawTabTeam()
    local cW = math.floor((w - 4) / 2)
    drawBox(2, 4, cW, h - 4, "SINAIS VITAIS", colors.green, lockdownMode)
    
    local function renderPlayer(name, yPos, title)
        local p = getPlayerStats(name)
        drawText(4, yPos, title .. name, colors.white)
        if p then
            drawText(cW - 10, yPos, "[ ONLINE ]", colors.lime)
            drawText(4, yPos+1, string.format("HP: %d/%d", p.health, p.maxHealth), colors.white)
            drawProgressBar(4, yPos+2, cW - 6, p.health, p.maxHealth, p.health <= 6 and colors.red or colors.lime)
        else
            drawText(cW - 11, yPos, "[ OFFLINE ]", colors.gray)
            drawText(4, yPos+1, "Sinal ausente.", colors.gray)
        end
    end
    
    renderPlayer(OWNER, 6, "CMTE: ")
    renderPlayer(ALLY, 12, "ALIADO: ")

    drawBox(3 + cW, 4, cW, h - 4, "DEFESA DA BASE", colors.red, lockdownMode)
    if #knownIntruders == 0 then
        drawText(5 + cW, 6, "Perímetro limpo.", colors.lime)
    else
        drawText(5 + cW, 6, "INTRUSOS:", colors.red)
        for i, inv in ipairs(knownIntruders) do drawText(5 + cW, 7 + i, "! " .. inv, colors.white) end
    end
    
    local lkTxt = lockdownMode and "DESATIVAR LOCKDOWN" or "ATIVAR LOCKDOWN"
    drawButton(3 + cW + math.floor((cW - #lkTxt - 4)/2), h - 2, lkTxt, colors.white, lockdownMode and colors.red or colors.orange)
end

-- ABA 4: SISTEMA
local function drawTabSystem()
    local bx, by = 2, 4
    local bw = math.floor(w / 3)
    
    drawBox(bx, by, bw, h - 4, "NÚCLEO", colors.lightBlue, lockdownMode)
    local t = os.time()
    local isDay = (t >= 6 and t < 18.5)
    drawText(bx + 2, by + 2, "Hora Local:", colors.gray)
    drawText(bx + 2, by + 3, textutils.formatTime(t, false), colors.white)
    drawText(bx + 2, by + 6, "Ameaça Externa:", colors.gray)
    drawText(bx + 2, by + 7, isDay and "BAIXA (Dia)" or "ALTA (Monstros)", isDay and colors.yellow or colors.red)
    drawText(bx + 2, by + 10, "Tempo Ativo: " .. uptime .. "s", colors.lightGray)
    
    local lx = bx + bw + 1
    drawBox(lx, by, w - lx, h - 4, "TERMINAL DE REGISTOS", colors.gray, lockdownMode)
    for i, msg in ipairs(logs) do
        if i <= maxLogs then
            local col = (i == 1) and colors.white or colors.gray
            drawText(lx + 2, by + 1 + i, ((i==1) and "> " or "  ") .. msg, col)
        end
    end
end

-- ABA 5: COMMS
local function drawTabComms()
    drawBox(2, 4, w - 2, h - 4, "INTERCETADOR DE COMUNICAÇÕES", colors.magenta, lockdownMode)
    for i, msg in ipairs(chatHistory) do
        if i <= maxLogs then
            local col = (i == 1) and colors.white or colors.gray
            drawText(4, 5 + i, msg, col)
        end
    end
    if chatBox then
        drawButton(4, h - 2, "ENVIAR ALERTA DE EQUIPA", colors.white, colors.magenta)
    else
        drawText(4, h - 2, "Chat Box não detetado.", colors.red)
    end
end

-- ABA 6: BASE (Redstone Smart Home)
local function drawTabBase()
    drawBox(2, 4, w - 2, h - 4, "CONTROLO DE ENERGIA (SMART HOME)", colors.yellow, lockdownMode)
    
    drawText(4, 6, "Liga fios de Redstone ou Cabos aos lados do computador", colors.gray)
    drawText(4, 7, "para controlar portas, luzes ou armadilhas da base.", colors.gray)
    
    local function renderSwitch(label, side, y)
        local state = rsStates[side]
        drawText(4, y, label .. ":", colors.white)
        drawButton(16, y, state and " LIGADO  " or "DESLIGADO", state and colors.lime or colors.gray, colors.black)
    end
    
    renderSwitch("Lado CIMA", "top", 10)
    renderSwitch("Lado BAIXO", "bottom", 12)
    renderSwitch("Esquerda", "left", 14)
    renderSwitch("Direita", "right", 16)
end

-- ==========================================================
-- GESTOR DO ECRÃ
-- ==========================================================
local function updateScreen()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    drawTopBar()
    
    if activeTab == 1 then drawTabRadar()
    elseif activeTab == 2 then drawTabScanner()
    elseif activeTab == 3 then drawTabTeam()
    elseif activeTab == 4 then drawTabSystem()
    elseif activeTab == 5 then drawTabComms()
    elseif activeTab == 6 then drawTabBase()
    end
end

-- ==========================================================
-- LOOP PRINCIPAL E TOQUES
-- ==========================================================
term.clear()
print("J.A.R.V.I.S. OS V7 (Ultimate) Online.")
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
                    aiLog(lockdownMode and "ALERTA VERMELHO ATIVADO!" or "Defesas desativadas.")
                    updateScreen()
                end
            elseif activeTab == 5 then -- COMMS
                if ty == h - 2 and tx >= 4 and tx <= 30 and chatBox then
                    chatBox.sendMessage("&c[ALERTA]: &fA Base J.A.R.V.I.S. requer atenção!")
                    addChat("[J.A.R.V.I.S.]: Alerta enviado.")
                    updateScreen()
                end
            elseif activeTab == 6 then -- REDSTONE BASE
                if tx >= 16 and tx <= 26 then
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
