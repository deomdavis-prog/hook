-- ╔═══════════════════════════════════════════════════════════╗
-- ║           GUI TODO EN 1 - ELEGANT & MODERN v3.0          ║
-- ║  Stats, Coins, Pets, GamePasses, Auto-Farm & More        ║
-- ║              Optimizado para Delta Executor              ║
-- ╚═══════════════════════════════════════════════════════════╝

local player = game:GetService("Players").LocalPlayer
local playerName = player.Name
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Referencias
local leaderstats = player:WaitForChild("leaderstats")
local playerGui = player:WaitForChild("PlayerGui")

-- ════════════════════════════════════════════════════════════
-- CONFIGURACIÓN
-- ════════════════════════════════════════════════════════════

local CONFIG = {
    Stats = {
        Coins = 999999999,
        MoonCoins = 999999999,
        PetsCount = 999,
        PetLevel = 999999,
        PetPower = 999999
    },
    AutoFarm = {
        Enabled = false,
        CollectCoins = true,
        Interval = 0.5
    },
    GamePasses = {
        InfinitePets = false,
        TripleSpeed = false
    }
}

-- ════════════════════════════════════════════════════════════
-- FUNCIONES CORE
-- ════════════════════════════════════════════════════════════

local farmRunning = false
local farmLoopCount = 0

local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    return success, result or "Error desconocido"
end

local function FormatNumber(num)
    if num >= 1000000000 then
        return string.format("%.2fB", num / 1000000000)
    elseif num >= 1000000 then
        return string.format("%.2fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.2fK", num / 1000)
    else
        return tostring(num)
    end
end

local function ModifyCoins(amount)
    SafeCall(function()
        local coinsValue = leaderstats:FindFirstChild("💰 Coins")
        if coinsValue then
            coinsValue.Value = amount
        end
    end)
end

local function ModifyMoonCoins(amount)
    SafeCall(function()
        local moonCoinsValue = leaderstats:FindFirstChild("🌑 Moon Coins")
        if moonCoinsValue then
            moonCoinsValue.Value = amount
        end
    end)
end

local function ModifyPetsCount(amount)
    SafeCall(function()
        local petsValue = leaderstats:FindFirstChild("🐾 Pets")
        if petsValue then
            petsValue.Value = amount
        end
    end)
end

local function ModifyPetStats(level, power)
    SafeCall(function()
        local Stats = workspace.__REMOTES.Core["Get Other Stats"]:InvokeServer()
        if Stats and Stats[playerName] and Stats[playerName]["Save"]["Pets"] then
            for i, v in pairs(Stats[playerName]["Save"]["Pets"]) do
                v.l = level
                v.p = power
            end
            workspace.__REMOTES.Core["Set Stats"]:FireServer(Stats[playerName])
        end
    end)
end

local function CollectCoins()
    SafeCall(function()
        local args = {"Get"}
        workspace:WaitForChild("__REMOTES"):WaitForChild("Game"):WaitForChild("Coins"):FireServer(unpack(args))
    end)
end

local function StartAutoFarm()
    if farmRunning then return end
    farmRunning = true
    farmLoopCount = 0
    CONFIG.AutoFarm.Enabled = true
    
    spawn(function()
        while farmRunning and CONFIG.AutoFarm.Enabled do
            farmLoopCount = farmLoopCount + 1
            if CONFIG.AutoFarm.CollectCoins then
                CollectCoins()
            end
            wait(CONFIG.AutoFarm.Interval)
        end
    end)
end

local function StopAutoFarm()
    farmRunning = false
    CONFIG.AutoFarm.Enabled = false
end

-- ════════════════════════════════════════════════════════════
-- CREAR GUI
-- ════════════════════════════════════════════════════════════

-- Eliminar GUI existente si existe
if playerGui:FindFirstChild("TodoEn1GUI") then
    playerGui:FindFirstChild("TodoEn1GUI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TodoEn1GUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- Frame principal
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 550, 0, 650)
MainFrame.Position = UDim2.new(0.5, -275, 0.5, -325)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Sombra
local Shadow = Instance.new("ImageLabel")
Shadow.Name = "Shadow"
Shadow.Size = UDim2.new(1, 30, 1, 30)
Shadow.Position = UDim2.new(0, -15, 0, -15)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(10, 10, 118, 118)
Shadow.ZIndex = 0
Shadow.Parent = MainFrame

