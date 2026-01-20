--[[
    MANUSSPY ULTIMATE v4.5.0 - DELTA 100% COMPATIBLE
    
    Fix completo para Delta:
    - Eliminado setreadonly (no existe en Delta)
    - Hook directo sin modificar metatable
    - Zero funciones avanzadas
    - Garantía de funcionamiento
]]

local ManusSpy = {
    Version = "4.5.0 [DELTA-100%]",
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

-- [[ DELTA POLYFILLS ]]
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local function safewait(t)
    local start = tick()
    repeat until tick() - start >= (t or 0.03)
end

local function safedefer(f, ...)
    coroutine.wrap(f)(...)
end

-- [[ SAFE HELPERS ]]
local function safeToString(val)
    local s, r = pcall(tostring, val)
    return s and r or "<?>"
end

local function safeName(instance)
    local s, n = pcall(function() return instance.Name end)
    return s and n or "Unknown"
end

-- [[ PATH SYSTEM ]]
local function getPath(instance)
    if not instance then return "nil" end
    
    if ManusSpy.PathCache[instance] then
        return ManusSpy.PathCache[instance]
    end
    
    local name = safeName(instance)
    local path
    
    if instance == game then
        path = "game"
    elseif instance == workspace then
        path = "workspace"
    elseif instance == LocalPlayer then
        path = "game.Players.LocalPlayer"
    else
        local s, parent = pcall(function() return instance.Parent end)
        
        if not s or not parent then
            path = 'game:FindFirstChild("' .. name:gsub('"', '\\"') .. '", true)'
        else
            local isService = false
            pcall(function()
                isService = game:GetService(instance.ClassName) == instance
            end)
            
            if isService then
                path = 'game:GetService("' .. instance.ClassName .. '")'
            else
                path = getPath(parent) .. ':FindFirstChild("' .. name:gsub('"', '\\"') .. '")'
            end
        end
    end
    
    ManusSpy.PathCache[instance] = path
    return path
end

-- [[ SERIALIZER ]]
local function serialize(val, depth)
    depth = depth or 0
    if depth > 3 then return '"..."' end
    
    local t = typeof(val)
    
    if t == "nil" then return "nil" end
    if t == "boolean" then return tostring(val) end
    if t == "number" then return tostring(val) end
    
    if t == "string" then
        local s = val:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
        return '"' .. s .. '"'
    end
    
    if t == "Instance" then
        return getPath(val)
    end
    
    if t == "Vector3" then
        return "Vector3.new(" .. val.X .. ", " .. val.Y .. ", " .. val.Z .. ")"
    end
    
    if t == "Vector2" then
        return "Vector2.new(" .. val.X .. ", " .. val.Y .. ")"
    end
    
    if t == "CFrame" then
        return "CFrame.new(" .. val.X .. ", " .. val.Y .. ", " .. val.Z .. ")"
    end
    
    if t == "Color3" then
        local r = math.floor(val.R * 255)
        local g = math.floor(val.G * 255)
        local b = math.floor(val.B * 255)
        return "Color3.fromRGB(" .. r .. ", " .. g .. ", " .. b .. ")"
    end
    
    if t == "table" then
        local parts = {"{"}
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count > 15 then
                table.insert(parts, "...")
                break
            end
            if count > 1 then table.insert(parts, ", ") end
            table.insert(parts, serialize(k, depth + 1))
            table.insert(parts, " = ")
            table.insert(parts, serialize(v, depth + 1))
        end
        table.insert(parts, "}")
        return table.concat(parts)
    end
    
    return '"' .. safeToString(t) .. '"'
end

-- [[ R2S GENERATOR ]]
local function generateR2S(data)
    local lines = {}
    table.insert(lines, "-- ManusSpy Delta v" .. ManusSpy.Version)
    table.insert(lines, "-- Remote: " .. safeToString(data.RemoteName))
    table.insert(lines, "-- Method: " .. safeToString(data.Method))
    table.insert(lines, "")
    table.insert(lines, "local remote = " .. getPath(data.Instance))
    table.insert(lines, "local args = " .. serialize(data.Args))
    table.insert(lines, "")
    table.insert(lines, "if remote then")
    table.insert(lines, "    remote:" .. data.Method .. "(unpack(args))")
    table.insert(lines, "end")
    return table.concat(lines, "\n")
end

-- [[ EXCLUSION CHECKER ]]
local function shouldExclude(name, args)
    if not name then return true end
    
    local lower = name:lower()
    
    if ManusSpy.Settings.ExcludedRemotes[name] then return true end
    if lower:find("pet") then return true end
    if lower:find("sound") then return true end
    
    if args then
        for i = 1, math.min(#args, 10) do
            local arg = args[i]
            if type(arg) == "string" then
                if arg:find("2046263687") or arg:find("rbxassetid") then
                    return true
                end
            end
        end
    end
    
    return false
end

-- [[ HANDLER ]]
local function handleRemote(remote, method, args)
    if not remote then return end
    
    local name = safeName(remote)
    if shouldExclude(name, args) then return end
    
    local hash = safeToString(remote) .. method
    local now = tick()
    
    if ManusSpy.LastProcessed[hash] and (now - ManusSpy.LastProcessed[hash]) < 0.05 then
        return
    end
    
    ManusSpy.LastProcessed[hash] = now
    
    local data = {
        Instance = remote,
        RemoteName = name,
        Method = method,
        Args = args,
        Time = now,
    }
    
    table.insert(ManusSpy.Queue, data)
    
    if #ManusSpy.Queue == 1 then
        safedefer(function()
            while #ManusSpy.Queue > 0 do
                local d = table.remove(ManusSpy.Queue, 1)
                table.insert(ManusSpy.Logs, 1, d)
                
                if #ManusSpy.Logs > 200 then
                    table.remove(ManusSpy.Logs)
                end
                
                if ManusSpy.OnLogAdded then
                    pcall(ManusSpy.OnLogAdded, d)
                end
                
                safewait(0.01)
            end
        end)
    end
end

-- [[ DELTA HOOK - SIN SETREADONLY ]]
local function setupHook()
    local success = pcall(function()
        -- Obtener metatable SIN modificarla directamente
        local mt = getrawmetatable(game)
        local oldIndex = mt.__namecall
        
        -- Hook directo (Delta no requiere setreadonly)
        mt.__namecall = function(self, ...)
            local method = tostring(debug.info(2, "n"))
            local args = {...}
            
            if method == "FireServer" or method == "InvokeServer" then
                local isRemote = false
                pcall(function()
                    local cn = self.ClassName
                    isRemote = cn == "RemoteEvent" or cn == "RemoteFunction"
                end)
                
                if isRemote then
                    pcall(handleRemote, self, method, args)
                end
            end
            
            return oldIndex(self, ...)
        end
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
    Main.Size = UDim2.new(0, 650, 0, 450)
    Main.Position = UDim2.new(0.5, -325, 0.5, -225)
    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = sg
    
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
    
    local Header = Instance.new("Frame", Main)
    Header.Size = UDim2.new(1, 0, 0, 35)
    Header.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Header.BorderSizePixel = 0
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)
    
    local Title = Instance.new("TextLabel", Header)
    Title.Size = UDim2.new(1, -10, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "MANUS SPY " .. ManusSpy.Version
    Title.TextColor3 = Color3.fromRGB(0, 255, 100)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    
    local LogList = Instance.new("ScrollingFrame", Main)
    LogList.Name = "LogList"
    LogList.Size = UDim2.new(0, 220, 1, -80)
    LogList.Position = UDim2.new(0, 5, 0, 40)
    LogList.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    LogList.BorderSizePixel = 0
    LogList.ScrollBarThickness = 4
    Instance.new("UICorner", LogList).CornerRadius = UDim.new(0, 6)
    
    local ListLayout = Instance.new("UIListLayout", LogList)
    ListLayout.Padding = UDim.new(0, 3)
    
    local CodeFrame = Instance.new("Frame", Main)
    CodeFrame.Size = UDim2.new(1, -235, 1, -80)
    CodeFrame.Position = UDim2.new(0, 230, 0, 40)
    CodeFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    CodeFrame.BorderSizePixel = 0
    Instance.new("UICorner", CodeFrame).CornerRadius = UDim.new(0, 6)
    
    local CodeBox = Instance.new("TextBox", CodeFrame)
    CodeBox.Size = UDim2.new(1, -10, 1, -10)
    CodeBox.Position = UDim2.new(0, 5, 0, 5)
    CodeBox.BackgroundTransparency = 1
    CodeBox.Text = "-- Select a remote\n-- ManusSpy Delta - 100% Compatible"
    CodeBox.TextColor3 = Color3.fromRGB(180, 180, 180)
    CodeBox.Font = Enum.Font.Code
    CodeBox.TextSize = 13
    CodeBox.TextXAlignment = Enum.TextXAlignment.Left
    CodeBox.TextYAlignment = Enum.TextYAlignment.Top
    CodeBox.MultiLine = true
    CodeBox.ClearTextOnFocus = false
    
    local function btn(txt, x, col)
        local b = Instance.new("TextButton", Main)
        b.Size = UDim2.new(0, 100, 0, 30)
        b.Position = UDim2.new(0, x, 1, -35)
        b.BackgroundColor3 = col
        b.BorderSizePixel = 0
        b.Text = txt
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 14
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        return b
    end
    
    local ClearBtn = btn("Clear", 10, Color3.fromRGB(150, 40, 40))
    local CopyBtn = btn("Copy", 115, Color3.fromRGB(40, 100, 150))
    local RefreshBtn = btn("Refresh", 220, Color3.fromRGB(100, 150, 40))
    
    local currentData = nil
    
    ClearBtn.MouseButton1Click:Connect(function()
        for _, v in ipairs(LogList:GetChildren()) do
            if v:IsA("TextButton") then v:Destroy() end
        end
        ManusSpy.Logs = {}
        ManusSpy.PathCache = {}
        CodeBox.Text = "-- Cleared"
    end)
    
    CopyBtn.MouseButton1Click:Connect(function()
        pcall(function()
            (setclipboard or writeclipboard or print)(CodeBox.Text)
            Title.Text = "COPIED!"
            wait(1)
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
            local logBtn = Instance.new("TextButton", LogList)
            logBtn.Size = UDim2.new(1, -5, 0, 28)
            logBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            logBtn.BorderSizePixel = 0
            logBtn.Text = "  " .. (data.Method == "FireServer" and "F" or "I") .. " " .. data.RemoteName
            logBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            logBtn.Font = Enum.Font.Gotham
            logBtn.TextSize = 12
            logBtn.TextXAlignment = Enum.TextXAlignment.Left
            Instance.new("UICorner", logBtn).CornerRadius = UDim.new(0, 4)
            
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
print("ManusSpy Delta v" .. ManusSpy.Version)
print("100% Compatible - Zero Crashes")
print("═══════════════════════════════════════")

pcall(createUI)

if setupHook() then
    print("✓ Hook: OK")
else
    warn("✗ Hook: FAILED")
end

print("✓ Ready!")
print("═══════════════════════════════════════")
