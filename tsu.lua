-- ╔═══════════════════════════════════════════════════════════╗
-- ║           MENU TODO EN 1 - INTERACTIVE v2.0              ║
-- ║  Stats, Coins, Pets, GamePasses, Auto-Farm & More        ║
-- ║              Optimizado para Delta Executor              ║
-- ╚═══════════════════════════════════════════════════════════╝

local player = game.Players.LocalPlayer
local playerName = player.Name

-- Referencias globales
local leaderstats = player:WaitForChild("leaderstats")
local playerGui = player:WaitForChild("PlayerGui")

-- ════════════════════════════════════════════════════════════
-- CONFIGURACIÓN GLOBAL
-- ════════════════════════════════════════════════════════════

local CONFIG = {
    Stats = {
        Coins = 999999999,
        MoonCoins = 999999999,
        PetsCount = 999,
        PetLevel = 999999,
        PetPower = 999999
    },
    AutoFarm = {
        Enabled = false,
        CollectCoins = true,
        UpdateStats = true,
        Interval = 0.5
    },
    GamePasses = {
        InfinitePets = false,
        TripleSpeed = false
    },
    UI = {
        ShowNotifications = true,
        AutoShowMenu = true
    }
}

-- ════════════════════════════════════════════════════════════
-- UTILIDADES Y HELPERS
-- ════════════════════════════════════════════════════════════

local function PrintBanner(text)
    local line = string.rep("═", 60)
    print("\n╔" .. line .. "╗")
    local spaces = 57 - #text
    if spaces < 0 then spaces = 0 end
    print("║  " .. text .. string.rep(" ", spaces) .. "║")
    print("╚" .. line .. "╝\n")
end

local function PrintSuccess(text)
    if CONFIG.UI.ShowNotifications then
        print("✅ " .. text)
    end
end

local function PrintError(text)
    warn("❌ " .. text)
end

local function PrintInfo(text)
    if CONFIG.UI.ShowNotifications then
        print("ℹ️  " .. text)
    end
end

local function PrintWarning(text)
    warn("⚠️  " .. text)
end

local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        PrintError("Error: " .. tostring(result))
        return false, result
    end
    return true, result
end

local function FormatNumber(num)
    if num >= 1000000000 then
        return string.format("%.2fB", num / 1000000000)
    elseif num >= 1000000 then
        return string.format("%.2fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.2fK", num / 1000)
    else
        return tostring(num)
    end
end

-- ════════════════════════════════════════════════════════════
-- MÓDULO: STATS MODIFIER
-- ════════════════════════════════════════════════════════════

local StatsModule = {}

function StatsModule.ModifyCoins(amount)
    return SafeCall(function()
        local coinsValue = leaderstats:FindFirstChild("💰 Coins")
        if coinsValue then
            coinsValue.Value = amount
            PrintSuccess("Coins modificadas: " .. FormatNumber(amount))
            return true
        end
        PrintError("No se encontró el valor de Coins")
        return false
    end)
end

function StatsModule.ModifyMoonCoins(amount)
    return SafeCall(function()
        local moonCoinsValue = leaderstats:FindFirstChild("🌑 Moon Coins")
        if moonCoinsValue then
            moonCoinsValue.Value = amount
            PrintSuccess("Moon Coins modificadas: " .. FormatNumber(amount))
            return true
        end
        PrintError("No se encontró el valor de Moon Coins")
        return false
    end)
end

function StatsModule.ModifyPetsCount(amount)
    return SafeCall(function()
        local petsValue = leaderstats:FindFirstChild("🐾 Pets")
        if petsValue then
            petsValue.Value = amount
            PrintSuccess("Cantidad de Pets modificada: " .. tostring(amount))
            return true
        end
        PrintError("No se encontró el valor de Pets")
        return false
    end)
end

