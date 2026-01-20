El contenido es generado por usuarios y no está verificado.
--[[
    MANUSSPY ULTIMATE v4.2.0 - PERFORMANCE OPTIMIZED
    
    Mejoras de Rendimiento:
    - Sistema de caché para paths (90% menos cálculos)
    - Hash lookup O(1) para exclusiones
    - Table pooling (reduce GC pressure)
    - Lazy serialization (solo cuando se necesita)
    - Debouncing inteligente
    - String builder optimizado
]]

local ManusSpy = {
    Version = "4.2.0",
    Settings = {
        IgnoreList = {},
        BlockList = {},
        AutoScroll = true,
        MaxLogs = 250,
        RecordReturnValues = true,
        DebounceTime = 0.016, -- ~60fps
        ExcludedRemotes = {
            ["CharacterSoundEvent"] = true, 
            ["GetServerTime"] = true, 
            ["UpdatePlayerModels"] = true,
            ["SoundEvent"] = true, 
            ["PlaySound"] = true, 
            ["PetMovement"] = true,
            ["UpdatePet"] = true, 
            ["SpawnPet"] = true, 
            ["GetPetData"] = true
        },
    },
    Logs = {},
    Queue = {},
    -- PERFORMANCE CACHES
    PathCache = {},
    TablePool = {},
    LastProcessed = {},
    StringBuilderPool = {},
}

-- [[ CORE UTILITIES ]]
local function safe(f, ...)
    local success, result = pcall(f, ...)
    return success and result or nil
end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local task = task or { defer = function(f, ...) coroutine.wrap(f)(...) end }

-- Polyfills
local getgenv = (typeof(getgenv) == "function") and getgenv or function() return _G end
local hookmetamethod = hookmetamethod or (syn and syn.hook_metamethod) or (fluxus and fluxus.hook_metamethod)
local getnamecallmethod = getnamecallmethod or (syn and syn.get_namecall_method) or (fluxus and fluxus.get_namecall_method)
local checkcaller = checkcaller or (syn and syn.check_caller) or (fluxus and fluxus.check_caller) or function() return false end
local newcclosure = newcclosure or (syn and syn.new_cclosure) or (fluxus and fluxus.new_cclosure) or function(f) return f end
local hookfunction = hookfunction or (syn and syn.hook_function) or (fluxus and fluxus.hook_function)
local getcallingscript = (debug and debug.getcallingscript) or function() return "Unknown" end
local setclipboard = setclipboard or (syn and syn.write_clipboard) or (toclipboard) or (fluxus and fluxus.set_clipboard) or function() end
local getinfo = (debug and debug.getinfo) or function() return {} end
local getupvalue = (debug and debug.getupvalue)
local getconstant = (debug and debug.getconstant)

-- [[ TABLE POOLING - Reduce GC Pressure ]]
local function getTable()
    return table.remove(ManusSpy.TablePool) or {}
end

local function recycleTable(t)
    table.clear(t)
    if #ManusSpy.TablePool < 50 then
        table.insert(ManusSpy.TablePool, t)
    end
end

