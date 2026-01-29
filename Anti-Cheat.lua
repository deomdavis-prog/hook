print("[METATABLE AUDIT v11] Iniciando inspección...")

local player = game.Players.LocalPlayer
local ws = game.Workspace

-- Función para inspeccionar metatable
local function inspectMeta(obj, name)
    local mt = getmetatable(obj)
    if mt then
        print("[META] " .. name .. " tiene metatable")
        for k, v in pairs(mt) do
            print("   " .. tostring(k) .. " → " .. tostring(v))
        end
        if mt.__index then print("   ¡Tiene __index custom!")
        if mt.__newindex then print("   ¡Tiene __newindex custom! (posible protección)")
        if mt.__namecall then print("   ¡Tiene __namecall! (posible hook global)")
    else
        print("[META] " .. name .. " NO tiene metatable visible")
    end
end

-- Inspeccionar leaderstats
local leaderstats = player:WaitForChild("leaderstats", 5)
if leaderstats then
    inspectMeta(leaderstats, "leaderstats")
    for _, stat in pairs(leaderstats:GetChildren()) do
        if stat:IsA("ValueBase") then
            inspectMeta(stat, stat.Name .. " (ValueBase)")
            inspectMeta(stat.Value, stat.Name .. ".Value")
        end
    end
end

-- Inspeccionar carpeta __DEBRIS.Pets (primer pet encontrado)
local debris = ws:FindFirstChild("__DEBRIS", true)
if debris then
    local pets = debris:FindFirstChild("Pets")
    if pets then
        local somePet = pets:GetChildren()[1]
        if somePet then
            inspectMeta(somePet, "Ejemplo pet model: " .. somePet.Name)
            for _, desc in pairs(somePet:GetDescendants()) do
                if desc:IsA("ValueBase") or desc:IsA("TextLabel") then
                    inspectMeta(desc, desc:GetFullName())
                end
            end
        end
    end
end

-- Intentar hook global namecall (cuidado, puede crashear – comentado por default)
--[[
local oldNamecall
pcall(function()
    oldNamecall = getrawmetatable(game).__namecall
    setrawmetatable(game, {
        __namecall = function(self, ...)
            local method = getnamecallmethod()
            print("[NAMECALL HOOK] Método:", method, "en", self:GetFullName())
            return oldNamecall(self, ...)
        end
    })
    print("[META] Hook namecall global activado (prueba acciones)")
end)
--]]

print("[METATABLE AUDIT v11] Inspección terminada. Copia los prints arriba.")
print("Ahora haz acciones manuales (equip pet, open egg, etc.) y mira si sale algo nuevo.")