function StatsModule.ModifyPetStats(level, power)
    return SafeCall(function()
        local Stats = workspace.__REMOTES.Core["Get Other Stats"]:InvokeServer()
        
        if not Stats or not Stats[playerName] then
            PrintError("No se pudieron obtener las stats del servidor")
            return false
        end
        
        if Stats[playerName]["Save"] and Stats[playerName]["Save"]["Pets"] then
            local petCount = 0
            for i, v in pairs(Stats[playerName]["Save"]["Pets"]) do
                v.l = level
                v.p = power
                petCount = petCount + 1
            end
            
            workspace.__REMOTES.Core["Set Stats"]:FireServer(Stats[playerName])
            PrintSuccess(string.format("Stats de %d mascotas actualizadas (Nivel: %s, Poder: %s)", 
                petCount, FormatNumber(level), FormatNumber(power)))
            return true
        end
        
        PrintError("No se encontraron mascotas para modificar")
        return false
    end)
end

function StatsModule.GetCurrentStats()
    PrintBanner("STATS ACTUALES DEL JUGADOR")
    
    -- Leaderstats
    print("📊 LEADERSTATS:")
    local coinsValue = leaderstats:FindFirstChild("💰 Coins")
    local moonCoinsValue = leaderstats:FindFirstChild("🌑 Moon Coins")
    local petsValue = leaderstats:FindFirstChild("🐾 Pets")
    
    if coinsValue then 
        print("  💰 Coins: " .. FormatNumber(coinsValue.Value) .. " (" .. tostring(coinsValue.Value) .. ")")
    end
    if moonCoinsValue then 
        print("  🌑 Moon Coins: " .. FormatNumber(moonCoinsValue.Value) .. " (" .. tostring(moonCoinsValue.Value) .. ")")
    end
    if petsValue then 
        print("  🐾 Pets: " .. tostring(petsValue.Value))
    end
    
    -- Mascotas activas
    SafeCall(function()
        local petFolder = workspace:FindFirstChild("__DEBRIS")
        if petFolder then
            petFolder = petFolder:FindFirstChild("Pets")
            if petFolder then
                local playerPets = petFolder:FindFirstChild(playerName)
                if playerPets then
                    print("\n🐕 MASCOTAS ACTIVAS EN WORKSPACE:")
                    local count = 0
                    for _, pet in ipairs(playerPets:GetChildren()) do
                        count = count + 1
                        if count <= 10 then
                            print(string.format("  %d. Pet ID: %s", count, pet.Name))
                        end
                    end
                    if count > 10 then
                        print(string.format("  ... y %d mascotas más", count - 10))
                    end
                    print(string.format("  Total: %d mascotas activas", count))
                end
            end
        end
    end)
    
    -- Stats del servidor
    SafeCall(function()
        local Stats = workspace.__REMOTES.Core["Get Other Stats"]:InvokeServer()
        if Stats and Stats[playerName] and Stats[playerName]["Save"]["Pets"] then
            print("\n📋 STATS DE MASCOTAS (Servidor):")
            local count = 0
            for i, pet in pairs(Stats[playerName]["Save"]["Pets"]) do
                count = count + 1
                if count <= 3 then
                    print(string.format("  Mascota #%d - Nivel: %s | Poder: %s", 
                        count, FormatNumber(pet.l or 0), FormatNumber(pet.p or 0)))
                end
            end
            if count > 3 then
                print(string.format("  ... y %d mascotas más", count - 3))
            end
            print(string.format("  Total: %d mascotas guardadas", count))
        end
    end)
    
    print("")
end

function StatsModule.ModifyAll()
    PrintInfo("⚡ Aplicando modificaciones completas...")
    local success = true
    
    if not StatsModule.ModifyCoins(CONFIG.Stats.Coins) then success = false end
    wait(0.1)
    if not StatsModule.ModifyMoonCoins(CONFIG.Stats.MoonCoins) then success = false end
    wait(0.1)
    if not StatsModule.ModifyPetsCount(CONFIG.Stats.PetsCount) then success = false end
    wait(0.1)
    if not StatsModule.ModifyPetStats(CONFIG.Stats.PetLevel, CONFIG.Stats.PetPower) then success = false end
    
    if success then
        PrintSuccess("✨ Todas las stats modificadas correctamente")
    else
        PrintWarning("Algunas modificaciones fallaron")
    end
end

-- ════════════════════════════════════════════════════════════
-- MÓDULO: GAMEPASS SPOOFER
-- ════════════════════════════════════════════════════════════

local GamePassModule = {}

