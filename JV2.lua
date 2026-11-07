-- ==========================================================
-- J.A.R.V.I.S. MAINFRAME - Monitor Dashboard (MC 1.21.1)
-- ==========================================================

local NOME_DO_DONO = "TeuNickAqui" -- <-- MUDA PARA O TEU NICK!
local AI_NAME = "J.A.R.V.I.S."

-- Conectar Periféricos
local mon = peripheral.find("monitor")
if not mon then error("ERRO: Nenhum monitor ligado ao computador!", 0) end

local scanner  = peripheral.find("geoScanner") or peripheral.find("geo_scanner")
local detector = peripheral.find("playerDetector") or peripheral.find("player_detector")
local chatBox  = peripheral.find("chatBox") or peripheral.find("chat_box")

-- Configurar Monitor
mon.setTextScale(0.5) -- Alta resolução para caber mais dados
local w, h = mon.getSize()

-- Sistema de Logs (Mensagens da IA)
local logs = { "Sistemas operacionais e online." }
local maxLogs = h - 14 -- Calcula o espaço restante no ecrã para o log

local function aiSay(msg)
    table.insert(logs, 1, msg)
    if #logs > maxLogs then table.remove(logs, #logs) end
    
    if chatBox then
        pcall(function() chatBox.sendMessage("&b["..AI_NAME.."] &f"..msg) end)
    end
end

-- Função auxiliar para escrever no monitor
local function drawText(x, y, txt, color, bg)
    mon.setCursorPos(x, y)
    if color then mon.setTextColor(color) end
    if bg then mon.setBackgroundColor(bg) end
    mon.write(txt)
end

-- 1. Detetar o Dono
local function getOwnerStats()
    if not detector then return nil end
    local ok, pos = pcall(function() return detector.getPlayerPos(NOME_DO_DONO) end)
    if ok and type(pos) == "table" and pos.x then
        return pos
    end
    return nil
end

-- 2. Scanner de Minérios
local RARE = {"ancient_debris","uranium","osmium","diamond","emerald","fluorite","zinc"}
local lastScanResult = "A aguardar ordem de scan..."

local function performScan()
    if not scanner then 
        lastScanResult = "ERRO: Geo Scanner ausente." 
        return 
    end
    local fn = scanner.scanBlocks or scanner.scan
    if not fn then return end
    
    local ok, blocks = pcall(function() return fn(16) end) -- Scan máximo de 16
    if not ok or type(blocks) ~= "table" then 
        lastScanResult = "Scanner a arrefecer..." 
        return 
    end
    
    local best, minDist, total = nil, 999, 0
    for _, b in ipairs(blocks) do
        local n = (b.name or ""):lower()
        for _, r in ipairs(RARE) do
            if n:find(r) then
                total = total + 1
                local dist = math.abs(b.x or 0) + math.abs(b.y or 0) + math.abs(b.z or 0)
                if dist < minDist then
                    minDist = dist
                    best = { n = r:upper(), x = b.x, y = b.y, z = b.z }
                end
                break
            end
        end
    end
    
    if best then
        local ud = best.y > 0 and "Acima" or (best.y < 0 and "Abaixo" or "Nível")
        lastScanResult = string.format("ALVO: %s (%s) [+%d outros]", best.n, ud, total)
        aiSay("Minério raro detectado nas redondezas da base.")
    else
        lastScanResult = "Nenhum minério raro num raio de 16m."
    end
end

-- 3. Desenhar a Interface Gráfica
local function updateDashboard()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- Cabeçalho
    local t = textutils.formatTime(os.time(), false)
    local header = string.format(" [ %s MAINFRAME ] - Hora Local: %s ", AI_NAME, t)
    local hPad = math.floor((w - string.len(header)) / 2)
    drawText(1, 1, string.rep(" ", w), colors.white, colors.gray)
    drawText(hPad, 1, header, colors.cyan, colors.gray)
    mon.setBackgroundColor(colors.black)
    
    -- Secção 1: Status do Dono
    drawText(2, 3, "--- STATUS DO JOGADOR (" .. NOME_DO_DONO .. ") ---", colors.yellow)
    local stats = getOwnerStats()
    if stats then
        local hpColor = stats.health > 10 and colors.lime or colors.red
        drawText(4, 5, string.format("Localizacao: X:%d Y:%d Z:%d", stats.x, stats.y, stats.z), colors.white)
        drawText(4, 6, string.format("Sinais Vitais: %d HP", math.floor(stats.health)), hpColor)
        drawText(4, 7, "Dimensao: " .. (stats.dimension or "Desconhecida"), colors.lightGray)
    else
        drawText(4, 5, "Jogador fora do alcance do radar da base.", colors.red)
    end
    
    -- Secção 2: Sensores da Base (Scanner)
    drawText(2, 9, "--- SENSORES GEOLOGICOS ---", colors.yellow)
    drawText(4, 11, lastScanResult, colors.white)
    
    -- Botões Touch no ecrã
    drawText(w - 12, 11, "[ ESCANEAR ]", colors.white, colors.blue)
    mon.setBackgroundColor(colors.black)
    
    -- Secção 3: Terminal de Logs da IA
    drawText(2, 13, "--- REGISTOS DA IA ---", colors.yellow)
    for i, msg in ipairs(logs) do
        if i <= maxLogs then
            local color = i == 1 and colors.white or colors.gray
            drawText(4, 13 + i, "> " .. msg, color)
        end
    end
end

-- ==========================================================
-- LOOP PRINCIPAL (Eventos e Atualização)
-- ==========================================================
term.clear()
print("J.A.R.V.I.S. Mainframe a correr no Monitor.")
print("Podes tocar no ecrã ou usar o chat para interagir.")

updateDashboard()
local lastWarnHp = false

while true do
    local tid = os.startTimer(1.0)
    local ev, p1, p2, p3 = os.pullEvent()
    
    if ev == "timer" and p1 == tid then
        -- Atualizar ecrã a cada 1 segundo
        updateDashboard()
        
        -- Alerta de vida automático
        local stats = getOwnerStats()
        if stats and stats.health <= 6 and not lastWarnHp then
            aiSay("ALERTA: Sinais vitais críticos detetados na base!")
            lastWarnHp = true
        elseif stats and stats.health > 10 then
            lastWarnHp = false
        end
        
    elseif ev == "monitor_touch" then
        -- p2 é X, p3 é Y do toque
        if p3 == 11 and p2 >= (w - 12) then
            aiSay("A iniciar varrimento geológico...")
            updateDashboard()
            sleep(0.5)
            performScan()
            updateDashboard()
        end
        
    elseif ev == "chat" then
        -- Comandos por chat (se tiver Chat Box)
        local msg = type(p2) == "string" and p2 or p3
        if type(msg) == "string" and msg:sub(1, 1) == "$" then
            local cmd = msg:sub(2):lower()
            if cmd == "scan" then
                aiSay("Scan solicitado remotamente.")
                performScan()
            elseif cmd == "status" then
                aiSay("Mainframe a operar a 100%.")
            else
                aiSay("Comando não reconhecido.")
            end
            updateDashboard()
        end
    end
end