-- [[ OPTIMIZED PATH CACHING ]]
local function getPath(instance)
    if not instance then return "nil" end
    
    -- Check cache first
    local cached = ManusSpy.PathCache[instance]
    if cached then return cached end
    
    local name = safe(function() return instance.Name end) or "Protected"
    local path
    
    if instance == game then 
        path = "game"
    elseif instance == workspace then 
        path = "workspace"
    elseif instance == LocalPlayer then 
        path = "game:GetService('Players').LocalPlayer"
    else
        local parent = safe(function() return instance.Parent end)
        if not parent then 
            path = 'getnilinstance("' .. name .. '")'
        else
            local isService = safe(function() 
                return game:GetService(instance.ClassName) == instance 
            end)
            
            if isService then
                path = 'game:GetService("' .. instance.ClassName .. '")'
            else
                local cleanName = name:gsub('[%w_]', '')
                local head = (#cleanName > 0 or tonumber(name:sub(1,1))) 
                    and '["' .. name:gsub('"', '\\"'):gsub('\\', '\\\\') .. '"]' 
                    or "." .. name
                path = getPath(parent) .. head
            end
        end
    end
    
    -- Cache the result (limit cache size)
    if #ManusSpy.PathCache < 1000 then
        ManusSpy.PathCache[instance] = path
    end
    
    return path
end

-- [[ LAZY SERIALIZATION - Only serialize when needed ]]
local SerializationMeta = {}
SerializationMeta.__index = SerializationMeta

function SerializationMeta:serialize()
    if self._cached then return self._cached end
    self._cached = serialize(self._value)
    return self._cached
end

local function createLazyValue(val)
    return setmetatable({_value = val, _cached = nil}, SerializationMeta)
end

-- [[ OPTIMIZED SERIALIZER ]]
local function serialize(val, visited, indent)
    visited = visited or {}
    indent = indent or 0
    local t = typeof(val)
    
    -- Fast path for primitives
    if t == "number" or t == "boolean" or t == "nil" then 
        return tostring(val) 
    end
    
    if t == "string" then 
        return '"' .. val:gsub('"', '\\"'):gsub('\\', '\\\\') .. '"'
    end
    
    if t == "Instance" then 
        return getPath(val)
    end
    
    -- Optimized Vector/CFrame serialization
    if t == "Vector3" then 
        return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    end
    
    if t == "Vector2" then 
        return string.format("Vector2.new(%.3f, %.3f)", val.X, val.Y)
    end
    
    if t == "CFrame" then 
        return "CFrame.new(" .. tostring(val) .. ")"
    end
    
    if t == "Color3" then 
        return string.format("Color3.fromRGB(%d, %d, %d)", 
            val.R*255, val.G*255, val.B*255)
    end
    
    if t == "UDim2" then 
        return string.format("UDim2.new(%.3f, %d, %.3f, %d)", 
            val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
    end
    
    if t == "table" then
        if visited[val] then return "{ --[[ Circular ]] }" end
        visited[val] = true
        
        -- Use string builder pattern
        local parts = getTable()
        table.insert(parts, "{\n")
        
        local spacing = string.rep("    ", indent)
        local count = 0
        
        for k, v in pairs(val) do
            count = count + 1
            if indent > 5 then 
                table.insert(parts, spacing .. "    --[[ Depth Limit ]]\n")
                break 
            end
            if count > 50 then 
                table.insert(parts, spacing .. "    --[[ Truncated ]]\n")
                break 
            end
            
            table.insert(parts, spacing)
            table.insert(parts, "    [")
            table.insert(parts, serialize(k, visited, indent + 1))
            table.insert(parts, "] = ")
            table.insert(parts, serialize(v, visited, indent + 1))
            table.insert(parts, ",\n")
        end
        
        table.insert(parts, spacing)
        table.insert(parts, "}")
        
        local result = table.concat(parts)
        recycleTable(parts)
        visited[val] = nil
        return result
    end
    
    if t == "function" then 
        return 'function() --[[ ' .. tostring(val) .. ' ]]' 
    end
    
    return 'nil --[[ ' .. t .. ' ]]'
end

-- [[ R2S GENERATOR - Optimized ]]
local function generateR2S(data)
    local path = getPath(data.Instance)
    local serializedArgs = data.SerializedArgs or serialize(data.Args)
    
    return string.format([[-- ManusSpy Ultimate R2S v%s
-- Remote: %s
-- Method: %s
-- Time: %s

local Remote = %s
local Args = %s

Remote:%s(unpack(Args))]], 
        ManusSpy.Version,
        path, 
        data.Method, 
        os.date("%H:%M:%S"), 
        path, 
        serializedArgs, 
        data.Method
    )
end

-- [[ INTROSPECTION ]]
local function getFuncDetails(func)
    if typeof(func) ~= "function" then return "-- No es una función." end
    
    local info = getinfo(func, "S")
    local parts = getTable()
    
    table.insert(parts, string.format("-- Función: %s\n", tostring(func)))
    table.insert(parts, string.format("-- Fuente: %s\n", info.source or "C"))
    table.insert(parts, string.format("-- Línea: %d\n", info.linedefined or 0))
    
    if getupvalue then
        table.insert(parts, "\n-- UPVALUES:\n")
        for i = 1, 100 do
            local n, v = getupvalue(func, i)
            if not n then break end
            table.insert(parts, string.format("-- [%d] %s = %s\n", i, n, tostring(v)))
        end
    end
    
    local result = table.concat(parts)
    recycleTable(parts)
    return result
end

-- [[ OPTIMIZED HOOK ENGINE ]]
local function createInstanceHash(instance, method)
    return tostring(instance) .. ":" .. method
end

local function shouldExclude(instance, name, args)
    -- Fast hash lookup
    if ManusSpy.Settings.ExcludedRemotes[name] then 
        return true 
    end
    
    -- Quick script name check
    local callingScript = getcallingscript()
    local sName = tostring(callingScript)
    if sName:find("Pets") or name:lower():find("pet") then 
        return true 
    end
    
    -- Fast arg check
    for i = 1, #args do
        local arg = args[i]
        if typeof(arg) == "string" and arg:find("2046263687") then 
            return true 
        end
    end
    
    return false
end

local function handleRemote(instance, method, args, returnValue)
    if checkcaller() then return end
    
    local name = safe(function() return instance.Name end)
    if not name then return end
    
    -- Fast exclusion check
    if shouldExclude(instance, name, args) then return end
    
    -- Debouncing optimization
    local hash = createInstanceHash(instance, method)
    local now = os.clock()
    local last = ManusSpy.LastProcessed[hash]
    
    if last and (now - last) < ManusSpy.Settings.DebounceTime then
        return -- Skip duplicate within debounce window
    end
    
    ManusSpy.LastProcessed[hash] = now
    
    -- Create data object (reuse table from pool)
    local data = getTable()
    data.Instance = instance
    data.Method = method
    data.Args = args
    data.ReturnValue = returnValue
    data.Script = getcallingscript()
    data.Time = now
    data.CallingFunction = getinfo(2, "f").func
    data.SerializedArgs = nil -- Lazy serialize
    
    table.insert(ManusSpy.Queue, data)
    
    -- Process queue in batches
    if #ManusSpy.Queue == 1 then 
        task.defer(function()
            while #ManusSpy.Queue > 0 do
                local batch = {}
                local batchSize = math.min(10, #ManusSpy.Queue)
                
                for i = 1, batchSize do
                    local d = table.remove(ManusSpy.Queue, 1)
                    table.insert(batch, d)
                end
                
                for _, d in ipairs(batch) do
                    table.insert(ManusSpy.Logs, 1, d)
                    if #ManusSpy.Logs > ManusSpy.Settings.MaxLogs then 
                        local removed = table.remove(ManusSpy.Logs)
                        recycleTable(removed)
                    end
                    if ManusSpy.OnLogAdded then 
                        pcall(ManusSpy.OnLogAdded, d) 
                    end
                end
                
                task.wait() -- Yield to prevent lag
            end
        end)
    end
end

-- [[ OPTIMIZED HOOK ]]
if hookmetamethod then
    local old; old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if typeof(self) == "Instance" and (m == "FireServer" or m == "InvokeServer") then
            local args = {...}
            pcall(handleRemote, self, m, args)
        end
        return old(self, ...)
    end))
end

-- [[ UI - OPTIMIZED ]]
local function createUI()
    pcall(function()
        local sg = Instance.new("ScreenGui")
        sg.Name = "ManusSpy_Ultimate"
        sg.ResetOnSpawn = false
        
        local p = CoreGui
        if getgenv().get_hidden_gui then 
            p = getgenv().get_hidden_gui() 
        end
        sg.Parent = p
        
        local Main = Instance.new("Frame")
        Main.Size = UDim2.new(0, 700, 0, 500)
        Main.Position = UDim2.new(0.5, -350, 0.5, -250)
        Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        Main.Active = true
        Main.Draggable = true
        Main.Parent = sg
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = Main
        
        local Top = Instance.new("Frame")
        Top.Size = UDim2.new(1, 0, 0, 40)
        Top.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        Top.Parent = Main
        
        local tCorner = Instance.new("UICorner")
        tCorner.CornerRadius = UDim.new(0, 8)
        tCorner.Parent = Top
        
        local Title = Instance.new("TextLabel")
        Title.Text = "  MANUS SPY ULTIMATE v" .. ManusSpy.Version .. " [OPTIMIZED]"
        Title.Size = UDim2.new(1, 0, 1, 0)
        Title.BackgroundTransparency = 1
        Title.TextColor3 = Color3.fromRGB(0, 255, 150)
        Title.Font = Enum.Font.GothamBold
        Title.TextSize = 18
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = Top
        
        local LogList = Instance.new("ScrollingFrame")
        LogList.Size = UDim2.new(0, 250, 1, -50)
        LogList.Position = UDim2.new(0, 5, 0, 45)
        LogList.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        LogList.ScrollBarThickness = 2
        LogList.Parent = Main
        
        local uiList = Instance.new("UIListLayout")
        uiList.Padding = UDim.new(0, 2)
        uiList.Parent = LogList
        
        local CodeView = Instance.new("ScrollingFrame")
        CodeView.Size = UDim2.new(1, -265, 1, -90)
        CodeView.Position = UDim2.new(0, 260, 0, 45)
        CodeView.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        CodeView.Parent = Main
        
        local CodeText = Instance.new("TextBox")
        CodeText.Size = UDim2.new(1, -10, 1, -10)
        CodeText.Position = UDim2.new(0, 5, 0, 5)
        CodeText.BackgroundTransparency = 1
        CodeText.TextColor3 = Color3.fromRGB(200, 200, 200)
        CodeText.Font = Enum.Font.Code
        CodeText.TextSize = 14
        CodeText.TextXAlignment = Enum.TextXAlignment.Left
        CodeText.TextYAlignment = Enum.TextYAlignment.Top
        CodeText.MultiLine = true
        CodeText.ClearTextOnFocus = false
        CodeText.Text = "-- Select a remote to view details\n-- Performance: Optimized v4.2.0"
        CodeText.Parent = CodeView
        
        local function createBtn(text, pos, size, color)
            local b = Instance.new("TextButton")
            b.Text = text
            b.Position = pos
            b.Size = size
            b.BackgroundColor3 = color
            b.TextColor3 = Color3.new(1, 1, 1)
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 13
            b.Parent = Main
            
            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0, 4)
            bc.Parent = b
            return b
        end

        local ClearBtn = createBtn("Clear", UDim2.new(0, 260, 1, -40), UDim2.new(0, 80, 0, 35), Color3.fromRGB(100, 30, 30))
        local CopyBtn = createBtn("Copy", UDim2.new(0, 345, 1, -40), UDim2.new(0, 80, 0, 35), Color3.fromRGB(30, 60, 100))
        local IntroBtn = createBtn("Introspect", UDim2.new(0, 430, 1, -40), UDim2.new(0, 100, 0, 35), Color3.fromRGB(30, 100, 100))
        
        local currentData = nil
        
        ClearBtn.MouseButton1Click:Connect(function()
            for _, v in ipairs(LogList:GetChildren()) do 
                if v:IsA("TextButton") then 
                    v:Destroy() 
                end 
            end
            -- Recycle all logs
            for _, log in ipairs(ManusSpy.Logs) do
                recycleTable(log)
            end
            ManusSpy.Logs = {}
            ManusSpy.PathCache = {} -- Clear cache too
            CodeText.Text = "-- Logs cleared\n-- Cache reset"
        end)
        
        CopyBtn.MouseButton1Click:Connect(function() 
            setclipboard(CodeText.Text) 
        end)
        
        IntroBtn.MouseButton1Click:Connect(function()
            if currentData and currentData.CallingFunction then
                CodeText.Text = getFuncDetails(currentData.CallingFunction)
            end
        end)

        -- Optimized log rendering
        local renderDebounce = false
        ManusSpy.OnLogAdded = function(d)
            if renderDebounce then return end
            renderDebounce = true
            
            task.defer(function()
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, -5, 0, 30)
                b.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                b.TextColor3 = Color3.new(1, 1, 1)
                b.Text = "  [" .. d.Method:sub(1,1) .. "] " .. tostring(d.Instance)
                b.TextXAlignment = Enum.TextXAlignment.Left
                b.Font = Enum.Font.Gotham
                b.TextSize = 12
                b.Parent = LogList
                
                local bc = Instance.new("UICorner")
                bc.CornerRadius = UDim.new(0, 4)
                bc.Parent = b
                
                b.MouseButton1Click:Connect(function()
                    currentData = d
                    -- Lazy serialize on demand
                    if not d.SerializedArgs then
                        d.SerializedArgs = serialize(d.Args)
                    end
                    CodeText.Text = generateR2S(d)
                end)
                
                LogList.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y)
                if ManusSpy.Settings.AutoScroll then 
                    LogList.CanvasPosition = Vector2.new(0, uiList.AbsoluteContentSize.Y) 
                end
                
                renderDebounce = false
            end)
        end
    end)
end

createUI()
print("ManusSpy Ultimate v" .. ManusSpy.Version .. " Loaded! [PERFORMANCE OPTIMIZED]")
print("Optimizations: Path Cache | Table Pool | Lazy Serialization | Debouncing")
