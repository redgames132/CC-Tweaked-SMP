-- ==========================================================
-- J.A.R.V.I.S. MAINFRAME V6 - WIDESCREEN (4x3)
-- 3 Colunas, Radar Tatico com Zoom Ajustavel, Equipa
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S. OS"
local OWNER = "redgames132"
local ALLY = "cadipadi"

local TEAM = {
    [OWNER] = true,
    [ALLY] = true
}

-- Opcoes de Distancia do Radar
local R_RANGES = {16, 32, 64, 128, 256}
local rIdx = 2 -- Comeca nos 32m

-- Conectar Perifericos
local mon = peripheral.find("monitor")
if not mon then error("ERRO: Nenhum monitor ligado!", 0) end
local detector = peripheral.find("playerDetector") or peripheral.find("player_detector")

-- Configurar Ecra (Alta Resolucao)
mon.setTextScale(0.5)
local w, h = mon.getSize()

-- Divisao em 3 Colunas Dinamicas
local colW = math.floor((w - 5) / 3)
local c1X = 2
local c2X = c1X + colW + 1
local c3X = c2X + colW + 1

-- Variaveis de Estado
local logs = { "Layout Panoramico 4x3 carregado.", "Controles de Zoom do radar desbloqueados." }
local maxLogs = h - 17
local uptime = 0
local lockdownMode = false
local knownIntruders = {}

-- ==========================================================
-- FUNCOES DE DESENHO BASE
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
-- RENDERIZACAO DO RADAR (COM ZOOM DINAMICO)
-- ==========================================================
local function drawRadar(bx, by, bw, bh)
    drawBox(bx, by, bw, bh, " RADAR TATICO ", colors.blue)
    local cx = bx + math.floor(bw/2)
    local cy = by + math.floor(bh/2)
    local currentRange = R_RANGES[rIdx]

    -- Desenhar Cruz Central
    for i = bx + 1, bx + bw - 2 do drawText(i, cy, "-", colors.cyan) end
    for i = by + 1, by + bh - 2 do drawText(cx, i, "|", colors.cyan) end
    drawText(cx, cy, "+", colors.white)

    -- Aneis Concentricos (Ajuste de Aspect Ratio do texto)
    local aspect = 2.0 -- Texto é 2x mais alto que largo
    for iy = by + 1, by + bh - 2 do
        for ix = bx + 1, bx + bw - 2 do
            local rx = (ix - cx) / (bw/2 - 1)
            local ry = (iy - cy) / (bh/2 - 1) * aspect
            local dist = math.sqrt(rx*rx + ry*ry)
            
            -- 3 Aneis em 33%, 66% e 100% da caixa
            if math.abs(dist - 0.33) < 0.1 or math.abs(dist - 0.66) < 0.1 or math.abs(dist - 0.99) < 0.1 then
                if ix ~= cx and iy ~= cy then
                    drawText(ix, iy, ".", colors.lightBlue)
                end
            end
        end
    end

    -- Plotar Jogadores
    local refPos = getPlayerStats(OWNER) or getPlayerStats(ALLY)
    if refPos and detector then
        local ok, players = pcall(detector.getOnlinePlayers)
        if ok and type(players) == "table" then
            for _, p in ipairs(players) do
                local st = getPlayerStats(p)
                if st then
                    -- Calcular posicao relativa ao limite (Range)
                    local relX = st.x - refPos.x
                    local relZ = st.z - refPos.z
                    
                    -- Mapear para o ecra
                    local px = cx + math.floor((relX / currentRange) * (bw/2 - 2))
                    local py = cy + math.floor((relZ / currentRange) * (bh/2 - 2))

                    -- Se estiver dentro do radar, desenha
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
end

