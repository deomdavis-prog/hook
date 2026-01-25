--[[
    MANUS SPY GODTIER v5.0 - The Memory Infiltrator
    Técnica: Upvalue Injection & GC Scanning (Inmune a bloqueos de hookfunction)
    Optimizado para Solara V3 y Estabilidad Extrema
    
    Este script se infiltra en la memoria de los scripts del juego para
    interceptar remotos desde adentro, sin tocar metatablas ni funciones globales.
]]

local ManusSpy = {
    Enabled = true,
    Logs = {},
    MaxLogs = 250,
    InjectedFunctions = 0,
    GUI = {}
}

-- Servicios
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Abstracción de Funciones de Bajo Nivel
local getgc = getgc or function() return {} end
local debug = debug or {}
local getupvalues = debug.getupvalues or function() return {} end
local setupvalue = debug.setupvalue or function() end
local checkcaller = checkcaller or function() return false end

-- Serializador de Nivel Experto
local function Serialize(val, depth, visited)
    depth = depth or 0
    visited = visited or {}
    if depth > 4 then return '"..." ' end
    
    local t = typeof(val)
    if t == "string" then return '"' .. val .. '"'
    elseif t == "number" or t == "boolean" or t == "nil" then return tostring(val)
    elseif t == "Vector3" then return string.format("Vector3.new(%.1f, %.1f, %.1f)", val.X, val.Y, val.Z)
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
            if i > 8 then s = s .. "..."; break end
            s = s .. Serialize(v, depth + 1, visited) .. ", "
        end
        return s .. "}"
    end
    return tostring(val)
end

-- Función de Log
local function LogRemote(remote, method, args)
    if not ManusSpy.Enabled then return end
    if checkcaller() then return end
    
    local time = os.date("%H:%M:%S")
    local argStr = ""
    for i, v in ipairs(args) do
        argStr = argStr .. Serialize(v) .. (i < #args and ", " or "")
    end
    
    local entry = {
        Remote = remote,
        Method = method,
        Time = time,
        Args = argStr,
        Name = remote.Name
    }
    
    table.insert(ManusSpy.Logs, 1, entry)
    if #ManusSpy.Logs > ManusSpy.MaxLogs then table.remove(ManusSpy.Logs) end
    if ManusSpy.GUI.Update then ManusSpy.GUI.Update() end
end

-- MOTOR DE INYECCIÓN (God Tier Logic)
local function WrapRemote(realRemote)
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)
    
    mt.__index = function(_, key)
        local val = realRemote[key]
        if key == "FireServer" or key == "InvokeServer" then
            return function(_, ...)
                local args = {...}
                task.spawn(function() LogRemote(realRemote, key, args) end)
                return realRemote[key](realRemote, unpack(args))
            end
        end
        if typeof(val) == "function" then
            return function(_, ...)
                return val(realRemote, unpack({...}))
            end
        end
        return val
    end
    
    mt.__tostring = function() return tostring(realRemote) end
    return proxy
end

local function StartInfiltration()
    local count = 0
    for _, obj in pairs(getgc()) do
        if type(obj) == "function" then
            local upvalues = getupvalues(obj)
            for i, v in pairs(upvalues) do
                if typeof(v) == "Instance" and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
                    local success, err = pcall(function()
                        setupvalue(obj, i, WrapRemote(v))
                    end)
                    if success then count = count + 1 end
                end
            end
        end
    end
    ManusSpy.InjectedFunctions = count
    return count
end

-- GUI de Grado Militar
local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ManusSpyGodTierUI"
    ScreenGui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 420, 0, 280)
    Main.Position = UDim2.new(0.5, -210, 0.5, -140)
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
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
    Title.Size = UDim2.new(1, -100, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.Text = "MANUS SPY GODTIER v5.0 | Memory Infiltrator"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 11
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.BackgroundTransparency = 1
    Title.Parent = Top

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(0, 100, 1, 0)
    Status.Position = UDim2.new(1, -110, 0, 0)
    Status.Text = "Injected: " .. ManusSpy.InjectedFunctions
    Status.TextColor3 = Color3.fromRGB(0, 255, 150)
    Status.Font = Enum.Font.GothamBold
    Status.TextSize = 10
    Status.TextXAlignment = Enum.TextXAlignment.Right
    Status.BackgroundTransparency = 1
    Status.Parent = Top

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, -10, 1, -40)
    Scroll.Position = UDim2.new(0, 5, 0, 35)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 3
    Scroll.Parent = Main

    local UIList = Instance.new("UIListLayout")
    UIList.Parent = Scroll
    UIList.Padding = UDim.new(0, 2)

    ManusSpy.GUI.Update = function()
        Status.Text = "Injected: " .. ManusSpy.InjectedFunctions
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
        for _, log in ipairs(ManusSpy.Logs) do
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 38)
            f.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
            f.BorderSizePixel = 0
            f.Parent = Scroll
            
            local n = Instance.new("TextLabel")
            n.Size = UDim2.new(1, -10, 0, 16)
            n.Position = UDim2.new(0, 8, 0, 4)
            n.Text = string.format("[%s] %s (%s)", log.Time, log.Name, log.Method)
            n.TextColor3 = Color3.fromRGB(255, 255, 255)
            n.Font = Enum.Font.GothamBold
            n.TextSize = 10
            n.TextXAlignment = Enum.TextXAlignment.Left
            n.BackgroundTransparency = 1
            n.Parent = f
            
            local a = Instance.new("TextLabel")
            a.Size = UDim2.new(1, -10, 0, 14)
            a.Position = UDim2.new(0, 8, 0, 20)
            a.Text = log.Args
            a.TextColor3 = Color3.fromRGB(160, 160, 170)
            a.Font = Enum.Font.SourceSans
            a.TextSize = 10
            a.TextXAlignment = Enum.TextXAlignment.Left
            a.BackgroundTransparency = 1
            a.Parent = f
        end
    end
end

-- Ejecución
CreateGUI()
task.spawn(function()
    print("ManusSpy GodTier: Iniciando infiltración de memoria...")
    local count = StartInfiltration()
    print("ManusSpy GodTier: Infiltración completada. Funciones inyectadas: " .. count)
    if ManusSpy.GUI.Update then ManusSpy.GUI.Update() end
end)
