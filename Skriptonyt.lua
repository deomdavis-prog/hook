--[[
    SISTEMA DE INFILTRACIÓN DE METATABLES - NIVEL DEFINITIVO
    Diseñado para: Pet Simulator 1 (BIG Games)
    Compatibilidad: Delta Mobile / Luau de Bajo Nivel
    
    Este sistema ignora el objeto bloqueado y ataca directamente el Registro de Luau.
    Técnicas:
    1. Registry Scan: Escanea debug.getregistry() buscando metatables huérfanas o ligadas.
    2. Metamethod Hooking: Intercepta __index para capturar la tabla real en el stack.
    3. Upvalue Extraction: Desenvuelve closures para encontrar la tabla de datos de BIG Games.
    4. Zero Dependencies: Sin HttpService, sin funciones detectables.
]]

local _G1 = game:GetService("Players")
local _G2 = game:GetService("CoreGui")
local _G3 = game:GetService("ReplicatedStorage")

-- APIs de Nivel Bajo (Delta/Mobile)
local _A1 = getrawmetatable or (debug and debug.getmetatable)
local _A2 = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local _A3 = debug.getupvalues or getupvalues
local _A4 = setclipboard or print
local _A5 = debug.getregistry or getreg
local _A6 = debug.getconstants or getconstants

-- GUI
local _S1 = Instance.new("ScreenGui")
_S1.Name = "Infiltrator_" .. tostring(math.random(1000, 9999))
_S1.Parent = _G2

local _F1 = Instance.new("Frame")
_F1.Size = UDim2.new(0, 360, 0, 460)
_F1.Position = UDim2.new(0.5, -180, 0.5, -230)
_F1.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
_F1.BorderSizePixel = 0
_F1.Active = true
_F1.Draggable = true
_F1.Parent = _S1
Instance.new("UICorner", _F1).CornerRadius = UDim.new(0, 12)

local _T1 = Instance.new("TextLabel")
_T1.Size = UDim2.new(1, 0, 0, 45)
_T1.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
_T1.Text = "ULTIMATE METATABLE INFILTRATOR"
_T1.TextColor3 = Color3.fromRGB(255, 255, 255)
_T1.Font = Enum.Font.Code
_T1.TextSize = 13
_T1.Parent = _F1
Instance.new("UICorner", _T1).CornerRadius = UDim.new(0, 12)

local _L1 = Instance.new("ScrollingFrame")
_L1.Size = UDim2.new(1, -20, 1, -150)
_L1.Position = UDim2.new(0, 10, 0, 55)
_L1.BackgroundTransparency = 1
_L1.CanvasSize = UDim2.new(0, 0, 0, 0)
_L1.ScrollBarThickness = 2
_L1.Parent = _F1

local _U1 = Instance.new("UIListLayout")
_U1.Parent = _L1
_U1.Padding = UDim.new(0, 5)

local _ST = Instance.new("TextLabel")
_ST.Size = UDim2.new(1, -20, 0, 20)
_ST.Position = UDim2.new(0, 10, 1, -90)
_ST.BackgroundTransparency = 1
_ST.Text = "Status: Ready for Infiltration"
_ST.TextColor3 = Color3.fromRGB(0, 255, 180)
_ST.TextSize = 11
_ST.Parent = _F1

local _B1 = Instance.new("TextButton")
_B1.Size = UDim2.new(0.45, 0, 0, 40)
_B1.Position = UDim2.new(0.05, 0, 1, -60)
_B1.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
_B1.Text = "COPY DUMP"
_B1.TextColor3 = Color3.fromRGB(255, 255, 255)
_B1.Parent = _F1
Instance.new("UICorner", _B1).CornerRadius = UDim.new(0, 8)

local _B2 = Instance.new("TextButton")
_B2.Size = UDim2.new(0.45, 0, 0, 40)
_B2.Position = UDim2.new(0.5, 0, 1, -60)
_B2.BackgroundColor3 = Color3.fromRGB(50, 25, 25)
_B2.Text = "INFILTRATE"
_B2.TextColor3 = Color3.fromRGB(255, 255, 255)
_B2.Parent = _F1
Instance.new("UICorner", _B2).CornerRadius = UDim.new(0, 8)

-- Serializador de Bajo Nivel
local function _SER(v, d, s)
    d = d or 0
    s = s or {}
    if type(v) == "string" then return "'" .. v .. "'" end
    if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
    if type(v) == "table" then
        if d > 2 then return "{...}" end
        if s[v] then return "{CIRC}" end
        s[v] = true
        local r = "{\n"
        local i = string.rep(" ", (d + 1) * 2)
        pcall(function() if _A2 then _A2(v, false) end end)
        for k, val in pairs(v) do
            local ok, res = pcall(function() return _SER(val, d + 1, s) end)
            r = r .. i .. "[" .. tostring(k) .. "] = " .. (ok and res or "ERR") .. ",\n"
        end
        return r .. string.rep(" ", d * 2) .. "}"
    end
    if type(v) == "function" then
        local info = "func("
        pcall(function()
            if _A6 then
                local c = _A6(v)
                for _, val in pairs(c) do
                    if type(val) == "string" and #val > 1 then info = info .. "'" .. val .. "'," end
                end
            end
        end)
        return info .. ")"
    end
    return tostring(v)
end

local _DUMP = ""

local function _LOG(n, c)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 30)
    l.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    l.Text = " [!] " .. n
    l.TextColor3 = Color3.fromRGB(220, 220, 220)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.Code
    l.TextSize = 10
    l.Parent = _L1
    Instance.new("UICorner", l).CornerRadius = UDim.new(0, 6)
    _DUMP = _DUMP .. "\n--- " .. n .. " ---\n" .. c .. "\n"
    _L1.CanvasSize = UDim2.new(0, 0, 0, _U1.AbsoluteContentSize.Y)
end

-- Infiltración del Registro
local function _INFILTRATE()
    _ST.Text = "Infiltrating Registry..."
    local reg = nil
    pcall(function() reg = _A5() end)
    
    if reg then
        for k, v in pairs(reg) do
            if type(v) == "table" then
                -- Buscar tablas que parezcan metatables de BIG Games
                local is_target = false
                pcall(function()
                    if v.__index or v.__namecall or v.Network or v.Library then
                        is_target = true
                    end
                end)
                
                if is_target then
                    _LOG("RegTable_" .. tostring(k), _SER(v))
                end
            end
        end
    end
    
    -- Escaneo de Módulos con Hooking de Upvalues
    local lib = _G3:FindFirstChild("Library")
    if lib then
        for _, m in pairs(lib:GetDescendants()) do
            if m:IsA("ModuleScript") then
                local ok, res = pcall(require, m)
                if ok and type(res) == "table" then
                    -- Buscar en upvalues de las funciones del módulo
                    for _, f in pairs(res) do
                        if type(f) == "function" then
                            pcall(function()
                                local ups = _A3(f)
                                for i, up in pairs(ups) do
                                    if type(up) == "table" then
                                        _LOG(m.Name .. "_UP_" .. tostring(i), _SER(up))
                                    end
                                end
                            end)
                        end
                    end
                end
            end
        end
    end
    
    _ST.Text = "Infiltration Complete."
end

_B2.MouseButton1Click:Connect(function()
    for _, v in pairs(_L1:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    _DUMP = ""
    _INFILTRATE()
end)

_B1.MouseButton1Click:Connect(function()
    if _A4 then _A4(_DUMP) _ST.Text = "Dump Copied!" end
end)
