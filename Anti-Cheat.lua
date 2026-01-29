print("[AUDIT v10] Iniciando...")

local player = game.Players.LocalPlayer
local ws = game.Workspace

print("[AUDIT v10] Player y Workspace OK")

-- Leaderstats simple
local leaderstats = player:WaitForChild("leaderstats", 5)
if leaderstats then
    for _, v in pairs(leaderstats:GetChildren()) do
        if v:IsA("ValueBase") then
            v.Changed:Connect(function(new)
                print("[AUDIT v10] Leaderstat changed:", v.Name, "→", new)
            end)
        end
    end
    print("[AUDIT v10] Leaderstats monitoreado")
else
    print("[AUDIT v10] No se encontró leaderstats")
end

-- Hook básico de remotes (sin wrap complejo)
local remotesFolder = ws:FindFirstChild("__REMOTES", true)
if remotesFolder then
    print("[AUDIT v10] __REMOTES encontrado")
    for _, folder in pairs({"Game", "Core"}) do
        local f = remotesFolder:FindFirstChild(folder)
        if f then
            for _, r in pairs(f:GetChildren()) do
                if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                    print("[AUDIT v10] Remote detectado:", r:GetFullName())
                    
                    if r:IsA("RemoteEvent") then
                        r.OnClientEvent:Connect(function(...)
                            print("[AUDIT v10] ← OnClientEvent", r.Name, ...)
                        end)
                    end
                end
            end
        end
    end
else
    print("[AUDIT v10] No __REMOTES")
end

print("[AUDIT v10] Cargado. Haz acciones manuales (equip pet, open egg, etc.)")
