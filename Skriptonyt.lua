--[[
    GHOST AUDITOR - BRUTE FORCE EDITION
    Objetivo: Forzar la extracción de datos de proxies 'Locked' en PS1.
    
    Técnica: 
    - Inspección de Upvalues en metamétodos (donde reside la tabla real).
    - Extracción de constantes de funciones bloqueadas.
    - Bypass de proxy mediante redirección de __index.
]]

local _G1 = game:GetService("Players")
local _G2 = game:GetService("CoreGui")
local _G3 = game:GetService("ReplicatedStorage")

local _A1 = getrawmetatable or (debug and debug.getmetatable)
local _A2 = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local _A3 = debug.getupvalues or getupvalues
local _A4 = setclipboard or print
local _A5 = debug.getconstants or getconstants

local _S1 = Instance.new("ScreenGui")
_S1.Name = "BF_" .. tostring(math.random(1000, 9999))
_S1.Parent = _G2

local _F1 = Instance.new("Frame")
_F1.Size = UDim2.new(0, 340, 0, 420)
_F1.Position = UDim2.new(0.5, -170, 0.5, -210)
_F1.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
_F1.BorderSizePixel = 0
_F1.Active = true
_F1.Draggable = true
_F1.Parent = _S1
Instance.new("UICorner", _F1).CornerRadius = UDim.new(0, 15)

local _T1 = Instance.new("TextLabel")
_T1.Size = UDim2.new(1, 0, 0, 40)
_T1.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
_T1.Text = "BRUTE-FORCE UNPACKER"
_T1.TextColor3 = Color3.fromRGB(255, 255, 255)
_T1.Font = Enum.Font.Code
_T1.TextSize = 14
_T1.Parent = _F1
Instance.new("UICorner", _T1).CornerRadius = UDim.new(0, 15)

local _L1 = Instance.new("ScrollingFrame")
_L1.Size = UDim2.new(1, -20, 1, -140)
_L1.Position = UDim2.new(0, 10, 0, 50)
_L1.BackgroundTransparency = 1
_L1.CanvasSize = UDim2.new(0, 0, 0, 0)
_L1.ScrollBarThickness = 0
_L1.Parent = _F1

local _U1 = Instance.new("UIListLayout")
_U1.Parent = _L1
_U1.Padding = UDim.new(0, 5)

local _ST = Instance.new("TextLabel")
_ST.Size = UDim2.new(1, -20, 0, 20)
_ST.Position = UDim2.new(0, 10, 1, -85)
_ST.BackgroundTransparency = 1
_ST.Text = "Status: Ready"
_ST.TextColor3 = Color3.fromRGB(0, 255, 200)
_ST.TextSize = 11
_ST.Parent = _F1

local _B1 = Instance.new("TextButton")
_B1.Size = UDim2.new(0.45, 0, 0, 40)
_B1.Position = UDim2.new(0.05, 0, 1, -55)
_B1.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
_B1.Text = "COPY ALL"
_B1.TextColor3 = Color3.fromRGB(255, 255, 255)
_B1.Parent = _F1
Instance.new("UICorner", _B1).CornerRadius = UDim.new(0, 10)

local _B2 = Instance.new("TextButton")
_B2.Size = UDim2.new(0.45, 0, 0, 40)
_B2.Position = UDim2.new(0.5, 0, 1, -55)
_B2.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
_B2.Text = "BRUTE FORCE"
_B2.TextColor3 = Color3.fromRGB(255, 255, 255)
_B2.Parent = _F1
Instance.new("UICorner", _B2).CornerRadius = UDim.new(0, 10)

local function _SERIALIZE(v, d, s)
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
            local ok, res = pcall(function() return _SERIALIZE(val, d + 1, s) end)
            r = r .. i .. "[" .. tostring(k) .. "] = " .. (ok and res or "ERR") .. ",\n"
        end
        return r .. string.rep(" ", d * 2) .. "}"
    end
    if type(v) == "function" then
        local info = "func("
        -- EXTRAER CONSTANTES (Aquí es donde están los datos reales en PS1)
        pcall(function()
            if _A5 then
                local consts = _A5(v)
                for _, c in pairs(consts) do
                    if type(c) == "string" and #c > 1 then
                        info = info .. "'" .. c .. "',"
                    end
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
    l.Text = " [+] " .. n
    l.TextColor3 = Color3.fromRGB(220, 220, 220)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.Code
    l.TextSize = 10
    l.Parent = _L1
    Instance.new("UICorner", l).CornerRadius = UDim.new(0, 5)
    _DUMP = _DUMP .. "\n--- " .. n .. " ---\n" .. c .. "\n"
    _L1.CanvasSize = UDim2.new(0, 0, 0, _U1.AbsoluteContentSize.Y)
end

local function _FORCE_UNPACK(o, n)
    if not o then return end
    _ST.Text = "Forcing: " .. n
    local mt = nil
    pcall(function() mt = _A1(o) end)
    
    if mt then
        -- Técnica 1: Inspección de Upvalues en metamétodos
        pcall(function()
            for m_name, f in pairs(mt) do
                if type(f) == "function" then
                    local ups = _A3(f)
                    for i, up in pairs(ups) do
                        if type(up) == "table" and up ~= mt then
                            _LOG(n .. "_UP_" .. tostring(i), _SERIALIZE(up))
                        end
                    end
                end
            end
        end)
        
        -- Técnica 2: Serialización de la MT cruda con constantes
        _LOG(n .. "_MT", _SERIALIZE(mt))
    else
        _LOG(n, "NO_MT")
    end
end

_B2.MouseButton1Click:Connect(function()
    for _, v in pairs(_L1:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    _DUMP = ""
    _ST.Text = "Brute-Forcing..."
    
    -- Escaneo de módulos de PS1 (Library es el objetivo principal)
    local lib = _G3:FindFirstChild("Library")
    if lib then
        for _, m in pairs(lib:GetDescendants()) do
            if m:IsA("ModuleScript") then
                local ok, res = pcall(require, m)
                if ok and type(res) == "table" then 
                    _FORCE_UNPACK(res, m.Name) 
                end
            end
        end
    end
    
    -- Escaneo de objetos base
    _FORCE_UNPACK(game, "Game")
    _FORCE_UNPACK(workspace, "Workspace")
    
    _ST.Text = "Done. Check Logs."
end)

_B1.MouseButton1Click:Connect(function()
    if _A4 then _A4(_DUMP) _ST.Text = "Copied!" end
end)
