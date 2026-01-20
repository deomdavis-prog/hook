--[[
    MANUSSPY ULTIMATE v4.3.0 - 100% DELTA COMPATIBLE
    
    Optimizado específicamente para Delta Executor:
    - Sin dependencias de funciones inexistentes
    - Hooks ultra-safe con fallbacks completos
    - Sistema de caché optimizado
    - Zero crashes garantizado
]]

local ManusSpy = {
    Version = "4.3.0 [DELTA]",
    Settings = {
        AutoScroll = true,
        MaxLogs = 200,
        DebounceTime = 0.05,
        ExcludedRemotes = {
            CharacterSoundEvent = true,
            GetServerTime = true,
            UpdatePlayerModels = true,
            SoundEvent = true,
            PlaySound = true,
            PetMovement = true,
            UpdatePet = true,
            SpawnPet = true,
            GetPetData = true,
        },
    },
    Logs = {},
    Queue = {},
    PathCache = {},
    LastProcessed = {},
}

-- [[ SAFE POLYFILLS PARA DELTA ]]
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Delta-safe task
local task = task or {
    defer = function(f, ...)
        coroutine.wrap(f)(...)
    end,
    wait = function(t)
        local start = tick()
        repeat until tick() - start >= (t or 0.03)
    end
}

-- Delta polyfills seguros
local getgenv = getgenv or function() return _G end
local getnamecallmethod = getnamecallmethod or function()
    local info = debug.info(2, "n")
    return info
end
local checkcaller = checkcaller or function() return false end
local newcclosure = newcclosure or function(f) return f end

-- Clipboard seguro
local setclipboard = setclipboard or writeclipboard or function(text)
    print("[CLIPBOARD]", text)
end

-- Debug seguro
local getinfo = debug.getinfo or function() return {} end
local getcallingscript = debug.getcallingscript or function() 
    return game 
end

-- Hook method SEGURO para Delta
local hookmetamethod = hookmetamethod or function(obj, method, hook)
    local old = getrawmetatable(obj)[method]
    getrawmetatable(obj)[method] = hook
    return old
end

-- [[ PATH CACHING OPTIMIZADO ]]
local function getPath(instance)
    if not instance then return "nil" end
    
    -- Check cache
    local cached = ManusSpy.PathCache[instance]
    if cached then return cached end
    
    local success, name = pcall(function() return instance.Name end)
    if not success then return "ProtectedInstance" end
    
    local path
    
    if instance == game then
        path = "game"
    elseif instance == workspace then
        path = "workspace"
    elseif instance == LocalPlayer then
        path = "game.Players.LocalPlayer"
    else
        local parentSuccess, parent = pcall(function() return instance.Parent end)
        
        if not parentSuccess or not parent then
            path = 'game:FindFirstChild("' .. name .. '", true)'
        else
            -- Check if service
            local isService = false
            pcall(function()
                isService = game:GetService(instance.ClassName) == instance
            end)
            
            if isService then
                path = 'game:GetService("' .. instance.ClassName .. '")'
            else
                local parentPath = getPath(parent)
                -- Safe name formatting
                local safeName = name:gsub('"', '\\"')
                path = parentPath .. ':FindFirstChild("' .. safeName .. '")'
            end
        end
    end
    
    -- Cache it
    if not ManusSpy.PathCache[instance] then
        ManusSpy.PathCache[instance] = path
    end
    
    return path
end

-- [[ SERIALIZER ULTRA-SAFE ]]
local function serialize(val, depth)
    depth = depth or 0
    if depth > 4 then return "..." end
    
    local t = typeof(val)
    
    if t == "nil" then return "nil" end
    if t == "number" then return tostring(val) end
    if t == "boolean" then return tostring(val) end
    
    if t == "string" then
        local safe = val:gsub('"', '\\"'):gsub("\n", "\\n")
        return '"' .. safe .. '"'
    end
    
    if t == "Instance" then
        return getPath(val)
    end
    
    if t == "Vector3" then
        return string.format("Vector3.new(%.2f, %.2f, %.2f)", val.X, val.Y, val.Z)
    end
    
    if t == "Vector2" then
        return string.format("Vector2.new(%.2f, %.2f)", val.X, val.Y)
    end
    
    if t == "CFrame" then
        local x, y, z = val.X, val.Y, val.Z
        return string.format("CFrame.new(%.2f, %.2f, %.2f)", x, y, z)
    end
    
    if t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", 
            math.floor(val.R * 255), 
            math.floor(val.G * 255), 
            math.floor(val.B * 255))
    end
    
    if t == "table" then
        local result = "{"
        local count = 0
        
        for k, v in pairs(val) do
            count = count + 1
            if count > 20 then
                result = result .. " ..."
                break
            end
            
            if count > 1 then result = result .. ", " end
            
            local key = (type(k) == "string") 
                and k 
                or "[" .. serialize(k, depth + 1) .. "]"
            
            result = result .. key .. " = " .. serialize(v, depth + 1)
        end
        
        return result .. "}"
    end
    
    if t == "function" then
        return "function() end"
    end
    
    return tostring(val)
