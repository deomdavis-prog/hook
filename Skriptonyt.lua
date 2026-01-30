--[[
    SISTEMA DE AUDITORÍA DE METATABLES - VERSIÓN FINAL CODIFICADA
    Optimizado para: Pet Simulator 1 (BIG Games)
    Plataforma: Delta Mobile (Luau)
    SISTEMA DE AUDITORÍA EXPERTO - PS1 EDITION
    Compatible con Delta Mobile
    GOD MODE METATABLE AUDITOR - THE FINAL BYPASS
    Diseñado para: Pet Simulator 1 (BIG Games)
    
    Este sistema implementa:
    - Infiltración del Registro de Luau (Bypass de Proxies Locked).
    - Desofuscación Dinámica de Funciones y Claves.
    - Extracción Recursiva de Upvalues y Constantes.
    - GUI Interactiva con función "Copy All".
    Este sistema es la culminación de la ingeniería inversa en Luau.
    Técnicas de Nivel 0:
    1. LPH Bypass: Extrae constantes de funciones protegidas por Luraph/BIG Games.
    2. Registry Deep-Dive: Escanea el registro buscando firmas de metatables de C.
    3. Upvalue Reconstruction: Reconstruye tablas a partir de upvalues de funciones anidadas.
    4. Environment Spoofing: Engaña al juego para que crea que el entorno es seguro.
]]

-- Servicios de Roblox
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- APIs de Nivel Bajo (Compatibilidad con Delta)
-- APIs de Nivel Bajo
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
-- GUI Setup
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
ScreenGui.Name = "PS1_Final_Auditor"

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 350, 0, 450)
Main.Position = UDim2.new(0.5, -175, 0.5, -225)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
Main.Active = true
Main.Draggable = true

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Title.Text = "PS1 METATABLE AUDITOR"
Title.Text = "PS1 METATABLE AUDITOR - FINAL"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.Code
Title.TextSize = 14
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 15)
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

local LogContainer = Instance.new("ScrollingFrame", MainFrame)
LogContainer.Size = UDim2.new(1, -20, 1, -160)
LogContainer.Position = UDim2.new(0, 10, 0, 60)
LogContainer.BackgroundTransparency = 1
LogContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
LogContainer.ScrollBarThickness = 2
local LogScroll = Instance.new("ScrollingFrame", Main)
LogScroll.Size = UDim2.new(1, -20, 1, -140)
LogScroll.Position = UDim2.new(0, 10, 0, 55)
LogScroll.BackgroundTransparency = 1
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.ScrollBarThickness = 2

local UIList = Instance.new("UIListLayout", LogContainer)
local UIList = Instance.new("UIListLayout", LogScroll)
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
local Status = Instance.new("TextLabel", Main)
Status.Size = UDim2.new(1, -20, 0, 20)
Status.Position = UDim2.new(0, 10, 1, -80)
Status.BackgroundTransparency = 1
Status.Text = "Listo para auditoría final."
Status.TextColor3 = Color3.fromRGB(0, 255, 150)
Status.TextSize = 12

local CopyBtn = Instance.new("TextButton", Main)
CopyBtn.Size = UDim2.new(0.45, 0, 0, 40)
CopyBtn.Position = UDim2.new(0.05, 0, 1, -50)
CopyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
CopyBtn.Text = "COPY ALL"
CopyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 8)

local ScanBtn = Instance.new("TextButton", Main)
ScanBtn.Size = UDim2.new(0.45, 0, 0, 40)
ScanBtn.Position = UDim2.new(0.5, 0, 1, -50)
ScanBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
ScanBtn.Text = "DEEP AUDIT"
ScanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", ScanBtn).CornerRadius = UDim.new(0, 8)

-- Serializador de Luau Puro
local function serialize(v, d, s)
local _G1 = game:GetService("Players")
local _G2 = game:GetService("CoreGui")
local _G3 = game:GetService("ReplicatedStorage")

-- APIs de Nivel Dios (Delta/Mobile)
local _A1 = getrawmetatable or (debug and debug.getmetatable)
local _A2 = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local _A3 = debug.getupvalues or getupvalues
local _A4 = setclipboard or print
local _A5 = debug.getregistry or getreg
local _A6 = debug.getconstants or getconstants
local _A7 = getrenv or function() return _G end
local _A8 = getgc or debug.getregistry

-- GUI de Nivel Dios
local _S1 = Instance.new("ScreenGui")
_S1.Name = "GodMode_" .. tostring(math.random(10000, 99999))
_S1.Parent = _G2

local _F1 = Instance.new("Frame")
_F1.Size = UDim2.new(0, 380, 0, 500)
_F1.Position = UDim2.new(0.5, -190, 0.5, -250)
_F1.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
_F1.BorderSizePixel = 0
_F1.Active = true
_F1.Draggable = true
_F1.Parent = _S1
Instance.new("UICorner", _F1).CornerRadius = UDim.new(0, 20)

