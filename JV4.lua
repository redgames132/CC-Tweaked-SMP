-- ==========================================================
-- J.A.R.V.I.S. MAINFRAME V3 - TALL DASHBOARD (2x3)
-- Nome configurado, Radar fixo, Novos paineis de seguranca
-- ==========================================================

local NOME_DO_DONO = "redgames132"
local AI_NAME = "J.A.R.V.I.S. OS"

-- Conectar Perifericos
local mon = peripheral.find("monitor")
if not mon then error("ERRO: Nenhum monitor ligado!", 0) end

local scanner  = peripheral.find("geoScanner") or peripheral.find("geo_scanner")
local detector = peripheral.find("playerDetector") or peripheral.find("player_detector")

-- Configurar Ecra
mon.setTextScale(0.5)
local w, h = mon.getSize()
local colW = math.floor((w - 3) / 2) -- Largura de cada coluna (Esquerda/Direita)

-- Estado do Sistema
local logs = { "Sistema J.A.R.V.I.S. operacional.", "Bem-vindo de volta, " .. NOME_DO_DONO .. "." }
local maxLogs = 5
local uptime = 0
local scanResults = {}
local scanStatus = "AGUARDANDO ORDEM"
local scanCooldown = 0
local knownPlayers = {}

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
    -- Desenhar as barras laterais
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

-- ==========================================================
-- LOGICA DOS SENSORES E RADAR
-- ==========================================================
local RARE = {"ancient_debris", "uranium", "osmium", "diamond", "emerald", "fluorite", "zinc", "gold"}

