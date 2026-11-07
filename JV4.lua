-- ==========================================================
-- J.A.R.V.I.S. MAINFRAME V4 - COMANDO E CONTROLE (2x3)
-- Sem radar. Foco em Equipe (cadipadi), Seguranca e Ambiente.
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S. OS"
local OWNER = "redgames132"
local ALLY = "cadipadi"

local TEAM = {
    [OWNER] = true,
    [ALLY] = true
}

-- Conectar Perifericos
local mon = peripheral.find("monitor")
if not mon then error("ERRO: Nenhum monitor ligado!", 0) end
local detector = peripheral.find("playerDetector") or peripheral.find("player_detector")

-- Configurar Ecra
mon.setTextScale(0.5)
local w, h = mon.getSize()
local colW = math.floor((w - 3) / 2)

-- Estado do Sistema
local logs = { "Painel de Comando e Controle Online.", "Bem-vindos, " .. OWNER .. " e " .. ALLY .. "." }
local maxLogs = 5
local uptime = 0
local lockdownMode = false
local knownIntruders = {}

-- ==========================================================
-- FUNCOES DE DESENHO (UI)
-- ==========================================================
local function drawText(x, y, txt, fg, bg)
    mon.setCursorPos(x, y)
    if fg then mon.setTextColor(fg) end
    if bg then mon.setBackgroundColor(bg) else mon.setBackgroundColor(colors.black) end
    mon.write(txt)
end

local function drawBox(x, y, bw, bh, title, color)
    local line = string.rep("-", bw)
    drawText(x, y, line, color)
    drawText(x, y + bh - 1, line, color)
    for i = 1, bh - 2 do
        drawText(x, y + i, "|", color)
        drawText(x + bw - 1, y + i, "|", color)
    end
    if title then
        drawText(x + 2, y, " " .. title .. " ", colors.white, colors.black)
    end
end