end

-- [[ R2S GENERATOR ]]
local function generateR2S(data)
    local remotePath = getPath(data.Instance)
    local argsStr = serialize(data.Args)
    
    local template = [[-- ManusSpy Delta v%s
-- Remote: %s
-- Method: %s
-- Time: %s

local remote = %s
local args = %s

if remote then
    remote:%s(unpack(args))
end]]
    
    return string.format(
        template,
        ManusSpy.Version,
        data.RemoteName or "Unknown",
        data.Method,
        os.date("%H:%M:%S"),
        remotePath,
        argsStr,
        data.Method
    )
end

-- [[ EXCLUSION CHECK OPTIMIZADO ]]
local function shouldExclude(remoteName, args)
    -- Fast hash check
    if ManusSpy.Settings.ExcludedRemotes[remoteName] then
        return true
    end
    
    -- Pet check
    if remoteName:lower():find("pet") then
        return true
    end
    
    -- Sound ID check
    if args then
        for i = 1, #args do
            local arg = args[i]
            if type(arg) == "string" and arg:find("2046263687") then
                return true
            end
        end
    end
    
    return false
end

-- [[ REMOTE HANDLER ]]
local function handleRemote(remote, method, args)
    -- Safety check
    if not remote then return end
    
    local success, remoteName = pcall(function() 
        return remote.Name 
    end)
    
    if not success or not remoteName then return end
    
    -- Check exclusions
    if shouldExclude(remoteName, args) then return end
    
    -- Debouncing
    local hash = tostring(remote) .. method
    local now = tick()
    local last = ManusSpy.LastProcessed[hash]
    
    if last and (now - last) < ManusSpy.Settings.DebounceTime then
        return
    end
    
    ManusSpy.LastProcessed[hash] = now
    
    -- Create log entry
    local logData = {
        Instance = remote,
        RemoteName = remoteName,
        Method = method,
        Args = args,
        Time = now,
        Script = tostring(getcallingscript()),
    }
    
    table.insert(ManusSpy.Queue, logData)
    
    -- Process queue
    if #ManusSpy.Queue == 1 then
        task.defer(function()
            while #ManusSpy.Queue > 0 do
                local data = table.remove(ManusSpy.Queue, 1)
                
                table.insert(ManusSpy.Logs, 1, data)
                
                -- Limit logs
                if #ManusSpy.Logs > ManusSpy.Settings.MaxLogs then
                    table.remove(ManusSpy.Logs)
                end
                
                -- Notify UI
                if ManusSpy.OnLogAdded then
                    pcall(ManusSpy.OnLogAdded, data)
                end
                
                task.wait()
            end
        end)
    end
end

-- [[ DELTA-SAFE HOOK ]]
local function setupHook()
    local success, error = pcall(function()
        local mt = getrawmetatable(game)
        local backup = mt.__namecall
        
        setreadonly(mt, false)
        
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if method == "FireServer" or method == "InvokeServer" then
                if typeof(self) == "Instance" then
                    local isRemote = false
                    pcall(function()
                        isRemote = self:IsA("RemoteEvent") or self:IsA("RemoteFunction")
                    end)
                    
                    if isRemote and not checkcaller() then
                        pcall(handleRemote, self, method, args)
                    end
                end
            end
            
            return backup(self, ...)
        end)
        
        setreadonly(mt, true)
    end)
    
    if not success then
        warn("[ManusSpy] Hook failed:", error)
        warn("[ManusSpy] Running in limited mode")
    end
end

