--[[
    PET SIMULATOR! - SCRIPT ACTUALIZADO (RAYFIELD)
    Solución al error HTTP 404
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Pet Simulator! | Hub Basado en Dump",
    LoadingTitle = "Cargando Scripts...",
    LoadingSubtitle = "by Gemini",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "PetSimHub",
        FileName = "HubConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true 
    },
    KeySystem = false, 
})

-- // VARIABLES Y REFERENCIAS (Basadas en tu archivo All_info.txt) //
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Intentamos localizar la carpeta de Remotes
local Remotes = RS:WaitForChild("Game"):WaitForChild("Remotes")
local CoinsRemote = Remotes:WaitForChild("Coins")
local EggRemote = Remotes:WaitForChild("Open Egg")
local InventoryRemote = Remotes:WaitForChild("Inventory")
local HallowRemote = Remotes:FindFirstChild("Halloween") -- Detectado en el dump a veces

-- Variables de Control
_G.AutoCollect = false
_G.AutoFarm = false
_G.AutoHatch = false
_G.SelectedEgg = "Tier 1 Egg"
_G.TripleHatch = false

-- // NOTIFICACIÓN DE CARGA //
Rayfield:Notify({
    Title = "Script Cargado",
    Content = "Referencias remotas conectadas correctamente.",
    Duration = 5,
    Image = 4483362458,
})

-- // LÓGICA INTERNA //

function CollectCoins()
    spawn(function()
        while _G.AutoCollect do
            pcall(function()
                CoinsRemote:FireServer("Get") 
            end)
            task.wait(0.1)
        end
    end)
end

function FarmNearest()
    spawn(function()
        while _G.AutoFarm do
            pcall(function()
                local coinContainer = Workspace:WaitForChild("__THINGS"):WaitForChild("Coins")
                for _, coin in pairs(coinContainer:GetChildren()) do
                    if not _G.AutoFarm then break end
                    if coin:IsA("BasePart") or coin:IsA("Model") then
                        if (LocalPlayer.Character.HumanoidRootPart.Position - coin.Position).Magnitude < 100 then
                            CoinsRemote:FireServer("Get", coin) 
                        end
                    end
                end
            end)
            task.wait(0.25)
        end
    end)
end

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
            task.wait(0.1)
        end
    end)
end

-- // CREACIÓN DE PESTAÑAS //

local TabFarm = Window:CreateTab("Auto Farm", 4483362458) -- Icono genérico
local TabEggs = Window:CreateTab("Huevos", 4483362458)
local TabPet = Window:CreateTab("Mascotas", 4483362458)
local TabLocal = Window:CreateTab("Jugador", 4483362458)

-- // SECCIÓN FARM //

TabFarm:CreateSection("Monedas")

TabFarm:CreateToggle({
    Name = "Auto Collect (Global)",
    CurrentValue = false,
    Flag = "ToggleCollect", 
    Callback = function(Value)
        _G.AutoCollect = Value
        if Value then CollectCoins() end
    end,
})

TabFarm:CreateToggle({
    Name = "Auto Mine (Cercanos)",
    CurrentValue = false,
    Flag = "ToggleMine", 
    Callback = function(Value)
        _G.AutoFarm = Value
        if Value then FarmNearest() end
    end,
})

-- // SECCIÓN HUEVOS //

TabEggs:CreateSection("Selección")

local EggList = {
    "Tier 1 Egg", "Tier 2 Egg", "Tier 3 Egg", "Tier 4 Egg", "Tier 5 Egg",
    "Spotted Egg", "Snake Egg", "Cursed Hallow Egg", "Christmas Egg"
}

TabEggs:CreateDropdown({
    Name = "Elegir Huevo",
    Options = EggList,
    CurrentOption = "Tier 1 Egg",
    MultipleOptions = false,
    Flag = "EggDropdown",
    Callback = function(Option)
        _G.SelectedEgg = Option[1]
    end,
})

TabEggs:CreateToggle({
    Name = "Modo Triple (Gamepass)",
    CurrentValue = false,
    Flag = "ToggleTriple", 
    Callback = function(Value)
        _G.TripleHatch = Value
    end,
})

TabEggs:CreateToggle({
    Name = "ACTIVAR Auto Hatch",
    CurrentValue = false,
    Flag = "ToggleHatch", 
    Callback = function(Value)
        _G.AutoHatch = Value
        if Value then HatchEgg() end
    end,
})

-- // SECCIÓN MASCOTAS //

TabPet:CreateButton({
    Name = "Equipar Mejor Equipo",
    Callback = function()
        pcall(function()
            Remotes.Inventory:InvokeServer("EquipBest") 
            -- Alternativa si el nombre del comando es distinto en remotes:
            Remotes.Hats:InvokeServer("EquipBest")
        end)
        Rayfield:Notify({Title = "Comando Enviado", Content = "Intentando equipar mejores mascotas.", Duration = 3})
    end,
})

-- // SECCIÓN JUGADOR //

TabLocal:CreateSlider({
    Name = "Velocidad (WalkSpeed)",
    Range = {16, 300},
    Increment = 1,
    Suffix = "Speed",
    CurrentValue = 16,
    Flag = "SliderSpeed", 
    Callback = function(Value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = Value
        end
    end,
})

TabLocal:CreateButton({
    Name = "Anti-AFK (Evitar Kick)",
    Callback = function()
        local VirtualUser = game:GetService("VirtualUser")
        LocalPlayer.Idled:connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        Rayfield:Notify({Title = "Anti-AFK", Content = "Activado correctamente.", Duration = 3})
    end,
})