-- ==========================================================
-- RENDERIZACAO PRINCIPAL
-- ==========================================================
local function updateDashboard()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    local themeColor = lockdownMode and colors.red or colors.cyan
    local headerTitle = lockdownMode and " === [ ALERTA VERMELHO - LOCKDOWN ] === " or string.format(" === [ %s ] === ", AI_NAME)
    drawText(math.floor((w - #headerTitle)/2), 2, headerTitle, themeColor)
    
    -- ==========================================
    -- COLUNA 1: RADAR E CONTROLES
    -- ==========================================
    local radarH = h - 9
    drawRadar(c1X, 4, colW, radarH)
    
    -- Controles de Zoom (Debaixo do Radar)
    drawBox(c1X, 4 + radarH, colW, 5, " CONTROLE DE ZOOM ", colors.gray)
    local rangeStr = string.format(" ALCANCE: %03dm ", R_RANGES[rIdx])
    local btnX = c1X + math.floor((colW - #rangeStr - 8)/2)
    local btnY = 4 + radarH + 2
    drawText(btnX, btnY, "[<<]", colors.yellow)
    drawText(btnX + 4, btnY, rangeStr, colors.white)
    drawText(btnX + 4 + #rangeStr, btnY, "[>>]", colors.yellow)

    -- ==========================================
    -- COLUNA 2: EQUIPA E DEFESA
    -- ==========================================
    local teamH = 16
    drawBox(c2X, 4, colW, teamH, " COMANDO DE EQUIPE ", colors.green)
    
    -- Jogador 1
    local p1 = getPlayerStats(OWNER)
    drawText(c2X + 2, 6, "CMTE: " .. OWNER, colors.white)
    if p1 then
        local hp1, hp1Max = math.floor(p1.health), math.floor(p1.maxHealth or 20)
        local c1 = hp1 <= 6 and colors.red or (hp1 <= 12 and colors.yellow or colors.lime)
        drawText(c2X + colW - 12, 6, "[ ONLINE ]", colors.lime)
        drawProgressBar(c2X + 2, 8, colW - 6, hp1, hp1Max, c1)
    else
        drawText(c2X + colW - 13, 6, "[ OFFLINE ]", colors.gray)
        drawText(c2X + 2, 8, "Sinal ausente.", colors.gray)
    end

    -- Jogador 2
    local p2 = getPlayerStats(ALLY)
    drawText(c2X + 2, 11, "ALIADO: " .. ALLY, colors.white)
    if p2 then
        local hp2, hp2Max = math.floor(p2.health), math.floor(p2.maxHealth or 20)
        local c2 = hp2 <= 6 and colors.red or (hp2 <= 12 and colors.yellow or colors.lime)
        drawText(c2X + colW - 12, 11, "[ ONLINE ]", colors.lime)
        drawProgressBar(c2X + 2, 13, colW - 6, hp2, hp2Max, c2)
    else
        drawText(c2X + colW - 13, 11, "[ OFFLINE ]", colors.gray)
        drawText(c2X + 2, 13, "Sinal ausente.", colors.gray)
    end

    -- Monitor de Intrusos
    local defY = 4 + teamH
    local defH = h - defY - 4
    local secColor = (lockdownMode or #knownIntruders > 0) and colors.red or colors.orange
    drawBox(c2X, defY, colW, defH, " MONITOR DE AMEACAS ", secColor)
    
    if #knownIntruders == 0 then
        drawText(c2X + 2, defY + 3, "Status da Base:", colors.gray)
        drawText(c2X + 2, defY + 4, "SEGURO - Sem ameacas.", colors.lime)
    else
        drawText(c2X + 2, defY + 2, "INTRUSAO DETECTADA:", colors.red)
        for i = 1, 5 do
            if knownIntruders[i] then drawText(c2X + 2, defY + 2 + i, "! " .. knownIntruders[i], colors.white) end
        end
    end
    
    -- Botao Lockdown (Base da Coluna 2)
    local lkTxt = lockdownMode and " [ DESATIVAR DEFESA ] " or " [ ATIVAR DEFESA ] "
    local lkCol = lockdownMode and colors.red or colors.orange
    drawText(c2X + math.floor((colW - #lkTxt)/2), h - 2, lkTxt, colors.white, lkCol)

    -- ==========================================
    -- COLUNA 3: AMBIENTE E LOGS
    -- ==========================================
    local envH = 10
    drawBox(c3X, 4, colW, envH, " AMBIENTE LOCAL ", colors.cyan)
    local t = os.time()
    local isDay = (t >= 6 and t < 18.5)
    
    drawText(c3X + 2, 6, "Relogio do Mundo:", colors.gray)
    drawText(c3X + 2, 7, textutils.formatTime(t, false), colors.white)
    drawText(c3X + 2, 9, "Nivel de Perigo Externo:", colors.gray)
    drawText(c3X + 2, 10, isDay and "BAIXO (Dia)" or "ALTO (Monstros)", isDay and colors.yellow or colors.red)
    drawProgressBar(c3X + 2, 11, colW - 6, t, 24, isDay and colors.yellow or colors.purple)

    local logY = 4 + envH
    drawBox(c3X, logY, colW, h - logY, " TERMINAL DE EVENTOS ", colors.gray)
    for i, msg in ipairs(logs) do
        if i <= maxLogs then
            local col = (i == 1) and colors.white or colors.gray
            drawText(c3X + 2, logY + 1 + i, ((i==1) and ">> " or "   ") .. msg, col)
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
                for _, old in ipairs(knownIntruders) do if old == p then isNew = false break end end
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
print("Mainframe V6 (4x3) Iniciado.")

checkIntruders()
updateDashboard()

while true do
    local tid = os.startTimer(1.0)
    local ev, p1, p2, p3 = os.pullEvent()
    
    if ev == "timer" and p1 == tid then
        uptime = uptime + 1
        if uptime % 2 == 0 then checkIntruders() end
        updateDashboard()
        
    elseif ev == "monitor_touch" then
        local tx, ty = p2, p3
        
        -- Toque na Coluna 1 (Botões de Zoom)
        if tx >= c1X and tx < c2X then
            local radarH = h - 9
            local btnY = 4 + radarH + 2
            if ty == btnY or ty == btnY + 1 or ty == btnY - 1 then
                if tx < c1X + (colW/2) then
                    if rIdx > 1 then rIdx = rIdx - 1; aiLog("Zoom: " .. R_RANGES[rIdx] .. "m") end
                else
                    if rIdx < #R_RANGES then rIdx = rIdx + 1; aiLog("Zoom: " .. R_RANGES[rIdx] .. "m") end
                end
                updateDashboard()
            end
            
        -- Toque na Coluna 2 (Botão de Defesa)
        elseif tx >= c2X and tx < c3X then
            if ty >= h - 3 then
                lockdownMode = not lockdownMode
                aiLog(lockdownMode and "PROTOCOLO DE DEFESA ATIVADO." or "Defesas desativadas.")
                updateDashboard()
            end
        end
    end
end
