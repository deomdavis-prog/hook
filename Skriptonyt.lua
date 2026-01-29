--[[
    SISTEMA DE AUDITORÍA DE METATABLES - NIVEL EXPERTO (VERSIÓN CORREGIDA)
    Optimizado para: Pet Simulator 1 (BIG Games)
    Compatibilidad: Delta Mobile / Luau Avanzado
    
    Correcciones:
    - Fix: HttpService:JSONEncode error (nil index).
    - Mejora: Manejo de Upvalues con pcall para evitar crashes.
    - Mejora: Sistema de serialización robusto para tablas circulares.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService") -- Asegurado

-- APIs de Nivel Bajo
local getrawmetatable = getrawmetatable or (debug and debug.getmetatable)
local setreadonly = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local getupvalues = debug.getupvalues or getupvalues
local getupvalue = debug.getupvalue or getupvalue

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Expert_Auditor_V2"
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 350, 0, 450)
Main.Position = UDim2.new(0.5, -175, 0.5, -225)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Title.Text = "PS1 METATABLE UNPACKER V2"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.Code
Title.TextSize = 14
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 10)

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(1, -20, 1, -130)
LogScroll.Position = UDim2.new(0, 10, 0, 50)
LogScroll.BackgroundTransparency = 1
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.ScrollBarThickness = 2
LogScroll.Parent = Main

local UIList = Instance.new("UIListLayout")
UIList.Parent = LogScroll
UIList.Padding = UDim.new(0, 5)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 20)
Status.Position = UDim2.new(0, 10, 1, -75)
Status.BackgroundTransparency = 1
Status.Text = "Sistema listo."
Status.TextColor3 = Color3.fromRGB(0, 255, 150)
Status.TextSize = 12
Status.Parent = Main

local CopyAll = Instance.new("TextButton")
CopyAll.Size = UDim2.new(0.45, 0, 0, 35)
CopyAll.Position = UDim2.new(0.05, 0, 1, -45)
CopyAll.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
CopyAll.Text = "COPY ALL"
CopyAll.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyAll.Font = Enum.Font.GothamBold
CopyAll.Parent = Main
Instance.new("UICorner", CopyAll).CornerRadius = UDim.new(0, 8)

local DeepScan = Instance.new("TextButton")
DeepScan.Size = UDim2.new(0.45, 0, 0, 35)
DeepScan.Position = UDim2.new(0.5, 0, 1, -45)
DeepScan.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
DeepScan.Text = "DEEP SCAN"
DeepScan.TextColor3 = Color3.fromRGB(255, 255, 255)
DeepScan.Font = Enum.Font.GothamBold
DeepScan.Parent = Main
Instance.new("UICorner", DeepScan).CornerRadius = UDim.new(0, 8)

-- Lógica de Extracción Reforzada
local full_dump = ""

local function safe_serialize(t, depth, seen)
    seen = seen or {}
    depth = depth or 0
    if depth > 3 then return "{ ...MAX DEPTH... }" end
    if seen[t] then return "{ ...CIRCULAR... }" end
    seen[t] = true
    
    local s = "{\n"
    local indent = string.rep("  ", depth + 1)
    
    pcall(function()
        if setreadonly then setreadonly(t, false) end
    end)
    
    for k, v in pairs(t) do
        local key = tostring(k)
        local val = ""
        if type(v) == "table" then
            val = safe_serialize(v, depth + 1, seen)
        elseif type(v) == "function" then
            local ups = {}
            pcall(function()
                local u = getupvalues(v)
                for i, up in pairs(u) do
                    ups[tostring(i)] = tostring(up) .. " [" .. type(up) .. "]"
                end
            end)
            local up_str = "{}"
            pcall(function() up_str = HttpService:JSONEncode(ups) end)
            val = "function() -- Upvalues: " .. up_str
        else
            val = tostring(v) .. " (" .. type(v) .. ")"
        end
        s = s .. indent .. "[" .. key .. "] = " .. val .. ",\n"
    end
    return s .. string.rep("  ", depth) .. "}"
end

local function addLog(name, content)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    label.Text = " [+] " .. name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.Parent = LogScroll
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 4)
    
    full_dump = full_dump .. "\n[AUDIT: " .. name .. "]\n" .. content .. "\n"
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
end

local function expert_audit(obj, name)
    if not obj then return end
    Status.Text = "Analizando: " .. name
    local mt = getrawmetatable(obj)
    
    if mt then
        -- Intentar bypass de lock buscando en upvalues
        pcall(function()
            for _, func in pairs(mt) do
                if type(func) == "function" then
                    local ups = getupvalues(func)
                    for _, up in pairs(ups) do
                        if type(up) == "table" and up ~= mt then
                            addLog(name .. " (Hidden Data)", safe_serialize(up))
                        end
                    end
                end
            end
        end)
        addLog(name .. " (Raw MT)", safe_serialize(mt))
    else
        addLog(name, "No metatable found.")
    end
end

DeepScan.MouseButton1Click:Connect(function()
    for _, v in pairs(LogScroll:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    full_dump = ""
    Status.Text = "Iniciando Deep Scan..."
    
    -- Escaneo de Sistema
    expert_audit(game, "Game")
    expert_audit(workspace, "Workspace")
    
    -- Escaneo de PS1 Library
    local lib = ReplicatedStorage:FindFirstChild("Library")
    if lib then
        for _, m in pairs(lib:GetDescendants()) do
            if m:IsA("ModuleScript") then
                local success, result = pcall(require, m)
                if success and type(result) == "table" then
                    expert_audit(result, "Module: " .. m.Name)
                end
            end
        end
    end
    
    Status.Text = "Deep Scan Finalizado."
end)

CopyAll.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard(full_dump)
        Status.Text = "Dump copiado al portapapeles."
    else
        Status.Text = "Error: setclipboard no soportado."
    end
end)
