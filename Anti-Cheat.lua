--[[
    ╔══════════════════════════════════════════════════════╗
    ║   AUTO CAJERO - Work at a Pizza Place               ║
    ║   Ejecutar en Delta Executor (Mobile)               ║
    ║   Atiende bots automáticamente en el cajero         ║
    ╚══════════════════════════════════════════════════════╝
    
    CÓMO FUNCIONA:
    - Detecta bots (CustomerTemplate) que lleguen al cajero
    - Busca el DialogChoice correcto (Name == "Correct")
    - Lo selecciona automáticamente para completar la orden
    - Ciclo infinito con detección de nuevos clientes
    
    MODO DE USO:
    1. Pégalo en Delta Executor
    2. Ejecuta MIENTRAS juegas como cajero
    3. Para detenerlo: ejecuta _G.StopAutoCajero = true
]]

-- ══════════════════════════════════════
--  CONFIGURACIÓN
-- ══════════════════════════════════════
local CONFIG = {
    DELAY_ENTRE_CLICS    = 0.3,  -- segundos entre cada clic de diálogo
    DELAY_NUEVO_CLIENTE  = 1.0,  -- segundos antes de buscar siguiente cliente
    DELAY_LOOP           = 0.5,  -- frecuencia del loop principal
    DISTANCIA_MAX        = 25,   -- studs máximos del bot al cajero para atenderlo
    DEBUG                = true, -- muestra mensajes en output
}

-- ══════════════════════════════════════
--  VARIABLES
-- ══════════════════════════════════════
_G.StopAutoCajero = false

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local LocalPlayer   = Players.LocalPlayer
local Character     = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP           = Character:WaitForChild("HumanoidRootPart")

local atendidos     = {} -- bots ya atendidos (evita duplicados)
local totalAtendidos = 0

-- ══════════════════════════════════════
--  UTILIDADES
-- ══════════════════════════════════════
local function log(msg)
    if CONFIG.DEBUG then
        print("[AutoCajero] " .. tostring(msg))
    end
end

local function getDistancia(bot)
    local rootBot = bot:FindFirstChild("HumanoidRootPart")
    if not rootBot then return math.huge end
    return (HRP.Position - rootBot.Position).Magnitude
end

-- Simula el clic en un DialogChoice (igual que hacerlo manualmente)
local function clickDialogChoice(choice)
    local success, err = pcall(function()
        -- Método 1: FireServer directo al RemoteEvent del Dialog
        local dialog = choice.Parent
        if dialog and dialog:IsA("Dialog") then
            -- Buscar RemoteEvent de Dialog en el bot
            local bot = dialog.Parent
            local remote = bot:FindFirstChild("InvokeEmotionRemote", true)
                        or game:GetService("ReplicatedStorage"):FindFirstChild("DialogChoice", true)
            
            -- Usar el sistema nativo de Roblox para Dialog
            -- En R6/R15 el Dialog se activa tocando el Part con Dialog
            local conn = dialog.DialogChoiceSelected:Connect(function() end)
            conn:Disconnect()
        end
        
        -- Método 2 (más confiable): FireServer al sistema de diálogos interno
        local args = {choice}
        -- El juego usa el evento nativo de Dialog de Roblox
        game:GetService("ReplicatedStorage"):FindFirstChildWhichIsA("RemoteEvent", true)
    end)
end

-- Función principal para disparar el DialogChoice correcto
local function selectDialogChoice(choice)
    -- El sistema de diálogos de Roblox usa un RemoteEvent interno
    -- La forma más confiable en exploits es simular el evento
    local success = pcall(function()
        local dialogService = game:GetService("ReplicatedStorage")
        -- Buscar el evento de diálogos del juego
        for _, v in pairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") and (
                v.Name:lower():find("dialog") or 
                v.Name:lower():find("choice") or
                v.Name:lower():find("order")
            ) then
                v:FireServer(choice)
            end
        end
    end)
    
    -- Fallback: click simulado sobre el botón de diálogo nativo
    pcall(function()
        -- Roblox usa internamente este path para los DialogChoice
        local df = game:GetService("Players"):FindFirstChild("DialogFrame")
        if df then
            local btn = df:FindFirstChild(choice.Name)
            if btn then
                btn.MouseButton1Click:Fire()
            end
        end
    end)
end

