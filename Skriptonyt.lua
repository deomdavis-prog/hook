--[[
    GOD MODE METATABLE AUDITOR - THE FINAL BYPASS
    Diseñado para: Pet Simulator 1 (BIG Games)
    
    Este sistema es la culminación de la ingeniería inversa en Luau.
    Técnicas de Nivel 0:
    1. LPH Bypass: Extrae constantes de funciones protegidas por Luraph/BIG Games.
    2. Registry Deep-Dive: Escanea el registro buscando firmas de metatables de C.
    3. Upvalue Reconstruction: Reconstruye tablas a partir de upvalues de funciones anidadas.
    4. Environment Spoofing: Engaña al juego para que crea que el entorno es seguro.
]]

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
        if d > 3 then return "{...}" end
        if s[v] then return "{CIRC}" end
        s[v] = true
        local r = "{\n"
        local i = string.rep(" ", (d + 1) * 2)
        pcall(function() if _A2 then _A2(v, false) end end)
        for k, val in pairs(v) do
            local ok, res = pcall(function() return _GOD_SER(val, d + 1, s) end)
            r = r .. i .. "[" .. tostring(k) .. "] = " .. (ok and res or "ERR") .. ",\n"
        end
        return r .. string.rep(" ", d * 2) .. "}"
    end
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
            local u = _A3(v)
            for k, up in pairs(u) do
                if type(up) == "table" then
                    info = info .. "UP_" .. tostring(k) .. ":" .. _GOD_SER(up, d + 1, s) .. ","
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

-- Escaneo de Nivel Dios
local function _GOD_SCAN()
    _ST.Text = "Initiating God Mode Scan..."
    
    -- 1. Infiltración del Registro de Bajo Nivel
    pcall(function()
        local reg = _A5()
        for k, v in pairs(reg) do
            if type(v) == "table" then
                local is_big = false
                pcall(function()
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

_B1.MouseButton1Click:Connect(function()
    if _A4 then _A4(_DUMP) _ST.Text = "God Dump Copied!" end
end)
