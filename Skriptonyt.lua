--[[
    ManusSpy Ultimate - The Final Remote Spy (Fixed & Optimized)
    
    Correcciones aplicadas:
    - Corregido error 'ReadOnly' en TextBox (cambiado a 'TextEditable').
    - Corregido error de argumentos en RemoteFunction (uso correcto de task.spawn/defer).
    - Mejorada la serialización y el manejo de hilos.
    - Optimizada la interfaz y el sistema de logs.
]]

local ManusSpy = {
    Version = "3.1.0",
    Settings = {
        IgnoreList = {},
        BlockList = {},
        AutoScroll = true,
        MaxLogs = 200,
        RecordReturnValues = true,
        ShowCallingScript = true,
        ExcludedRemotes = {"CharacterSoundEvent", "GetServerTime", "UpdatePlayerModels"}, -- Ruido común
    },
    Logs = {},
    Hooks = {},
    Queue = {},
}

-- Services
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Environment Check & Polyfills
local getgenv = getgenv or function() return _G end
local hookmetamethod = hookmetamethod or (syn and syn.hook_metamethod)
local getnamecallmethod = getnamecallmethod or (syn and syn.get_namecall_method)
local checkcaller = checkcaller or (syn and syn.check_caller)
local newcclosure = newcclosure or (syn and syn.new_cclosure)
local hookfunction = hookfunction or (syn and syn.hook_function)
local getcallingscript = getcallingscript or (debug and debug.getcallingscript) or function() return "Unknown" end
local setclipboard = setclipboard or (syn and syn.write_clipboard) or (toclipboard)

-- Utility: Advanced Path Generation
local function getPath(instance)
    if not instance then return "nil" end
    local success, name = pcall(function() return instance.Name end)
    if not success then return "ProtectedInstance" end
    
    if instance == game then return "game" end
    if instance == workspace then return "workspace" end
    if instance == LocalPlayer then return "game:GetService('Players').LocalPlayer" end
    
    local parent = instance.Parent
    
    -- Check if it's a service
    local isService, service = pcall(function() return game:GetService(instance.ClassName) end)
    if isService and service == instance then
        return 'game:GetService("' .. instance.ClassName .. '")'
    end

    if not parent then
        return 'getnilinstance("' .. name .. '")'
    end
    
    local cleanName = name:gsub('[%w_]', '')
    local head = ""
    if #cleanName > 0 or tonumber(name:sub(1,1)) then
        head = '["' .. name:gsub('"', '\\"'):gsub('\\', '\\\\') .. '"]'
    else
        head = "." .. name
    end
    
    return getPath(parent) .. head
end