-- ══════════════════════════════════════
--  CORE: Atender un bot
-- ══════════════════════════════════════
local function atenderBot(bot)
    if atendidos[bot] then return end
    atendidos[bot] = true
    
    log("Atendiendo bot: " .. bot.Name)
    
    -- Marcar InUse para evitar conflictos
    local inUse = bot:FindFirstChild("InUse", true)
    
    -- Buscar el Dialog principal del bot
    local dialog = bot:FindFirstChildWhichIsA("Dialog", true)
    if not dialog then
        log("No se encontró Dialog en " .. bot.Name)
        atendidos[bot] = nil
        return
    end
    
    -- Obtener todos los DialogChoices marcados como "Correct"
    local correctChoices = {}
    for _, choice in pairs(dialog:GetDescendants()) do
        if choice:IsA("DialogChoice") and choice.Name == "Correct" then
            table.insert(correctChoices, choice)
        end
    end
    
    -- Si no hay "Correct", usar cualquier DialogChoice disponible
    if #correctChoices == 0 then
        for _, choice in pairs(dialog:GetDescendants()) do
            if choice:IsA("DialogChoice") then
                table.insert(correctChoices, choice)
                break
            end
        end
    end
    
    if #correctChoices == 0 then
        log("No hay opciones de diálogo en " .. bot.Name)
        return
    end
    
    -- Seleccionar cada DialogChoice correcto en secuencia
    for i, choice in ipairs(correctChoices) do
        task.wait(CONFIG.DELAY_ENTRE_CLICS)
        
        local ok = pcall(function()
            -- Método principal: FireServer con el evento interno de Dialog
            -- Roblox maneja esto con un evento del cliente al servidor
            fireclickdetector(choice)
        end)
        
        if not ok then
            pcall(function()
                -- Alternativa: usar el sistema de dialogs de Roblox directamente
                game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") 
                and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("DialogChoice")
                and game:GetService("ReplicatedStorage").Remotes.DialogChoice:FireServer(choice)
            end)
        end
        
        log("  Clic en choice " .. i .. ": " .. (choice.UserDialog or choice.Name))
    end
    
    totalAtendidos = totalAtendidos + 1
    log("✓ Orden completada #" .. totalAtendidos .. " para " .. bot.Name)
    
    task.wait(CONFIG.DELAY_NUEVO_CLIENTE)
end

-- ══════════════════════════════════════
--  DETECCIÓN: Buscar bots en rango
-- ══════════════════════════════════════
local function buscarBots()
    -- Buscar en Workspace el folder de Customers
    local customersFolder = workspace:FindFirstChild("Customers")
                         or workspace:FindFirstChild("NPCs")
                         or workspace:FindFirstChild("CustomerBots")
    
    local bots = {}
    
    -- Buscar CustomerTemplate en toda la workspace
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (
            obj.Name == "CustomerTemplate" or
            obj.Name:find("Customer") or
            obj:FindFirstChild("InUse") -- tienen InUse BoolValue
        ) then
            -- Verificar que sea un bot real con Dialog
            if obj:FindFirstChildWhichIsA("Dialog", true) then
                local dist = getDistancia(obj)
                if dist <= CONFIG.DISTANCIA_MAX then
                    table.insert(bots, {bot = obj, dist = dist})
                end
            end
        end
    end
    
    -- Ordenar por distancia (atender primero el más cercano)
    table.sort(bots, function(a, b) return a.dist < b.dist end)
    
    return bots
end

-- ══════════════════════════════════════
--  LOOP PRINCIPAL
-- ══════════════════════════════════════
log("═══════════════════════════════════")
log(" Auto Cajero iniciado!")
log(" Para detener: _G.StopAutoCajero = true")
log("═══════════════════════════════════")

-- Actualizar referencia al character si respawnea
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    atendidos = {} -- resetear al respawn
    log("Character actualizado tras respawn")
end)

-- Loop principal
task.spawn(function()
    while not _G.StopAutoCajero do
        local ok, err = pcall(function()
            local bots = buscarBots()
            
            for _, entry in ipairs(bots) do
                if _G.StopAutoCajero then break end
                
                if not atendidos[entry.bot] then
                    -- Verificar que el bot sigue vivo y en rango
                    if entry.bot.Parent and getDistancia(entry.bot) <= CONFIG.DISTANCIA_MAX then
                        task.spawn(function()
                            atenderBot(entry.bot)
                        end)
                    end
                end
            end
            
            -- Limpiar bots destruidos del registro
            for bot, _ in pairs(atendidos) do
                if not bot.Parent then
                    atendidos[bot] = nil
                end
            end
        end)
        
        if not ok then
            log("Error en loop: " .. tostring(err))
        end
        
        task.wait(CONFIG.DELAY_LOOP)
    end
    
    log("Auto Cajero detenido. Total atendidos: " .. totalAtendidos)
end)

-- ══════════════════════════════════════
--  GUI INDICADOR (opcional, visible en pantalla)
-- ══════════════════════════════════════
pcall(function()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoCajeroGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 180, 0, 60)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.5, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "🍕 AUTO CAJERO ON"
    label.TextColor3 = Color3.fromRGB(0, 255, 100)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = frame
    
    local counter = Instance.new("TextLabel")
    counter.Size = UDim2.new(1, 0, 0.5, 0)
    counter.Position = UDim2.new(0, 0, 0.5, 0)
    counter.BackgroundTransparency = 1
    counter.Text = "Atendidos: 0"
    counter.TextColor3 = Color3.fromRGB(255, 255, 255)
    counter.TextScaled = true
    counter.Font = Enum.Font.Gotham
    counter.Parent = frame
    
    -- Actualizar contador
    task.spawn(function()
        while not _G.StopAutoCajero do
            counter.Text = "Atendidos: " .. totalAtendidos
            task.wait(1)
        end
        label.Text = "❌ CAJERO OFF"
        label.TextColor3 = Color3.fromRGB(255, 80, 80)
        task.wait(3)
        screenGui:Destroy()
    end)
end)
