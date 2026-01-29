--[[
    GHOST AUDITOR - PS1 EDITION
    Bypass de filtros dinámicos y errores forzados.
    
    Nota: Si sigues viendo errores de 'deep_serialize', por favor reinicia tu Delta 
    o limpia el editor, ya que esa función ya no existe en este código.
]]

local _G1 = game:GetService("Players")
local _G2 = game:GetService("CoreGui")
local _G3 = game:GetService("ReplicatedStorage")

local _A1 = getrawmetatable or (debug and debug.getmetatable)
local _A2 = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local _A3 = debug.getupvalues or getupvalues
local _A4 = setclipboard or print

local _S1 = Instance.new("ScreenGui")
_S1.Name = "GA_" .. tostring(math.random(100, 999))
_S1.Parent = _G2

local _F1 = Instance.new("Frame")
_F1.Size = UDim2.new(0, 340, 0, 420)
_F1.Position = UDim2.new(0.5, -170, 0.5, -210)
_F1.BackgroundColor3 = Color3.fromRGB(5, 5, 10)
_F1.BorderSizePixel = 0
_F1.Active = true
_F1.Draggable = true
_F1.Parent = _S1
Instance.new("UICorner", _F1).CornerRadius = UDim.new(0, 15)

local _T1 = Instance.new("TextLabel")
_T1.Size = UDim2.new(1, 0, 0, 40)
_T1.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
_T1.Text = "GHOST UNPACKER"
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
_ST.Text = "Status: Standby"
_ST.TextColor3 = Color3.fromRGB(100, 255, 100)
_ST.TextSize = 11
_ST.Parent = _F1

local _B1 = Instance.new("TextButton")
_B1.Size = UDim2.new(0.45, 0, 0, 40)
_B1.Position = UDim2.new(0.05, 0, 1, -55)
_B1.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
_B1.Text = "COPY"
_B1.TextColor3 = Color3.fromRGB(255, 255, 255)
_B1.Parent = _F1
Instance.new("UICorner", _B1).CornerRadius = UDim.new(0, 10)

local _B2 = Instance.new("TextButton")
_B2.Size = UDim2.new(0.45, 0, 0, 40)
_B2.Position = UDim2.new(0.5, 0, 1, -55)
_B2.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
_B2.Text = "UNPACK"
_B2.TextColor3 = Color3.fromRGB(255, 255, 255)
_B2.Parent = _F1
Instance.new("UICorner", _B2).CornerRadius = UDim.new(0, 10)

-- Motor de Serialización Ofuscado (Sin dependencias)
local function _X9(v, d, s)
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
            local ok, res = pcall(function() return _X9(val, d + 1, s) end)
            r = r .. i .. "[" .. tostring(k) .. "] = " .. (ok and res or "ERR") .. ",\n"
        end
        return r .. string.rep(" ", d * 2) .. "}"
    end
    if type(v) == "function" then
        local u_str = "func("
        pcall(function()
            local u = _A3(v)
            for k, _ in pairs(u) do u_str = u_str .. tostring(k) .. "," end
        end)
        return u_str .. ")"
    end
    return tostring(v)
end

local _DUMP = ""

local function _LOG(n, c)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 25)
    l.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    l.Text = " > " .. n
    l.TextColor3 = Color3.fromRGB(200, 200, 200)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.Code
    l.TextSize = 10
    l.Parent = _L1
    Instance.new("UICorner", l).CornerRadius = UDim.new(0, 5)
    _DUMP = _DUMP .. "\n[" .. n .. "]\n" .. c .. "\n"
    _L1.CanvasSize = UDim2.new(0, 0, 0, _U1.AbsoluteContentSize.Y)
end

local function _AUDIT(o, n)
    if not o then return end
    _ST.Text = "Scan: " .. n
    local mt = nil
    pcall(function() mt = _A1(o) end)
    if mt then
        pcall(function()
            for _, f in pairs(mt) do
                if type(f) == "function" then
                    local u = _A3(f)
                    for _, up in pairs(u) do
                        if type(up) == "table" and up ~= mt then
                            _LOG(n .. "_HIDDEN", _X9(up))
                        end
                    end
                end
            end
        end)
        _LOG(n .. "_RAW", _X9(mt))
    else
        _LOG(n, "EMPTY")
    end
end

_B2.MouseButton1Click:Connect(function()
    for _, v in pairs(_L1:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    _DUMP = ""
    _ST.Text = "Running..."
    _AUDIT(game, "G")
    _AUDIT(workspace, "W")
    local lib = _G3:FindFirstChild("Library")
    if lib then
        for _, m in pairs(lib:GetDescendants()) do
            if m:IsA("ModuleScript") then
                local ok, res = pcall(require, m)
                if ok and type(res) == "table" then _AUDIT(res, m.Name) end
            end
        end
    end
    _ST.Text = "Finished."
end)

_B1.MouseButton1Click:Connect(function()
    if _A4 then _A4(_DUMP) _ST.Text = "Copied!" end
end)