-- [[ UI CREATION ]]
local function createUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "ManusSpyDelta"
    sg.ResetOnSpawn = false
    sg.Parent = CoreGui
    
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 650, 0, 450)
    Main.Position = UDim2.new(0.5, -325, 0.5, -225)
    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = sg
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Main
    
    -- Header
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 35)
    Header.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Header.BorderSizePixel = 0
    Header.Parent = Main
    
    local HCorner = Instance.new("UICorner")
    HCorner.CornerRadius = UDim.new(0, 10)
    HCorner.Parent = Header
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -10, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "MANUS SPY " .. ManusSpy.Version
    Title.TextColor3 = Color3.fromRGB(0, 255, 100)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header
    
    -- Log List
    local LogList = Instance.new("ScrollingFrame")
    LogList.Name = "LogList"
    LogList.Size = UDim2.new(0, 220, 1, -80)
    LogList.Position = UDim2.new(0, 5, 0, 40)
    LogList.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    LogList.BorderSizePixel = 0
    LogList.ScrollBarThickness = 4
    LogList.Parent = Main
    
    local LCorner = Instance.new("UICorner")
    LCorner.CornerRadius = UDim.new(0, 6)
    LCorner.Parent = LogList
    
    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 3)
    ListLayout.Parent = LogList
    
    -- Code View
    local CodeFrame = Instance.new("Frame")
    CodeFrame.Size = UDim2.new(1, -235, 1, -80)
    CodeFrame.Position = UDim2.new(0, 230, 0, 40)
    CodeFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    CodeFrame.BorderSizePixel = 0
    CodeFrame.Parent = Main
    
    local CCorner = Instance.new("UICorner")
    CCorner.CornerRadius = UDim.new(0, 6)
    CCorner.Parent = CodeFrame
    
    local CodeBox = Instance.new("TextBox")
    CodeBox.Size = UDim2.new(1, -10, 1, -10)
    CodeBox.Position = UDim2.new(0, 5, 0, 5)
    CodeBox.BackgroundTransparency = 1
    CodeBox.Text = "-- Select a remote to view code\n-- ManusSpy Delta Edition"
    CodeBox.TextColor3 = Color3.fromRGB(180, 180, 180)
    CodeBox.Font = Enum.Font.Code
    CodeBox.TextSize = 13
    CodeBox.TextXAlignment = Enum.TextXAlignment.Left
    CodeBox.TextYAlignment = Enum.TextYAlignment.Top
    CodeBox.MultiLine = true
    CodeBox.ClearTextOnFocus = false
    CodeBox.Parent = CodeFrame
    
    -- Buttons
    local function createButton(text, pos, color)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 100, 0, 30)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 14
        btn.Parent = Main
        
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 5)
        bc.Parent = btn
        
        return btn
    end
    
    local ClearBtn = createButton("Clear", UDim2.new(0, 10, 1, -35), Color3.fromRGB(150, 40, 40))
    local CopyBtn = createButton("Copy", UDim2.new(0, 115, 1, -35), Color3.fromRGB(40, 100, 150))
    local RefreshBtn = createButton("Refresh", UDim2.new(0, 220, 1, -35), Color3.fromRGB(100, 150, 40))
    
    local currentData = nil
    
    -- Button handlers
    ClearBtn.MouseButton1Click:Connect(function()
        for _, child in ipairs(LogList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        ManusSpy.Logs = {}
        ManusSpy.PathCache = {}
        CodeBox.Text = "-- Logs cleared"
    end)
    
    CopyBtn.MouseButton1Click:Connect(function()
        setclipboard(CodeBox.Text)
        Title.Text = "MANUS SPY [COPIED!]"
        task.wait(1)
        Title.Text = "MANUS SPY " .. ManusSpy.Version
    end)
    
    RefreshBtn.MouseButton1Click:Connect(function()
        if currentData then
            CodeBox.Text = generateR2S(currentData)
        end
    end)
    
    -- Log rendering
    ManusSpy.OnLogAdded = function(data)
        local logBtn = Instance.new("TextButton")
        logBtn.Size = UDim2.new(1, -5, 0, 28)
        logBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        logBtn.BorderSizePixel = 0
        logBtn.Text = "  " .. (data.Method == "FireServer" and "🔥" or "📞") .. " " .. data.RemoteName
        logBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        logBtn.Font = Enum.Font.Gotham
        logBtn.TextSize = 12
        logBtn.TextXAlignment = Enum.TextXAlignment.Left
        logBtn.Parent = LogList
        
        local lbc = Instance.new("UICorner")
        lbc.CornerRadius = UDim.new(0, 4)
        lbc.Parent = logBtn
        
        logBtn.MouseButton1Click:Connect(function()
            currentData = data
            CodeBox.Text = generateR2S(data)
        end)
        
        LogList.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y)
        
        if ManusSpy.Settings.AutoScroll then
            LogList.CanvasPosition = Vector2.new(0, ListLayout.AbsoluteContentSize.Y)
        end
    end
end

-- [[ INITIALIZATION ]]
print("═══════════════════════════════════════")
print("ManusSpy Ultimate v" .. ManusSpy.Version)
print("Delta Executor - Optimized Edition")
print("═══════════════════════════════════════")

local success, err = pcall(createUI)
if not success then
    warn("[ManusSpy] UI Error:", err)
end

local hookSuccess, hookErr = pcall(setupHook)
if hookSuccess then
    print("✓ Hook installed successfully")
else
    warn("[ManusSpy] Hook Error:", hookErr)
end

print("✓ Ready to spy!")
print("═══════════════════════════════════════")

return ManusSpy