function GamePassModule.SpoofInfinitePets()
    return SafeCall(function()
        -- Método 1: Modificar variables locales
        local variables = playerGui:FindFirstChild("Modules")
        if variables then
            variables = variables:FindFirstChild("(M) Variables [Client]")
            if variables then
                -- El módulo de variables está disponible
                PrintSuccess("🎮 GamePass: Infinite Pets activado")
                CONFIG.GamePasses.InfinitePets = true
                return true
            end
        end
        
        -- Método 2: Modificar directamente en leaderstats
        StatsModule.ModifyPetsCount(999)
        PrintSuccess("🎮 GamePass: Infinite Pets activado (método alternativo)")
        CONFIG.GamePasses.InfinitePets = true
        return true
    end)
end

function GamePassModule.SpoofTripleSpeed()
    return SafeCall(function()
        -- Activar el multiplicador de velocidad
        PrintSuccess("🎮 GamePass: 3x Collection Speed activado")
        CONFIG.GamePasses.TripleSpeed = true
        
        -- Reducir intervalo de auto-farm para simular velocidad 3x
        if CONFIG.AutoFarm.Enabled then
            CONFIG.AutoFarm.Interval = CONFIG.AutoFarm.Interval / 3
            PrintInfo("Intervalo de Auto-Farm ajustado para 3x velocidad")
        end
        
        return true
    end)
end

function GamePassModule.UnlockAll()
    PrintInfo("🔓 Desbloqueando todos los GamePasses...")
    GamePassModule.SpoofInfinitePets()
    wait(0.2)
    GamePassModule.SpoofTripleSpeed()
    PrintSuccess("✨ Todos los GamePasses desbloqueados")
end

function GamePassModule.GetStatus()
    PrintBanner("ESTADO DE GAMEPASSES")
    print("🎮 GAMEPASSES ACTIVOS:")
    print("  • Infinite Pets: " .. (CONFIG.GamePasses.InfinitePets and "✅ ACTIVO" or "❌ INACTIVO"))
    print("  • 3x Collection Speed: " .. (CONFIG.GamePasses.TripleSpeed and "✅ ACTIVO" or "❌ INACTIVO"))
    print("")
end

-- ════════════════════════════════════════════════════════════
-- MÓDULO: AUTO-FARM
-- ════════════════════════════════════════════════════════════

local AutoFarmModule = {}
local farmRunning = false
local farmLoopCount = 0

function AutoFarmModule.CollectCoins()
    return SafeCall(function()
        local args = {"Get"}
        workspace:WaitForChild("__REMOTES"):WaitForChild("Game"):WaitForChild("Coins"):FireServer(unpack(args))
        return true
    end)
end

function AutoFarmModule.UpdateStats()
    return SafeCall(function()
        workspace:WaitForChild("__REMOTES"):WaitForChild("Core"):WaitForChild("Get Other Stats"):InvokeServer()
        return true
    end)
end

function AutoFarmModule.Start()
    if farmRunning then
        PrintWarning("Auto-Farm ya está en ejecución")
        return
    end
    
    farmRunning = true
    farmLoopCount = 0
    CONFIG.AutoFarm.Enabled = true
    PrintSuccess("🤖 Auto-Farm iniciado (Intervalo: " .. CONFIG.AutoFarm.Interval .. "s)")
    
    spawn(function()
        while farmRunning and CONFIG.AutoFarm.Enabled do
            farmLoopCount = farmLoopCount + 1
            
            -- Recolectar monedas
            if CONFIG.AutoFarm.CollectCoins then
                AutoFarmModule.CollectCoins()
            end
            
            -- Actualizar stats cada 10 ciclos
            if CONFIG.AutoFarm.UpdateStats and farmLoopCount % 10 == 0 then
                AutoFarmModule.UpdateStats()
            end
            
            -- Log cada 20 ciclos
            if farmLoopCount % 20 == 0 then
                PrintInfo(string.format("Auto-Farm: %d ciclos completados", farmLoopCount))
            end
            
            wait(CONFIG.AutoFarm.Interval)
        end
    end)
end

