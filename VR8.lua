local overlay = peripheral.find("overlay") 
    or peripheral.find("advancedperipherals:overlay")
    or peripheral.find("arController")

if not overlay and smartglasses and smartglasses.modules then
    overlay = smartglasses.modules["advancedperipherals:overlay"] or smartglasses.modules.overlay
end

if not overlay then
    error("ERRO: O computador nao esta a detetar o modulo no teu inventario/cabeca!", 0)
end

print("Modulo detetado! A limpar ecrã...")
if overlay.clear then pcall(overlay.clear) end

print("A tentar desenhar...")

-- Método 1: AP 0.8+ (Canvas)
if overlay.canvas then
    pcall(function()
        local c = overlay.canvas()
        c.clear()
        c.addText({x = 100, y = 100}, "TESTE CANVAS", 0xFFFFFFFF, 2.0)
    end)
end

-- Método 2: createObject (Clássico)
if overlay.createObject then
    pcall(function()
        overlay.createObject("text", {text="TESTE CREATE", x=100, y=120, color=0xFFFFFF, gui=true})
    end)
end

-- Método 3: addText direto
if overlay.addText then
    pcall(function()
        overlay.addText(100, 140, "TESTE ADDTEXT", 0xFFFFFFFF)
    end)
end

print("A sincronizar com os óculos...")
if overlay.sync then pcall(overlay.sync) end
if overlay.update then pcall(overlay.update) end

print("Olha para o ecrã do jogo. Apareceu alguma palavra 'TESTE'?")
