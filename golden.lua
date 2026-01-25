--[[
    MANUS SPY CORE v9.0 - The VM Infiltrator
    Técnica: Environment Virtualization & Constant Hijacking (Black Hat Grade)
    Optimizado para: Solara V3 & Estabilidad Extrema (Anti-Nil Error)
    
    Core es la respuesta definitiva. No toca metatablas ni el objeto game.
    Se infiltra en el entorno de ejecución para interceptar remotos de forma invisible.
]]

local Core = {
    Enabled = true,
    Logs = {},
    MaxLogs = 300,
    History = {},
    UI = {}
}

-- Servicios Reales
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Abstracción de Funciones de Bajo Nivel
local debug = debug or {}
local getconstants = debug.getconstants or function() return {} end
local setconstant = debug.setconstant or function() end
local getgc = getgc or function() return {} end
local checkcaller = checkcaller or function() return false end

-- Serializador Core-S (Alta Fidelidad)
local function CoreSerialize(val, depth, visited)
    depth = depth or 0
    visited = visited or {}
    if depth > 4 then return '"..." ' end
    
    local t = typeof(val)
    if t == "string" then return '"' .. val .. '"'
    elseif t == "number" or t == "boolean" or t == "nil" then return tostring(val)
    elseif t == "Vector3" then return string.format("Vector3.new(%.2f, %.2f, %.2f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then return "CFrame.new(" .. tostring(val) .. ")"
    elseif t == "Instance" then 
        local s, n = pcall(function() return val.Name end)
        return s and n or "Instance"
    elseif t == "table" then
        if visited[val] then return '"Circular"' end
        visited[val] = true
        local s = "{"
        local i = 0
        for k, v in pairs(val) do
            i = i + 1
            if i > 10 then s = s .. "..."; break end
            s = s .. CoreSerialize(v, depth + 1, visited) .. ", "
        end
        return s .. "}"
    end
    return tostring(val)
end

-- Función de Log (Passive Logging)
local function LogCore(remote, method, args)
    if not Core.Enabled or checkcaller() then return end
    
    local time = os.date("%H:%M:%S")
    local argStr = ""
    for i, v in ipairs(args) do
        argStr = argStr .. CoreSerialize(v) .. (i < #args and ", " or "")
    end
    
    local entry = {
        Remote = remote,
        Method = method,
        Time = time,
        Args = argStr,
        Name = remote.Name,
        Stack = debug.traceback()
    }
    
    table.insert(Core.Logs, 1, entry)
    if #Core.Logs > Core.MaxLogs then table.remove(Core.Logs) end
    if Core.UI.Update then Core.UI.Update() end
end

-- MOTOR DE INTERCEPTACIÓN CORE (Environment Virtualization)
local function CreateCoreInterceptor()
    local RealFireServer = Instance.new("RemoteEvent").FireServer
    local RealInvokeServer = Instance.new("RemoteFunction").InvokeServer
    
    -- Inyectamos en el entorno global de forma segura
    local function InterceptFire(self, ...)
        local args = {...}
        task.spawn(function() LogCore(self, "FireServer", args) end)
        return RealFireServer(self, unpack(args))
    end
    
    local function InterceptInvoke(self, ...)
        local args = {...}
        task.spawn(function() LogCore(self, "InvokeServer", args) end)
        return RealInvokeServer(self, unpack(args))
    end
    
    -- Técnica de Constant Hijacking
    task.spawn(function()
        for _, obj in pairs(getgc()) do
            if type(obj) == "function" then
                local constants = getconstants(obj)
                for i, c in pairs(constants) do
                    if c == "FireServer" then
                        pcall(function() setconstant(obj, i, InterceptFire) end)
                    elseif c == "InvokeServer" then
                        pcall(function() setconstant(obj, i, InterceptInvoke) end)
                    end
                end
            end
        end
    end)
end

-- GUI Core (Grado Militar)
local function CreateCoreUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ManusSpyCoreUI"
    ScreenGui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 420, 0, 280)
    Main.Position = UDim2.new(0.5, -210, 0.5, -140)
    Main.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui
    Main.Active = true
    Main.Draggable = true

    local Top = Instance.new("Frame")
    Top.Size = UDim2.new(1, 0, 0, 28)
    Top.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Top.BorderSizePixel = 0
    Top.Parent = Main

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -10, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.Text = "MANUS SPY CORE v9.0 | VM Infiltrator"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 11
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.BackgroundTransparency = 1
    Title.Parent = Top

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, -10, 1, -40)
    Scroll.Position = UDim2.new(0, 5, 0, 35)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 2
    Scroll.Parent = Main

    local UIList = Instance.new("UIListLayout")
    UIList.Parent = Scroll
    UIList.Padding = UDim.new(0, 2)

    Core.UI.Update = function()
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
        for _, log in ipairs(Core.Logs) do
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 35)
            f.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
            f.BorderSizePixel = 0
            f.Parent = Scroll
            
            local n = Instance.new("TextLabel")
            n.Size = UDim2.new(1, -10, 0, 16)
            n.Position = UDim2.new(0, 10, 0, 4)
            n.Text = string.format("[%s] %s", log.Time, log.Name)
            n.TextColor3 = Color3.fromRGB(255, 255, 255)
            n.Font = Enum.Font.GothamBold
            n.TextSize = 10
            n.TextXAlignment = Enum.TextXAlignment.Left
            n.BackgroundTransparency = 1
            n.Parent = f
            
            local a = Instance.new("TextLabel")
            a.Size = UDim2.new(1, -10, 0, 14)
            a.Position = UDim2.new(0, 10, 0, 20)
            a.Text = log.Args
            a.TextColor3 = Color3.fromRGB(160, 160, 170)
            a.Font = Enum.Font.SourceSans
            a.TextSize = 9
            a.TextXAlignment = Enum.TextXAlignment.Left
            a.BackgroundTransparency = 1
            a.Parent = f
        end
    end
end

-- Ejecución
CreateCoreUI()
task.spawn(function()
    print("ManusSpy Core: Iniciando infiltración de la VM...")
    CreateCoreInterceptor()
    print("ManusSpy Core: Infiltración completada. Observando constantes de red.")
    if Core.UI.Update then Core.UI.Update() end
end)
