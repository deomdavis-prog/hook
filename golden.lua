--[[
    MANUS SPY APEX v7.0 - The Bytecode Observer
    Técnica: Constant Hijacking & Upvalue Redirection (Sin Proxies de 'game')
    Optimizado para: Solara V3 & Estabilidad Absoluta
    
    Apex elimina los errores de "nil index" al no usar proxies sobre el objeto game.
    En su lugar, escanea las constantes de las funciones para interceptar remotos.
]]

local Apex = {
    Config = {
        Enabled = true,
        MaxLogs = 250,
        IgnoreSpam = true
    },
    Logs = {},
    History = {},
    InjectedCount = 0,
    UI = {}
}

-- Servicios Reales (Sin Proxies)
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Abstracción de Funciones de Bajo Nivel
local getgc = getgc or function() return {} end
local debug = debug or {}
local getconstants = debug.getconstants or function() return {} end
local getupvalues = debug.getupvalues or function() return {} end
local setupvalue = debug.setupvalue or function() end
local checkcaller = checkcaller or function() return false end

-- Serializador Apex-S (Alta Fidelidad y Estabilidad)
local function ApexSerialize(val, depth, visited)
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
            s = s .. ApexSerialize(v, depth + 1, visited) .. ", "
        end
        return s .. "}"
    end
    return tostring(val)
end

-- Función de Log Central
local function LogApex(remote, method, args)
    if not Apex.Config.Enabled or checkcaller() then return end
    
    local time = os.date("%H:%M:%S")
    local argStr = ""
    for i, v in ipairs(args) do
        argStr = argStr .. ApexSerialize(v) .. (i < #args and ", " or "")
    end
    
    local entry = {
        Remote = remote,
        Method = method,
        Time = time,
        Args = argStr,
        Name = remote.Name,
        Stack = debug.traceback()
    }
    
    table.insert(Apex.Logs, 1, entry)
    if #Apex.Logs > Apex.Config.MaxLogs then table.remove(Apex.Logs) end
    if Apex.UI.Update then Apex.UI.Update() end
end

-- MOTOR DE INTERCEPTACIÓN APEX (Sin Proxies de Game)
local function CreateRemoteWrapper(realRemote)
    -- No usamos newproxy para evitar errores de indexación nil en el juego
    -- Solo envolvemos las funciones de disparo si son llamadas
    local wrapper = {
        FireServer = function(_, ...)
            local args = {...}
            task.spawn(function() LogApex(realRemote, "FireServer", args) end)
            return realRemote.FireServer(realRemote, unpack(args))
        end,
        InvokeServer = function(_, ...)
            local args = {...}
            task.spawn(function() LogApex(realRemote, "InvokeServer", args) end)
            return realRemote.InvokeServer(realRemote, unpack(args))
        end
    }
    
    -- Metatabla para que el wrapper se comporte como el remoto real
    return setmetatable({}, {
        __index = function(_, key)
            if key == "FireServer" or key == "InvokeServer" then
                return wrapper[key]
            end
            return realRemote[key]
        end,
        __tostring = function() return tostring(realRemote) end
    })
end

-- Escaneo de Constantes y Upvalues
local function StartApexInfiltration()
    local count = 0
    for _, obj in pairs(getgc()) do
        if type(obj) == "function" then
            local constants = getconstants(obj)
            local isRemoteFunc = false
            for _, c in pairs(constants) do
                if c == "FireServer" or c == "InvokeServer" then
                    isRemoteFunc = true
                    break
                end
            end
            
            if isRemoteFunc then
                local upvalues = getupvalues(obj)
                for i, v in pairs(upvalues) do
                    if typeof(v) == "Instance" and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
                        pcall(function()
                            setupvalue(obj, i, CreateRemoteWrapper(v))
                            count = count + 1
                        end)
                    end
                end
            end
        end
    end
    Apex.InjectedCount = count
    return count
end

-- GUI Apex (Minimalista y Estable)
local function CreateApexUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ManusSpyApexUI"
    ScreenGui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 400, 0, 260)
    Main.Position = UDim2.new(0.5, -200, 0.5, -130)
    Main.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui
    Main.Active = true
    Main.Draggable = true

    local Top = Instance.new("Frame")
    Top.Size = UDim2.new(1, 0, 0, 26)
    Top.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    Top.BorderSizePixel = 0
    Top.Parent = Main

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -10, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.Text = "MANUS SPY APEX v7.0 | Bytecode Observer"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 11
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.BackgroundTransparency = 1
    Title.Parent = Top

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, -10, 1, -35)
    Scroll.Position = UDim2.new(0, 5, 0, 30)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 2
    Scroll.Parent = Main

    local UIList = Instance.new("UIListLayout")
    UIList.Parent = Scroll
    UIList.Padding = UDim.new(0, 2)

    Apex.UI.Update = function()
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
        for _, log in ipairs(Apex.Logs) do
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 32)
            f.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
            f.BorderSizePixel = 0
            f.Parent = Scroll
            
            local n = Instance.new("TextLabel")
            n.Size = UDim2.new(1, -10, 0, 14)
            n.Position = UDim2.new(0, 8, 0, 3)
            n.Text = string.format("[%s] %s", log.Time, log.Name)
            n.TextColor3 = Color3.fromRGB(255, 255, 255)
            n.Font = Enum.Font.GothamBold
            n.TextSize = 10
            n.TextXAlignment = Enum.TextXAlignment.Left
            n.BackgroundTransparency = 1
            n.Parent = f
            
            local a = Instance.new("TextLabel")
            a.Size = UDim2.new(1, -10, 0, 12)
            a.Position = UDim2.new(0, 8, 0, 17)
            a.Text = log.Args
            a.TextColor3 = Color3.fromRGB(140, 140, 150)
            a.Font = Enum.Font.SourceSans
            a.TextSize = 9
            a.TextXAlignment = Enum.TextXAlignment.Left
            a.BackgroundTransparency = 1
            a.Parent = f
        end
    end
end

-- Ejecución
CreateApexUI()
task.spawn(function()
    print("ManusSpy Apex: Iniciando observación de bytecode...")
    local count = StartApexInfiltration()
    print("ManusSpy Apex: Listo. Funciones observadas: " .. count)
    if Apex.UI.Update then Apex.UI.Update() end
end)
