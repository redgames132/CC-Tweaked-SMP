-- ==========================================================
-- J.A.R.V.I.S. MAINFRAME - ULTIMATE DASHBOARD
-- Sem acentos, sem chat, design visual avancado (MC 1.21.1)
-- ==========================================================

local NOME_DO_DONO = "redgames132" -- <-- MUDA PARA O TEU NICK!
local AI_NAME = "J.A.R.V.I.S. OS"

-- Perifericos
local mon = peripheral.find("monitor")
if not mon then error("ERRO: Nenhum monitor ligado!", 0) end

local scanner  = peripheral.find("geoScanner") or peripheral.find("geo_scanner")
local detector = peripheral.find("playerDetector") or peripheral.find("player_detector")

-- Configuracao do Ecra
mon.setTextScale(0.5)
local w, h = mon.getSize()
local cx = math.floor(w / 2)

-- Variaveis de Estado
local logs = { "Sistema reiniciado com sucesso.", "Aguardando comandos..." }
local maxLogs = 6
local uptime = 0
local scanResults = {}
local isScanning = false

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
    if fill > 0 then drawText(x + 1, y, string.rep("|", fill), color) end
    if empty > 0 then drawText(x + 1 + fill, y, string.rep(".", empty), colors.gray) end
    drawText(x + width + 1, y, "]", colors.lightGray)
end

local function aiLog(msg)
    table.insert(logs, 1, msg)
    if #logs > maxLogs then table.remove(logs, #logs) end
end

-- ==========================================================
-- LOGICA DE SENSORES
-- ==========================================================
local RARE = {"ancient_debris", "uranium", "osmium", "diamond", "emerald", "fluorite", "zinc"}

local function runScan()
    isScanning = true
    scanResults = {}
    aiLog("Iniciando varredura sismica profunda...")
    
    if not scanner then 
        aiLog("ERRO: Modulo Geo-Scanner offline.")
        isScanning = false
        return 
    end
    
    local fn = scanner.scanBlocks or scanner.scan
    if not fn then isScanning = false return end
    
    local ok, blocks = pcall(function() return fn(16) end)
    if not ok or type(blocks) ~= "table" then 
        aiLog("Aviso: Scanner em arrefecimento.")
        isScanning = false
        return 
    end
    
    for _, b in ipairs(blocks) do
        local n = (b.name or ""):lower()
        for _, r in ipairs(RARE) do
            if n:find(r) then
                local dist = math.abs(b.x or 0) + math.abs(b.y or 0) + math.abs(b.z or 0)
                table.insert(scanResults, { name = r:upper(), d = dist, y = b.y })
                break
            end
        end
    end
    
    -- Ordenar por proximidade
    table.sort(scanResults, function(a, b) return a.d < b.d end)
    
    if #scanResults > 0 then
        aiLog("Sucesso! Minerios anomalos detectados.")
    else
        aiLog("Nenhum recurso critico no perimetro.")
    end
    isScanning = false
end

