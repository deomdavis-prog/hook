local game = game
local print = print
local pcall = pcall
local ipairs = ipairs
local table = table
local string = string
local task = task
local os = os

local function safePrint(label, ...)
    pcall(print, "[AUDIT v9]", label, ...)
end

local player = pcall(game.GetService, game, "Players").LocalPlayer
local ws = pcall(game.GetService, game, "Workspace")

local IMPORTANT_REMOTES = {"Coins", "Open Egg", "Pets", "Inventory", "Get Other Stats", "Get Stats"}

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
            local old = remote.FireServer
            remote.FireServer = function(self, ...)
                safePrint("→ FireServer", name, ...)
                return old(self, ...)
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
            local old = remote.InvokeServer
            remote.InvokeServer = function(self, ...)
                safePrint("→ InvokeServer", name, ...)
                local ok, result = pcall(old, self, ...)
                if not ok then safePrint("Invoke ERROR:", result) end
                return result
            end
        end)
    end
end

-- Hook remotes
pcall(function()
    local remotes = ws:FindFirstChild("__REMOTES", true)
    if remotes then
        for _, fName in ipairs({"Game", "Core"}) do
            local folder = remotes:FindFirstChild(fName)
            if folder then
                for _, child in ipairs(folder:GetChildren()) do
                    if (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) and table.find(IMPORTANT_REMOTES, child.Name) then
                        safeWrapRemote(child)
                    end
                end
            end
        end
        safePrint("Remotes hooked.")
    end
end)

-- Leaderstats
pcall(function()
    local leaderstats = player:WaitForChild("leaderstats", 10)
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat:IsA("ValueBase") then
                stat.Changed:Connect(function(val)
                    safePrint("Leaderstat Changed:", stat.Name, "→", val)
                end)
            end
        end
        safePrint("Leaderstats monitored.")
    end
end)

-- Simple search (shallow, no deep descend)
pcall(function()
    local parents = {ws, player.PlayerGui, game.ReplicatedStorage, player}
    for _, parent in ipairs(parents) do
        if parent then
            safePrint("Buscando en:", parent:GetFullName())
            for _, obj in ipairs(parent:GetDescendants()) do
                local n = string.lower(obj.Name)
                if string.find(n, "level") or string.find(n, "lvl") or string.find(n, "exp") or string.find(n, "xp") or string.find(n, "petdata") then
                    local info = obj:GetFullName() .. " | " .. obj.ClassName
                    if obj:IsA("ValueBase") then info = info .. " | Value=" .. tostring(obj.Value) end
                    if obj:IsA("TextLabel") then info = info .. " | Text=" .. obj.Text end
                    safePrint("Hidden found:", info)
                end
            end
        end
    end
end)

-- Reward GUI monitor (simple loop)
task.wait(2)
while true do
    pcall(function()
        local gui = player.PlayerGui
        for _, desc in ipairs(gui:GetDescendants()) do
            if desc:IsA("TextLabel") and string.find(string.lower(desc.Text), "rewarded") then
                safePrint("Reward GUI:", desc.Text, "Path:", desc:GetFullName())
            end
        end
    end)
    task.wait(0.5)
end

safePrint("v9 loaded. Do manual actions (equip, open egg etc.) and copy logs.")
