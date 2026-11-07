-- ==========================================================
-- J.A.R.V.I.S. OS - BROWSER EDITION (Monitor 4x3)
-- Sistema de Abas (Tabs), Interface Otimizada e Limpa.
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

-- Configuracao do Ecra
mon.setTextScale(0.5)
local w, h = mon.getSize()

-- Sistema de Abas (Tabs)
local TABS = {"RADAR TATICO", "GEO SCANNER", "EQUIPA & DEFESA", "SISTEMA"}
local activeTab = 1
local tabZones = {} -- Guarda a posicao X de cada aba para o touch

-- Estado Global
local logs = { "J.A.R.V.I.S. OS Iniciado.", "Bem-vindos, " .. OWNER .. " e " .. ALLY .. "." }
local maxLogs = h - 8
local uptime = 0
local lockdownMode = false
local knownIntruders = {}

-- Estado do Scanner
local scanResults = {}
local scanStatus = "PRONTO PARA VARREDURA"
local scanCooldown = 0

-- Estado do Radar
local R_RANGES = {16, 32, 64, 128, 256}
local rIdx = 2 -- Padrao 32m

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
-- LOGICA DOS SENSORES
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

local function runScan()
    if scanCooldown > 0 then return end
    scanResults = {}
    scanStatus = "PROCESSANDO DADOS SISMICOS..."
    aiLog("Iniciando escaneamento geologico...")
    
    if not scanner then 
        scanStatus = "ERRO: GEO SCANNER AUSENTE"
        return 
    end
    
    local fn = scanner.scanBlocks or scanner.scan
    local ok, blocks = pcall(function() return fn(16) end)
    
    if not ok or type(blocks) ~= "table" then 
        scanStatus = "FALHA / EM ARREFECIMENTO"
        return 
    end
    
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