-- ==========================================================
-- RENDERIZACAO PRINCIPAL
-- ==========================================================
local function updateDashboard()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- HEADER PRINCIPAL
    local headerTitle = string.format(" === [ %s ] === ", AI_NAME)
    drawText(math.floor((w - #headerTitle)/2), 2, headerTitle, colors.cyan)
    
    local timeStr = string.format("Hora Global: %s | Uptime: %ds", textutils.formatTime(os.time(), false), uptime)
    drawText(math.floor((w - #timeStr)/2), 3, timeStr, colors.lightGray)
    
    -- PAINEL 1: STATUS DO JOGADOR (Esquerda)
    local p1W = cx - 2
    drawBox(2, 6, p1W, 10, "MONITORAMENTO DE SINAIS VITAIS", colors.blue)
    
    local stats = nil
    if detector then
        local ok, pos = pcall(function() return detector.getPlayerPos(NOME_DO_DONO) end)
        if ok and type(pos) == "table" and pos.x then stats = pos end
    end
    
    if stats then
        local hp = math.floor(stats.health or 0)
        local hpMax = math.floor(stats.maxHealth or 20)
        local hpColor = colors.lime
        if hp <= 6 then hpColor = colors.red elseif hp <= 12 then hpColor = colors.yellow end
        
        drawText(4, 8, "Alvo: " .. NOME_DO_DONO, colors.white)
        drawText(4, 10, string.format("Posicao: X:%d Y:%d Z:%d", stats.x, stats.y, stats.z), colors.lightGray)
        drawText(4, 11, "Dimensao: " .. (stats.dimension or "Normal"), colors.lightGray)
        
        drawText(4, 13, string.format("Integridade (HP): %d/%d", hp, hpMax), hpColor)
        drawProgressBar(4, 14, p1W - 6, hp, hpMax, hpColor)
    else
        drawText(4, 10, "Sinal do jogador perdido.", colors.red)
        drawText(4, 11, "Alvo fora da area de cobertura.", colors.gray)
    end
    
    -- PAINEL 2: RADAR GEOLOGICO (Direita)
    local p2X = cx + 2
    local p2W = w - cx - 3
    drawBox(p2X, 6, p2W, 10, "SENSOR GEOLOGICO (16m)", colors.orange)
    
    if isScanning then
        drawText(p2X + 2, 9, "Processando dados...", colors.yellow)
    elseif #scanResults == 0 then
        drawText(p2X + 2, 9, "Nenhum resultado recente.", colors.gray)
    else
        drawText(p2X + 2, 8, "TOP 3 RECURSOS PROXIMOS:", colors.lightGray)
        for i = 1, 3 do
            if scanResults[i] then
                local res = scanResults[i]
                local ud = res.y > 0 and "Acima" or (res.y < 0 and "Abaixo" or "Nivel")
                local txt = string.format("%d. %s [%s]", i, res.name, ud)
                drawText(p2X + 2, 9 + i, txt, colors.white)
            end
        end
    end
    
    -- BOTAO TOUCH
    local btnTxt = " [ INICIAR SCAN ] "
    local btnX = p2X + math.floor((p2W - #btnTxt)/2)
    drawText(btnX, 14, btnTxt, colors.white, colors.blue)
    
    -- PAINEL 3: TERMINAL DE LOGS (Fundo)
    drawBox(2, 17, w - 3, 9, "REGISTOS DO SISTEMA", colors.gray)
    for i, msg in ipairs(logs) do
        local col = (i == 1) and colors.white or colors.gray
        local prefix = (i == 1) and ">> " or "   "
        drawText(4, 18 + i, prefix .. msg, col)
    end
end

-- ==========================================================
-- EXECUCAO PRINCIPAL
-- ==========================================================
term.clear()
print("Mainframe iniciado. Veja o monitor gigante.")
aiLog("Interface visual carregada.")
updateDashboard()

local warnedHp = false

while true do
    local tid = os.startTimer(1.0)
    local ev, p1, p2, p3 = os.pullEvent()
    
    if ev == "timer" and p1 == tid then
        uptime = uptime + 1
        
        -- Alertas automaticos silenciosos
        if detector then
            local ok, pos = pcall(function() return detector.getPlayerPos(NOME_DO_DONO) end)
            if ok and type(pos) == "table" and pos.health then
                if pos.health <= 6 and not warnedHp then
                    aiLog("ALERTA CRITICO: Integridade fisica em risco!")
                    warnedHp = true
                elseif pos.health > 10 then
                    warnedHp = false
                end
            end
        end
        
        updateDashboard()
        
    elseif ev == "monitor_touch" then
        -- Detetar toque no botão "INICIAR SCAN"
        local p2X = cx + 2
        local p2W = w - cx - 3
        local btnTxt = " [ INICIAR SCAN ] "
        local btnX = p2X + math.floor((p2W - #btnTxt)/2)
        
        -- Se o toque for na linha 14 e dentro da largura do botão
        if p3 == 14 and p2 >= btnX and p2 <= (btnX + #btnTxt) then
            if not isScanning then
                runScan()
                updateDashboard()
            end
        end
    end
end
