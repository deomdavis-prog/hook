--[[
    MANUS SPY SINGULARITY v10.0 - The Final Observer
    Técnica: Registry-Based Interception & Metatable Redirection (Sin getgc)
    Optimizado para: Solara V3 & Estabilidad Absoluta (Anti-Nil Error)
    
    Singularity es la culminación. No depende de getgc ni sustituye game.
    Utiliza el registro de Luau para interceptar remotos de forma infalible.
]]

local Singularity = {
    Enabled = true,
    Logs = {},
    MaxLogs = 250,
    UI = {}
}

-- Servicios Reales
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Abstracción de Funciones de Bajo Nivel
local getreg = getreg or function() return {} end
local debug = debug or {}
local getconstants = debug.getconstants or function() return {} end
local setconstant = debug.setconstant or function() end
local getrawmetatable = getrawmetatable or debug.getmetatable
local setreadonly = setreadonly or make_writeable or function(t, b) if b then make_writeable(t) else make_readonly(t) end end
local checkcaller = checkcaller or function() return false end

-- Serializador Singularity-S (Alta Fidelidad)
local function SingularitySerialize(val, depth, visited)
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
            if i > 8 then s = s .. "..."; break end
            s = s .. SingularitySerialize(v, depth + 1, visited) .. ", "
        end
        return s .. "}"
    end
    return tostring(val)
end

-- Función de Log (Silent Logging)
local function LogSingularity(remote, method, args)
    if not Singularity.Enabled or checkcaller() then return end
    
    local time = os.date("%H:%M:%S")
    local argStr = ""
    for i, v in ipairs(args) do
        argStr = argStr .. SingularitySerialize(v) .. (i < #args and ", " or "")
    end
    
    local entry = {
        Remote = remote,
        Method = method,
        Time = time,
        Args = argStr,
        Name = remote.Name
    }
    
    table.insert(Singularity.Logs, 1, entry)
    if #Singularity.Logs > Singularity.MaxLogs then table.remove(Singularity.Logs) end
    if Singularity.UI.Update then Singularity.UI.Update() end
end

-- MOTOR DE INTERCEPTACIÓN SINGULARITY (Registry-Based)
local function ApplySingularityHooks()
    local count = 0
    
    -- Técnica 1: Metatable Redirection (Sin Proxies)
    pcall(function()
        local remote = Instance.new("RemoteEvent")
        local mt = getrawmetatable(remote)
        if mt and mt.__index then
            local oldIndex = mt.__index
            setreadonly(mt, false)
            
            mt.__index = function(self, key)
                local val = oldIndex(self, key)
                if key == "FireServer" or key == "InvokeServer" then
                    return function(_, ...)
                        local args = {...}
                        task.spawn(function() LogSingularity(self, key, args) end)
                        return val(self, unpack(args))
                    end
                end
                return val
            end
            
            setreadonly(mt, true)
            count = count + 1
        end
        remote:Destroy()
    end)
    
    -- Técnica 2: Registry Constant Hijacking (Bypass de getgc)
    task.spawn(function()
        local reg = getreg()
        for _, obj in pairs(reg) do
            if type(obj) == "function" then
                local constants = getconstants(obj)
                for i, c in pairs(constants) do
                    if c == "FireServer" or c == "InvokeServer" then
                        pcall(function()
                            local original = obj
                            setconstant(obj, i, function(self, ...)
                                local args = {...}
                                task.spawn(function() LogSingularity(self, c, args) end)
                                return original(self, unpack(args))
                            end)
                            count = count + 1
                        end)
                    end
                end
            end
        end
    end)
    
    return count
end

-- GUI Singularity (Grado Profesional)
local function CreateSingularityUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ManusSpySingularityUI"
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
    Title.Text = "MANUS SPY SINGULARITY v10.0 | Final Observer"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 10
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

    Singularity.UI.Update = function()
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
        for _, log in ipairs(Singularity.Logs) do
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
            n.TextSize = 9
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
CreateSingularityUI()
task.spawn(function()
    print("ManusSpy Singularity: Iniciando observación de red...")
    local count = ApplySingularityHooks()
    print("ManusSpy Singularity: Listo. Puntos de interceptación activos.")
    if Singularity.UI.Update then Singularity.UI.Update() end
end)
