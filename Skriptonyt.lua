--[[
    METATABLE INTERCEPTOR - NIVEL 0 (BYPASS DE FAKE PROXY)
    Diseñado para: Pet Simulator 1 (BIG Games)
    
    Técnica:
    En lugar de usar getrawmetatable (que devuelve el proxy falso), 
    este script hookea el metamétodo __index. Cuando el juego accede 
    a una propiedad, capturamos la metatable real que Luau usa internamente.
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

-- GUI
local _S1 = Instance.new("ScreenGui")
_S1.Name = "Interceptor_L0"
_S1.Parent = _G2

local _F1 = Instance.new("Frame")
_F1.Size = UDim2.new(0, 350, 0, 400)
_F1.Position = UDim2.new(0.5, -175, 0.5, -200)
_F1.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
_F1.Parent = _S1
Instance.new("UICorner", _F1)

local _T1 = Instance.new("TextLabel")
_T1.Size = UDim2.new(1, 0, 0, 40)
_T1.Text = "LEVEL 0 INTERCEPTOR"
_T1.TextColor3 = Color3.fromRGB(255, 0, 0)
_T1.Font = Enum.Font.Code
_T1.Parent = _F1

local _L1 = Instance.new("ScrollingFrame")
_L1.Size = UDim2.new(1, -20, 1, -100)
_L1.Position = UDim2.new(0, 10, 0, 50)
_L1.BackgroundTransparency = 1
_L1.CanvasSize = UDim2.new(0, 0, 0, 0)
_L1.Parent = _F1
local _U1 = Instance.new("UIListLayout", _L1)

local _B1 = Instance.new("TextButton")
_B1.Size = UDim2.new(0.9, 0, 0, 40)
_B1.Position = UDim2.new(0.05, 0, 1, -45)
_B1.Text = "START INTERCEPTION"
_B1.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
_B1.TextColor3 = Color3.fromRGB(255, 255, 255)
_B1.Parent = _F1

local _DUMP = ""

local function _LOG(n, c)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 20)
    l.Text = " > " .. n
    l.TextColor3 = Color3.fromRGB(200, 200, 200)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = _L1
    _DUMP = _DUMP .. "\n[" .. n .. "]\n" .. c .. "\n"
    _L1.CanvasSize = UDim2.new(0, 0, 0, _U1.AbsoluteContentSize.Y)
end

-- Intercepción de Metamétodos
local function _START()
    _LOG("System", "Hooking __index...")
    
    -- Hookeamos __index de un objeto base para capturar la MT real
    local old_index
    old_index = _A2(game, "__index", function(self, key)
        local mt = _A1(self)
        -- Si la MT que obtenemos es diferente a la bloqueada, la capturamos
        if mt and tostring(mt.__metatable) ~= "The metatable is locked" then
            _LOG("CAPTURED_MT", "Real Metatable Found!")
        end
        return old_index(self, key)
    end)
    
    -- Escaneo de Upvalues en la Library (PS1)
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
                                        _LOG(m.Name .. "_UP", "Table Found in Upvalues")
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
end

_B1.MouseButton1Click:Connect(_START)
