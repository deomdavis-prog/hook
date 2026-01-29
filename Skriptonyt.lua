--[[
    SISTEMA DE AUDITORÍA DE METATABLES - EDICIÓN PET SIMULATOR 1 (ORIGINAL)
    Optimizado para Delta Mobile / Luau de BIG Games
    
    Este sistema está diseñado para auditar la seguridad de las metatables en Pet Simulator 1,
    enfocándose en los módulos de Library, Network y Database que el juego utiliza.
    
    Funcionalidades:
    - Escaneo de módulos específicos de PS1 (Library, Network, Functions).
    - Bypass de __metatable lock (getrawmetatable).
    - Desbloqueo de tablas protegidas (setreadonly).
    - GUI Interactiva con diseño adaptado a móviles.
    - Función "Copy All" para extraer el dump completo.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- APIs de Executor (Delta/Mobile)
local getrawmetatable = getrawmetatable or (debug and debug.getmetatable)
local setreadonly = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local setclipboard = setclipboard or print

-- Configuración de la GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS1_Auditor_Delta"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Parent = ScreenGui
Main.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Main.BorderSizePixel = 0
Main.Position = UDim2.new(0.5, -160, 0.5, -200)
Main.Size = UDim2.new(0, 320, 0, 400)
Main.Active = true
Main.Draggable = true

-- Esquinas redondeadas para estilo moderno
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Parent = Main
TopBar.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
TopBar.Size = UDim2.new(1, 0, 0, 40)

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 10)
TopCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Parent = TopBar
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "PS1 METATABLE AUDITOR"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local Close = Instance.new("TextButton")
Close.Parent = TopBar
Close.Position = UDim2.new(1, -35, 0, 7)
Close.Size = UDim2.new(0, 25, 0, 25)
Close.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
Close.Text = "X"
Close.TextColor3 = Color3.fromRGB(255, 255, 255)
Close.Font = Enum.Font.GothamBold
Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 5)

local Content = Instance.new("ScrollingFrame")
Content.Parent = Main
Content.Position = UDim2.new(0, 10, 0, 50)
Content.Size = UDim2.new(1, -20, 1, -130)
Content.BackgroundTransparency = 1
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.ScrollBarThickness = 4

local UIList = Instance.new("UIListLayout")
UIList.Parent = Content
UIList.Padding = UDim.new(0, 5)

local Controls = Instance.new("Frame")
Controls.Parent = Main
Controls.Position = UDim2.new(0, 10, 1, -75)
Controls.Size = UDim2.new(1, -20, 0, 65)
Controls.BackgroundTransparency = 1

local ScanBtn = Instance.new("TextButton")
ScanBtn.Parent = Controls
ScanBtn.Size = UDim2.new(0.48, 0, 0, 35)
ScanBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
ScanBtn.Text = "SCAN PS1"
ScanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", ScanBtn).CornerRadius = UDim.new(0, 8)

local CopyBtn = Instance.new("TextButton")
CopyBtn.Parent = Controls
CopyBtn.Position = UDim2.new(0.52, 0, 0, 0)
CopyBtn.Size = UDim2.new(0.48, 0, 0, 35)
CopyBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
CopyBtn.Text = "COPY ALL"
CopyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 8)

local Status = Instance.new("TextLabel")
Status.Parent = Controls
Status.Position = UDim2.new(0, 0, 0, 40)
Status.Size = UDim2.new(1, 0, 0, 20)
Status.BackgroundTransparency = 1
Status.Text = "Listo para auditar Pet Simulator!"
Status.TextColor3 = Color3.fromRGB(180, 180, 180)
Status.TextSize = 12
Status.Font = Enum.Font.Gotham

-- Lógica de Auditoría
local full_dump = ""

local function serialize(t, depth)
    depth = depth or 0
    if depth > 2 then return "{ ... }" end
    local s = "{\n"
    local indent = string.rep("  ", depth + 1)
    for k, v in pairs(t) do
        local key = tostring(k)
        local val = ""
        if type(v) == "table" then
            val = serialize(v, depth + 1)
        elseif type(v) == "function" then
            val = "function()"
        else
            val = tostring(v) .. " (" .. type(v) .. ")"
        end
        s = s .. indent .. "[" .. key .. "] = " .. val .. ",\n"
    end
    return s .. string.rep("  ", depth) .. "}"
end

local function addEntry(name, data)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 45)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    frame.Parent = Content
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 5)
    
    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "MT: " .. name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    
    full_dump = full_dump .. "\n--- " .. name .. " ---\n" .. data .. "\n"
    Content.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
end

local function audit(obj, name)
    if not obj then return end
    local mt = getrawmetatable(obj)
    if mt then
        if mt.__metatable then
            pcall(function()
                if setreadonly then setreadonly(mt, false) end
            end)
        end
        addEntry(name, serialize(mt))
    end
end

ScanBtn.MouseButton1Click:Connect(function()
    for _, v in pairs(Content:GetChildren()) do
        if v:IsA("Frame") then v:Destroy() end
    end
    full_dump = ""
    Status.Text = "Escaneando módulos de PS1..."
    
    -- 1. Auditar el objeto Game y Workspace
    audit(game, "Game")
    audit(workspace, "Workspace")
    
    -- 2. Buscar módulos específicos de Pet Simulator 1
    -- En PS1, BIG Games suele usar un módulo central llamado 'Library'
    local library = ReplicatedStorage:FindFirstChild("Library")
    if library then
        Status.Text = "Auditando Library..."
        for _, m in pairs(library:GetDescendants()) do
            if m:IsA("ModuleScript") then
                local success, result = pcall(require, m)
                if success and type(result) == "table" then
                    audit(result, "Mod: " .. m.Name)
                end
            end
        end
    end
    
    -- 3. Buscar módulos de Network
    local network = ReplicatedStorage:FindFirstChild("Network")
    if network then
        audit(network, "Network Folder")
    end
    
    Status.Text = "Auditoría de PS1 completada."
end)

CopyBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard(full_dump)
        Status.Text = "¡Todo copiado al portapapeles!"
    else
        Status.Text = "Error: setclipboard no disponible."
    end
end)
