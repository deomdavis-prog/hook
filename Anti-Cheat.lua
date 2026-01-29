-- AUDIT SCRIPT v7 - Usa paths de DIRECCIONES.txt, dump tables, monitor pets
local player = game.Players.LocalPlayer
local ws = game.Workspace
local rs = game.ReplicatedStorage

local IMPORTANT_REMOTES = { -- Igual v6
    "Coins", "Open Egg", "Pets", "Inventory", "Get Other Stats", "Get Stats", "Claim", "Shop", 
    "Equip", "Unequip", "LevelUp", "EquipPet", "UnequipPet", "LevelPet", "Buy", "Collect", "Reward", "Hatch"
}

local function safePrint(label, ...)
    print("[AUDIT v7]", label, ...)
end

local function dumpTable(t, depth)
    depth = depth or 0
    if depth > 3 then return "{deep}" end
    if type(t) != "table" then return tostring(t) end
    local str = "{"
    for k, v in pairs(t) do
        str = str .. tostring(k) .. "=" .. dumpTable(v, depth + 1) .. ", "
    end
    return str .. "}"
end

local function safeWrapRemote(remote)
    if not remote then return end
    local name = remote.Name
    safePrint("Hooking:", remote:GetFullName(), "("..remote.ClassName..")")

    if remote:IsA("RemoteEvent") then
        pcall(function()
            remote.OnClientEvent:Connect(function(...)
                local args = {...}
                for i, arg in ipairs(args) do
                    if type(arg) == "table" then args[i] = dumpTable(arg) end
                end
                safePrint("← OnClientEvent", name, unpack(args))
            end)
        end)
        pcall(function()
            local oldFire = remote.FireServer
            remote.FireServer = function(self, ...)
                local args = {...}
                for i, arg in ipairs(args) do
                    if type(arg) == "table" then args[i] = dumpTable(arg) end
                end
                safePrint("→ FireServer", name, unpack(args))
                return oldFire(self, ...)
            end
        end)
    elseif remote:IsA("RemoteFunction") then
        pcall(function()
            remote.OnClientInvoke = function(...)
                local args = {...}
                for i, arg in ipairs(args) do
                    if type(arg) == "table" then args[i] = dumpTable(arg) end
                end
                safePrint("← OnClientInvoke", name, unpack(args))
                return nil
            end
        end)
        pcall(function()
            local oldInvoke = remote.InvokeServer
            remote.InvokeServer = function(self, ...)
                local args = {...}
                for i, arg in ipairs(args) do
                    if type(arg) == "table" then args[i] = dumpTable(arg) end
                end
                safePrint("→ InvokeServer", name, unpack(args))
                local ok, result = pcall(oldInvoke, self, ...)
                if not ok then
                    safePrint("Invoke ERROR:", result)
                end
                return result
            end
        end)
    end
end

-- Hook remotes
task.wait(2)
local remotesFolder = ws:FindFirstChild("__REMOTES", true)
if remotesFolder then
    for _, folder in {"Game", "Core"} do
        local subFolder = remotesFolder:FindFirstChild(folder)
        if subFolder then
            findAndHook = function(f) -- Local func
                for _, child in pairs(f:GetDescendants()) do
                    if (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) and table.find(IMPORTANT_REMOTES, child.Name) then
                        safeWrapRemote(child)
                    end
                end
            end
            findAndHook(subFolder)
        end
    end
    safePrint("Remotes hooked.")
end

-- Leaderstats
local leaderstats = player:WaitForChild("leaderstats", 10)
if leaderstats then
    for _, stat in pairs(leaderstats:GetChildren()) do
        if stat:IsA("ValueBase") then
            stat.Changed:Connect(function(val)
                safePrint("Leaderstat Changed:", stat.Name, "→", val)
            end
        end
    end
    safePrint("Leaderstats monitored.")
end

-- Search from DIRECCIONES.txt paths (targeted, no full scan)
task.wait(2)
local function checkPath(pathStr)
    local obj = game
    for part in string.gmatch(pathStr, "[^%.]+") do
        obj = obj:FindFirstChild(part) or obj:FindFirstChild(part, true)
        if not obj then return end
    end
    if obj then
        local n = string.lower(obj.Name)
        local isMatch = string.find(n, "level") or string.find(n, "lvl") or string.find(n, "exp") or string.find(n, "xp") or string.find(n, "petdata")
        if isMatch then
            local info = obj:GetFullName() .. " | " .. obj.ClassName
            if obj:IsA("ValueBase") then info = info .. " | Value=" .. tostring(obj.Value) end
            if obj:IsA("TextLabel") then info = info .. " | Text=" .. obj.Text end
            local attrs = obj:GetAttributes()
            if next(attrs) then info = info .. " | Attrs=" .. dumpTable(attrs) end
            safePrint("Hidden in path:", info)
        end
    end
end

-- List of relevant paths from your txt (filtered to potential matches)
local paths = { -- Agregué los hits de mi análisis
    "Players.If_IBeatYou.PlayerGui.PremiumShop.Frame.Gamepasses.Sprint, 1.5x XP, and more!",
    "Players.If_IBeatYou.PlayerGui.PremiumShop.Frame.Gamepasses.2x XP!",
    "ReplicatedStorage.Assets.Billboards.XP",
    "ReplicatedStorage.Assets.Billboards.Level",
    "ReplicatedStorage.Assets.Particles.LevelUp",
    "ReplicatedStorage.Assets.InfoOverlay.Blocks.Block_Level",
    "ReplicatedStorage.Assets.InfoOverlay.Blocks.Block_XP",
    "ReplicatedStorage.Assets.InfoOverlay.Blocks.Block_Level.Level",
    "ReplicatedStorage.Assets.Other.Unbox Info.SurfaceGui.ItemLevel",
    "Players.If_IBeatYou.PlayerGui.Scripts.GUIs.Inventory.Pet.Pet.Level",
    "Players.If_IBeatYou.PlayerGui.Scripts.GUIs.Trading.Pet.Pet.Level",
    -- Agrega más si necesitas, pero estos son los principales
}

for _, p in ipairs(paths) do
    pcall(checkPath, p)
end

-- Monitor Pets folder + GUI rewards (igual v6)
-- ... (copia el monitor de v6 para __DEBRIS.Pets y Reward GUI)

safePrint("v7 loaded. Do manual actions & check for →/← with dumped args.")