-- ==========================================================
-- DESENHO DAS ABAS (TABS)
-- ==========================================================
local function drawTopBar()
    -- Fundo da barra
    drawText(1, 1, string.rep(" ", w), colors.white, colors.gray)
    drawText(1, 2, string.rep(" ", w), colors.white, colors.gray)
    
    local theme = lockdownMode and colors.red or colors.cyan
    drawText(2, 1, AI_NAME .. " // MODO " .. (lockdownMode and "DEFESA" or "OPERACIONAL"), theme, colors.gray)
    
    tabZones = {}
    local currentX = 2
    for i, tabName in ipairs(TABS) do
        local isSelected = (i == activeTab)
        local bg = isSelected and colors.blue or colors.lightGray
        local fg = isSelected and colors.white or colors.gray
        
        local txt = "  " .. tabName .. "  "
        drawText(currentX, 2, txt, fg, bg)
        
        tabZones[i] = { startX = currentX, endX = currentX + #txt - 1 }
        currentX = currentX + #txt + 1
    end
end

-- ==========================================================
-- CONTEUDO DAS ABAS
-- ==========================================================
local function drawTabRadar()
    local bx, by = 2, 4
    local bw, bh = w - 2, h - 4
    drawBox(bx, by, bw, bh, " RADAR DE MAPEAMENTO ", colors.blue)
    
    local cx = bx + math.floor(bw/2)
    local cy = by + math.floor(bh/2)
    local range = R_RANGES[rIdx]

    -- Eixos
    for i = bx + 1, bx + bw - 2 do drawText(i, cy, "-", colors.cyan) end
    for i = by + 1, by + bh - 2 do drawText(cx, i, "|", colors.cyan) end
    drawText(cx, cy, "+", colors.white)

    -- Aneis
    local aspect = 2.0
    for iy = by + 1, by + bh - 2 do
        for ix = bx + 1, bx + bw - 2 do
            local rx = (ix - cx) / (bw/2 - 1)
            local ry = (iy - cy) / (bh/2 - 1) * aspect
            local dist = math.sqrt(rx*rx + ry*ry)
            if math.abs(dist - 0.33) < 0.05 or math.abs(dist - 0.66) < 0.05 or math.abs(dist - 0.99) < 0.05 then
                if ix ~= cx and iy ~= cy then drawText(ix, iy, ".", colors.lightBlue) end
            end
        end
    end

    -- Jogadores
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
    
    -- Botões de Zoom no Radar
    local rStr = string.format(" ZOOM: %03dm ", range)
    drawText(4, h - 2, "[ - ]", colors.yellow)
    drawText(9, h - 2, rStr, colors.white)
    drawText(10 + #rStr, h - 2, "[ + ]", colors.yellow)
end

local function drawTabScanner()
    local bx, by = 2, 4
    local bw = math.floor(w / 2)
    drawBox(bx, by, bw, h - 4, " CONTROLE DO SCANNER ", colors.orange)
    
    local btnTxt = scanCooldown > 0 and ("AGUARDE " .. scanCooldown .. "s") or " INICIAR VARREDURA "
    local btnCol = scanCooldown > 0 and colors.gray or colors.blue
    drawText(bx + 4, by + 4, "Status:", colors.gray)
    drawText(bx + 4, by + 5, scanStatus, colors.white)
    
    local btnX = bx + math.floor((bw - #btnTxt)/2)
    drawText(btnX, by + 9, " " .. btnTxt .. " ", colors.white, btnCol)
    
    -- Resultados (Lado Direito)
    local rx = bx + bw + 1
    local rw = w - rx
    drawBox(rx, by, rw, h - 4, " RESULTADOS GEOLOGICOS ", colors.lightGray)
    
    if #scanResults == 0 then
        drawText(rx + 4, by + 4, "Aguardando escaneamento...", colors.gray)
    else
        drawText(rx + 2, by + 2, " RECURSO        DISTANCIA  POSICAO", colors.cyan)
        for i = 1, math.min(#scanResults, h - 8) do
            local res = scanResults[i]
            local ud = res.y > 0 and "Acima" or (res.y < 0 and "Abaixo" or "Nivel")
            local line = string.format(" %-14s %-10s %s", res.name:sub(1,12), res.d.."m", ud)
            drawText(rx + 2, by + 3 + i, line, colors.white)
        end
    end
end

local function drawTabTeam()
    local colW = math.floor((w - 4) / 2)
    
    -- Equipa
    drawBox(2, 4, colW, 14, " SINAIS VITAIS - EQUIPA ", colors.green)
    local p1 = getPlayerStats(OWNER)
    drawText(4, 6, "COMANDANTE: " .. OWNER, colors.white)
    if p1 then
        drawText(4, 8, string.format("HP: %d/%d", p1.health, p1.maxHealth), colors.lime)
        drawProgressBar(4, 9, colW - 6, p1.health, p1.maxHealth, colors.lime)
    else drawText(4, 8, "[ OFFLINE ]", colors.gray) end
    
    local p2 = getPlayerStats(ALLY)
    drawText(4, 12, "ALIADO: " .. ALLY, colors.white)
    if p2 then
        drawText(4, 14, string.format("HP: %d/%d", p2.health, p2.maxHealth), colors.lime)
        drawProgressBar(4, 15, colW - 6, p2.health, p2.maxHealth, colors.lime)
    else drawText(4, 14, "[ OFFLINE ]", colors.gray) end

    -- Seguranca e Lockdown
    local secColor = (lockdownMode or #knownIntruders > 0) and colors.red or colors.orange
    drawBox(3 + colW, 4, colW, 14, " SISTEMA DE SEGURANCA ", secColor)
    
    if #knownIntruders == 0 then
        drawText(5 + colW, 6, "Nenhum intruso detetado.", colors.lime)
    else
        drawText(5 + colW, 6, "INTRUSOS NO PERIMETRO:", colors.red)
        for i, inv in ipairs(knownIntruders) do
            drawText(5 + colW, 7 + i, "! " .. inv, colors.white)
        end
    end
    
    local lkTxt = lockdownMode and " [ DESATIVAR ALERTA ] " or " [ ATIVAR ALERTA VERMELHO ] "
    local lkCol = lockdownMode and colors.red or colors.orange
    drawText(3 + colW + math.floor((colW - #lkTxt)/2), 16, lkTxt, colors.white, lkCol)
end

local function drawTabSystem()
    local bx, by = 2, 4
    local bw = math.floor(w / 3)
    
    -- Ambiente
    drawBox(bx, by, bw, h - 4, " RELOGIO / AMBIENTE ", colors.cyan)
    local t = os.time()
    local isDay = (t >= 6 and t < 18.5)
    drawText(bx + 4, by + 4, "Hora Local:", colors.gray)
    drawText(bx + 4, by + 5, textutils.formatTime(t, false), colors.white)
    drawText(bx + 4, by + 8, "Perigo:", colors.gray)
    drawText(bx + 4, by + 9, isDay and "BAIXO (Sol)" or "ALTO (Monstros)", isDay and colors.yellow or colors.red)
    drawText(bx + 4, by + 12, "Uptime: " .. uptime .. "s", colors.lightGray)
    
    -- Terminal Logs
    local lx = bx + bw + 1
    drawBox(lx, by, w - lx, h - 4, " TERMINAL DE REGISTOS GERAIS ", colors.gray)
    for i, msg in ipairs(logs) do
        if i <= maxLogs then
            local col = (i == 1) and colors.white or colors.gray
            drawText(lx + 2, by + 1 + i, ((i==1) and ">> " or "   ") .. msg, col)
        end
    end
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
    end
end

-- ==========================================================
-- LOOP PRINCIPAL E TOQUES
-- ==========================================================
term.clear()
print("J.A.R.V.I.S. OS Browser Edition Online.")
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
        
    elseif ev == "monitor_touch" then
        local tx, ty = p2, p3
        
        -- CLIQUE NA BARRA DE TABS (Y = 2)
        if ty == 2 then
            for i, zone in ipairs(tabZones) do
                if tx >= zone.startX and tx <= zone.endX then
                    activeTab = i
                    updateScreen()
                    break
                end
            end
        
        -- CLIQUES DENTRO DA ABA ATIVA
        else
            if activeTab == 1 then
                -- Radar Zoom Clicks
                if ty == h - 2 then
                    if tx >= 4 and tx <= 8 then
                        if rIdx > 1 then rIdx = rIdx - 1; updateScreen() end
                    elseif tx >= 10 + 13 and tx <= 14 + 13 then
                        if rIdx < #R_RANGES then rIdx = rIdx + 1; updateScreen() end
                    end
                end
                
            elseif activeTab == 2 then
                -- Scanner Button
                if ty == 13 and tx > 2 and tx < (w/2) then
                    if scanCooldown == 0 then
                        runScan()
                        updateScreen()
                    end
                end
                
            elseif activeTab == 3 then
                -- Lockdown Button
                if ty == 16 and tx > (w/2) then
                    lockdownMode = not lockdownMode
                    aiLog(lockdownMode and "ALERTA VERMELHO ATIVADO!" or "Defesas desativadas.")
                    updateScreen()
                end
            end
        end
    end
end
