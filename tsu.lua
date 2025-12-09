-- Bubble Gum Simulator - Script Optimizado v2.0
-- Performance: RunService, cached refs, optimized loops
-- UI: Modern design con animaciones y efectos

local RS = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RepStorage = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")

-- Cache de referencias (performance)
local LP = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

-- Estados optimizados
local state = {
    farm = false,
    collect = false,
    hatch = false,
    egg = "Tier 1",
    area = "1",
    stats = {coins = 0, hatches = 0}
}

-- Conexiones para cleanup
local connections = {}

-- Notify optimizado (single table creation)
local function notify(txt)
    StarterGui:SetCore("SendNotification", {
        Title = "BGS Script",
        Text = txt,
        Duration = 2.5
    })
end

-- Tween helper optimizado
local function tween(obj, props, time)
    TweenService:Create(obj, TweenInfo.new(time or 0.3, Enum.EasingStyle.Quad), props):Play()
end

-- UI Creation con cache de propiedades
local function createUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "BGSOptimized"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = game.CoreGui
    
    -- Frame principal con gradiente
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 380, 0, 520)
    frame.Position = UDim2.new(0.5, -190, 0.5, -260)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = sg
    
    -- Esquinas redondeadas
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = frame
    
    -- Sombra (efecto de profundidad)
    local shadow = Instance.new("ImageLabel")
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.Position = UDim2.new(0, -15, 0, -15)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.7
    shadow.ZIndex = 0
    shadow.Parent = frame
    
    -- Header con gradiente
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    header.BorderSizePixel = 0
    header.Parent = frame
    
    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 16)
    hCorner.Parent = header
    
    -- Gradiente animado
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 101, 242)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 92, 246))
    }
    gradient.Rotation = 45
    gradient.Parent = header
    
    -- Animar gradiente
    spawn(function()
        while header.Parent do
            for i = 0, 360, 2 do
                if not header.Parent then break end
                gradient.Rotation = i
                RS.Heartbeat:Wait()
            end
        end
    end)
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "🎮 BGS SCRIPT"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 22
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    -- Versión
    local ver = Instance.new("TextLabel")
    ver.Size = UDim2.new(0, 60, 0, 20)
    ver.Position = UDim2.new(1, -70, 0.5, -10)
    ver.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    ver.BackgroundTransparency = 0.3
    ver.Font = Enum.Font.GothamBold
    ver.Text = "v2.0"
    ver.TextColor3 = Color3.fromRGB(255, 255, 255)
    ver.TextSize = 11
    ver.Parent = header
    
    local vCorner = Instance.new("UICorner")
    vCorner.CornerRadius = UDim.new(0, 8)
    vCorner.Parent = ver
    
    -- Stats Panel
    local stats = Instance.new("Frame")
    stats.Size = UDim2.new(0.9, 0, 0, 60)
    stats.Position = UDim2.new(0.05, 0, 0, 75)
    stats.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    stats.BorderSizePixel = 0
    stats.Parent = frame
    
    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 10)
    sCorner.Parent = stats
    
    local statsText = Instance.new("TextLabel")
    statsText.Size = UDim2.new(1, -20, 1, 0)
    statsText.Position = UDim2.new(0, 10, 0, 0)
    statsText.BackgroundTransparency = 1
    statsText.Font = Enum.Font.GothamMedium
    statsText.Text = "💰 Coins: 0 | 🥚 Hatches: 0"
    statsText.TextColor3 = Color3.fromRGB(150, 255, 150)
    statsText.TextSize = 14
    statsText.TextXAlignment = Enum.TextXAlignment.Left
    statsText.Parent = stats
    
    -- Función para crear botones optimizados
    local function btn(txt, pos, col, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.9, 0, 0, 50)
        b.Position = pos
        b.BackgroundColor3 = col
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.Text = txt
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextSize = 15
        b.AutoButtonColor = false
        b.Parent = frame
        
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 10)
        bc.Parent = b
        
        -- Efecto hover
        b.MouseEnter:Connect(function()
            tween(b, {BackgroundColor3 = Color3.fromRGB(
                col.R * 255 * 1.2,
                col.G * 255 * 1.2,
                col.B * 255 * 1.2
            )}, 0.15)
            tween(b, {Size = UDim2.new(0.92, 0, 0, 52)}, 0.15)
        end)
        
        b.MouseLeave:Connect(function()
            tween(b, {BackgroundColor3 = col}, 0.15)
            tween(b, {Size = UDim2.new(0.9, 0, 0, 50)}, 0.15)
        end)
        
        -- Click con animación
        b.MouseButton1Click:Connect(function()
            tween(b, {Size = UDim2.new(0.88, 0, 0, 48)}, 0.1)
            wait(0.1)
            tween(b, {Size = UDim2.new(0.9, 0, 0, 50)}, 0.1)
            callback()
        end)
        
        return b
    end
    
    -- Botones principales
    local farmBtn = btn("🌾 Auto Farm: OFF", 
        UDim2.new(0.05, 0, 0, 150),
        Color3.fromRGB(220, 53, 69),
        function()
            state.farm = not state.farm
            farmBtn.Text = "🌾 Auto Farm: " .. (state.farm and "ON ✓" or "OFF")
            tween(farmBtn, {BackgroundColor3 = state.farm and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)}, 0.2)
            notify("Auto Farm " .. (state.farm and "activado" or "desactivado"))
        end)
    
    local collectBtn = btn("💎 Auto Collect: OFF",
        UDim2.new(0.05, 0, 0, 215),
        Color3.fromRGB(220, 53, 69),
        function()
            state.collect = not state.collect
            collectBtn.Text = "💎 Auto Collect: " .. (state.collect and "ON ✓" or "OFF")
            tween(collectBtn, {BackgroundColor3 = state.collect and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)}, 0.2)
            notify("Auto Collect " .. (state.collect and "activado" or "desactivado"))
        end)
    
    local hatchBtn = btn("🥚 Auto Hatch: OFF",
        UDim2.new(0.05, 0, 0, 280),
        Color3.fromRGB(220, 53, 69),
        function()
            state.hatch = not state.hatch
            hatchBtn.Text = "🥚 Auto Hatch: " .. (state.hatch and "ON ✓" or "OFF")
            tween(hatchBtn, {BackgroundColor3 = state.hatch and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)}, 0.2)
            notify("Auto Hatch " .. (state.hatch and "activado" or "desactivado"))
        end)
    
    -- Input de huevo
    local eggInput = Instance.new("TextBox")
    eggInput.Size = UDim2.new(0.9, 0, 0, 45)
    eggInput.Position = UDim2.new(0.05, 0, 0, 345)
    eggInput.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    eggInput.BorderSizePixel = 0
    eggInput.Font = Enum.Font.Gotham
    eggInput.PlaceholderText = "🥚 Nombre del huevo (Tier 1, etc.)"
    eggInput.Text = "Tier 1"
    eggInput.TextColor3 = Color3.new(1, 1, 1)
    eggInput.TextSize = 14
    eggInput.ClearTextOnFocus = false
    eggInput.Parent = frame
    
    local eCorner = Instance.new("UICorner")
    eCorner.CornerRadius = UDim.new(0, 10)
    eCorner.Parent = eggInput
    
    eggInput.FocusLost:Connect(function()
        state.egg = eggInput.Text
        notify("Huevo: " .. state.egg)
    end)
    
    -- Botón TP
    btn("📍 TP to Spawn",
        UDim2.new(0.05, 0, 0, 405),
        Color3.fromRGB(23, 162, 184),
        function()
            if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                LP.Character.HumanoidRootPart.CFrame = CFrame.new(0, 5, 0)
                notify("Teletransportado ✓")
            end
        end)
    
    -- Botón cerrar
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 35, 0, 35)
    close.Position = UDim2.new(1, -45, 0, 10)
    close.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    close.BorderSizePixel = 0
    close.Font = Enum.Font.GothamBold
    close.Text = "✕"
    close.TextColor3 = Color3.new(1, 1, 1)
    close.TextSize = 18
    close.AutoButtonColor = false
    close.Parent = frame
    
    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 8)
    cCorner.Parent = close
    
    close.MouseEnter:Connect(function()
        tween(close, {Rotation = 90, BackgroundColor3 = Color3.fromRGB(255, 70, 70)}, 0.2)
    end)
    
    close.MouseLeave:Connect(function()
        tween(close, {Rotation = 0, BackgroundColor3 = Color3.fromRGB(220, 53, 69)}, 0.2)
    end)
    
    close.MouseButton1Click:Connect(function()
        tween(frame, {Size = UDim2.new(0, 0, 0, 0)}, 0.3)
        wait(0.3)
        for _, conn in pairs(connections) do
            conn:Disconnect()
        end
        sg:Destroy()
    end)
    
    -- Animación de entrada
    frame.Size = UDim2.new(0, 0, 0, 0)
    tween(frame, {Size = UDim2.new(0, 380, 0, 520)}, 0.5)
    
    return sg, statsText
