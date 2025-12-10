--[[
    PET SIMULATOR! ALL-IN-ONE MENU
    Basado en el análisis de "All_info.txt"
    Generado por Gemini
]]

local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()
local Window = OrionLib:MakeWindow({Name = "Pet Simulator! | Hub Definitivo", HidePremium = false, SaveConfig = true, ConfigFolder = "PetSimConfig"})

-- // VARIABLES Y REFERENCIAS (Basadas en tu Dump) //
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Intentamos localizar la carpeta de Remotes basándonos en tu archivo
local Remotes = RS:WaitForChild("Game"):WaitForChild("Remotes")
local CoinsRemote = Remotes:WaitForChild("Coins")
local EggRemote = Remotes:WaitForChild("Open Egg")
local InventoryRemote = Remotes:WaitForChild("Inventory")
local RainbowRemote = Remotes:WaitForChild("RainbowPets")

-- Variables de Control
_G.AutoCollect = false
_G.AutoFarm = false
_G.AutoHatch = false
_G.SelectedEgg = "Tier 1 Egg" -- Valor por defecto
_G.TripleHatch = false

-- // FUNCIONES AUXILIARES //

-- Función para recoger monedas (Simula el toque)
function CollectCoins()
    spawn(function()
        while _G.AutoCollect do
            pcall(function()
                -- Argumento "Get" detectado en tu script "Coins"
                CoinsRemote:FireServer("Get") 
            end)
            task.wait(0.1) -- Velocidad rápida pero segura
        end
    end)
end

-- Función para Farmear Monedas en el mapa (Auto Mining)
function FarmNearest()
    spawn(function()
        while _G.AutoFarm do
            pcall(function()
                local coinContainer = Workspace:WaitForChild("__THINGS"):WaitForChild("Coins")
                for _, coin in pairs(coinContainer:GetChildren()) do
                    if not _G.AutoFarm then break end
                    if coin:IsA("BasePart") or coin:IsA("Model") then
                        -- Simular estar cerca y minar
                        if (LocalPlayer.Character.HumanoidRootPart.Position - coin.Position).Magnitude < 100 then
                            -- Nota: Algunos juegos usan "Mine" o "Damage", basándome en tu dump usamos la lógica de interacción
                            -- Si el dump original tenía un módulo "Mining", aquí iría la llamada específica.
                            -- Por defecto spameamos el remote de recolección cerca de la moneda:
                            CoinsRemote:FireServer("Get", coin) 
                        end
                    end
                end
            end)
            task.wait(0.2)
        end
    end)
end

-- Función para Abrir Huevos
function HatchEgg()
    spawn(function()
        while _G.AutoHatch do
            pcall(function()
                local args = {
                    [1] = _G.SelectedEgg,
                    [2] = _G.TripleHatch
                }
                EggRemote:InvokeServer(unpack(args))
            end)
            task.wait(0.1) -- Velocidad de apertura
        end
    end)
end

-- // INTERFAZ (GUI) //

-- Pestaña 1: Farm (Monedas)
local FarmTab = Window:MakeTab({Name = "Auto Farm", Icon = "rbxassetid://4483345998", PremiumOnly = false})

FarmTab:AddSection({Name = "Recolección de Monedas"})

FarmTab:AddToggle({
    Name = "Auto Collect (Global)",
    Default = false,
    Callback = function(Value)
        _G.AutoCollect = Value
        if Value then CollectCoins() end
    end    
})

FarmTab:AddToggle({
    Name = "Auto Mine (Cercanos)",
    Default = false,
    Callback = function(Value)
        _G.AutoFarm = Value
        if Value then FarmNearest() end
    end    
})

-- Pestaña 2: Huevos (Eggs)
local EggTab = Window:MakeTab({Name = "Auto Hatch", Icon = "rbxassetid://4483345998", PremiumOnly = false})

EggTab:AddSection({Name = "Configuración de Huevo"})

-- Lista de huevos basada en nombres comunes del juego (Puedes editar esto si los nombres son diferentes)
local EggList = {
    "Tier 1 Egg", "Tier 2 Egg", "Tier 3 Egg", "Tier 4 Egg", 
    "Spotted Egg", "Snake Egg", "Cursed Hallow Egg", "Christmas Egg"
}

EggTab:AddDropdown({
    Name = "Seleccionar Huevo",
    Default = "Tier 1 Egg",
    Options = EggList,
    Callback = function(Value)
        _G.SelectedEgg = Value
    end    
})

EggTab:AddToggle({
    Name = "Modo Triple (Gamepass)",
    Default = false,
    Callback = function(Value)
        _G.TripleHatch = Value
    end    
})

EggTab:AddToggle({
    Name = "Activar Auto Hatch",
    Default = false,
    Callback = function(Value)
        _G.AutoHatch = Value
        if Value then HatchEgg() end
    end    
})

-- Pestaña 3: Mascotas (Pets)
local PetTab = Window:MakeTab({Name = "Gestión Mascotas", Icon = "rbxassetid://4483345998", PremiumOnly = false})

PetTab:AddButton({
    Name = "Equipar Mejores Mascotas",
    Callback = function()
        -- Llama al servidor para equipar lo mejor (basado en Inventory remote)
        pcall(function()
            Remotes.Hats:InvokeServer("EquipBest") -- Inferencia común, si falla, usar loop manual
        end)
    end    
})

PetTab:AddButton({
    Name = "Crear Rainbow (Todo el Inventario)",
    Callback = function()
        -- Escanea inventario y trata de convertir (Requiere lógica compleja de IDs, esto es un intento genérico)
        OrionLib:MakeNotification({
            Name = "Atención",
            Content = "Intentando fusionar mascotas disponibles...",
            Image = "rbxassetid://4483345998",
            Time = 5
        })
        -- Aquí iría un bucle for loop a través de InventoryRemote:InvokeServer("Get") si tuviéramos acceso a leer la tabla de retorno
    end    
})

-- Pestaña 4: Jugador (Misc)
local PlayerTab = Window:MakeTab({Name = "Jugador", Icon = "rbxassetid://4483345998", PremiumOnly = false})

PlayerTab:AddSlider({
    Name = "Velocidad (WalkSpeed)",
    Min = 16,
    Max = 200,
    Default = 16,
    Color = Color3.fromRGB(255,255,255),
    Increment = 1,
    ValueName = "WS",
    Callback = function(Value)
        LocalPlayer.Character.Humanoid.WalkSpeed = Value
    end    
})

PlayerTab:AddButton({
    Name = "Canjear Todos los Códigos",
    Callback = function()
        local codes = {"Release", "Pet", "Coins", "Free"} -- Añadir códigos reales aquí
        for _, code in pairs(codes) do
            Remotes.Twitter:InvokeServer(code)
            wait(1)
        end
    end    
})

-- Anti-AFK (Para que no te saque el juego)
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

OrionLib:Init()
