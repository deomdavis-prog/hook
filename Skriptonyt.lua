--[[
    SISTEMA DE AUDITORÍA DE METATABLES - VERSIÓN FINAL CODIFICADA
    Optimizado para: Pet Simulator 1 (BIG Games)
    Plataforma: Delta Mobile (Luau)
    
    Este sistema implementa:
    - Infiltración del Registro de Luau (Bypass de Proxies Locked).
    - Desofuscación Dinámica de Funciones y Claves.
    - Extracción Recursiva de Upvalues y Constantes.
    - GUI Interactiva con función "Copy All".
]]

-- Servicios de Roblox
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- APIs de Nivel Bajo (Compatibilidad con Delta)
local getrawmetatable = getrawmetatable or (debug and debug.getmetatable)
local setreadonly = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local getupvalues = debug.getupvalues or getupvalues
local getreg = debug.getregistry or getreg
local getconstants = debug.getconstants or getconstants
local setclipboard = setclipboard or print

-- Diccionario de Traducción (Desofuscación)
local DEOBFUSCATION_MAP = {
    ["InvokeServer"] = "Invoke",
    ["FireServer"] = "Fire",
    ["GetPetData"] = "GetPetData",
    ["GetSave"] = "GetSave",
    ["_index"] = "__index",
    ["_namecall"] = "__namecall",
    ["_metatable"] = "__metatable"
}

-- Configuración de la Interfaz Gráfica
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "PS1_Auditor_Final"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 360, 0, 480)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 15)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 50)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Title.Text = "PS1 METATABLE AUDITOR"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.Code
Title.TextSize = 14
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 15)

local LogContainer = Instance.new("ScrollingFrame", MainFrame)
LogContainer.Size = UDim2.new(1, -20, 1, -160)
LogContainer.Position = UDim2.new(0, 10, 0, 60)
LogContainer.BackgroundTransparency = 1
LogContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
LogContainer.ScrollBarThickness = 2

local UIList = Instance.new("UIListLayout", LogContainer)
UIList.Padding = UDim.new(0, 5)

local StatusLabel = Instance.new("TextLabel", MainFrame)
StatusLabel.Size = UDim2.new(1, -20, 0, 20)
StatusLabel.Position = UDim2.new(0, 10, 1, -100)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Estado: Listo para auditar"
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
StatusLabel.TextSize = 11

local CopyButton = Instance.new("TextButton", MainFrame)
CopyButton.Size = UDim2.new(0.45, 0, 0, 45)
CopyButton.Position = UDim2.new(0.05, 0, 1, -70)
CopyButton.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
CopyButton.Text = "COPY ALL"
CopyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyButton.Font = Enum.Font.GothamBold
Instance.new("UICorner", CopyButton).CornerRadius = UDim.new(0, 10)

local AuditButton = Instance.new("TextButton", MainFrame)
AuditButton.Size = UDim2.new(0.45, 0, 0, 45)
AuditButton.Position = UDim2.new(0.5, 0, 1, -70)
AuditButton.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
AuditButton.Text = "DEEP AUDIT"
AuditButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AuditButton.Font = Enum.Font.GothamBold
Instance.new("UICorner", AuditButton).CornerRadius = UDim.new(0, 10)

-- Motor de Serialización y Desofuscación
local function deep_serialize(val, depth, seen)
    depth = depth or 0
    seen = seen or {}
    
    if type(val) == "string" then return "'" .. val .. "'" end
    if type(val) == "number" or type(val) == "boolean" then return tostring(val) end
    
    if type(val) == "table" then
        if depth > 2 then return "{...}" end
        if seen[val] then return "{CIRCULAR}" end
        seen[val] = true
        
        local result = "{\n"
        local indent = string.rep("  ", depth + 1)
        
        pcall(function() if setreadonly then setreadonly(val, false) end end)
        
        for k, v in pairs(val) do
            local key_name = tostring(k)
            if DEOBFUSCATION_MAP[key_name] then key_name = DEOBFUSCATION_MAP[key_name] end
            
            local ok, res = pcall(function() return deep_serialize(v, depth + 1, seen) end)
            result = result .. indent .. "[" .. key_name .. "] = " .. (ok and res or "ERR") .. ",\n"
        end
        return result .. string.rep("  ", depth) .. "}"
    end
    
    if type(val) == "function" then
        local func_name = "function"
        pcall(function()
            if getconstants then
                for _, c in pairs(getconstants(val)) do
                    if DEOBFUSCATION_MAP[c] then func_name = DEOBFUSCATION_MAP[c] break end
                end
            end
        end)
        return func_name .. "()"
    end
    
    return tostring(val) .. " (" .. type(val) .. ")"
end

local full_dump_text = ""

local function log_entry(name, content)
    local label = Instance.new("TextLabel", LogContainer)
    label.Size = UDim2.new(1, 0, 0, 35)
    label.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    label.Text = " [!] " .. name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Code
    label.TextSize = 10
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)
    
    full_dump_text = full_dump_text .. "\n--- " .. name .. " ---\n" .. content .. "\n"
    LogContainer.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
end

-- Lógica de Auditoría Nuclear
AuditButton.MouseButton1Click:Connect(function()
    for _, v in pairs(LogContainer:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    full_dump_text = ""
    StatusLabel.Text = "Iniciando Auditoría Nuclear..."
    
    -- 1. Escaneo del Registro (Bypass de Proxies)
    local registry = getreg()
    for k, v in pairs(registry) do
        if type(v) == "table" then
            local is_big_games = false
            pcall(function()
                if v.Network or v.Library or v.GetPetData or v.InvokeServer then is_big_games = true end
            end)
            if is_big_games then
                log_entry("Registry_Table_" .. k, deep_serialize(v))
            end
        end
    end
    
    -- 2. Escaneo de Upvalues en Módulos de Library
    local library_folder = ReplicatedStorage:FindFirstChild("Library")
    if library_folder then
        for _, module in pairs(library_folder:GetDescendants()) do
            if module:IsA("ModuleScript") then
                pcall(function()
                    local result = require(module)
                    if type(result) == "table" then
                        for _, func in pairs(result) do
                            if type(func) == "function" then
                                for i, up in pairs(getupvalues(func)) do
                                    if type(up) == "table" then
                                        log_entry(module.Name .. "_UP_" .. i, deep_serialize(up))
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
    
    StatusLabel.Text = "Auditoría Completada."
end)

CopyButton.MouseButton1Click:Connect(function()
    setclipboard(full_dump_text)
    StatusLabel.Text = "¡Dump copiado al portapapeles!"
end)
