-- ==========================================================
-- J.A.R.V.I.S. HUD - Redesenho Contínuo (Anti-Erros)
-- Compatível com Canvas API e createObject (AP 0.8+)
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S."
local ar = peripheral.find("arController") or peripheral.find("overlay")

-- Fallback caso seja executado diretamente nos smartglasses
if not ar and smartglasses then ar = smartglasses end
if not ar then error("ERRO: Modulo Overlay ou AR Controller ausente!", 0) end

local scanner = peripheral.find("geoScanner") or peripheral.find("geo_scanner")
local chatBox = peripheral.find("chatBox") or peripheral.find("chat_box")

-- Posições base do HUD (Abaixo do minimapa)
local hX, hY = 6, 148
local lastMsg = "Sistemas prontos."

-- Função robusta para desenhar texto em qualquer versão do AP
local function drawLine(txt, yOffset, rgb)
    local finalY = hY + yOffset
    
    -- Tenta desenhar usando a Canvas API moderna (ARGB)
    local canvasOk = pcall(function()
        ar.canvas().addText({x = hX, y = finalY}, txt, 0xFF000000 + rgb)
    end)
    
    -- Se a Canvas API falhar, usa o sistema antigo (createObject)
    if not canvasOk then
        pcall(function()
            ar.createObject("text", {text = txt, x = hX, y = finalY, color = rgb, gui = true})
        end)
    end
end

-- Obtém os dados do jogador
local function getOwner()
    local info = { x = 0, y = 0, z = 0, hp = 20 }
    if ar.getOwner then
        local ok, d = pcall(ar.getOwner)
        if ok and type(d) == "table" then
            info.x = math.floor(d.x or d.yaw or 0)
            info.y = math.floor(d.y or d.pitch or 0)
            info.z = math.floor(d.z or 0)
            info.hp = d.health or 20
        end
    end
    return info
end

-- Varrer minérios e encontrar o mais próximo
local RARE = {"ancient_debris","uranium","osmium","diamond","emerald","fluorite","zinc"}
local function getScan()
    if not scanner then return "Sem Geo Scanner" end
    local fn = scanner.scanBlocks or scanner.scan
    if not fn then return "Scanner Indisponivel" end
    
    local ok, b = pcall(function() return fn(8) end)
    if not ok or type(b) ~= "table" then return "A varrer arredores..." end
    
    local best, minDist = nil, 999
    for _, block in ipairs(b) do
        local n = (block.name or ""):lower()
        for _, r in ipairs(RARE) do
            if n:find(r) then
                local dist = math.abs(block.x or 0) + math.abs(block.y or 0) + math.abs(block.z or 0)
                if dist < minDist then
                    minDist = dist
                    best = { n = r:upper(), x = block.x, y = block.y, z = block.z }
                end
            end
        end
    end
    
    if best then
        local ud = best.y > 0 and "Acima" or (best.y < 0 and "Abaixo" or "Lado")
        return string.format("ALVO: %s (%s)", best.n, ud)
    end
    return "Nenhum minerio raro (8m)"
end

-- Limpa tudo e redesenha o ecrã inteiro do zero
local function updateHUD()
    -- Tenta limpar de todas as formas possíveis
    pcall(function() if ar.clear then ar.clear() end end)
    pcall(function() if ar.canvas then ar.canvas().clear() end end)
    
    local info = getOwner()
    
    -- Desenha as 4 linhas do HUD
    drawLine(string.format("[%s] Overlay Ativo", AI_NAME), 0, 0x00FFFF)
    drawLine(string.format("XYZ: %d %d %d | HP: %d", info.x, info.y, info.z, math.floor(info.hp)), 12, 0x55FF55)
    drawLine(getScan(), 24, 0xFFFF55)
    drawLine("> " .. lastMsg, 36, 0xFFFFFF)
    
    -- Sincroniza e envia pacote para o jogador
    if ar.sync then pcall(ar.sync) end
end

-- Sistema de Mensagens
local function aiSay(msg)
    lastMsg = msg
    updateHUD()
    if chatBox then
        pcall(function() chatBox.sendMessage("&b["..AI_NAME.."] &f"..msg) end)
    end
end

-- ==========================================================
-- LOOP PRINCIPAL
-- ==========================================================
term.clear()
print("J.A.R.V.I.S. Overlay Iniciado.")
print("Escreva os comandos no chat usando '$'. Ex: $pos topo")
updateHUD()

while true do
    local tid = os.startTimer(2.0)
    local ev, p1, p2, p3 = os.pullEvent()
    
    if ev == "timer" and p1 == tid then
        updateHUD()
        
    elseif ev == "chat" then
        local msg = type(p2) == "string" and p2 or p3
        if type(msg) == "string" and msg:sub(1, 1) == "$" then
            local cmd = msg:sub(2):lower()
            if cmd == "pos topo" then
                hX, hY = 300, 8
                aiSay("Movido para o topo.")
            elseif cmd == "pos mapa" then
                hX, hY = 6, 148
                aiSay("Movido para baixo do mapa.")
            elseif cmd == "nv" then
                -- Fallback se tiver modulo de night vision manual
                aiSay("Comando NV recebido.")
            else
                aiSay("Comando: " .. cmd)
            end
        end
    end
end
