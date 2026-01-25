--[[
    MANUS SPY ZENITH v6.0 - The Ultimate Network Debugger
    Arquitectura: Hybrid Interception (Upvalue Hijacking + Prototype Swizzling + Global Proxy)
    Optimizado para: Luau (luau.org) & Solara V3 (2026)
    
    Zenith combina las mejores lógicas de Hydroxide, SimpleSpy y TurtleSpy
    en un motor unificado, robusto y original.
]]

-- Estructura de Datos Zenith (Optimizado para Luau)
local Zenith = {
    Config = {
        Enabled = true,
        MaxLogs = 300,
        AutoBlockSpam = true,
        SafeMode = true -- Evita crashes en mecánicas sensibles
    },
    Logs = {},
    History = {},
    InjectedCount = 0,
    UI = {}
}

-- Servicios de Roblox
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Abstracción de Funciones de Exploit (UNC Compliant)
local Env = {
    getgc = getgc or function() return {} end,
    getupvalues = (debug and debug.getupvalues) or function() return {} end,
    setupvalue = (debug and debug.setupvalue) or function() end,
    hookfunction = hookfunction or replacefunction,
    newcclosure = newcclosure or function(f) return f end,
    checkcaller = checkcaller or function() return false end,
    getrawmetatable = getrawmetatable or debug.getmetatable,
    setreadonly = setreadonly or make_writeable or function(t, b) if b then make_writeable(t) else make_readonly(t) end end
}

-- MOTOR DE SERIALIZACIÓN ZENITH-S (Alta Fidelidad)
local function ZenithSerialize(val, depth, visited)
    depth = depth or 0
    visited = visited or {}
    if depth > 5 then return '"[Max Depth]"' end
    
    local t = typeof(val)
    if t == "string" then
        return '"' .. val .. '"'
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(val)
    elseif t == "Vector3" then
        return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then
        return "CFrame.new(" .. tostring(val) .. ")"
    elseif t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", val.R*255, val.G*255, val.B*255)
    elseif t == "Instance" then
        local success, name = pcall(function() return val:GetFullName() end)
        return success and name or "Instance(Destroyed)"
    elseif t == "table" then
        if visited[val] then return '"[Circular Reference]"' end
        visited[val] = true
        local s = "{"
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count > 20 then s = s .. "..."; break end
            s = s .. "[" .. ZenithSerialize(k, depth + 1, visited) .. "] = " .. ZenithSerialize(v, depth + 1, visited) .. ", "
        end
        return s .. "}"
    end
    return tostring(val)
end

-- GENERADOR DE CÓDIGO PROFESIONAL
local function GenerateRemoteCode(remote, method, args)
    local argStrings = {}
    for i, v in ipairs(args) do
        table.insert(argStrings, ZenithSerialize(v))
    end
    local path = remote:GetFullName()
    return string.format("-- Zenith Remote Script\nlocal remote = %s\nremote:%s(%s)", 
        ZenithSerialize(remote), method, table.concat(argStrings, ", "))
end

-- SISTEMA DE LOGS (Optimizado)
local function LogZenith(remote, method, args)
    if not Zenith.Config.Enabled or Env.checkcaller() then return end
    
    -- Filtro de Spam Inteligente
    if Zenith.Config.AutoBlockSpam then
        local key = remote:GetFullName() .. method
        if Zenith.History[key] and tick() - Zenith.History[key] < 0.1 then return end
        Zenith.History[key] = tick()
    end

    local entry = {
        Remote = remote,
        Method = method,
        Time = os.date("%H:%M:%S"),
        Args = args,
        Code = GenerateRemoteCode(remote, method, args),
        Stack = debug.traceback()
    }

    table.insert(Zenith.Logs, 1, entry)
    if #Zenith.Logs > Zenith.Config.MaxLogs then table.remove(Zenith.Logs) end
    if Zenith.UI.Update then Zenith.UI.Update() end
end

-- CAPA DE INTERCEPTACIÓN HÍBRIDA
local function WrapRemote(realRemote)
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)
    
    mt.__index = function(_, key)
        local val = realRemote[key]
        if key == "FireServer" or key == "InvokeServer" then
            return function(_, ...)
                local args = {...}
                task.spawn(function() LogZenith(realRemote, key, args) end)
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