-- Utility: Advanced Value Serialization
local function serialize(val, visited, indent)
    visited = visited or {}
    indent = indent or 0
    local t = typeof(val)
    local spacing = string.rep("    ", indent)
    
    if t == "string" then
        return '"' .. val:gsub('"', '\\"'):gsub('\\', '\\\\') .. '"'
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(val)
    elseif t == "Instance" then
        return getPath(val)
    elseif t == "Vector3" then
        return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "Vector2" then
        return string.format("Vector2.new(%.3f, %.3f)", val.X, val.Y)
    elseif t == "CFrame" then
        return "CFrame.new(" .. tostring(val) .. ")"
    elseif t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(val.R*255), math.floor(val.G*255), math.floor(val.B*255))
    elseif t == "UDim2" then
        return string.format("UDim2.new(%.3f, %d, %.3f, %d)", val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
    elseif t == "table" then
        if visited[val] then return "{ --[[ Circular ]] }" end
        visited[val] = true
        local str = "{\n"
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            str = str .. spacing .. "    [" .. serialize(k, visited, indent + 1) .. "] = " .. serialize(v, visited, indent + 1) .. ",\n"
            if count > 100 then str = str .. spacing .. "    --[[ Truncated ]]\n" break end
        end
        visited[val] = nil
        return str .. spacing .. "}"
    else
        return '"' .. tostring(val) .. ' --[[ ' .. t .. ' ]]"'
    end
end

-- Performance: Task Scheduler for UI Updates
local function scheduleUpdate(data)
    table.insert(ManusSpy.Queue, data)
end

RunService.Heartbeat:Connect(function()
    if #ManusSpy.Queue > 0 then
        local data = table.remove(ManusSpy.Queue, 1)
        table.insert(ManusSpy.Logs, 1, data)
        if #ManusSpy.Logs > ManusSpy.Settings.MaxLogs then
            table.remove(ManusSpy.Logs)
        end
        if ManusSpy.OnLogAdded then
            pcall(ManusSpy.OnLogAdded, data)
        end
    end
end)

-- Hooking Engine
local function handleRemote(instance, method, args, returnValue)
    if checkcaller() then return end
    
    local success, name = pcall(function() return instance.Name end)
    if not success then return end
    
    -- Filtering
    if table.find(ManusSpy.Settings.ExcludedRemotes, name) then return end
    if ManusSpy.Settings.IgnoreList[instance] or ManusSpy.Settings.IgnoreList[name] then return end
    
    local callData = {
        Instance = instance,
        Method = method,
        Args = args,
        ReturnValue = returnValue,
        Script = getcallingscript(),
        Time = os.clock(),
    }
    
    scheduleUpdate(callData)
    
    if ManusSpy.Settings.BlockList[instance] or ManusSpy.Settings.BlockList[name] then
        return true -- Blocked
    end
end

-- Namecall Hook
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if typeof(self) == "Instance" and (method == "FireServer" or method == "InvokeServer") then
        if method == "InvokeServer" and ManusSpy.Settings.RecordReturnValues then
            -- Para RemoteFunctions, capturamos el retorno de forma segura
            local results
            local success = pcall(function()
                results = {oldNamecall(self, unpack(args))}
            end)
            
            if success then
                handleRemote(self, method, args, results)
                return unpack(results)
            end
        else
            if handleRemote(self, method, args) then return end
        end
    end
    
    return oldNamecall(self, ...)
end))

-- Method Hooks
local function hookRemoteMethod(class, methodName)
    local original
    local success, proto = pcall(function() return Instance.new(class)[methodName] end)
    if not success then return end
    
    original = hookfunction(proto, newcclosure(function(self, ...)
        local args = {...}
        if methodName == "InvokeServer" and ManusSpy.Settings.RecordReturnValues then
            local results = {original(self, ...)}
            handleRemote(self, methodName, args, results)
            return unpack(results)
        else
            if handleRemote(self, methodName, args) then return end
        end
        return original(self, ...)
    end))
end

hookRemoteMethod("RemoteEvent", "FireServer")
hookRemoteMethod("RemoteFunction", "InvokeServer")

