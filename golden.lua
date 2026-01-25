--[[
    MANUS SPY ORIGIN v8.0 - The Native Interceptor
    Técnica: Native Method Redirection (Sin Proxies, Sin GC Scanning)
    Optimizado para: Solara V3 & Estabilidad Absoluta (Anti-Nil Error)
    
    Origin es la solución definitiva. No intenta engañar al motor de Roblox,
    sino que redefine los métodos de red de forma segura y transparente.
]]

local Origin = {
    Enabled = true,
    Logs = {},
    MaxLogs = 200,
    UI = {}
}

-- Servicios Reales
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Abstracción de Funciones de Exploit
local getrawmetatable = getrawmetatable or debug.getmetatable
local setreadonly = setreadonly or make_writeable or function(t, b) if b then make_writeable(t) else make_readonly(t) end end
local checkcaller = checkcaller or function() return false end

-- Serializador Origin-S (Estabilidad Total)
local function OriginSerialize(val, depth, visited)
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
            s = s .. OriginSerialize(v, depth + 1, visited) .. ", "
        end
        return s .. "}"
    end
    return tostring(val)
end

-- Función de Log (Silent Logging)
local function LogOrigin(remote, method, args)
    if not Origin.Enabled or checkcaller() then return end
    
    local time = os.date("%H:%M:%S")
    local argStr = ""
    for i, v in ipairs(args) do
        argStr = argStr .. OriginSerialize(v) .. (i < #args and ", " or "")
    end
    
    local entry = {
        Remote = remote,
        Method = method,
        Time = time,
        Args = argStr,
        Name = remote.Name
    }
    
    table.insert(Origin.Logs, 1, entry)
    if #Origin.Logs > Origin.MaxLogs then table.remove(Origin.Logs) end
    if Origin.UI.Update then Origin.UI.Update() end
end

-- MOTOR DE INTERCEPTACIÓN ORIGIN (Native Redirection)
local function ApplyOriginHooks()
    local success = false
    
    -- Intentamos acceder a la metatabla de la clase RemoteEvent
    pcall(function()
        local mt = getrawmetatable(game:GetService("ReplicatedStorage")) -- Metatabla base de instancias
        if mt and mt.__namecall then
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)
            
            mt.__namecall = function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                
                if method == "FireServer" or method == "InvokeServer" then
                    task.spawn(function() LogOrigin(self, method, args) end)
                end
                
                return oldNamecall(self, unpack(args))
            end
            
            setreadonly(mt, true)
            success = true
        end
    end)
    
    -- Fallback: Si __namecall falla, intentamos envolver los métodos en la metatabla de RemoteEvent directamente
    if not success then
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
                            task.spawn(function() LogOrigin(self, key, args) end)
                            return val(self, unpack(args))
                        end
                    end
                    return val
                end
                
                setreadonly(mt, true)
                success = true
            end
            remote:Destroy()
        end)
    end
    
    return success
end

-- GUI Origin (Ultra-Estable)
local function CreateOriginUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ManusSpyOriginUI"
    ScreenGui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 380, 0, 240)
    Main.Position = UDim2.new(0.5, -190, 0.5, -120)
    Main.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui
    Main.Active = true
    Main.Draggable = true

    local Top = Instance.new("Frame")
    Top.Size = UDim2.new(1, 0, 0, 24)
    Top.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Top.BorderSizePixel = 0
    Top.Parent = Main

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -10, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.Text = "MANUS SPY ORIGIN v8.0 | Native Interceptor"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 10
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.BackgroundTransparency = 1
    Title.Parent = Top

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, -10, 1, -30)
    Scroll.Position = UDim2.new(0, 5, 0, 28)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 2
    Scroll.Parent = Main

    local UIList = Instance.new("UIListLayout")
    UIList.Parent = Scroll
    UIList.Padding = UDim.new(0, 2)

    Origin.UI.Update = function()
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
        for _, log in ipairs(Origin.Logs) do
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 30)
            f.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
            f.BorderSizePixel = 0
            f.Parent = Scroll
            
            local n = Instance.new("TextLabel")
            n.Size = UDim2.new(1, -10, 0, 14)
            n.Position = UDim2.new(0, 8, 0, 2)
            n.Text = string.format("[%s] %s", log.Time, log.Name)
            n.TextColor3 = Color3.fromRGB(255, 255, 255)
            n.Font = Enum.Font.GothamBold
            n.TextSize = 9
            n.TextXAlignment = Enum.TextXAlignment.Left
            n.BackgroundTransparency = 1
            n.Parent = f
            
            local a = Instance.new("TextLabel")
            a.Size = UDim2.new(1, -10, 0, 12)
            a.Position = UDim2.new(0, 8, 0, 16)
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
local hooked = ApplyOriginHooks()
CreateOriginUI()
if hooked then
    print("ManusSpy Origin: Interceptación nativa activada.")
else
    warn("ManusSpy Origin: No se pudo activar la interceptación nativa. El ejecutor es demasiado limitado.")
end
