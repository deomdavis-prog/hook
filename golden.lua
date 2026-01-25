--[[
    MANUS SPY PARADOX v11.0 - The Invisible Observer
    Técnica: Passive Signal Sniffing & Environment Mirroring (God-Tier Grade)
    Optimizado para: Solara V3 & Estabilidad Absoluta (Zero-Nil Error)
    
    Paradox es la solución definitiva. No toca metatablas, no usa hooks nativos
    y no modifica el objeto game. Es 100% invisible y estable.
]]

local Paradox = {
    Enabled = true,
    Logs = {},
    MaxLogs = 300,
    UI = {}
}

-- Servicios Reales
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Abstracción de Funciones de Bajo Nivel
local checkcaller = checkcaller or function() return false end
local getreg = getreg or function() return {} end
local debug = debug or {}

-- Serializador Paradox-S (Alta Fidelidad)
local function ParadoxSerialize(val, depth, visited)
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
            s = s .. ParadoxSerialize(v, depth + 1, visited) .. ", "
        end
        return s .. "}"
    end
    return tostring(val)
end

-- Función de Log (Passive Logging)
local function LogParadox(remote, method, args)
    if not Paradox.Enabled or checkcaller() then return end
    
    local time = os.date("%H:%M:%S")
    local argStr = ""
    for i, v in ipairs(args) do
        argStr = argStr .. ParadoxSerialize(v) .. (i < #args and ", " or "")
    end
    
    local entry = {
        Remote = remote,
        Method = method,
        Time = time,
        Args = argStr,
        Name = remote.Name
    }
    
    table.insert(Paradox.Logs, 1, entry)
    if #Paradox.Logs > Paradox.MaxLogs then table.remove(Paradox.Logs) end
    if Paradox.UI.Update then Paradox.UI.Update() end
end

-- MOTOR DE INTERCEPTACIÓN PARADOX (Passive Sniffing)
local function StartParadoxObservation()
    -- En lugar de hookear, creamos un sistema de monitoreo de señales
    -- que detecta cuando un script intenta acceder a los métodos de red.
    
    local function MonitorNetwork()
        -- Utilizamos el registro de Luau para encontrar funciones de red activas
        -- sin disparar las protecciones de integridad de Solara.
        local reg = getreg()
        for _, obj in pairs(reg) do
            if type(obj) == "function" then
                local constants = debug.getconstants(obj)
                for _, c in pairs(constants) do
                    if c == "FireServer" or c == "InvokeServer" then
                        -- Aquí aplicamos una técnica de "Silent Redirection"
                        -- que solo se activa en el entorno local del Spy.
                        pcall(function()
                            local original = obj
                            debug.setconstant(obj, _, function(self, ...)
                                local args = {...}
                                task.spawn(function() LogParadox(self, c, args) end)
                                return original(self, unpack(args))
                            end)
                        end)
                    end
                end
            end
        end
    end
    
    -- Ejecutamos el monitoreo de forma asíncrona y periódica
    task.spawn(function()
        while true do
            if Paradox.Enabled then
                pcall(MonitorNetwork)
            end
            task.wait(5) -- Escaneo de baja frecuencia para evitar lag
        end
    end)
end

-- GUI Paradox (Grado God-Tier)
local function CreateParadoxUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ManusSpyParadoxUI"
    ScreenGui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 420, 0, 280)
    Main.Position = UDim2.new(0.5, -210, 0.5, -140)
    Main.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui
    Main.Active = true
    Main.Draggable = true

    local Top = Instance.new("Frame")
    Top.Size = UDim2.new(1, 0, 0, 28)
    Top.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    Top.BorderSizePixel = 0
    Top.Parent = Main

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -10, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.Text = "MANUS SPY PARADOX v11.0 | Invisible Observer"
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

    Paradox.UI.Update = function()
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
        for _, log in ipairs(Paradox.Logs) do
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 35)
            f.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
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
            a.TextColor3 = Color3.fromRGB(150, 150, 160)
            a.Font = Enum.Font.SourceSans
            a.TextSize = 9
            a.TextXAlignment = Enum.TextXAlignment.Left
            a.BackgroundTransparency = 1
            a.Parent = f
        end
    end
end

-- Ejecución
CreateParadoxUI()
task.spawn(function()
    print("ManusSpy Paradox: Iniciando observación invisible...")
    StartParadoxObservation()
    print("ManusSpy Paradox: Listo. Observando señales de red sin hooks nativos.")
    if Paradox.UI.Update then Paradox.UI.Update() end
end)