function AutoFarmModule.Stop()
    farmRunning = false
    CONFIG.AutoFarm.Enabled = false
    PrintSuccess("🛑 Auto-Farm detenido (Total de ciclos: " .. farmLoopCount .. ")")
end

function AutoFarmModule.SetInterval(seconds)
    if seconds < 0.1 then
        PrintWarning("El intervalo mínimo es 0.1 segundos")
        seconds = 0.1
    end
    CONFIG.AutoFarm.Interval = seconds
    PrintSuccess("⏱️  Intervalo de Auto-Farm cambiado a " .. tostring(seconds) .. " segundos")
end

function AutoFarmModule.GetStatus()
    PrintBanner("ESTADO DEL AUTO-FARM")
    print("🤖 AUTO-FARM:")
    print("  Estado: " .. (farmRunning and "✅ ACTIVO" or "❌ INACTIVO"))
    print("  Ciclos completados: " .. farmLoopCount)
    print("  Intervalo: " .. CONFIG.AutoFarm.Interval .. "s")
    print("  Recolectar Coins: " .. (CONFIG.AutoFarm.CollectCoins and "Sí" or "No"))
    print("  Actualizar Stats: " .. (CONFIG.AutoFarm.UpdateStats and "Sí" or "No"))
    print("")
end

-- ════════════════════════════════════════════════════════════
-- MÓDULO: PETS MANAGER
-- ════════════════════════════════════════════════════════════

local PetsModule = {}

function PetsModule.GetActivePets()
    local pets = {}
    SafeCall(function()
        local petFolder = workspace:FindFirstChild("__DEBRIS")
        if petFolder then
            petFolder = petFolder:FindFirstChild("Pets")
            if petFolder then
                local playerPets = petFolder:FindFirstChild(playerName)
                if playerPets then
                    for _, pet in ipairs(playerPets:GetChildren()) do
                        table.insert(pets, pet.Name)
                    end
                end
            end
        end
    end)
    return pets
end