end

-- Sistema optimizado: RunService en lugar de loops
local function initSystems()
    local lastCollect = 0
    local lastFarm = 0
    local lastHatch = 0
    
    -- Single Heartbeat connection (más eficiente)
    connections.mainLoop = RS.Heartbeat:Connect(function()
        local now = tick()
        
        -- Auto Collect (optimizado: 10 FPS)
        if state.collect and now - lastCollect > 0.1 then
            lastCollect = now
            pcall(function()
                local coins = WS.Game.Coins:GetChildren()
                for i = 1, #coins do
                    local c = coins[i]
                    if c:FindFirstChild("TouchInterest") then
                        firetouchinterest(LP.Character.HumanoidRootPart, c, 0)
                        firetouchinterest(LP.Character.HumanoidRootPart, c, 1)
                    end
                end
            end)
        end
        
        -- Auto Farm (optimizado: 2 FPS)
        if state.farm and now - lastFarm > 0.5 then
            lastFarm = now
            pcall(function()
                local pets = {}
                for i = 1, 20 do pets[i] = i end
                RepStorage.RemoteEvents.CheckAreaUpdate:InvokeServer(state.area, pets)
            end)
        end
        
        -- Auto Hatch (optimizado: 1 FPS)
        if state.hatch and now - lastHatch > 1 then
            lastHatch = now
            pcall(function()
                RepStorage.RemoteEvents.BuyEgg:InvokeServer(state.egg, 1)
                state.stats.hatches = state.stats.hatches + 1
            end)
        end
    end)
end

-- Initialize
local sg, statsLabel = createUI()
initSystems()

-- Stats updater (optimizado: 2 FPS)
spawn(function()
    while sg.Parent do
        wait(0.5)
        pcall(function()
            statsLabel.Text = string.format("💰 Coins: %d | 🥚 Hatches: %d", 
                state.stats.coins, state.stats.hatches)
        end)
    end
end)

notify("✨ Script cargado - Optimizado v2.0")
print("═══════════════════════════════")
print("🚀 BGS Script v2.0 - OPTIMIZADO")
print("📊 Performance: RunService + Cache")
print("🎨 UI: Modern + Animations")
print("═══════════════════════════════")
