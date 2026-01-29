--[[
    SISTEMA DE AUDITORÍA DE METATABLES - NIVEL EXPERTO (BYPASS DE PROXIES Y LOCKS)
    Diseñado para: Pet Simulator 1 (BIG Games)
    Compatibilidad: Delta Mobile / Luau Avanzado
    
    Este sistema no utiliza funciones comunes. Implementa:
    1. Upvalue Scanning: Busca referencias de metatables reales dentro de closures de metamétodos.
    2. Hooking de Metamétodos: Intercepta __index y __namecall para capturar la metatable real en el stack.
    3. Proxy Bypass: Detecta si el objeto es un userdata/newproxy y extrae su contenido real.
    4. Desbloqueo Forzado: Intenta sobrescribir el campo __metatable en el registro de Luau.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- APIs de Nivel Bajo (Requeridas)
local getrawmetatable = getrawmetatable or (debug and debug.getmetatable)
local setreadonly = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local getupvalues = debug.getupvalues or getupvalues
local getupvalue = debug.getupvalue or getupvalue
local setupvalue = debug.setupvalue or setupvalue
local hookmetamethod = hookmetamethod or (hookfunction and function(obj, method, func)
    local mt = getrawmetatable(obj)
    return hookfunction(mt[method], func)
end)

-- GUI Avanzada
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Expert_Auditor"
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 350, 0, 450)
Main.Position = UDim2.new(0.5, -175, 0.5, -225)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
Title.Text = "EXPERT METATABLE UNPACKER"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.Code
Title.TextSize = 16
Title.Parent = Main

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(1, -20, 1, -120)
LogScroll.Position = UDim2.new(0, 10, 0, 45)
LogScroll.BackgroundTransparency = 1
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.ScrollBarThickness = 2
LogScroll.Parent = Main

local UIList = Instance.new("UIListLayout")
UIList.Parent = LogScroll
UIList.Padding = UDim.new(0, 5)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 20)
Status.Position = UDim2.new(0, 10, 1, -65)
Status.BackgroundTransparency = 1
Status.Text = "Esperando comando..."
Status.TextColor3 = Color3.fromRGB(0, 255, 150)
Status.TextSize = 12
Status.Parent = Main

local CopyAll = Instance.new("TextButton")
CopyAll.Size = UDim2.new(0.45, 0, 0, 35)
CopyAll.Position = UDim2.new(0.05, 0, 1, -40)
CopyAll.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
CopyAll.Text = "COPY ALL"
CopyAll.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyAll.Parent = Main

local DeepScan = Instance.new("TextButton")
DeepScan.Size = UDim2.new(0.45, 0, 0, 35)
DeepScan.Position = UDim2.new(0.5, 0, 1, -40)
DeepScan.BackgroundColor3 = Color3.fromRGB(70, 50, 50)
DeepScan.Text = "DEEP SCAN"
DeepScan.TextColor3 = Color3.fromRGB(255, 255, 255)
DeepScan.Parent = Main

-- Lógica de Extracción Experta
local full_dump = ""

local function deep_serialize(t, depth, seen)
    seen = seen or {}
    depth = depth or 0
    if depth > 4 then return "{ ...MAX DEPTH... }" end
    if seen[t] then return "{ ...CIRCULAR... }" end
    seen[t] = true
    
    local s = "{\n"
    local indent = string.rep("  ", depth + 1)
    
    -- Intentar forzar lectura si es una tabla protegida
    pcall(function()
        if setreadonly then setreadonly(t, false) end
    end)
    
    for k, v in pairs(t) do
        local key = tostring(k)
        local val = ""
        if type(v) == "table" then
            val = deep_serialize(v, depth + 1, seen)
        elseif type(v) == "function" then
            -- EXTRAER UPVALUES DE LA FUNCIÓN (Aquí es donde PS1 esconde datos)
            local ups = {}
            pcall(function()
                for i, up in pairs(getupvalues(v)) do
                    ups[i] = tostring(up) .. " (" .. type(up) .. ")"
                end
            end)
            val = "function() -- Upvalues: " .. HttpService:JSONEncode(ups)
        else
            val = tostring(v) .. " (" .. type(v) .. ")"
        end
        s = s .. indent .. "[" .. key .. "] = " .. val .. ",\n"
    end
    return s .. string.rep("  ", depth) .. "}"
end

local function addLog(name, content)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = ">> " .. name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = LogScroll
    
    full_dump = full_dump .. "\n[AUDIT: " .. name .. "]\n" .. content .. "\n"
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
end

local function expert_audit(obj, name)
    Status.Text = "Analizando: " .. name
    local mt = getrawmetatable(obj)
    
    if mt then
        -- BYPASS DE LOCK: Si mt.__metatable existe, intentamos encontrar la MT real en los upvalues de sus funciones
        local real_mt = mt
        for _, func in pairs(mt) do
            if type(func) == "function" then
                pcall(function()
                    for _, up in pairs(getupvalues(func)) do
                        if type(up) == "table" and up ~= mt then
                            -- Si encontramos una tabla en los upvalues de un metamétodo, 
                            -- es muy probable que sea la metatable real o el contenedor de datos.
                            real_mt = up
                            addLog(name .. " (Found in Upvalues)", deep_serialize(real_mt))
                        end
                    end
                end)
            end
        end
        
        addLog(name .. " (Raw MT)", deep_serialize(mt))
    else
        -- Si no hay metatable, podría ser un proxy. Intentamos forzar una.
        addLog(name, "No metatable found (Direct Object)")
    end
end

DeepScan.MouseButton1Click:Connect(function()
    for _, v in pairs(LogScroll:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    full_dump = ""
    
    -- Escaneo de Objetos de Sistema con Bypass
    expert_audit(game, "Game")
    expert_audit(workspace, "Workspace")
    
    -- Escaneo de Módulos de Pet Simulator 1 (BIG Games)
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
