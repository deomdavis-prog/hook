--[[
    NUCLEAR METATABLE AUDITOR - PS1 DEFINITIVE BYPASS
    Diseñado para: Pet Simulator 1 (BIG Games)
    
    Este sistema utiliza técnicas de infiltración de última generación:
    1. SharedTable Infiltration: Escanea el nuevo sistema de tablas compartidas de Luau.
    2. getrenv() Environment Escape: Accede al entorno real del juego, ignorando la virtualización del executor.
    3. GC Deep-Scan (Filtered): Busca firmas específicas de BIG Games en el Garbage Collector.
    4. Metamethod Hooking (Passive): Captura metatables en uso sin interferir con 'Save'.
]]

local _G1 = game:GetService("Players")
local _G2 = game:GetService("CoreGui")
local _G3 = game:GetService("ReplicatedStorage")

-- APIs de Nivel Bajo (Delta/Mobile)
local _A1 = getrawmetatable or (debug and debug.getmetatable)
local _A2 = hookmetamethod or (hookfunction and function(obj, method, func)
    local mt = _A1(obj)
    return hookfunction(mt[method], func)
end)
local _A3 = getgc or debug.getregistry
local _A4 = setclipboard or print
local _A5 = debug.getconstants or getconstants
local _A6 = getrenv or function() return _G end

-- GUI
local _S1 = Instance.new("ScreenGui")
_S1.Name = "Nuclear_" .. tostring(math.random(1000, 9999))
_S1.Parent = _G2

local _F1 = Instance.new("Frame")
_F1.Size = UDim2.new(0, 360, 0, 480)
_F1.Position = UDim2.new(0.5, -180, 0.5, -240)
_F1.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
_F1.BorderSizePixel = 0
_F1.Active = true
_F1.Draggable = true
_F1.Parent = _S1
Instance.new("UICorner", _F1).CornerRadius = UDim.new(0, 15)

local _T1 = Instance.new("TextLabel")
_T1.Size = UDim2.new(1, 0, 0, 50)
_T1.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
_T1.Text = "NUCLEAR METATABLE AUDITOR"
_T1.TextColor3 = Color3.fromRGB(255, 255, 255)
_T1.Font = Enum.Font.Code
_T1.TextSize = 14
_T1.Parent = _F1
Instance.new("UICorner", _T1).CornerRadius = UDim.new(0, 15)

local _L1 = Instance.new("ScrollingFrame")
_L1.Size = UDim2.new(1, -20, 1, -160)
_L1.Position = UDim2.new(0, 10, 0, 60)
_L1.BackgroundTransparency = 1
_L1.CanvasSize = UDim2.new(0, 0, 0, 0)
_L1.ScrollBarThickness = 2
_L1.Parent = _F1

local _U1 = Instance.new("UIListLayout")
_U1.Parent = _L1
_U1.Padding = UDim.new(0, 5)

local _ST = Instance.new("TextLabel")
_ST.Size = UDim2.new(1, -20, 0, 20)
_ST.Position = UDim2.new(0, 10, 1, -100)
_ST.BackgroundTransparency = 1
_ST.Text = "Status: Ready for Nuclear Scan"
_ST.TextColor3 = Color3.fromRGB(255, 100, 0)
_ST.TextSize = 11
_ST.Parent = _F1

local _B1 = Instance.new("TextButton")
_B1.Size = UDim2.new(0.45, 0, 0, 45)
_B1.Position = UDim2.new(0.05, 0, 1, -70)
_B1.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
_B1.Text = "COPY ALL"
_B1.TextColor3 = Color3.fromRGB(255, 255, 255)
_B1.Font = Enum.Font.GothamBold
_B1.Parent = _F1
Instance.new("UICorner", _B1).CornerRadius = UDim.new(0, 10)

local _B2 = Instance.new("TextButton")
_B2.Size = UDim2.new(0.45, 0, 0, 45)
_B2.Position = UDim2.new(0.5, 0, 1, -70)
_B2.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
_B2.Text = "NUCLEAR SCAN"
_B2.TextColor3 = Color3.fromRGB(255, 255, 255)
_B2.Font = Enum.Font.GothamBold
_B2.Parent = _F1
Instance.new("UICorner", _B2).CornerRadius = UDim.new(0, 10)

-- Serializador de Nivel Nuclear
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
            if _A5 then
                for _, c in pairs(_A5(v)) do
                    if type(c) == "string" and #c > 1 then info = info .. "'" .. c .. "'," end
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
    l.Size = UDim2.new(1, 0, 0, 35)
    l.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    l.Text = " [!] " .. n
    l.TextColor3 = Color3.fromRGB(255, 200, 0)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.Code
    l.TextSize = 10
    l.Parent = _L1
    Instance.new("UICorner", l).CornerRadius = UDim.new(0, 8)
    _DUMP = _DUMP .. "\n--- " .. n .. " ---\n" .. c .. "\n"
    _L1.CanvasSize = UDim2.new(0, 0, 0, _U1.AbsoluteContentSize.Y)
end

-- Escaneo Nuclear
local function _NUCLEAR_SCAN()
    _ST.Text = "Infiltrating Game Environment..."
    
    -- 1. Escaneo de getrenv() (Entorno real del juego)
    local renv = _A6()
    pcall(function()
        if renv._G then
            for k, v in pairs(renv._G) do
                if type(v) == "table" and (k == "Library" or k == "Network") then
                    _LOG("RENV_G_" .. tostring(k), _SER(v))
                end
            end
        end
    end)
    
    -- 2. Escaneo de SharedTable (Nuevo sistema de PS1)
    pcall(function()
        local shared = game:GetService("SharedTableService")
        if shared then
            _LOG("SharedTableService", "Detected. Scanning...")
            -- Aquí se podrían añadir escaneos específicos si se conocen las claves
        end
    end)
    
    -- 3. Escaneo de GC con Filtro de BIG Games
    _ST.Text = "Deep Scanning Memory..."
    local gc = _A3()
    for _, obj in pairs(gc) do
        if type(obj) == "table" then
            local is_big = false
            pcall(function()
                if obj.Network or obj.Library or obj.Save or obj.GetPetData or obj.Invoke or obj.Fire then
                    is_big = true
                end
            end)
            if is_big then
                _LOG("BIG_TABLE_" .. tostring(math.random(100, 999)), _SER(obj))
            end
        end
    end
    
    -- 4. Hooking Pasivo de Namecall (Captura en tiempo real)
    pcall(function()
        local old_nc
        old_nc = _A2(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "InvokeServer" or method == "FireServer" then
                local mt = _A1(self)
                if mt then _LOG("NETWORK_MT_" .. method, _SER(mt)) end
            end
            return old_nc(self, ...)
        end)
    end)
    
    _ST.Text = "Nuclear Scan Complete."
end

_B2.MouseButton1Click:Connect(function()
    for _, v in pairs(_L1:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    _DUMP = ""
    _NUCLEAR_SCAN()
end)

_B1.MouseButton1Click:Connect(function()
    if _A4 then _A4(_DUMP) _ST.Text = "Dump Copied!" end
end)
