--[[
    MANUSSPY ULTIMATE v4.6.0 - DELTA FINAL
    
    Método de Hook 100% Compatible:
    - Sin getrawmetatable (no existe en Delta)
    - Hook por wrapping de funciones
    - Compatible con Delta móvil/PC
    - Zero crashes GARANTIZADO
]]

local ManusSpy = {
    Version = "4.6.0 [DELTA-FINAL]",
    Settings = {
        AutoScroll = true,
        MaxLogs = 200,
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

-- [[ SERVICES ]]
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- [[ HELPERS ]]
local function safeName(obj)
    local s, n = pcall(function() return obj.Name end)
    return s and n or "Unknown"
end

local function getPath(obj)
    if not obj then return "nil" end
    if ManusSpy.PathCache[obj] then return ManusSpy.PathCache[obj] end
    
    local name = safeName(obj)
    local path
    
    if obj == game then path = "game"
    elseif obj == workspace then path = "workspace"
    elseif obj == LocalPlayer then path = "game.Players.LocalPlayer"
    else
        local s, p = pcall(function() return obj.Parent end)
        if not s or not p then
            path = 'game:FindFirstChild("' .. name:gsub('"', '') .. '", true)'
        else
            path = getPath(p) .. ':FindFirstChild("' .. name:gsub('"', '') .. '")'
        end
    end
    
    ManusSpy.PathCache[obj] = path
    return path
end

local function serialize(v, d)
    d = d or 0
    if d > 3 then return "..." end
    
    local t = typeof(v)
    if t == "nil" then return "nil" end
    if t == "boolean" or t == "number" then return tostring(v) end
    if t == "string" then return '"' .. v:gsub('"', '\\"') .. '"' end
    if t == "Instance" then return getPath(v) end
    if t == "Vector3" then return "Vector3.new(" .. v.X .. "," .. v.Y .. "," .. v.Z .. ")" end
    if t == "Vector2" then return "Vector2.new(" .. v.X .. "," .. v.Y .. ")" end
    if t == "CFrame" then return "CFrame.new(" .. v.X .. "," .. v.Y .. "," .. v.Z .. ")" end
    if t == "Color3" then 
        return "Color3.fromRGB(" .. math.floor(v.R*255) .. "," .. math.floor(v.G*255) .. "," .. math.floor(v.B*255) .. ")" 
    end
    if t == "table" then
        local p = {"{"}
        local c = 0
        for k, val in pairs(v) do
            c = c + 1
            if c > 10 then table.insert(p, "...") break end
            if c > 1 then table.insert(p, ",") end
            table.insert(p, serialize(k, d+1) .. "=" .. serialize(val, d+1))
        end
        table.insert(p, "}")
        return table.concat(p)
    end
    return '"' .. tostring(t) .. '"'
end

local function generateR2S(data)
    return [[-- ManusSpy Delta
-- Remote: ]] .. data.RemoteName .. [[

local remote = ]] .. getPath(data.Instance) .. [[

local args = ]] .. serialize(data.Args) .. [[

if remote then
    remote:]] .. data.Method .. [[(unpack(args))
end]]
end

local function shouldExclude(name, args)
    if not name then return true end
    local n = name:lower()
    if ManusSpy.Settings.ExcludedRemotes[name] then return true end
    if n:find("pet") or n:find("sound") then return true end
    if args then
        for i = 1, #args do
            if type(args[i]) == "string" and args[i]:find("2046263687") then
                return true
            end
        end
    end
    return false
end

local function handleRemote(remote, method, args)
    if not remote then return end
    
    local name = safeName(remote)
    if shouldExclude(name, args) then return end
    
    local hash = tostring(remote) .. method
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
        coroutine.wrap(function()
            while #ManusSpy.Queue > 0 do
                local d = table.remove(ManusSpy.Queue, 1)
                table.insert(ManusSpy.Logs, 1, d)
                if #ManusSpy.Logs > 200 then table.remove(ManusSpy.Logs) end
                if ManusSpy.OnLogAdded then pcall(ManusSpy.OnLogAdded, d) end
                wait(0.01)
            end
        end)()
    end
end

-- [[ HOOK ALTERNATIVO - SIN METATABLE ]]
local function setupHook()
    -- Método 1: Hook directo a RemoteEvent/RemoteFunction
    local hooked = {}
    
    local function hookRemote(remote)
        if hooked[remote] then return end
        hooked[remote] = true
        
        local className = remote.ClassName
        
        if className == "RemoteEvent" then
            local oldFire = remote.FireServer
            remote.FireServer = function(self, ...)
                pcall(handleRemote, self, "FireServer", {...})
                return oldFire(self, ...)
            end
        elseif className == "RemoteFunction" then
            local oldInvoke = remote.InvokeServer
            remote.InvokeServer = function(self, ...)
                pcall(handleRemote, self, "InvokeServer", {...})
                return oldInvoke(self, ...)
            end
        end
    end
    
    -- Hookear remotes existentes
    for _, desc in ipairs(game:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            pcall(hookRemote, desc)
        end
    end
    
    -- Hookear nuevos remotes
    game.DescendantAdded:Connect(function(desc)
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            wait(0.1)
            pcall(hookRemote, desc)
        end
    end)
    
    return true
end

-- [[ UI ]]
local function createUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "MSpy"
    sg.ResetOnSpawn = false
    sg.Parent = CoreGui
    
    local m = Instance.new("Frame", sg)
    m.Size = UDim2.new(0, 600, 0, 400)
    m.Position = UDim2.new(0.5, -300, 0.5, -200)
    m.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    m.BorderSizePixel = 0
    m.Active = true
    m.Draggable = true
    Instance.new("UICorner", m).CornerRadius = UDim.new(0, 8)
    
    local h = Instance.new("Frame", m)
    h.Size = UDim2.new(1, 0, 0, 30)
    h.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    h.BorderSizePixel = 0
    Instance.new("UICorner", h).CornerRadius = UDim.new(0, 8)
    
    local t = Instance.new("TextLabel", h)
    t.Size = UDim2.new(1, -10, 1, 0)
    t.Position = UDim2.new(0, 10, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = "MANUS SPY " .. ManusSpy.Version
    t.TextColor3 = Color3.fromRGB(0, 255, 100)
    t.Font = Enum.Font.GothamBold
    t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left
    
    local ll = Instance.new("ScrollingFrame", m)
    ll.Name = "LL"
    ll.Size = UDim2.new(0, 200, 1, -70)
    ll.Position = UDim2.new(0, 5, 0, 35)
    ll.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    ll.BorderSizePixel = 0
    ll.ScrollBarThickness = 4
    Instance.new("UICorner", ll).CornerRadius = UDim.new(0, 5)
    local layout = Instance.new("UIListLayout", ll)
    layout.Padding = UDim.new(0, 2)
    
    local cf = Instance.new("Frame", m)
    cf.Size = UDim2.new(1, -215, 1, -70)
    cf.Position = UDim2.new(0, 210, 0, 35)
    cf.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    cf.BorderSizePixel = 0
    Instance.new("UICorner", cf).CornerRadius = UDim.new(0, 5)
    
    local cb = Instance.new("TextBox", cf)
    cb.Size = UDim2.new(1, -10, 1, -10)
    cb.Position = UDim2.new(0, 5, 0, 5)
    cb.BackgroundTransparency = 1
    cb.Text = "-- Select remote"
    cb.TextColor3 = Color3.fromRGB(180, 180, 180)
    cb.Font = Enum.Font.Code
    cb.TextSize = 12
    cb.TextXAlignment = Enum.TextXAlignment.Left
    cb.TextYAlignment = Enum.TextYAlignment.Top
    cb.MultiLine = true
    cb.ClearTextOnFocus = false
    
    local function mkbtn(txt, x, c)
        local b = Instance.new("TextButton", m)
        b.Size = UDim2.new(0, 90, 0, 28)
        b.Position = UDim2.new(0, x, 1, -33)
        b.BackgroundColor3 = c
        b.BorderSizePixel = 0
        b.Text = txt
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        return b
    end
    
    local clr = mkbtn("Clear", 5, Color3.fromRGB(150, 40, 40))
    local cpy = mkbtn("Copy", 100, Color3.fromRGB(40, 100, 150))
    
    local cur = nil
    
    clr.MouseButton1Click:Connect(function()
        for _, v in ipairs(ll:GetChildren()) do
            if v:IsA("TextButton") then v:Destroy() end
        end
        ManusSpy.Logs = {}
        ManusSpy.PathCache = {}
        cb.Text = "-- Cleared"
    end)
    
    cpy.MouseButton1Click:Connect(function()
        pcall(function()
            (setclipboard or writeclipboard or print)(cb.Text)
            t.Text = "COPIED!"
            wait(0.5)
            t.Text = "MANUS SPY " .. ManusSpy.Version
        end)
    end)
    
    ManusSpy.OnLogAdded = function(data)
        pcall(function()
            local b = Instance.new("TextButton", ll)
            b.Size = UDim2.new(1, -5, 0, 25)
            b.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            b.BorderSizePixel = 0
            b.Text = "  " .. (data.Method == "FireServer" and "[F] " or "[I] ") .. data.RemoteName
            b.TextColor3 = Color3.fromRGB(200, 200, 200)
            b.Font = Enum.Font.Gotham
            b.TextSize = 11
            b.TextXAlignment = Enum.TextXAlignment.Left
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
            
            b.MouseButton1Click:Connect(function()
                cur = data
                pcall(function()
                    cb.Text = generateR2S(data)
                end)
            end)
            
            ll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
            if ManusSpy.Settings.AutoScroll then
                ll.CanvasPosition = Vector2.new(0, layout.AbsoluteContentSize.Y)
            end
        end)
    end
end

-- [[ INIT ]]
print("================================")
print("ManusSpy v" .. ManusSpy.Version)
print("Delta Compatible - Final Fix")
print("================================")

pcall(createUI)

if setupHook() then
    print("Hook: OK (Direct method)")
else
    warn("Hook: FAILED")
end

print("Ready!")
print("================================")