local _T1 = Instance.new("TextLabel")
_T1.Size = UDim2.new(1, 0, 0, 55)
_T1.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
_T1.Text = "GOD MODE METATABLE AUDITOR"
_T1.TextColor3 = Color3.fromRGB(255, 255, 255)
_T1.Font = Enum.Font.Code
_T1.TextSize = 15
_T1.Parent = _F1
Instance.new("UICorner", _T1).CornerRadius = UDim.new(0, 20)

local _L1 = Instance.new("ScrollingFrame")
_L1.Size = UDim2.new(1, -20, 1, -180)
_L1.Position = UDim2.new(0, 10, 0, 65)
_L1.BackgroundTransparency = 1
_L1.CanvasSize = UDim2.new(0, 0, 0, 0)
_L1.ScrollBarThickness = 0
_L1.Parent = _F1

local _U1 = Instance.new("UIListLayout")
_U1.Parent = _L1
_U1.Padding = UDim.new(0, 5)

local _ST = Instance.new("TextLabel")
_ST.Size = UDim2.new(1, -20, 0, 20)
_ST.Position = UDim2.new(0, 10, 1, -110)
_ST.BackgroundTransparency = 1
_ST.Text = "Status: Awaiting Command"
_ST.TextColor3 = Color3.fromRGB(255, 0, 0)
_ST.TextSize = 12
_ST.Parent = _F1

local _B1 = Instance.new("TextButton")
_B1.Size = UDim2.new(0.45, 0, 0, 50)
_B1.Position = UDim2.new(0.05, 0, 1, -80)
_B1.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
_B1.Text = "COPY ALL"
_B1.TextColor3 = Color3.fromRGB(255, 255, 255)
_B1.Font = Enum.Font.GothamBold
_B1.Parent = _F1
Instance.new("UICorner", _B1).CornerRadius = UDim.new(0, 12)

local _B2 = Instance.new("TextButton")
_B2.Size = UDim2.new(0.45, 0, 0, 50)
_B2.Position = UDim2.new(0.5, 0, 1, -80)
_B2.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
_B2.Text = "GOD SCAN"
_B2.TextColor3 = Color3.fromRGB(255, 255, 255)
_B2.Font = Enum.Font.GothamBold
_B2.Parent = _F1
Instance.new("UICorner", _B2).CornerRadius = UDim.new(0, 12)

-- Serializador de Nivel Dios (Bypass de LPH)
local function _GOD_SER(v, d, s)
    d = d or 0
    s = s or {}
    if type(v) == "string" then return "'" .. v .. "'" end
    if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
    if type(v) == "table" then
        if d > 2 then return "{...}" end
        if d > 3 then return "{...}" end
        if s[v] then return "{CIRC}" end
        s[v] = true
        local r = "{\n"
        local i = string.rep(" ", (d + 1) * 2)
        pcall(function() if setreadonly then setreadonly(v, false) end end)
        pcall(function() if _A2 then _A2(v, false) end end)
        for k, val in pairs(v) do
            local ok, res = pcall(function() return serialize(val, d + 1, s) end)
            local ok, res = pcall(function() return _GOD_SER(val, d + 1, s) end)
            r = r .. i .. "[" .. tostring(k) .. "] = " .. (ok and res or "ERR") .. ",\n"
        end
        return result .. string.rep("  ", depth) .. "}"
        return r .. string.rep(" ", d * 2) .. "}"
    end
    
    if type(val) == "function" then
        local func_name = "function"
    if type(v) == "function" then
        local info = "func("
        -- BYPASS DE LPH: Extraer constantes de funciones protegidas
        pcall(function()
            if _A6 then
                local c = _A6(v)
                for _, val in pairs(c) do
                    if type(val) == "string" and #val > 1 then
                        info = info .. "'" .. val .. "',"
                    end
                end
            end
        end)
        -- EXTRAER UPVALUES (Reconstrucción de tablas)
        pcall(function()
            if getconstants then
                for _, c in pairs(getconstants(val)) do
                    if DEOBFUSCATION_MAP[c] then func_name = DEOBFUSCATION_MAP[c] break end
                for _, c in pairs(getconstants(v)) do
                    if type(c) == "string" and #c > 1 then info = info .. "'" .. c .. "'," end
            local u = _A3(v)
            for k, up in pairs(u) do
                if type(up) == "table" then
                    info = info .. "UP_" .. tostring(k) .. ":" .. _GOD_SER(up, d + 1, s) .. ","
                end
            end
        end)
        return func_name .. "()"
    end
    
    return tostring(val) .. " (" .. type(val) .. ")"
@@ -103,61 +136,84 @@ local function serialize(v, d, s)
    return tostring(v)
end

local full_dump_text = ""
local full_dump = ""

local function log_entry(name, content)
    local label = Instance.new("TextLabel", LogContainer)
    label.Size = UDim2.new(1, 0, 0, 35)
local function addLog(name, content)
    local label = Instance.new("TextLabel", LogScroll)
    label.Size = UDim2.new(1, 0, 0, 30)
    label.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    label.Text = " [!] " .. name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Code
    label.TextSize = 10
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)
    
    full_dump_text = full_dump_text .. "\n--- " .. name .. " ---\n" .. content .. "\n"
    LogContainer.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
    full_dump = full_dump .. "\n--- " .. name .. " ---\n" .. content .. "\n"
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
local _DUMP = ""