-- Esquinas redondeadas
local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = MainFrame

-- Borde brillante
local Border = Instance.new("UIStroke")
Border.Color = Color3.fromRGB(100, 100, 255)
Border.Thickness = 2
Border.Transparency = 0.3
Border.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 60)
Header.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

-- Título
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0, 20, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ TODO EN 1 - SCRIPT HUB"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Name = "Subtitle"
Subtitle.Size = UDim2.new(1, -100, 0, 20)
Subtitle.Position = UDim2.new(0, 20, 0, 35)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Player: " .. playerName
Subtitle.TextColor3 = Color3.fromRGB(150, 150, 200)
Subtitle.TextSize = 12
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

-- Botón cerrar
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 40, 0, 40)
CloseButton.Position = UDim2.new(1, -50, 0, 10)
CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 20
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseButton

-- Contenedor con scroll
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "ScrollFrame"
ScrollFrame.Size = UDim2.new(1, -20, 1, -80)
ScrollFrame.Position = UDim2.new(0, 10, 0, 70)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 6
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 255)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1400)
ScrollFrame.Parent = MainFrame

-- ════════════════════════════════════════════════════════════
-- FUNCIÓN PARA CREAR SECCIONES
-- ════════════════════════════════════════════════════════════

local currentY = 10

local function CreateSection(title, icon)
    local Section = Instance.new("Frame")
    Section.Name = title
    Section.Size = UDim2.new(1, -10, 0, 40)
    Section.Position = UDim2.new(0, 5, 0, currentY)
    Section.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    Section.BorderSizePixel = 0
    Section.Parent = ScrollFrame
    
    local SectionCorner = Instance.new("UICorner")
    SectionCorner.CornerRadius = UDim.new(0, 8)
    SectionCorner.Parent = Section
    
    local SectionTitle = Instance.new("TextLabel")
    SectionTitle.Size = UDim2.new(1, -20, 1, 0)
    SectionTitle.Position = UDim2.new(0, 15, 0, 0)
    SectionTitle.BackgroundTransparency = 1
    SectionTitle.Text = icon .. " " .. title
    SectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    SectionTitle.TextSize = 16
    SectionTitle.Font = Enum.Font.GothamBold
    SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    SectionTitle.Parent = Section
    
    currentY = currentY + 50
    
    return Section
end

-- ════════════════════════════════════════════════════════════
-- FUNCIÓN PARA CREAR BOTONES
-- ════════════════════════════════════════════════════════════

local function CreateButton(text, color, callback)
    local Button = Instance.new("TextButton")
    Button.Name = text
    Button.Size = UDim2.new(1, -10, 0, 45)
    Button.Position = UDim2.new(0, 5, 0, currentY)
    Button.BackgroundColor3 = color
    Button.Text = text
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextSize = 14
    Button.Font = Enum.Font.GothamSemibold
    Button.AutoButtonColor = false
    Button.Parent = ScrollFrame
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 8)
    ButtonCorner.Parent = Button
    
    local ButtonStroke = Instance.new("UIStroke")
    ButtonStroke.Color = Color3.fromRGB(255, 255, 255)
    ButtonStroke.Thickness = 0
    ButtonStroke.Transparency = 0.7
    ButtonStroke.Parent = Button
    
    -- Animación hover
    Button.MouseEnter:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(
            math.min(color.R * 255 + 20, 255),
            math.min(color.G * 255 + 20, 255),
            math.min(color.B * 255 + 20, 255)
        )}):Play()
        TweenService:Create(ButtonStroke, TweenInfo.new(0.2), {Thickness = 2}):Play()
    end)
    
    Button.MouseLeave:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
        TweenService:Create(ButtonStroke, TweenInfo.new(0.2), {Thickness = 0}):Play()
    end)
    
    -- Animación click
    Button.MouseButton1Down:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.1), {Size = UDim2.new(1, -15, 0, 43)}):Play()
    end)
    
    Button.MouseButton1Up:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.1), {Size = UDim2.new(1, -10, 0, 45)}):Play()
    end)
    
    Button.MouseButton1Click:Connect(callback)
    
    currentY = currentY + 55
    
    return Button