-- 1. Upvalue Hijacking (Infiltración de Memoria)
local function HijackUpvalues()
    local count = 0
    for _, obj in pairs(Env.getgc()) do
        if type(obj) == "function" then
            local upvalues = Env.getupvalues(obj)
            for i, v in pairs(upvalues) do
                if typeof(v) == "Instance" and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
                    pcall(function()
                        Env.setupvalue(obj, i, WrapRemote(v))
                        count = count + 1
                    end)
                end
            end
        end
    end
    Zenith.InjectedCount = count
end

-- 2. Prototype Swizzling (Si está disponible)
local function ApplyPrototypeHooks()
    if not Env.hookfunction then return false end
    
    local success1, _ = pcall(function()
        local oldFire
        oldFire = Env.hookfunction(Instance.new("RemoteEvent").FireServer, Env.newcclosure(function(self, ...)
            local args = {...}
            task.spawn(function() LogZenith(self, "FireServer", args) end)
            return oldFire(self, unpack(args))
        end))
    end)
    
    return success1
end

-- INTERFAZ DE USUARIO ZENITH (Grado Profesional)
local function CreateZenithUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ManusSpyZenithUI"
    ScreenGui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
    ScreenGui.ResetOnSpawn = false

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 550, 0, 350)
    Main.Position = UDim2.new(0.5, -275, 0.5, -175)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui
    Main.Active = true
    Main.Draggable = true

    local Top = Instance.new("Frame")
    Top.Size = UDim2.new(1, 0, 0, 30)
    Top.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    Top.BorderSizePixel = 0
    Top.Parent = Main

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -150, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.Text = "MANUS SPY ZENITH v6.0 | Hybrid Network Debugger"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 12
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.BackgroundTransparency = 1
    Title.Parent = Top

    local List = Instance.new("ScrollingFrame")
    List.Size = UDim2.new(0.4, -10, 1, -40)
    List.Position = UDim2.new(0, 5, 0, 35)
    List.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    List.BorderSizePixel = 0
    List.ScrollBarThickness = 3
    List.Parent = Main

    local UIList = Instance.new("UIListLayout")
    UIList.Parent = List
    UIList.Padding = UDim.new(0, 2)

    local Inspector = Instance.new("ScrollingFrame")
    Inspector.Size = UDim2.new(0.6, -5, 1, -40)
    Inspector.Position = UDim2.new(0.4, 0, 0, 35)
    Inspector.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    Inspector.BorderSizePixel = 0
    Inspector.ScrollBarThickness = 3
    Inspector.Parent = Main

    local CodeBox = Instance.new("TextBox")
    CodeBox.Size = UDim2.new(1, -10, 1, -10)
    CodeBox.Position = UDim2.new(0, 5, 0, 5)
    CodeBox.BackgroundTransparency = 1
    CodeBox.TextColor3 = Color3.fromRGB(180, 180, 200)
    CodeBox.Text = "-- Selecciona un evento para inspección profunda --"
    CodeBox.MultiLine = true
    CodeBox.TextXAlignment = Enum.TextXAlignment.Left
    CodeBox.TextYAlignment = Enum.TextYAlignment.Top
    CodeBox.Font = Enum.Font.Code
    CodeBox.TextSize = 11
    CodeBox.ClearTextOnFocus = false
    CodeBox.Parent = Inspector

    Zenith.UI.Update = function()
        for _, v in pairs(List:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        for _, log in ipairs(Zenith.Logs) do
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 25)
            b.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
            b.Text = string.format("  [%s] %s", log.Time, log.Remote.Name)
            b.TextColor3 = Color3.fromRGB(230, 230, 230)
            b.Font = Enum.Font.Gotham
            b.TextSize = 11
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.BorderSizePixel = 0
            b.Parent = List
            b.MouseButton1Click:Connect(function()
                CodeBox.Text = string.format("--- ZENITH INSPECTOR ---\n\n[REMOTE]: %s\n[METHOD]: %s\n\n[CODE]:\n%s\n\n[STACK TRACE]:\n%s", 
                    log.Remote:GetFullName(), log.Method, log.Code, log.Stack)
            end)
        end
    end
end

-- INICIALIZACIÓN ZENITH
CreateZenithUI()
task.spawn(function()
    print("ManusSpy Zenith: Iniciando motor híbrido...")
    local protoSuccess = ApplyPrototypeHooks()
    HijackUpvalues()
    print(string.format("ManusSpy Zenith: Motor listo. Prototype Hook: %s | Upvalues Hijacked: %d", 
        protoSuccess and "SÍ" or "NO (Usando Fallback)", Zenith.InjectedCount))
    if Zenith.UI.Update then Zenith.UI.Update() end
end)

-- Global Proxy (Capa Final)
getgenv().game = WrapRemote(game)
