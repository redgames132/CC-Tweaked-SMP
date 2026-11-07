-- ==========================================================
-- J.A.R.V.I.S. - Versão Chat Box (Compatível com Iris/Shaders)
-- Minecraft 1.21.1 NeoForge
-- ==========================================================

local AI_NAME = "J.A.R.V.I.S."
local HOME_FILE = "ai_home.txt"

-- Detecção de Periféricos
local chatBox = peripheral.find("chat_box") or peripheral.find("chatBox")
local scanner = peripheral.find("geo_scanner") or peripheral.find("geoScanner")
local nvModule = nil

if smartglasses and smartglasses.modules then
    nvModule = smartglasses.modules["advancedperipherals:night_vision"] or smartglasses.modules.night_vision
end

if not chatBox then
    error("ERRO: Você precisa colocar um Chat Box nos óculos para esta versão funcionar!", 0)
end

-- Função central de comunicação (Toast + Chat Privado + Action Bar)
local function aiAlert(title, message, isUrgent)
    local titleCol = isUrgent and "red" or "aqua"
    
    -- 1. Notificação estilo "Conquista" no canto da tela
    pcall(function()
        chatBox.sendToast({
            title = AI_NAME .. " - " .. title,
            message = message,
            titleColor = titleCol,
            messageColor = "white"
        })
    end)
    
    -- 2. Mensagem flutuante acima da barra de vida/fome
    pcall(function()
        chatBox.sendActionBar("&b[" .. AI_NAME .. "] &f" .. message)
    end)

    -- 3. Mensagem no chat in-game (escondida dos outros)
    pcall(function()
        chatBox.sendMessage("&b[" .. AI_NAME .. "] &f" .. message)
    end)
    
    print("[" .. AI_NAME .. "] " .. message)
end

-- Sistema de Waypoint
local homePos = nil
if fs.exists(HOME_FILE) then
    local f = fs.open(HOME_FILE, "r")
    homePos = textutils.unserialize(f.readAll())
    f.close()
end

-- Dados do Jogador
local ownerName = "Boss"
local function getOwnerData()
    if smartglasses and smartglasses.getOwner then
        local ok, data = pcall(smartglasses.getOwner)
        if ok and type(data) == "table" then
            ownerName = data.name or ownerName
            return {
                x = math.floor(data.x or 0), y = math.floor(data.y or 0), z = math.floor(data.z or 0),
                health = data.health, maxHealth = data.maxHealth or 20
            }
        end
    end
    return { x = 0, y = 0, z = 0, health = 20, maxHealth = 20 }
end

-- Scanner Automático
local RARE_ORES = {"ancient_debris", "uranium", "osmium", "diamond", "emerald", "fluorite", "zinc", "gold"}
local function scanOres()
    if not scanner then return end
    local scanFn = scanner.scanBlocks or scanner.scan
    if not scanFn then return end

    local ok, blocks = pcall(function() return scanFn(8) end)
    if not ok or type(blocks) ~= "table" then return end

    local best, bestDist = nil, 999
    for _, b in ipairs(blocks) do
        local name = (b.name or ""):lower()
        for _, key in ipairs(RARE_ORES) do
            if name:find(key) then
                local dist = math.abs(b.x or 0) + math.abs(b.y or 0) + math.abs(b.z or 0)
                if dist < bestDist then
                    bestDist = dist
                    best = { name = key:gsub("_ore", ""):upper(), x = b.x, y = b.y, z = b.z }
                end
                break
            end
        end
    end

    if best then
        local ud = best.y > 0 and "Acima" or (best.y < 0 and "Abaixo" or "Lado")
        aiAlert("Minério Detectado", string.format("%s perto! Olhe para %s.", best.name, ud), false)
    end
end

-- Comandos In-Game
local function processCommand(cmd)
    local info = getOwnerData()
    cmd = cmd:lower():gsub("^%$", "")

    if cmd == "status" then
        aiAlert("Status", string.format("Vida: %d/%d | Pos: %d %d %d", info.health, info.maxHealth, info.x, info.y, info.z), false)
    elseif cmd == "nv" then
        if nvModule then
            local _, cur = pcall(nvModule.isNightVisionEnabled)
            pcall(function() nvModule.enableNightVision(not cur) end)
            aiAlert("Hardware", "Visão Noturna alterada.", false)
        end
    elseif cmd == "scan" or cmd == "ores" then
        scanOres()
    elseif cmd == "sethome" then
        homePos = { x = info.x, y = info.y, z = info.z }
        local f = fs.open(HOME_FILE, "w")
        f.write(textutils.serialize(homePos))
        f.close()
        aiAlert("GPS", "Base salva com sucesso!", false)
    elseif cmd == "home" then
        if homePos then
            local dist = math.floor(math.sqrt((homePos.x - info.x)^2 + (homePos.z - info.z)^2))
            aiAlert("GPS", string.format("Sua base está a %dm de distância.", dist), false)
        else
            aiAlert("Erro", "Você não salvou nenhuma base.", true)
        end
    end
end

-- Loops Principais
term.clear()
aiAlert("Boot Sequence", "Sistemas J.A.R.V.I.S. inicializados.", false)

local function loopBackground()
    local warnedHp = false
    while true do
        sleep(5)
        local info = getOwnerData()
        
        -- Auto-Scan a cada 5 segundos
        if math.random() > 0.5 then scanOres() end

        -- Alerta de Vida
        if info.health and info.health <= 6 and not warnedHp then
            aiAlert("PERIGO", "Sinais vitais críticos! Procure abrigo.", true)
            warnedHp = true
        elseif info.health and info.health > 10 then
            warnedHp = false
        end
    end
end

local function loopChat()
    while true do
        local ev, sender, msg = os.pullEvent("chat")
        -- Se a mensagem começar com $ (ex: $status, $nv, $home)
        if type(msg) == "string" and msg:sub(1, 1) == "$" then
            processCommand(msg)
        end
    end
end

parallel.waitForAny(loopBackground, loopChat)