end

-- ════════════════════════════════════════════════════════════
-- FUNCIÓN PARA CREAR TOGGLE
-- ════════════════════════════════════════════════════════════

local function CreateToggle(text, defaultState, callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Name = text
    ToggleFrame.Size = UDim2.new(1, -10, 0, 45)
    ToggleFrame.Position = UDim2.new(0, 5, 0, currentY)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    ToggleFrame.BorderSizePixel = 0
    ToggleFrame.Parent = ScrollFrame
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 8)
    ToggleCorner.Parent = ToggleFrame
    
    local ToggleLabel = Instance.new("TextLabel")
    ToggleLabel.Size = UDim2.new(1, -70, 1, 0)
    ToggleLabel.Position = UDim2.new(0, 15, 0, 0)
    ToggleLabel.BackgroundTransparency = 1
    ToggleLabel.Text = text
    ToggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleLabel.TextSize = 14
    ToggleLabel.Font = Enum.Font.Gotham
    ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    ToggleLabel.Parent = ToggleFrame
    
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(0, 50, 0, 25)
    ToggleButton.Position = UDim2.new(1, -60, 0.5, -12.5)
    ToggleButton.BackgroundColor3 = defaultState and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(100, 100, 100)
    ToggleButton.Text = ""
    ToggleButton.Parent = ToggleFrame
    
    local ToggleButtonCorner = Instance.new("UICorner")
    ToggleButtonCorner.CornerRadius = UDim.new(1, 0)
    ToggleButtonCorner.Parent = ToggleButton
    
    local ToggleCircle = Instance.new("Frame")
    ToggleCircle.Size = UDim2.new(0, 21, 0, 21)
    ToggleCircle.Position = defaultState and UDim2.new(1, -23, 0.5, -10.5) or UDim2.new(0, 2, 0.5, -10.5)
    ToggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ToggleCircle.BorderSizePixel = 0
    ToggleCircle.Parent = ToggleButton
    
    local CircleCorner = Instance.new("UICorner")
    CircleCorner.CornerRadius = UDim.new(1, 0)
    CircleCorner.Parent = ToggleCircle
    
    local isToggled = defaultState
    
    ToggleButton.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        
        if isToggled then
            TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 200, 100)}):Play()
            TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(1, -23, 0.5, -10.5)}):Play()
        else
            TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}):Play()
            TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -10.5)}):Play()
        end
        
        callback(isToggled)
    end)
    
    currentY = currentY + 55
    
    return ToggleFrame
end

-- ════════════════════════════════════════════════════════════
-- FUNCIÓN PARA STATUS DISPLAY
-- ════════════════════════════════════════════════════════════

local function CreateStatusDisplay()
    local StatusFrame = Instance.new("Frame")
    StatusFrame.Name = "StatusDisplay"
    StatusFrame.Size = UDim2.new(1, -10, 0, 80)
    StatusFrame.Position = UDim2.new(0, 5, 0, currentY)
    StatusFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    StatusFrame.BorderSizePixel = 0
    StatusFrame.Parent = ScrollFrame
    
    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(0, 8)
    StatusCorner.Parent = StatusFrame
    
    local StatusText = Instance.new("TextLabel")
    StatusText.Name = "StatusText"
    StatusText.Size = UDim2.new(1, -20, 1, -10)
    StatusText.Position = UDim2.new(0, 10, 0, 5)
    StatusText.BackgroundTransparency = 1
    StatusText.Text = "Coins: Cargando...\nMoon Coins: Cargando...\nPets: Cargando..."
    StatusText.TextColor3 = Color3.fromRGB(200, 200, 255)
    StatusText.TextSize = 13
    StatusText.Font = Enum.Font.GothamMedium
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    StatusText.TextYAlignment = Enum.TextYAlignment.Top
    StatusText.Parent = StatusFrame
    
    currentY = currentY + 90
    
    -- Actualizar stats cada segundo
    spawn(function()
        while true do
            local coinsValue = leaderstats:FindFirstChild("💰 Coins")
            local moonCoinsValue = leaderstats:FindFirstChild("🌑 Moon Coins")
            local petsValue = leaderstats:FindFirstChild("🐾 Pets")
            
            local text = ""
            if coinsValue then
                text = text .. "💰 Coins: " .. FormatNumber(coinsValue.Value) .. "\n"
            end
            if moonCoinsValue then
                text = text .. "🌑 Moon Coins: " .. FormatNumber(moonCoinsValue.Value) .. "\n"
            end
            if petsValue then
                text = text .. "🐾 Pets: " .. tostring(petsValue.Value)
            end
            
            StatusText.Text = text
            wait(1)
        end
    end)
    
    return StatusFrame