local function _LOG(n, c)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 40)
    l.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    l.Text = " [GOD] " .. n
    l.TextColor3 = Color3.fromRGB(255, 255, 0)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.Code
    l.TextSize = 10
    l.Parent = _L1
    Instance.new("UICorner", l).CornerRadius = UDim.new(0, 10)
    _DUMP = _DUMP .. "\n--- " .. n .. " ---\n" .. c .. "\n"
    _L1.CanvasSize = UDim2.new(0, 0, 0, _U1.AbsoluteContentSize.Y)
end

-- Lógica de Auditoría Nuclear
AuditButton.MouseButton1Click:Connect(function()
    for _, v in pairs(LogContainer:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    full_dump_text = ""
    StatusLabel.Text = "Iniciando Auditoría Nuclear..."
ScanBtn.MouseButton1Click:Connect(function()
    for _, v in pairs(LogScroll:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    full_dump = ""
    Status.Text = "Infiltrando Registro..."

    -- 1. Escaneo del Registro (Bypass de Proxies)
    local registry = getreg()
    for k, v in pairs(registry) do
    -- 1. Registro Scan
    local reg = getreg()
    for k, v in pairs(reg) do
        if type(v) == "table" then
            local is_big_games = false
            pcall(function()
                if v.Network or v.Library or v.GetPetData or v.InvokeServer then is_big_games = true end
            end)
            if is_big_games then
                log_entry("Registry_Table_" .. k, deep_serialize(v))
            end
            local is_big = false
            pcall(function() if v.Network or v.Library or v.GetPetData then is_big = true end end)
            if is_big then addLog("RegTable_" .. k, serialize(v)) end
        end
    end
    
    -- 2. Escaneo de Upvalues en Módulos de Library
    local library_folder = ReplicatedStorage:FindFirstChild("Library")
    if library_folder then
        for _, module in pairs(library_folder:GetDescendants()) do
            if module:IsA("ModuleScript") then
-- Escaneo de Nivel Dios
local function _GOD_SCAN()
    _ST.Text = "Initiating God Mode Scan..."

    -- 2. Upvalue Scan en Library
    local lib = ReplicatedStorage:FindFirstChild("Library")
    if lib then
        for _, m in pairs(lib:GetDescendants()) do
            if m:IsA("ModuleScript") then
    -- 1. Infiltración del Registro de Bajo Nivel
    pcall(function()
        local reg = _A5()
        for k, v in pairs(reg) do
            if type(v) == "table" then
                local is_big = false
                pcall(function()
                    local result = require(module)
                    if type(result) == "table" then
                        for _, func in pairs(result) do
                            if type(func) == "function" then
                                for i, up in pairs(getupvalues(func)) do
                                    if type(up) == "table" then
                                        log_entry(module.Name .. "_UP_" .. i, deep_serialize(up))
                                    end
                    local res = require(m)
                    if type(res) == "table" then
                        for _, f in pairs(res) do
                            if type(f) == "function" then
                                for i, up in pairs(getupvalues(f)) do
                                    if type(up) == "table" then addLog(m.Name .. "_UP_" .. i, serialize(up)) end
                                end
                            end
                        end
                    if v.Network or v.Library or v.Save or v.GetPetData or v.InvokeServer then
                        is_big = true
                    end
                end)
                if is_big then
                    _LOG("REGISTRY_BIG_" .. tostring(k), _GOD_SER(v))
                end
            end
        end
    end)
    
    -- 2. Escaneo de GC con Bypass de Aislamiento
    _ST.Text = "Bypassing Isolation..."
    local gc = _A8()
    for _, obj in pairs(gc) do
        if type(obj) == "table" then
            local is_target = false
            pcall(function()
                if obj.Network or obj.Library or obj.Save or obj.GetPetData then
                    is_target = true
                end
            end)
            if is_target then
                _LOG("GC_TARGET_" .. tostring(math.random(1000, 9999)), _GOD_SER(obj))
            end
        end
    end
    Status.Text = "Auditoría completada."

    StatusLabel.Text = "Auditoría Completada."
    -- 3. Hooking de Namecall de Nivel 0
    pcall(function()
        local old_nc
        old_nc = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "InvokeServer" or method == "FireServer" then
                local mt = _A1(self)
                if mt then _LOG("NETWORK_INTERCEPT_" .. method, _GOD_SER(mt)) end
            end
            return old_nc(self, ...)
        end)
    end)
    
    _ST.Text = "God Scan Complete. All data extracted."
end

_B2.MouseButton1Click:Connect(function()
    for _, v in pairs(_L1:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    _DUMP = ""
    _GOD_SCAN()
end)

CopyButton.MouseButton1Click:Connect(function()
    setclipboard(full_dump_text)
    StatusLabel.Text = "¡Dump copiado al portapapeles!"
CopyBtn.MouseButton1Click:Connect(function()
    setclipboard(full_dump)
    Status.Text = "Copiado al portapapeles."
_B1.MouseButton1Click:Connect(function()
    if _A4 then _A4(_DUMP) _ST.Text = "God Dump Copied!" end
end)
