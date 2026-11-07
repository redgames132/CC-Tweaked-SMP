-- ==========================================================
-- J.A.R.V.I.S. MAINFRAME V5 - RADAR TATICO VISUAL
-- Removido texto de posicoes, adicionado Radar Azul e Equipa.
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
local logs = { "Radar visual online.", "Bem-vindos, " .. OWNER .. " e " .. ALLY .. "." }
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
-- RADAR TATICO (DESENHO VISUAL)
-- ==========================================================
local function drawRadar(bx, by, bw, bh)
    drawBox(bx, by, bw, bh, " RADAR TATICO ", colors.blue)
    local cx = bx + math.floor(bw/2)
    local cy = by + math.floor(bh/2)

    -- Eixos (Cruz Central)
    for i = bx + 1, bx + bw - 2 do drawText(i, cy, "-", colors.cyan) end
    for i = by + 1, by + bh - 2 do drawText(cx, i, "|", colors.cyan) end
    drawText(cx, cy, "+", colors.white)

    -- Circulos Concentricos (Simulacao)
    for iy = by + 1, by + bh - 2 do
        for ix = bx + 1, bx + bw - 2 do
            local dx = ix - cx
            local dy = (iy - cy) * 2 -- Multiplica por 2 para corrigir a altura dos caracteres
            local dist = math.sqrt(dx*dx + dy*dy)
            
            -- Desenha 3 aneis azuis como na imagem
            if math.abs(dist - 5) < 0.8 or math.abs(dist - 10) < 0.8 or math.abs(dist - 15) < 0.8 then
                if ix ~= cx and iy ~= cy then
                    drawText(ix, iy, ".", colors.lightBlue)
                end
            end
        end
    end

    -- Plotar Jogadores no Radar
    local refPos = getPlayerStats(OWNER) or getPlayerStats(ALLY)
    if refPos and detector then
        local ok, players = pcall(detector.getOnlinePlayers)
        if ok and type(players) == "table" then
            for _, p in ipairs(players) do
                local st = getPlayerStats(p)
                if st then
                    -- Escala: 1 caractere = 6 blocos de distancia
                    local dx = math.floor((st.x - refPos.x) / 6)
                    local dz = math.floor((st.z - refPos.z) / 6)
                    local mx = cx + dx
                    local my = cy + math.floor(dz / 2)

                    -- Se o ponto estiver dentro da caixa do radar
                    if mx > bx and mx < bx + bw - 1 and my > by and my < by + bh - 1 then
                        local char = "!"
                        local col = colors.red
                        if p == OWNER then char = "@"; col = colors.lime
                        elseif p == ALLY then char = "+"; col = colors.lime end
                        
                        -- Fundo preto para o icone nao sobrepor a linha feio
                        drawText(mx, my, char, col, colors.black)
                    end
                end
            end
        end
    end
end

-- ==========================================================
-- RENDERIZACAO DO DASHBOARD
-- ==========================================================
local function updateDashboard()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- MODO LOCKDOWN
    local themeColor = lockdownMode and colors.red or colors.cyan
    local headerTitle = lockdownMode and " === [ ALERTA VERMELHO - LOCKDOWN ] === " or string.format(" === [ %s ] === ", AI_NAME)
    drawText(math.floor((w - #headerTitle)/2), 2, headerTitle, themeColor)
    
    -- QUADRANTE 1: RADAR VISUAL (Top Esquerda)
    drawRadar(2, 4, colW, 11)

    -- QUADRANTE 2: STATUS DA EQUIPA (Top Direita)
    local q2X = 2 + colW + 1
    drawBox(q2X, 4, colW, 11, " SINAIS VITAIS DA EQUIPE ", colors.green)
    
    -- Jogador 1 (Dono)
    local p1 = getPlayerStats(OWNER)
    drawText(q2X + 2, 6, OWNER, colors.white)
    if p1 then
        local hp1 = math.floor(p1.health)
        local hp1Max = math.floor(p1.maxHealth or 20)
        local c1 = hp1 <= 6 and colors.red or (hp1 <= 12 and colors.yellow or colors.lime)
        drawText(q2X + colW - 12, 6, "[ ONLINE ]", colors.lime)
        drawProgressBar(q2X + 2, 7, colW - 6, hp1, hp1Max, c1)
    else
        drawText(q2X + colW - 13, 6, "[ OFFLINE ]", colors.gray)
        drawText(q2X + 2, 7, "Sem sinal.", colors.gray)
    end

    -- Jogador 2 (Aliado)
    local p2 = getPlayerStats(ALLY)
    drawText(q2X + 2, 10, ALLY, colors.white)
    if p2 then
        local hp2 = math.floor(p2.health)
        local hp2Max = math.floor(p2.maxHealth or 20)
        local c2 = hp2 <= 6 and colors.red or (hp2 <= 12 and colors.yellow or colors.lime)
        drawText(q2X + colW - 12, 10, "[ ONLINE ]", colors.lime)
        drawProgressBar(q2X + 2, 11, colW - 6, hp2, hp2Max, c2)
    else
        drawText(q2X + colW - 13, 10, "[ OFFLINE ]", colors.gray)
        drawText(q2X + 2, 11, "Sem sinal.", colors.gray)
    end

    -- QUADRANTE 3: SEGURANCA E INTRUSOS
    local secColor = (lockdownMode or #knownIntruders > 0) and colors.red or colors.orange
    drawBox(2, 16, colW, 10, " MONITOR DE INTRUSOS ", secColor)
    
    if #knownIntruders == 0 then
        drawText(4, 18, "Status da Base:", colors.gray)
        drawText(4, 19, "SEGURO - Sem ameacas.", colors.lime)
    else
        drawText(4, 18, "AVISO DE INTRUSAO:", colors.red)
        for i = 1, 3 do
            if knownIntruders[i] then
                drawText(4, 18 + i, "! " .. knownIntruders[i], colors.white)
            end
        end
    end
    
    -- Botao de Alerta (Touch)
    local btnTxt = lockdownMode and " [ DESATIVAR DEFESA ] " or " [ ATIVAR DEFESA ] "
    local btnCol = lockdownMode and colors.red or colors.orange
    local btnX = 2 + math.floor((colW - #btnTxt)/2)
    drawText(btnX, 23, btnTxt, colors.white, btnCol)

    -- QUADRANTE 4: CONDICOES DO MUNDO
    drawBox(q2X, 16, colW, 10, " AMBIENTE ", colors.cyan)
    local t = os.time()
    local tStr = textutils.formatTime(t, false)
    local isDay = (t >= 6 and t < 18.5)
    
    drawText(q2X + 2, 18, "Hora Local do Servidor:", colors.gray)
    drawText(q2X + 2, 19, tStr, colors.white)
    
    drawText(q2X + 2, 21, "Nivel de Perigo Externo:", colors.gray)
    if isDay then
        drawText(q2X + 2, 22, "BAIXO (Luz Solar)", colors.yellow)
    else
        drawText(q2X + 2, 22, "ALTO (Monstros)", colors.red)
    end
    drawProgressBar(q2X + 2, 23, colW - 6, t, 24, isDay and colors.yellow or colors.purple)

    -- PAINEL INFERIOR: LOGS
    local logY = 27
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
print("Mainframe V5 com Radar Iniciado.")
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
        -- Detetar toque no Botao LOCKDOWN (Y=23 na nova interface)
        if p3 == 23 and p2 < colW then
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