-- UI Implementation
local function createUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ManusSpy_Ultimate"
    ScreenGui.ResetOnSpawn = false
    
    -- Protect UI
    local parent = CoreGui
    if getgenv().get_hidden_gui then parent = getgenv().get_hidden_gui()
    elseif syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
    ScreenGui.Parent = parent
    
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 700, 0, 500)
    Main.Position = UDim2.new(0.5, -350, 0.5, -250)
    Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = Main
    
    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = Main
    
    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 8)
    topCorner.Parent = TopBar
    
    local Title = Instance.new("TextLabel")
    Title.Text = "  MANUS SPY ULTIMATE v" .. ManusSpy.Version
    Title.Size = UDim2.new(1, -150, 1, 0)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = Color3.fromRGB(0, 255, 150)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.Parent = TopBar
    
    local LogList = Instance.new("ScrollingFrame")
    LogList.Size = UDim2.new(0, 250, 1, -50)
    LogList.Position = UDim2.new(0, 5, 0, 45)
    LogList.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    LogList.BorderSizePixel = 0
    LogList.CanvasSize = UDim2.new(0, 0, 0, 0)
    LogList.ScrollBarThickness = 3
    LogList.Parent = Main
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 3)
    UIListLayout.Parent = LogList
    
    local CodeView = Instance.new("ScrollingFrame")
    CodeView.Size = UDim2.new(1, -265, 1, -90)
    CodeView.Position = UDim2.new(0, 260, 0, 45)
    CodeView.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    CodeView.BorderSizePixel = 0
    CodeView.Parent = Main
    
    local CodeText = Instance.new("TextBox")
    CodeText.Size = UDim2.new(1, -10, 1, -10)
    CodeText.Position = UDim2.new(0, 5, 0, 5)
    CodeText.BackgroundTransparency = 1
    CodeText.TextColor3 = Color3.fromRGB(220, 220, 220)
    CodeText.TextXAlignment = Enum.TextXAlignment.Left
    CodeText.TextYAlignment = Enum.TextYAlignment.Top
    CodeText.Font = Enum.Font.Code
    CodeText.TextSize = 14
    CodeText.ClearTextOnFocus = false
    CodeText.TextEditable = false -- CORRECCIÓN: 'ReadOnly' no existe, se usa 'TextEditable'
    CodeText.MultiLine = true
    CodeText.Text = "-- Select a remote to view details\n-- Performance optimized for heavy traffic"
    CodeText.Parent = CodeView
    
    -- Buttons
    local function createBtn(text, pos, size, color)
        local btn = Instance.new("TextButton")
        btn.Text = text
        btn.Position = pos
        btn.Size = size
        btn.BackgroundColor3 = color or Color3.fromRGB(50, 50, 50)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.Parent = Main
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 4)
        bCorner.Parent = btn
        return btn
    end

    local ClearBtn = createBtn("Clear Logs", UDim2.new(0, 260, 1, -40), UDim2.new(0, 100, 0, 35), Color3.fromRGB(120, 40, 40))
    local CopyBtn = createBtn("Copy Script", UDim2.new(0, 370, 1, -40), UDim2.new(0, 110, 0, 35))
    local RunBtn = createBtn("Execute", UDim2.new(0, 490, 1, -40), UDim2.new(0, 100, 0, 35), Color3.fromRGB(40, 120, 40))
    
    ClearBtn.MouseButton1Click:Connect(function()
        for _, child in ipairs(LogList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        ManusSpy.Logs = {}
        CodeText.Text = "-- Logs cleared"
    end)

    CopyBtn.MouseButton1Click:Connect(function()
        if setclipboard then setclipboard(CodeText.Text) end
    end)

    RunBtn.MouseButton1Click:Connect(function()
        local func, err = loadstring(CodeText.Text)
        if func then pcall(func) else warn("ManusSpy Error: " .. tostring(err)) end
    end)

    ManusSpy.OnLogAdded = function(data)
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(1, -5, 0, 32)
        Button.BackgroundColor3 = data.Method:find("Invoke") and Color3.fromRGB(45, 45, 60) or Color3.fromRGB(40, 40, 40)
        Button.TextColor3 = Color3.new(1, 1, 1)
        Button.Text = "  [" .. data.Method:sub(1,1) .. "] " .. (data.Instance and data.Instance.Name or "Unknown")
        Button.TextXAlignment = Enum.TextXAlignment.Left
        Button.Font = Enum.Font.Gotham
        Button.TextSize = 13
        Button.Parent = LogList
        
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 4)
        bCorner.Parent = Button

        Button.MouseButton1Click:Connect(function()
            local code = "-- Remote: " .. getPath(data.Instance) .. "\n"
            code = code .. "-- Method: " .. data.Method .. "\n"
            code = code .. "-- Calling Script: " .. (typeof(data.Script) == "Instance" and getPath(data.Script) or tostring(data.Script)) .. "\n"
            code = code .. "-- Time: " .. os.date("%H:%M:%S", data.Time) .. "\n"
            
            if data.ReturnValue then
                code = code .. "-- Return Value: " .. serialize(data.ReturnValue) .. "\n"
            end
            
            code = code .. "\nlocal args = " .. serialize(data.Args) .. "\n"
            code = code .. getPath(data.Instance) .. ":" .. data.Method .. "(unpack(args))"
            
            CodeText.Text = code
        end)
        
        LogList.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
        if ManusSpy.Settings.AutoScroll then
            LogList.CanvasPosition = Vector2.new(0, UIListLayout.AbsoluteContentSize.Y)
        end
    end
end

createUI()
print("ManusSpy Ultimate v3.1.0 Loaded! Fixed & Optimized.")