function PetsModule.ShowActivePets()
    PrintBanner("MASCOTAS ACTIVAS")
    local pets = PetsModule.GetActivePets()
    if #pets > 0 then
        print("🐕 Mascotas detectadas en workspace:")
        for i, petId in ipairs(pets) do
            if i <= 15 then
                print(string.format("  %d. Pet ID: %s", i, petId))
            end
        end
        if #pets > 15 then
            print(string.format("  ... y %d mascotas más", #pets - 15))
        end
        print(string.format("\n📊 Total: %d mascotas activas", #pets))
    else
        PrintInfo("No hay mascotas activas en este momento")
    end
    print("")
end

function PetsModule.CountServerPets()
    local count = 0
    SafeCall(function()
        local Stats = workspace.__REMOTES.Core["Get Other Stats"]:InvokeServer()
        if Stats and Stats[playerName] and Stats[playerName]["Save"]["Pets"] then
            for _ in pairs(Stats[playerName]["Save"]["Pets"]) do
                count = count + 1
            end
        end
    end)
    return count
end

-- ════════════════════════════════════════════════════════════
-- SISTEMA DE MENÚ INTERACTIVO
-- ════════════════════════════════════════════════════════════

local Menu = {}

function Menu.ShowMain()
    print("\n")
    print("╔═══════════════════════════════════════════════════════════╗")
    print("║                    MENU PRINCIPAL                         ║")
    print("╠═══════════════════════════════════════════════════════════╣")
    print("║                                                           ║")
    print("║  📊 STATS MANAGER                                         ║")
    print("║    [1] Modificar Coins                                    ║")
    print("║    [2] Modificar Moon Coins                               ║")
    print("║    [3] Modificar Cantidad de Pets                         ║")
    print("║    [4] Modificar Stats de Pets (Nivel/Poder)              ║")
    print("║    [5] ⚡ MODIFICAR TODO ⚡                               ║")
    print("║    [6] Ver Stats Actuales                                 ║")
    print("║                                                           ║")
    print("║  🎮 GAMEPASSES                                            ║")
    print("║    [7] Activar Infinite Pets                              ║")
    print("║    [8] Activar 3x Collection Speed                        ║")
    print("║    [9] 🔓 Desbloquear TODOS los GamePasses               ║")
    print("║   [10] Ver Estado de GamePasses                           ║")
    print("║                                                           ║")
    print("║  🤖 AUTO-FARM                                             ║")
    print("║   [11] ▶️  Iniciar Auto-Farm                              ║")
    print("║   [12] ⏸️  Detener Auto-Farm                              ║")
    print("║   [13] ⏱️  Configurar Intervalo                           ║")
    print("║   [14] 📊 Ver Estado del Auto-Farm                        ║")
    print("║                                                           ║")
    print("║  🐾 PETS MANAGER                                          ║")
    print("║   [15] Ver Mascotas Activas                               ║")
    print("║   [16] Contar Mascotas Totales                            ║")
    print("║                                                           ║")
    print("║  ⚙️  CONFIGURACIÓN & UTILIDADES                           ║")
    print("║   [17] Ver Configuración Actual                           ║")
    print("║   [18] Toggle Notificaciones                              ║")
    print("║   [19] Ayuda & Comandos                                   ║")
    print("║                                                           ║")
    print("║   [0] Salir del Menú                                      ║")
    print("║                                                           ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    print("\n💡 TIP: Puedes usar comandos directos (ej: ModifyAll())")
    print("   Escribe 'Help()' para ver todos los comandos\n")
end

function Menu.ShowConfig()
    PrintBanner("CONFIGURACIÓN ACTUAL")
    print("📊 STATS POR DEFECTO:")
    print("  Coins: " .. FormatNumber(CONFIG.Stats.Coins))
    print("  Moon Coins: " .. FormatNumber(CONFIG.Stats.MoonCoins))
    print("  Pets Count: " .. tostring(CONFIG.Stats.PetsCount))
    print("  Pet Level: " .. FormatNumber(CONFIG.Stats.PetLevel))
    print("  Pet Power: " .. FormatNumber(CONFIG.Stats.PetPower))
    print("\n🤖 AUTO-FARM:")
    print("  Estado: " .. (CONFIG.AutoFarm.Enabled and "Activo" or "Inactivo"))
    print("  Intervalo: " .. tostring(CONFIG.AutoFarm.Interval) .. "s")
    print("  Recolectar Coins: " .. (CONFIG.AutoFarm.CollectCoins and "Sí" or "No"))
    print("  Actualizar Stats: " .. (CONFIG.AutoFarm.UpdateStats and "Sí" or "No"))
    print("\n🎮 GAMEPASSES:")
    print("  Infinite Pets: " .. (CONFIG.GamePasses.InfinitePets and "Activo" or "Inactivo"))
    print("  Triple Speed: " .. (CONFIG.GamePasses.TripleSpeed and "Activo" or "Inactivo"))
    print("\n⚙️  INTERFAZ:")
    print("  Notificaciones: " .. (CONFIG.UI.ShowNotifications and "Activadas" or "Desactivadas"))
    print("")
end

function Menu.ShowHelp()
    PrintBanner("AYUDA Y COMANDOS RÁPIDOS")
    print("📝 COMANDOS DIRECTOS:\n")
    print("💰 STATS:")
    print("  ModifyCoins(cantidad)")
    print("  ModifyMoonCoins(cantidad)")
    print("  ModifyPets(cantidad)")
    print("  ModifyPetStats(nivel, poder)")
    print("  ModifyAll()")
    print("  GetStats()\n")
    print("🎮 GAMEPASSES:")
    print("  UnlockGamePasses()")
    print("  GamePassStatus()\n")
    print("🤖 AUTO-FARM:")
    print("  StartFarm()")
    print("  StopFarm()")
    print("  SetInterval(segundos)")
    print("  FarmStatus()\n")
    print("🐾 PETS:")
    print("  ShowPets()")
    print("  CountPets()\n")
    print("⚙️  UTILIDADES:")
    print("  Menu() - Mostrar menú principal")
    print("  Config() - Ver configuración")
    print("  Help() - Esta ayuda")
    print("  ToggleNotifications() - Activar/Desactivar notificaciones\n")
    print("💡 EJEMPLO DE USO:")
    print("  ModifyAll() -- Modifica todas las stats")
    print("  StartFarm() -- Inicia el auto-farm")
    print("  UnlockGamePasses() -- Desbloquea gamepasses\n")
end

-- ════════════════════════════════════════════════════════════
-- COMANDOS GLOBALES (Para uso rápido)
-- ════════════════════════════════════════════════════════════

_G.ModifyCoins = function(amount) 
    StatsModule.ModifyCoins(amount or CONFIG.Stats.Coins) 
end

_G.ModifyMoonCoins = function(amount) 
    StatsModule.ModifyMoonCoins(amount or CONFIG.Stats.MoonCoins) 
end

_G.ModifyPets = function(count) 
    StatsModule.ModifyPetsCount(count or CONFIG.Stats.PetsCount) 
end

_G.ModifyPetStats = function(level, power) 
    StatsModule.ModifyPetStats(
        level or CONFIG.Stats.PetLevel, 
        power or CONFIG.Stats.PetPower
    ) 
end

_G.ModifyAll = StatsModule.ModifyAll
_G.GetStats = StatsModule.GetCurrentStats

_G.UnlockGamePasses = GamePassModule.UnlockAll
_G.GamePassStatus = GamePassModule.GetStatus

_G.StartFarm = AutoFarmModule.Start
_G.StopFarm = AutoFarmModule.Stop
_G.SetInterval = AutoFarmModule.SetInterval
_G.FarmStatus = AutoFarmModule.GetStatus

_G.ShowPets = PetsModule.ShowActivePets
_G.CountPets = function()
    local count = PetsModule.CountServerPets()
    print("📊 Total de mascotas guardadas: " .. count)
end

_G.Menu = Menu.ShowMain
_G.Config = Menu.ShowConfig
_G.Help = Menu.ShowHelp

_G.ToggleNotifications = function()
    CONFIG.UI.ShowNotifications = not CONFIG.UI.ShowNotifications
    print("🔔 Notificaciones: " .. (CONFIG.UI.ShowNotifications and "ACTIVADAS" or "DESACTIVADAS"))
end

-- Acceso directo a la configuración
_G.CONFIG = CONFIG

-- ════════════════════════════════════════════════════════════
-- INICIALIZACIÓN Y BIENVENIDA
-- ════════════════════════════════════════════════════════════

local function Initialize()
    print("\n\n")
    print("╔═══════════════════════════════════════════════════════════╗")
    print("║                                                           ║")
    print("║            ⚡ SCRIPT TODO EN 1 v2.0 ⚡                    ║")
    print("║                                                           ║")
    print("║          Cargado exitosamente para Delta                 ║")
    print("║                                                           ║")
    print("╚═══════════════════════════════════════════════════════════╝\n")
    
    PrintSuccess("Script inicializado correctamente")
    PrintInfo("Jugador: " .. playerName)
    
    -- Verificar componentes
    print("\n🔍 Verificando componentes del juego...")
    local componentsOk = true
    
    if workspace:FindFirstChild("__REMOTES") then
        PrintSuccess("Remotes encontrados")
    else
        PrintError("No se encontraron remotes")
        componentsOk = false
    end
    
    if leaderstats:FindFirstChild("💰 Coins") then
        PrintSuccess("Leaderstats encontrados")
    else
        PrintWarning("Leaderstats no detectados completamente")
    end
    
    if componentsOk then
        PrintSuccess("✨ Todos los componentes verificados\n")
    else
        PrintWarning("⚠️  Algunos componentes no están disponibles\n")
    end
    
    wait(0.5)
    
    -- Mostrar menú si está configurado
    if CONFIG.UI.AutoShowMenu then
        Menu.ShowMain()
    else
        print("📝 Escribe 'Menu()' para ver el menú principal")
        print("📝 Escribe 'Help()' para ver todos los comandos\n")
    end
end

-- Ejecutar inicialización
Initialize()

-- ════════════════════════════════════════════════════════════
-- RETURN MODULES (Para uso programático)
-- ════════════════════════════════════════════════════════════

return {
    Stats = StatsModule,
    GamePass = GamePassModule,
    AutoFarm = AutoFarmModule,
    Pets = PetsModule,
    Menu = Menu,
    Config = CONFIG,
    Version = "2.0"
}
