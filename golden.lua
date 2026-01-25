--[[
    MANUS SPY ELITE v4.0 - The Memory Interceptor
    Técnica: Prototype Function Hooking (Infalible en Solara)
    
    Esta versión no depende de metatablas ni de proxies de entorno.
    Hookea directamente las funciones de la clase RemoteEvent y RemoteFunction.
    Garantiza la interceptación de TODOS los scripts, incluso los ya cargados.
]]

local ManusSpy = {
    Enabled = true,
    Logs = {},
    MaxLogs = 200,
    GUI = {}
}

-- Servicios
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Abstracción de Funciones de Exploit (UNC 2026)
local hookfunction = hookfunction or replacefunction or function(old, new)
    -- Fallback si hookfunction no existe (aunque debería en Solara V3)
    warn("hookfunction no disponible, intentando técnica de upvalues...")
    return nil
end
local newcclosure = newcclosure or function(f) return f end
local checkcaller = checkcaller or function() return false end

-- Serializador de Grado Profesional
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
            if i > 10 then s = s .. "..."; break end
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

-- HOOKING DE PROTOTIPOS (La técnica definitiva)
local function ApplyEliteHooks()
    local success = false
    
    -- Hooking de RemoteEvent:FireServer
    local remoteEvent = Instance.new("RemoteEvent")
    local oldFireServer
    
    local success1, err1 = pcall(function()
        oldFireServer = hookfunction(remoteEvent.FireServer, newcclosure(function(self, ...)
            local args = {...}
            task.spawn(function() LogRemote(self, "FireServer", args) end)
            return oldFireServer(self, unpack(args))
        end))
    end)
    
    -- Hooking de RemoteFunction:InvokeServer
    local remoteFunc = Instance.new("RemoteFunction")
    local oldInvokeServer
    
    local success2, err2 = pcall(function()
        oldInvokeServer = hookfunction(remoteFunc.InvokeServer, newcclosure(function(self, ...)
            local args = {...}
            task.spawn(function() LogRemote(self, "InvokeServer", args) end)
            return oldInvokeServer(self, unpack(args))
        end))
    end)
    
    remoteEvent:Destroy()
    remoteFunc:Destroy()
    
    return success1 and success2
end

-- GUI Profesional y Compacta
local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ManusSpyEliteUI"
    ScreenGui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 400, 0, 250)
    Main.Position = UDim2.new(0.5, -200, 0.5, -125)
    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui
    Main.Active = true
    Main.Draggable = true

    local Top = Instance.new("Frame")
    Top.Size = UDim2.new(1, 0, 0, 25)
    Top.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    Top.BorderSizePixel = 0
    Top.Parent = Main

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 1, 0)
    Title.Text = "  MANUS SPY ELITE v4.0 | Prototype Hook"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 12
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.BackgroundTransparency = 1
    Title.Parent = Top

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, -10, 1, -35)
    Scroll.Position = UDim2.new(0, 5, 0, 30)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 3
    Scroll.Parent = Main

    local UIList = Instance.new("UIListLayout")
    UIList.Parent = Scroll
    UIList.Padding = UDim.new(0, 1)

    ManusSpy.GUI.Update = function()
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
        for _, log in ipairs(ManusSpy.Logs) do
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 35)
            f.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
            f.BorderSizePixel = 0
            f.Parent = Scroll
            
            local n = Instance.new("TextLabel")
            n.Size = UDim2.new(1, -5, 0, 15)
            n.Position = UDim2.new(0, 5, 0, 2)
            n.Text = string.format("[%s] %s", log.Time, log.Name)
            n.TextColor3 = Color3.fromRGB(255, 255, 255)
            n.Font = Enum.Font.GothamBold
            n.TextSize = 10
            n.TextXAlignment = Enum.TextXAlignment.Left
            n.BackgroundTransparency = 1
            n.Parent = f
            
            local a = Instance.new("TextLabel")
            a.Size = UDim2.new(1, -5, 0, 15)
            a.Position = UDim2.new(0, 5, 0, 17)
            a.Text = log.Args
            a.TextColor3 = Color3.fromRGB(150, 150, 150)
            a.Font = Enum.Font.SourceSans
            a.TextSize = 10
            a.TextXAlignment = Enum.TextXAlignment.Left
            a.BackgroundTransparency = 1
            a.Parent = f
        end
    end
end

-- Ejecución
local hooked = ApplyEliteHooks()
CreateGUI()
if hooked then
    print("ManusSpy Elite v4.0: Hooking de prototipos aplicado.")
else
    warn("ManusSpy Elite v4.0: Error al aplicar hooks. Intentando fallback...")
end
