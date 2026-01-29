--[[
    LEVEL 0 INTERCEPTOR - FINAL EDITION (WITH COPY ALL)
    Diseñado para: Pet Simulator 1 (BIG Games)
    
    Técnica:
    - Hooking de __index para capturar la metatable real en el stack.
    - Serializador Luau puro (Zero Dependencies).
    - Botón de Copy All funcional para Delta Mobile.
]]

local _G1 = game:GetService("Players")
local _G2 = game:GetService("CoreGui")
local _G3 = game:GetService("ReplicatedStorage")

-- APIs de Nivel Bajo
local _A1 = getrawmetatable or (debug and debug.getmetatable)
local _A2 = hookmetamethod or (hookfunction and function(obj, method, func)
    local mt = _A1(obj)
    return hookfunction(mt[method], func)
end)
local _A3 = debug.getupvalues or getupvalues
local _A4 = setclipboard or print
local _A5 = debug.getconstants or getconstants

-- GUI
local _S1 = Instance.new("ScreenGui")
_S1.Name = "L0_Final_" .. tostring(math.random(100, 999))
_S1.Parent = _G2

local _F1 = Instance.new("Frame")
_F1.Size = UDim2.new(0, 350, 0, 450)
_F1.Position = UDim2.new(0.5, -175, 0.5, -225)
_F1.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
_F1.BorderSizePixel = 0
_F1.Active = true
_F1.Draggable = true
_F1.Parent = _S1
Instance.new("UICorner", _F1).CornerRadius = UDim.new(0, 12)

local _T1 = Instance.new("TextLabel")
_T1.Size = UDim2.new(1, 0, 0, 45)
_T1.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
_T1.Text = "L0 METATABLE INTERCEPTOR"
_T1.TextColor3 = Color3.fromRGB(255, 255, 255)
_T1.Font = Enum.Font.Code
_T1.TextSize = 14
_T1.Parent = _F1
Instance.new("UICorner", _T1).CornerRadius = UDim.new(0, 12)

local _L1 = Instance.new("ScrollingFrame")
_L1.Size = UDim2.new(1, -20, 1, -140)
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
_ST.Position = UDim2.new(0, 10, 1, -80)
_ST.BackgroundTransparency = 1
_ST.Text = "Status: Waiting for Start"
_ST.TextColor3 = Color3.fromRGB(0, 255, 150)
_ST.TextSize = 12
_ST.Parent = _F1

local _B1 = Instance.new("TextButton")
_B1.Size = UDim2.new(0.45, 0, 0, 40)
_B1.Position = UDim2.new(0.05, 0, 1, -50)
_B1.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
_B1.Text = "COPY ALL"
_B1.TextColor3 = Color3.fromRGB(255, 255, 255)
_B1.Font = Enum.Font.GothamBold
_B1.Parent = _F1
Instance.new("UICorner", _B1).CornerRadius = UDim.new(0, 8)

local _B2 = Instance.new("TextButton")
_B2.Size = UDim2.new(0.45, 0, 0, 40)
_B2.Position = UDim2.new(0.5, 0, 1, -50)
_B2.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
_B2.Text = "START HOOK"
_B2.TextColor3 = Color3.fromRGB(255, 255, 255)
_B2.Font = Enum.Font.GothamBold
_B2.Parent = _F1
Instance.new("UICorner", _B2).CornerRadius = UDim.new(0, 8)

-- Serializador Luau Puro
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

_B2.MouseButton1Click:Connect(function()
    _ST.Text = "Hooking __index..."
    _B2.Visible = false
    
    -- Hooking de __index para capturar la MT real
    local old_index
    old_index = _A2(game, "__index", function(self, key)
        local mt = _A1(self)
        if mt and tostring(mt.__metatable) ~= "The metatable is locked" then
            _LOG("REAL_MT_CAPTURED", _SER(mt))
        end
        return old_index(self, key)
    end)
    
    -- Escaneo de Upvalues en Library
    local lib = _G3:FindFirstChild("Library")
    if lib then
        for _, m in pairs(lib:GetDescendants()) do
            if m:IsA("ModuleScript") then
                pcall(function()
                    local res = require(m)
                    if type(res) == "table" then
                        for _, f in pairs(res) do
                            if type(f) == "function" then
                                local ups = _A3(f)
                                for i, up in pairs(ups) do
                                    if type(up) == "table" then
                                        _LOG(m.Name .. "_UP_" .. i, _SER(up))
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
    _ST.Text = "Hook Active. Move or open menus!"
end)

_B1.MouseButton1Click:Connect(function()
    if _A4 then _A4(_DUMP) _ST.Text = "Dump Copied!" end
end)
