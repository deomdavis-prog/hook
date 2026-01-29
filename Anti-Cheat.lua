-- AUDIT SCRIPT v4 - Iterativo (sin recursion), Lua 5.1 puro, WaitForChild, ultra-estable
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local ws = game.Workspace

local IMPORTANT_REMOTES = {
    "Coins", "Open Egg", "Pets", "Inventory", 
    "Get Other Stats", "Get Stats", "Claim", "Shop", 
    "Equip", "Unequip", "LevelUp", "EquipPet", "UnequipPet",
    "LevelPet", "Buy", "Collect", "Reward", "Hatch"
}

local function safePrint(label, ...)
    print("[AUDIT]", label, ...)
end

local function safeWrapRemote(remote)
    if not remote then return end
    local name = remote.Name
    safePrint("Hooking:", remote:GetFullName(), "("..remote.ClassName..")")

    if remote:IsA("RemoteEvent") then
        pcall(function()
            remote.OnClientEvent:Connect(function(...)
                safePrint("← OnClientEvent", name, ...)
            end)
        end)
        pcall(function()
            local oldFire = remote.FireServer
            remote.FireServer = function(self, ...)
                local args = {...}
                safePrint("→ FireServer", name, unpack(args))
                return oldFire(self, ...)
            end
        end)
    elseif remote:IsA("RemoteFunction") then
        pcall(function()
            remote.OnClientInvoke = function(...)
                safePrint("← OnClientInvoke", name, ...)
                return nil
            end
        end)
        pcall(function()
            local oldInvoke = remote.InvokeServer
            remote.InvokeServer = function(self, ...)
                local args = {...}
                safePrint("→ InvokeServer", name, unpack(args))
                local ok, result = pcall(oldInvoke, self, ...)
                if not ok then
                    safePrint("InvokeServer ERROR:", result)
                end
                return result
            end
        end)
    end
end

local function findAndHook(folder)
    if not folder then return end
    for _, child in ipairs(folder:GetDescendants()) do
        if (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) and table.find(IMPORTANT_REMOTES, child.Name) then
            safeWrapRemote(child)
        end
    end
end

task.wait(2)
local remotesFolder = ws:FindFirstChild("__REMOTES", true)
if remotesFolder then
    local gameFolder = remotesFolder:FindFirstChild("Game")
    local coreFolder = remotesFolder:FindFirstChild("Core")
    findAndHook(gameFolder)
    findAndHook(coreFolder)
    safePrint("Remotes hooked exitosamente.")
else
    safePrint("ERROR: No __REMOTES encontrado.")
end

task.wait(1)
local leaderstats = player:WaitForChild("leaderstats", 10)
if leaderstats then
    for _, stat in ipairs(leaderstats:GetChildren()) do
        if stat:IsA("StringValue") or stat:IsA("IntValue") or stat:IsA("NumberValue") then
            stat.Changed:Connect(function(val)
                safePrint("Leaderstat Changed:", stat.Name, "→", val)
            end)
        end
    end
    safePrint("Leaderstats monitoreados.")
else
    safePrint("ERROR: leaderstats no encontrado.")
end

-- Búsqueda ITERATIVA de valores ocultos (sin recursion, depth limit)
task.wait(2)
local function searchHidden(parent)
    if not parent then return end
    safePrint("Buscando en:", parent:GetFullName())
    local queue = {{obj = parent, depth = 0}}
    while #queue > 0 do
        local entry = table.remove(queue, 1)
        local obj = entry.obj
        local depth = entry.depth
        if depth > 5 then
            continue
        end
        local n = string.lower(obj.Name)
        local isMatch = false
        if string.find(n, "level") or string.find(n, "lvl") or string.find(n, "exp") or string.find(n, "xp") or string.find(n, "petdata") then
            isMatch = true
        end
        if isMatch then
            local info = obj:GetFullName() .. " | " .. obj.ClassName
            if obj:IsA("ValueBase") then
                info = info .. " | Value=" .. tostring(obj.Value)
            end
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                info = info .. " | Text=" .. tostring(obj.Text)
            end
            local attrs = obj:GetAttributes()
            if next(attrs) then
                info = info .. " | Attrs=" .. game:GetService("HttpService"):JSONEncode(attrs)
            end
            safePrint("Hidden data found:", info)
        end
        for _, child in ipairs(obj:GetChildren()) do
            table.insert(queue, {obj = child, depth = depth + 1})
        end
    end
end

local PlayerGui = player:WaitForChild("PlayerGui", 10)
searchHidden(ws)
if PlayerGui then
    searchHidden(PlayerGui)
end
searchHidden(ReplicatedStorage)
searchHidden(player)

safePrint("=== SCRIPT v4 CARGADO 100% === Realiza acciones manuales UNA POR UNA y pega TODOS los logs aquí.")
