-- AUDIT SCRIPT v5 - Fix iterator, added GUI reward monitor, ultra-stable
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
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
    for _, child in pairs(folder:GetDescendants()) do
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
    for _, stat in pairs(leaderstats:GetChildren()) do
        if stat:IsA("ValueBase") then
            stat.Changed:Connect(function(val)
                safePrint("Leaderstat Changed:", stat.Name, "→", val)
            end)
        end
    end
    safePrint("Leaderstats monitoreados.")
else
    safePrint("ERROR: leaderstats no encontrado.")
end

-- Búsqueda ITERATIVA (pairs, pcall)
task.wait(2)
local function searchHidden(parent)
    if not parent then return end
    safePrint("Buscando en:", parent:GetFullName())
    local queue = {{obj = parent, depth = 0}}
    while #queue > 0 do
        local entry = table.remove(queue, 1)
        local obj = entry.obj
        local depth = entry.depth
        if depth > 5 then continue end
        pcall(function()
            local n = string.lower(obj.Name)
            local isMatch = string.find(n, "level") or string.find(n, "lvl") or string.find(n, "exp") or string.find(n, "xp") or string.find(n, "petdata")
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
                    info = info .. " | Attrs=" .. HttpService:JSONEncode(attrs)
                end
                safePrint("Hidden data found:", info)
            end
        end)
        for _, child in pairs(obj:GetChildren()) do
            table.insert(queue, {obj = child, depth = depth + 1})
        end
    end
end

local PlayerGui = player:WaitForChild("PlayerGui", 10)
pcall(function() searchHidden(ws) end)
if PlayerGui then pcall(function() searchHidden(PlayerGui) end) end
pcall(function() searchHidden(ReplicatedStorage) end)
pcall(function() searchHidden(player) end)

-- Monitor reward messages in GUI
task.spawn(function()
    while true do
        task.wait(0.5)
        if PlayerGui then
            for _, desc in pairs(PlayerGui:GetDescendants()) do
                if desc:IsA("TextLabel") and string.find(string.lower(desc.Text), "rewarded") then
                    safePrint("Reward GUI detected:", desc.Text, " | Path:", desc:GetFullName())
                end
            end
        end
    end
end)

safePrint("=== SCRIPT v5 CARGADO 100% === Realiza acciones manuales UNA POR UNA y pega TODOS los logs aquí.")