end

-- ════════════════════════════════════════════════════════════
-- CONSTRUIR INTERFAZ
-- ════════════════════════════════════════════════════════════

-- Status Display
CreateStatusDisplay()

-- STATS MANAGER
CreateSection("STATS MANAGER", "📊")

CreateButton("💰 Max Coins", Color3.fromRGB(255, 200, 50), function()
    ModifyCoins(CONFIG.Stats.Coins)
end)

CreateButton("🌑 Max Moon Coins", Color3.fromRGB(100, 100, 200), function()
    ModifyMoonCoins(CONFIG.Stats.MoonCoins)
end)

CreateButton("🐾 Max Pets Count", Color3.fromRGB(150, 100, 200), function()
    ModifyPetsCount(CONFIG.Stats.PetsCount)
end)

CreateButton("⭐ Max Pet Stats", Color3.fromRGB(255, 150, 50), function()
    ModifyPetStats(CONFIG.Stats.PetLevel, CONFIG.Stats.PetPower)
end)

CreateButton("⚡ MODIFICAR TODO", Color3.fromRGB(50, 200, 100), function()
    ModifyCoins(CONFIG.Stats.Coins)
    wait(0.1)
    ModifyMoonCoins(CONFIG.Stats.MoonCoins)
    wait(0.1)
    ModifyPetsCount(CONFIG.Stats.PetsCount)
    wait(0.1)
    ModifyPetStats(CONFIG.Stats.PetLevel, CONFIG.Stats.PetPower)
end)

-- GAMEPASSES
CreateSection("GAMEPASSES", "🎮")

CreateButton("♾️ Infinite Pets", Color3.fromRGB(100, 150, 255), function()
    ModifyPetsCount(999)
    CONFIG.GamePasses.InfinitePets = true
end)

CreateButton("⚡ 3x Speed", Color3.fromRGB(255, 100, 100), function()
    CONFIG.GamePasses.TripleSpeed = true
    CONFIG.AutoFarm.Interval = 0.16
end)

CreateButton("🔓 Unlock All", Color3.fromRGB(200, 100, 255), function()
    ModifyPetsCount(999)
    CONFIG.GamePasses.InfinitePets = true
    CONFIG.GamePasses.TripleSpeed = true
    CONFIG.AutoFarm.Interval = 0.16
end)

-- AUTO-FARM
CreateSection("AUTO-FARM", "🤖")

CreateToggle("Auto Collect Coins", false, function(state)
    if state then
        StartAutoFarm()
    else
        StopAutoFarm()
    end
end)

CreateButton("▶️ Start Farm", Color3.fromRGB(50, 200, 100), function()
    StartAutoFarm()
end)

CreateButton("⏸️ Stop Farm", Color3.fromRGB(220, 50, 50), function()
    StopAutoFarm()
end)

-- ════════════════════════════════════════════════════════════
-- BOTÓN CERRAR Y TOGGLE
-- ════════════════════════════════════════════════════════════

CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Toggle con tecla (Right Control)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- ════════════════════════════════════════════════════════════
-- ANIMACIÓN DE ENTRADA
-- ════════════════════════════════════════════════════════════

MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

ScreenGui.Parent = playerGui

TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 550, 0, 650),
    Position = UDim2.new(0.5, -275, 0.5, -325)
}):Play()

-- ════════════════════════════════════════════════════════════
-- COMANDOS GLOBALES
-- ════════════════════════════════════════════════════════════

_G.ToggleGUI = function()
    MainFrame.Visible = not MainFrame.Visible
end

print("✅ GUI Cargada - Presiona Right Control para abrir/cerrar")
print("📝 Comando: ToggleGUI() para toggle manual")