local function drawProgressBar(x, y, width, val, maxVal, color)
    local fill = math.floor((val / maxVal) * width)
    if fill > width then fill = width end
    if fill < 0 then fill = 0 end
    
    local empty = width - fill
    drawText(x, y, "[", colors.lightGray)
    if fill > 0 then drawText(x + 1, y, string.rep("=", fill), color) end
    if empty > 0 then drawText(x + 1 + fill, y, string.rep("-", empty), colors.gray) end
    drawText(x + width + 1, y, "]", colors.lightGray)
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
-- RENDERIZACAO DO DASHBOARD
-- ==========================================================
local function updateDashboard()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- MODO LOCKDOWN (Muda o titulo e cor base)
    local themeColor = lockdownMode and colors.red or colors.cyan
    local headerTitle = lockdownMode and " === [ ALERTA VERMELHO - LOCKDOWN ] === " or string.format(" === [ %s ] === ", AI_NAME)
    drawText(math.floor((w - #headerTitle)/2), 2, headerTitle, themeColor)
    
    -- ==========================================
    -- QUADRANTE 1: COMANDANTE (redgames132)
    -- ==========================================
    drawBox(2, 4, colW, 9, " COMANDANTE ", colors.lightBlue)
    local p1 = getPlayerStats(OWNER)
    
    drawText(4, 6, "ID: " .. OWNER, colors.white)
    if p1 then
        local hp = math.floor(p1.health)
        local hpMax = math.floor(p1.maxHealth or 20)
        local hpCol = hp <= 6 and colors.red or (hp <= 12 and colors.yellow or colors.lime)
        
        drawText(4, 5, "[ ONLINE ]", colors.lime)
        drawText(4, 7, string.format("POS: %d, %d, %d", p1.x, p1.y, p1.z), colors.lightGray)
        drawText(4, 9, string.format("HP: %d / %d", hp, hpMax), hpCol)
        drawProgressBar(4, 10, colW - 6, hp, hpMax, hpCol)
    else
        drawText(4, 5, "[ OFFLINE ]", colors.gray)
        drawText(4, 8, "Sem sinal do traje.", colors.gray)
    end

    -- ==========================================
    -- QUADRANTE 2: ALIADO (cadipadi)
    -- ==========================================
    local q2X = 2 + colW + 1
    drawBox(q2X, 4, colW, 9, " ALIADO / EQUIPE ", colors.green)
    local p2 = getPlayerStats(ALLY)
    
    drawText(q2X + 2, 6, "ID: " .. ALLY, colors.white)
    if p2 then
        local hp = math.floor(p2.health)
        local hpMax = math.floor(p2.maxHealth or 20)
        local hpCol = hp <= 6 and colors.red or (hp <= 12 and colors.yellow or colors.lime)
        
        drawText(q2X + 2, 5, "[ ONLINE ]", colors.lime)
        drawText(q2X + 2, 7, string.format("POS: %d, %d, %d", p2.x, p2.y, p2.z), colors.lightGray)
        drawText(q2X + 2, 9, string.format("HP: %d / %d", hp, hpMax), hpCol)
        drawProgressBar(q2X + 2, 10, colW - 6, hp, hpMax, hpCol)
    else
        drawText(q2X + 2, 5, "[ OFFLINE ]", colors.gray)
        drawText(q2X + 2, 8, "Aguardando conexao...", colors.gray)
    end

    -- ==========================================
    -- QUADRANTE 3: SEGURANCA E INTRUSOS
    -- ==========================================
    local secColor = (lockdownMode or #knownIntruders > 0) and colors.red or colors.orange
    drawBox(2, 14, colW, 10, " MONITOR DE INTRUSOS ", secColor)
    
    if #knownIntruders == 0 then
        drawText(4, 16, "Status da Base:", colors.gray)
        drawText(4, 17, "SEGURO - Sem ameacas.", colors.lime)
    else
        drawText(4, 16, "AVISO DE INTRUSAO:", colors.red)
        for i = 1, 3 do
            if knownIntruders[i] then
                drawText(4, 16 + i, "! " .. knownIntruders[i], colors.white)
            end
        end
    end
    
    -- Botao de Alerta (Touch)
    local btnTxt = lockdownMode and " [ DESATIVAR DEFESA ] " or " [ ATIVAR DEFESA ] "
    local btnCol = lockdownMode and colors.red or colors.orange
    local btnX = 2 + math.floor((colW - #btnTxt)/2)
    drawText(btnX, 21, btnTxt, colors.white, btnCol)

    -- ==========================================
    -- QUADRANTE 4: CONDICOES DO MUNDO
    -- ==========================================
    drawBox(q2X, 14, colW, 10, " AMBIENTE ", colors.cyan)
    local t = os.time()
    local tStr = textutils.formatTime(t, false)
    local isDay = (t >= 6 and t < 18.5)
    
    drawText(q2X + 2, 16, "Hora Local do Servidor:", colors.gray)
    drawText(q2X + 2, 17, tStr, colors.white)
    
    drawText(q2X + 2, 19, "Nivel de Perigo Externo:", colors.gray)
    if isDay then
        drawText(q2X + 2, 20, "BAIXO (Luz Solar)", colors.yellow)
    else
        drawText(q2X + 2, 20, "ALTO (Monstros)", colors.red)
    end
    drawProgressBar(q2X + 2, 21, colW - 6, t, 24, isDay and colors.yellow or colors.purple)

    -- ==========================================
    -- PAINEL INFERIOR: LOGS
    -- ==========================================
    local logY = 25
    local logH = h - logY
    drawBox(2, logY, w - 2, logH, " TERMINAL DE REGISTOS ", colors.gray)
    
    for i, msg in ipairs(logs) do
        if i <= maxLogs then
            local col = (i == 1) and colors.white or colors.gray
            local prefix = (i == 1) and ">> " or "   "
            drawText(4, logY + i, prefix .. msg, col)
        end
    end
end

-- ==========================================================
-- LOGICA DE SEGURANCA EM BACKGROUND
-- ==========================================================
local function checkIntruders()
    if not detector then return end
    local ok, players = pcall(detector.getOnlinePlayers)
    if ok and type(players) == "table" then
        local currentIntruders = {}
        for _, p in ipairs(players) do
            if not TEAM[p] then
                table.insert(currentIntruders, p)
                
                -- Verificar se e um intruso novo para avisar no log
                local isNew = true
                for _, old in ipairs(knownIntruders) do
                    if old == p then isNew = false break end
                end
                if isNew then aiLog("ALERTA: Intruso detectado -> " .. p) end
            end
        end
        knownIntruders = currentIntruders
    end
end

-- ==========================================================
-- EXECUCAO PRINCIPAL
-- ==========================================================
term.clear()
print("Mainframe V4 Iniciado.")
print("Dono: " .. OWNER .. " | Aliado: " .. ALLY)

checkIntruders()
updateDashboard()

while true do
    local tid = os.startTimer(1.0)
    local ev, p1, p2, p3 = os.pullEvent()
    
    if ev == "timer" and p1 == tid then
        uptime = uptime + 1
        
        -- Atualizar sensores a cada 2 segundos
        if uptime % 2 == 0 then
            checkIntruders()
        end
        
        updateDashboard()
        
    elseif ev == "monitor_touch" then
        -- Detetar toque no Quadrante 3 (Botao LOCKDOWN)
        -- Y=21, na metade esquerda do ecra
        if p3 == 21 and p2 < colW then
            lockdownMode = not lockdownMode
            if lockdownMode then
                aiLog("COMANDO: PROTOCOLO DE DEFESA ATIVADO.")
            else
                aiLog("COMANDO: Defesas desativadas. Modo normal.")
            end
            updateDashboard()
        end
    end
end
