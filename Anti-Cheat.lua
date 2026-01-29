-- AUDIT SCRIPT v8 - Simple, pcall everywhere for Delta stability
local function safePrint(label, ...)
    pcall(print, "[AUDIT v8]", label, ...)
end

local function safeGet(obj, name)
    return pcall(obj.FindFirstChild, obj, name) or pcall(obj.WaitForChild, obj, name, 5)
end

local player = pcall(game.GetService, game, "Players").LocalPlayer
local ws = pcall(game.GetService, game, "Workspace")
local rs = pcall(game.GetService, game, "ReplicatedStorage")
local http = pcall(game.GetService, game, "HttpService")

local IMPORTANT_REMOTES = {"Coins", "Open Egg", "Pets", "Inventory", "Get Other Stats", "Get Stats"}

local function safeWrapRemote(remote)
    if not remote then return end
    local ok, name = pcall(function() return remote.Name end)
    if ok then
        safePrint("Hooking:", remote:GetFullName(), "("..remote.ClassName..")")
    end

    if pcall(remote.IsA, remote, "RemoteEvent") then
        pcall(function()
            remote.OnClientEvent:Connect(function(...)
                safePrint("← OnClientEvent", name, ...)
            end)
        end)
        pcall(function()
            local oldFire = remote.FireServer
            remote.FireServer = function(self, ...)
                safePrint("→ FireServer", name, ...)
                return oldFire(self, ...)
            end
        end)
    elseif pcall(remote.IsA, remote, "RemoteFunction") then
        pcall(function()
            remote.OnClientInvoke = function(...)
                safePrint("← OnClientInvoke", name, ...)
                return nil
            end
        end)
        pcall(function()
            local oldInvoke = remote.InvokeServer
            remote.InvokeServer = function(self, ...)
                safePrint("→ InvokeServer", name, ...)
                local ok, result = pcall(oldInvoke, self, ...)
                if not ok then safePrint("Invoke ERROR:", result) end
                return result
            end
        end)
    end
end

-- Hook remotes
pcall(function()
    local remotesFolder = safeGet(ws, "__REMOTES")
    if remotesFolder then
        for _, folderName in ipairs({"Game", "Core"}) do
            local folder = safeGet(remotesFolder, folderName)
            if folder then
                for _, child in ipairs(pcall(folder.GetChildren, folder)) do
                    if (pcall(child.IsA, child, "RemoteEvent") or pcall(child.IsA, child, "RemoteFunction")) and table.find(IMPORTANT_REMOTES, child.Name) then
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
    local leaderstats = pcall(player.WaitForChild, player, "leaderstats", 10)
    if leaderstats then
        for _, stat in ipairs(pcall(leaderstats.GetChildren, leaderstats)) do
            if pcall(stat.IsA, stat, "ValueBase") then
                pcall(stat.Changed:Connect, stat, function(val)
                    safePrint("Leaderstat Changed:", stat.Name, "→", val)
                end)
            end
        end
        safePrint("Leaderstats monitored.")
    end
end)

-- Simple search hidden (no queue, shallow)
pcall(function()
    local parents = {ws, player.PlayerGui, rs, player}
    for _, parent in ipairs(parents) do
        if parent then
            safePrint("Buscando en:", parent:GetFullName())
            for _, obj in ipairs(pcall(parent.GetDescendants, parent)) do
                local n = string.lower(obj.Name)
                if string.find(n, "level") or string.find(n, "lvl") or string.find(n, "exp") or string.find(n, "xp") or string.find(n, "petdata") then
                    local info = obj:GetFullName() .. " | " .. obj.ClassName
                    if obj:IsA("ValueBase") then info = info .. " | Value=" .. tostring(obj.Value) end
                    if obj:IsA("TextLabel") then info = info .. " | Text=" .. obj.Text end
                    local attrs = obj:GetAttributes()
                    if next(attrs) then info = info .. " | Attrs=" .. pcall(http.JSONEncode, http, attrs) end
                    safePrint("Hidden found:", info)
                end
            end
        end
    end
end)

-- Monitor reward GUI
task.spawn(function()
    local gui = pcall(player.WaitForChild, player, "PlayerGui", 10)
    while task.wait(0.5) do
        if gui then
            for _, desc in ipairs(pcall(gui.GetDescendants, gui)) do
                if pcall(desc.IsA, desc, "TextLabel") and string.find(string.lower(desc.Text), "rewarded") then
                    safePrint("Reward GUI:", desc.Text, "Path:", desc:GetFullName())
                end
            end
        end
    end
end)

-- Monitor Pets folder
task.spawn(function()
    local debris = safeGet(ws, "__DEBRIS")
    if debris then
        local petsFolder = safeGet(debris, "Pets")
        if petsFolder then
            safePrint("Monitoring Pets:", petsFolder:GetFullName())
            pcall(petsFolder.ChildAdded:Connect, petsFolder, function(child)
                safePrint("Pet Added:", child.Name)
                for _, desc in ipairs(pcall(child.GetDescendants, child)) do
                    local n = string.lower(desc.Name)
                    if string.find(n, "level") or string.find(n, "exp") then
                        local info = desc:GetFullName() .. " | " .. desc.ClassName .. " | " .. (desc.Text or desc.Value or "")
                        safePrint("Pet Stat:", info)
                    end
                end
            end)
            pcall(petsFolder.ChildRemoved:Connect, petsFolder, function(child)
                safePrint("Pet Removed:", child.Name)
            end)
            -- Initial scan
            for _, pet in ipairs(pcall(petsFolder.GetChildren, petsFolder)) do
                safePrint("Initial Pet:", pet.Name)
                for _, desc in ipairs(pcall(pet.GetDescendants, pet)) do
                    local n = string.lower(desc.Name)
                    if string.find(n, "level") or string.find(n, "exp") then
                        local info = desc:GetFullName() .. " | " .. desc.ClassName .. " | " .. (desc.Text or desc.Value or "")
                        safePrint("Pet Stat:", info)
                    end
                end
            end
        end
    end
end)

safePrint("v8 loaded. Do manual actions 1 by 1 (equip pet, unequip, open egg, claim, buy shop) and copy logs.")