local function runScan()
    if scanCooldown > 0 then return end
    scanResults = {}
    scanStatus = "PROCESSANDO..."
    updateDashboard() -- Forcar atualizacao visual
    sleep(0.5)
    
    if not scanner then 
        scanStatus = "ERRO NO HARDWARE"
        aiLog("ERRO: Geo Scanner nao detectado.")
        return 
    end
    
    local fn = scanner.scanBlocks or scanner.scan
    if not fn then scanStatus = "FALHA NA API" return end
    
    local ok, blocks = pcall(function() return fn(16) end)
    if not ok or type(blocks) ~= "table" then 
        scanStatus = "EM ARREFECIMENTO"
        return 
    end
    
    for _, b in ipairs(blocks) do
        local rawName = (b.name or ""):lower()
        for _, r in ipairs(RARE) do
            if rawName:find(r) then
                local dist = math.floor(math.sqrt((b.x or 0)^2 + (b.y or 0)^2 + (b.z or 0)^2))
                -- Limpar o nome (remover minecraft: e _ore)
                local cleanName = rawName:match(":(.+)") or rawName
                cleanName = cleanName:gsub("_ore", ""):gsub("deepslate_", ""):upper()
                
                table.insert(scanResults, { name = cleanName, d = dist, y = math.floor(b.y or 0) })
                break
            end
        end
    end
    
    -- Ordenar minérios por distância
    table.sort(scanResults, function(a, b) return a.d < b.d end)
    
    if #scanResults > 0 then
        aiLog("Radar: " .. #scanResults .. " recursos detetados.")
        scanStatus = "CONCLUIDO"
    else
        aiLog("Radar: Nenhum recurso valioso no raio de 16m.")
        scanStatus = "NADA ENCONTRADO"
    end
    scanCooldown = 5 -- 5 segundos de cooldown
end

local function checkSecurity()
    if not detector then return end
    local ok, players = pcall(detector.getOnlinePlayers)
    if ok and type(players) == "table" then
        local current = {}
        for _, p in ipairs(players) do
            current[p] = true
            if not knownPlayers[p] and p ~= NOME_DO_DONO then
                aiLog("ALERTA DE SEGURANCA: " .. p .. " entrou na rede.")
            end
        end
        knownPlayers = current
    end
end

-- ==========================================================
-- RENDERIZACAO PRINCIPAL DO DASHBOARD
-- ==========================================================
function updateDashboard()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- HEADER
    local header = string.format(" === [ %s ] === ", AI_NAME)
    drawText(math.floor((w - #header)/2), 2, header, colors.cyan)
    
    -- QUADRANTE 1: STATUS DO JOGADOR (Topo Esquerda)
    drawBox(2, 4, colW, 9, " SINAIS VITAIS ", colors.blue)
    local stats = nil
    if detector then
        local ok, pos = pcall(function() return detector.getPlayerPos(NOME_DO_DONO) end)
        if ok and type(pos) == "table" and pos.health then stats = pos end
    end
    
    if stats then
        local hp = math.floor(stats.health)
        local hpMax = math.floor(stats.maxHealth or 20)
        local hpCol = colors.lime
        if hp <= 6 then hpCol = colors.red elseif hp <= 12 then hpCol = colors.yellow end
        
        drawText(4, 6, "ID: " .. NOME_DO_DONO, colors.white)
        drawText(4, 7, string.format("POS: %d, %d, %d", stats.x, stats.y, stats.z), colors.lightGray)
        drawText(4, 9, string.format("HP: %d / %d", hp, hpMax), hpCol)
        drawProgressBar(4, 10, colW - 6, hp, hpMax, hpCol)
    else
        drawText(4, 7, "Sinal perdido.", colors.red)
        drawText(4, 8, "Fora de alcance.", colors.gray)
    end
    
    -- QUADRANTE 2: SEGURANCA DA BASE (Topo Direita)
    local q2X = 2 + colW + 1
    drawBox(q2X, 4, colW, 9, " REDE / SEGURANCA ", colors.red)
    local others = 0
    for p, _ in pairs(knownPlayers) do
        if p ~= NOME_DO_DONO then
            others = others + 1
            if others <= 4 then
                drawText(q2X + 2, 5 + others, "[!] " .. p, colors.orange)
            end
        end
    end
    if others == 0 then
        drawText(q2X + 2, 7, "Sem intrusos.", colors.lime)
        drawText(q2X + 2, 8, "Rede segura.", colors.green)
    else
        drawText(q2X + 2, 11, "+" .. others .. " jogador(es).", colors.gray)
    end
    
    -- QUADRANTE 3: RADAR GEOLOGICO (Meio Esquerda)
    drawBox(2, 14, colW, 10, " SENSOR DE RECURSOS ", colors.orange)
    drawText(4, 15, "Status: " .. scanStatus, colors.gray)
    
    if #scanResults > 0 then
        for i = 1, 3 do
            if scanResults[i] then
                local r = scanResults[i]
                local ud = r.y > 0 and "^" or (r.y < 0 and "v" or "=")
                drawText(4, 16 + i, string.format("%d. %s [%dm%s]", i, r.name:sub(1,7), r.d, ud), colors.white)
            end
        end
    end
    
    -- Botao Touch do Scanner
    local btnTxt = scanCooldown > 0 and ("AGUARDE " .. scanCooldown .. "s") or " INICIAR SCAN "
    local btnCol = scanCooldown > 0 and colors.gray or colors.blue
    local btnX = 2 + math.floor((colW - #btnTxt)/2)
    drawText(btnX, 21, btnTxt, colors.white, btnCol)
    
    -- QUADRANTE 4: AMBIENTE E RELOGIO (Meio Direita)
    drawBox(q2X, 14, colW, 10, " AMBIENTE ", colors.cyan)
    local t = os.time()
    local tStr = textutils.formatTime(t, false)
    local isDay = (t >= 6 and t < 18.5)
    
    drawText(q2X + 2, 16, "Hora Local:", colors.gray)
    drawText(q2X + 2, 17, tStr, colors.white)
    
    drawText(q2X + 2, 19, "Estado do Mundo:", colors.gray)
    if isDay then
        drawText(q2X + 2, 20, "DIA (Seguro)", colors.lime)
    else
        drawText(q2X + 2, 20, "NOITE (Perigo)", colors.red)
    end
    drawProgressBar(q2X + 2, 21, colW - 6, t, 24, isDay and colors.yellow or colors.purple)
    
    -- PAINEL INFERIOR: LOGS (Fundo)
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
-- EXECUCAO PRINCIPAL
-- ==========================================================
term.clear()
print("J.A.R.V.I.S. V3 Iniciado no Monitor.")
print("Dono reconhecido: " .. NOME_DO_DONO)

checkSecurity()
updateDashboard()

local warnedHp = false

while true do
    local tid = os.startTimer(1.0)
    local ev, p1, p2, p3 = os.pullEvent()
    
    if ev == "timer" and p1 == tid then
        uptime = uptime + 1
        if scanCooldown > 0 then scanCooldown = scanCooldown - 1 end
        
        -- Verificar perigos a cada 2 segundos
        if uptime % 2 == 0 then
            checkSecurity()
            local stats = nil
            if detector then pcall(function() stats = detector.getPlayerPos(NOME_DO_DONO) end) end
            
            if type(stats) == "table" and stats.health then
                if stats.health <= 6 and not warnedHp then
                    aiLog("ALERTA: " .. NOME_DO_DONO .. ", sinais vitais em colapso!")
                    warnedHp = true
                elseif stats.health > 10 then
                    warnedHp = false
                end
            end
        end
        
        updateDashboard()
        
    elseif ev == "monitor_touch" then
        -- Detetar toque no Quadrante 3 (Botao Iniciar Scan)
        -- O botao esta na Y=21, no lado esquerdo do ecra.
        if p3 == 21 and p2 < colW then
            if scanCooldown == 0 then
                runScan()
                updateDashboard()
            end
        end
    end
end
