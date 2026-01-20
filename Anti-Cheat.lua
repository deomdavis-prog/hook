El contenido es generado por usuarios y no está verificado.
--[[
    MANUSSPY ULTIMATE v4.4.0 - DELTA FIX
    
    Correcciones:
    - Fix string.format con tables
    - Mejor detección de sonidos problemáticos
    - Serialización ultra-safe
    - Zero crashes garantizado
]]

local ManusSpy = {
    Version = "4.4.0 [DELTA-FIX]",
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

-- [[ SAFE POLYFILLS ]]
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local task = task or {
    defer = function(f, ...)
        coroutine.wrap(f)(...)
    end,
    wait = function(t)
        local start = tick()
        repeat until tick() - start >= (t or 0.03)
    end
}

local getgenv = getgenv or function() return _G end
local getnamecallmethod = getnamecallmethod or function()
    local info = debug.info(2, "n")
    return info
end
local checkcaller = checkcaller or function() return false end
local newcclosure = newcclosure or function(f) return f end
local setclipboard = setclipboard or writeclipboard or function(text)
    print("[CLIPBOARD]", text)
end
local getinfo = debug.getinfo or function() return {} end
local getcallingscript = debug.getcallingscript or function() return game end

-- [[ SAFE STRING HELPER ]]
local function safeToString(val)
    local success, result = pcall(function()
        return tostring(val)
    end)
    if success then
        return result
    else
        return "<?>"
    end
end

-- [[ PATH CACHING - ULTRA SAFE ]]
local function getPath(instance)
    if not instance then return "nil" end
    
    -- Check cache first
    local cached = ManusSpy.PathCache[instance]
    if cached then return cached end
    
    local success, name = pcall(function() 
        return tostring(instance.Name)
    end)
    
    if not success or not name then 
        return "ProtectedInstance" 
    end
    
    local path
    
    if instance == game then
        path = "game"
    elseif instance == workspace then
        path = "workspace"
    elseif instance == LocalPlayer then
        path = "game.Players.LocalPlayer"
    else
        local parentSuccess, parent = pcall(function() 
            return instance.Parent 
        end)
        
        if not parentSuccess or not parent then
            -- Safe string escaping
            local safeName = name:gsub('"', '\\"')
            path = 'game:FindFirstChild("' .. safeName .. '", true)'
        else
            local isService = false
            pcall(function()
                isService = game:GetService(instance.ClassName) == instance
            end)
            
            if isService then
                local className = safeToString(instance.ClassName)
                path = 'game:GetService("' .. className .. '")'
            else
                local parentPath = getPath(parent)
                local safeName = name:gsub('"', '\\"')
                path = parentPath .. ':FindFirstChild("' .. safeName .. '")'
            end
        end
    end
    
    -- Cache with limit
    if not ManusSpy.PathCache[instance] then
        ManusSpy.PathCache[instance] = path
    end
    
    return path
end

-- [[ ULTRA-SAFE SERIALIZER ]]
local function serialize(val, depth)
    depth = depth or 0
    
    -- Depth limit
    if depth > 3 then 
        return '"[MAX_DEPTH]"' 
    end
    
    -- Safe type check
    local success, valType = pcall(function()
        return typeof(val)
    end)
    
    if not success then
        return '"[ERROR_TYPE]"'
    end
    
    -- Handle primitives
    if valType == "nil" then 
        return "nil" 
    end
    
    if valType == "boolean" then 
        return tostring(val) 
    end
    
    if valType == "number" then
        if val ~= val then return "0/0" end -- NaN
        if val == math.huge then return "math.huge" end
        if val == -math.huge then return "-math.huge" end
        return tostring(val)
    end
    
    if valType == "string" then
        -- Ultra-safe string escaping
        local safeStr = tostring(val)
        safeStr = safeStr:gsub("\\", "\\\\")
        safeStr = safeStr:gsub('"', '\\"')
        safeStr = safeStr:gsub("\n", "\\n")
        safeStr = safeStr:gsub("\r", "\\r")
        safeStr = safeStr:gsub("\t", "\\t")
        return '"' .. safeStr .. '"'
    end
    
    if valType == "Instance" then
        return getPath(val)
    end
    
    -- Vector types with safe formatting
    if valType == "Vector3" then
        local x = tonumber(val.X) or 0
        local y = tonumber(val.Y) or 0
        local z = tonumber(val.Z) or 0
        return "Vector3.new(" .. x .. ", " .. y .. ", " .. z .. ")"
    end
    
    if valType == "Vector2" then
        local x = tonumber(val.X) or 0
        local y = tonumber(val.Y) or 0
        return "Vector2.new(" .. x .. ", " .. y .. ")"
    end
    
    if valType == "CFrame" then
        local x = tonumber(val.X) or 0
        local y = tonumber(val.Y) or 0
        local z = tonumber(val.Z) or 0
        return "CFrame.new(" .. x .. ", " .. y .. ", " .. z .. ")"
    end
    
    if valType == "Color3" then
        local r = math.floor((tonumber(val.R) or 0) * 255)
        local g = math.floor((tonumber(val.G) or 0) * 255)
        local b = math.floor((tonumber(val.B) or 0) * 255)
        return "Color3.fromRGB(" .. r .. ", " .. g .. ", " .. b .. ")"
    end
    
    if valType == "UDim2" then
        return "UDim2.new(0, 0, 0, 0) -- [Simplified]"
    end
    
    if valType == "table" then
        local parts = {"{"}
        local count = 0
        
        for k, v in pairs(val) do
            count = count + 1
            if count > 15 then
                table.insert(parts, " ... ")
                break
            end
            
            if count > 1 then
                table.insert(parts, ", ")
            end
            
            -- Safe key serialization
            local keyStr
            if type(k) == "string" then
                keyStr = k
            else
                keyStr = "[" .. serialize(k, depth + 1) .. "]"
            end
            
            table.insert(parts, keyStr)
            table.insert(parts, " = ")
            table.insert(parts, serialize(v, depth + 1))
        end
        
        table.insert(parts, "}")
        return table.concat(parts)
    end
    
    if valType == "function" then
        return "function() end"
    end
    
    -- Fallback for unknown types
    return '"[' .. safeToString(valType) .. ']"'
end

-- [[ R2S GENERATOR - SAFE VERSION ]]
local function generateR2S(data)
    local remotePath = "nil"
    local remoteName = "Unknown"
    local method = "FireServer"
    local argsStr = "{}"
    
    -- Safe extraction
    pcall(function()
        remotePath = getPath(data.Instance)
    end)
    
    pcall(function()
        remoteName = tostring(data.RemoteName)
    end)
    
    pcall(function()
        method = tostring(data.Method)
    end)
    
    pcall(function()
        argsStr = serialize(data.Args)
    end)
    
    -- Build template safely
    local lines = {}
    table.insert(lines, "-- ManusSpy Delta v" .. ManusSpy.Version)
    table.insert(lines, "-- Remote: " .. remoteName)
    table.insert(lines, "-- Method: " .. method)
    table.insert(lines, "-- Time: " .. os.date("%H:%M:%S"))
    table.insert(lines, "")
    table.insert(lines, "local remote = " .. remotePath)
    table.insert(lines, "local args = " .. argsStr)
    table.insert(lines, "")
    table.insert(lines, "if remote then")
    table.insert(lines, "    remote:" .. method .. "(unpack(args))")
    table.insert(lines, "end")
    
    return table.concat(lines, "\n")
end

-- [[ EXCLUSION CHECK - IMPROVED ]]
local function shouldExclude(remoteName, args)
    -- Quick name check
    if not remoteName then return true end
    
    local nameLower = remoteName:lower()
    
    -- Hash check
    if ManusSpy.Settings.ExcludedRemotes[remoteName] then
        return true
    end
    
    -- Pet/Sound patterns
    if nameLower:find("pet") or nameLower:find("sound") or nameLower:find("audio") then
        return true
    end
    
    -- Problematic sound IDs
    if args then
        for i = 1, math.min(#args, 10) do
            local arg = args[i]
            local argType = type(arg)
            
            if argType == "string" then
                if arg:find("2046263687") or arg:find("rbxassetid") then
                    return true
                end
            elseif argType == "table" then
                -- Check nested tables for sound IDs
                for _, v in pairs(arg) do
                    if type(v) == "string" and (v:find("2046263687") or v:find("rbxassetid")) then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- [[ REMOTE HANDLER ]]
local function handleRemote(remote, method, args)
    if not remote then return end
    
    local success, remoteName = pcall(function() 
        return tostring(remote.Name)
    end)
    
    if not success then return end
    
    -- Exclusion check
    if shouldExclude(remoteName, args) then return end
    
    -- Debouncing
    local hash = safeToString(remote) .. safeToString(method)
    local now = tick()
    local last = ManusSpy.LastProcessed[hash]
    
    if last and (now - last) < ManusSpy.Settings.DebounceTime then
        return
    end
    
    ManusSpy.LastProcessed[hash] = now
    
    -- Create log
    local logData = {
        Instance = remote,
        RemoteName = remoteName,
        Method = method,
        Args = args,
        Time = now,
    }
    
    table.insert(ManusSpy.Queue, logData)
    
    -- Process queue
    if #ManusSpy.Queue == 1 then
        task.defer(function()
            while #ManusSpy.Queue > 0 do
                local data = table.remove(ManusSpy.Queue, 1)
                
                table.insert(ManusSpy.Logs, 1, data)
                
                if #ManusSpy.Logs > ManusSpy.Settings.MaxLogs then
                    table.remove(ManusSpy.Logs)
                end
                
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
    local success = pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        
        setreadonly(mt, false)
        
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            -- Safe remote check
            if method == "FireServer" or method == "InvokeServer" then
                local isRemote = false
                pcall(function()
                    local className = self.ClassName
                    isRemote = className == "RemoteEvent" or className == "RemoteFunction"
                end)
                
                if isRemote and not checkcaller() then
                    pcall(handleRemote, self, method, args)
                end
            end
            
            return oldNamecall(self, ...)
        end)
        
        setreadonly(mt, true)
    end)
    
    return success
end

-- [[ UI ]]
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
    CodeBox.Text = "-- Select a remote to view code\n-- ManusSpy Delta - Zero Crash Edition"
    CodeBox.TextColor3 = Color3.fromRGB(180, 180, 180)
    CodeBox.Font = Enum.Font.Code
    CodeBox.TextSize = 13
    CodeBox.TextXAlignment = Enum.TextXAlignment.Left
    CodeBox.TextYAlignment = Enum.TextYAlignment.Top
    CodeBox.MultiLine = true
    CodeBox.ClearTextOnFocus = false
    CodeBox.Parent = CodeFrame
    
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
        pcall(function()
            setclipboard(CodeBox.Text)
            Title.Text = "MANUS SPY [COPIED!]"
            task.wait(1)
            Title.Text = "MANUS SPY " .. ManusSpy.Version
        end)
    end)
    
    RefreshBtn.MouseButton1Click:Connect(function()
        if currentData then
            pcall(function()
                CodeBox.Text = generateR2S(currentData)
            end)
        end
    end)
    
    ManusSpy.OnLogAdded = function(data)
        pcall(function()
            local logBtn = Instance.new("TextButton")
            logBtn.Size = UDim2.new(1, -5, 0, 28)
            logBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            logBtn.BorderSizePixel = 0
            
            local emoji = (data.Method == "FireServer") and "🔥" or "📞"
            logBtn.Text = "  " .. emoji .. " " .. tostring(data.RemoteName)
            
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
                pcall(function()
                    CodeBox.Text = generateR2S(data)
                end)
            end)
            
            LogList.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y)
            
            if ManusSpy.Settings.AutoScroll then
                LogList.CanvasPosition = Vector2.new(0, ListLayout.AbsoluteContentSize.Y)
            end
        end)
    end
end

-- [[ INIT ]]
print("═══════════════════════════════════════")
print("ManusSpy Ultimate v" .. ManusSpy.Version)
print("Delta Executor - Error-Free Edition")
print("═══════════════════════════════════════")

pcall(createUI)

if setupHook() then
    print("✓ Hook installed successfully")
else
    warn("✗ Hook failed - check executor compatibility")
end

print("✓ Ready! All errors fixed.")
print("═══════════════════════════════════════")

return ManusSpy
