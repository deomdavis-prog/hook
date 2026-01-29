--[[
    SISTEMA DE AUDITORÍA DE METATABLES - NIVEL EXPERTO (ZERO DEPENDENCIES)
    Optimizado para: Pet Simulator 1 (BIG Games)
    Compatibilidad: Delta Mobile / Luau Avanzado
    
    CAMBIOS CRÍTICOS:
    - Eliminado HttpService:JSONEncode por completo (Causa de errores nil).
    - Implementado Serializador de Luau Puro para Upvalues y Tablas.
    - Protección total con pcall en cada iteración.
    - Bypass de proxies mediante inspección de closures.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- APIs de Nivel Bajo (Delta/Mobile)
local getrawmetatable = getrawmetatable or (debug and debug.getmetatable)
local setreadonly = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local getupvalues = debug.getupvalues or getupvalues
local setclipboard = setclipboard or print

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Expert_Auditor_Final"
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 350, 0, 450)
Main.Position = UDim2.new(0.5, -175, 0.5, -225)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
Title.Text = "PS1 UNPACKER - ZERO DEP"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.Code
Title.TextSize = 14
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(1, -20, 1, -140)
LogScroll.Position = UDim2.new(0, 10, 0, 55)
LogScroll.BackgroundTransparency = 1
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.ScrollBarThickness = 2
LogScroll.Parent = Main

local UIList = Instance.new("UIListLayout")
UIList.Parent = LogScroll
UIList.Padding = UDim.new(0, 5)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 20)
Status.Position = UDim2.new(0, 10, 1, -80)
Status.BackgroundTransparency = 1
Status.Text = "Esperando Deep Scan..."
Status.TextColor3 = Color3.fromRGB(0, 200, 255)
Status.TextSize = 12
Status.Parent = Main

local CopyAll = Instance.new("TextButton")
CopyAll.Size = UDim2.new(0.45, 0, 0, 40)
CopyAll.Position = UDim2.new(0.05, 0, 1, -50)
CopyAll.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
CopyAll.Text = "COPY ALL"
CopyAll.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyAll.Font = Enum.Font.GothamBold
CopyAll.Parent = Main
Instance.new("UICorner", CopyAll).CornerRadius = UDim.new(0, 8)

local DeepScan = Instance.new("TextButton")
DeepScan.Size = UDim2.new(0.45, 0, 0, 40)
DeepScan.Position = UDim2.new(0.5, 0, 1, -50)
DeepScan.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
DeepScan.Text = "DEEP SCAN"
DeepScan.TextColor3 = Color3.fromRGB(255, 255, 255)
DeepScan.Font = Enum.Font.GothamBold
DeepScan.Parent = Main
Instance.new("UICorner", DeepScan).CornerRadius = UDim.new(0, 8)

-- Serializador de Luau Puro (Sin dependencias de HttpService)
local function custom_serialize(val, depth, seen)
    depth = depth or 0
    seen = seen or {}
    
    if type(val) == "string" then return '"' .. val .. '"' end
    if type(val) == "number" or type(val) == "boolean" then return tostring(val) end
    if type(val) == "nil" then return "nil" end
    
    if type(val) == "table" then
        if depth > 2 then return "{ ...MAX DEPTH... }" end
        if seen[val] then return "{ ...CIRCULAR... }" end
        seen[val] = true
        
        local s = "{\n"
        local indent = string.rep("  ", depth + 1)
        
        pcall(function()
            if setreadonly then setreadonly(val, false) end
        end)
        
        for k, v in pairs(val) do
            local key = tostring(k)
            local success, result = pcall(function() return custom_serialize(v, depth + 1, seen) end)
            s = s .. indent .. "[" .. key .. "] = " .. (success and result or "Error") .. ",\n"
        end
        return s .. string.rep("  ", depth) .. "}"
    end
    
    if type(val) == "function" then
        local up_info = "function() -- Upvalues: {"
        pcall(function()
            local ups = getupvalues(val)
            for i, up in pairs(ups) do
                up_info = up_info .. tostring(i) .. ": " .. type(up) .. ", "
            end
        end)
        return up_info .. "}"
    end
    
    return tostring(val) .. " (" .. type(val) .. ")"
end

local full_dump = ""

local function addLog(name, content)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 30)
    label.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    label.Text = " [!] " .. name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.Parent = LogScroll
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
    
    full_dump = full_dump .. "\n[AUDIT: " .. name .. "]\n" .. content .. "\n"
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
end

local function expert_audit(obj, name)
    if not obj then return end
    Status.Text = "Escaneando: " .. name
    
    local mt = nil
    pcall(function() mt = getrawmetatable(obj) end)
    
    if mt then
        -- Buscar en Upvalues de metamétodos
        pcall(function()
            for _, func in pairs(mt) do
                if type(func) == "function" then
                    local ups = getupvalues(func)
                    for _, up in pairs(ups) do
                        if type(up) == "table" and up ~= mt then
                            addLog(name .. " (Hidden Data)", custom_serialize(up))
                        end
                    end
                end
            end
        end)
        addLog(name .. " (Raw MT)", custom_serialize(mt))
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
    end
end)
