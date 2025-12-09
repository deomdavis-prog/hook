-- Modificador de Stats Avanzado para Mascotas
-- Autor: Script generado
-- Descripción: Modifica stats de mascotas con interfaz de control

local player = game.Players.LocalPlayer
local playerName = player.Name

-- Configuración de Stats
local CONFIG = {
    PetLevel = 999999,      -- Nivel de mascotas
    PetPower = 999999,      -- Poder de mascotas
    AutoUpdate = false,     -- Auto-actualizar cada X segundos
    UpdateInterval = 5      -- Intervalo de actualización (segundos)
}

-- Función principal para modificar stats
local function ModifyPetStats(level, power)
    local success, err = pcall(function()
        -- Obtener stats del servidor
        local Stats = workspace.__REMOTES.Core["Get Other Stats"]:InvokeServer()
        
        if not Stats then
            warn("[Error] No se pudieron obtener las stats del servidor")
            return false
        end
        
        if not Stats[playerName] then
            warn("[Error] No se encontraron datos del jugador")
            return false
        end
        
        if not Stats[playerName]["Save"] then
            warn("[Error] No se encontró el directorio 'Save'")
            return false
        end
        
        if not Stats[playerName]["Save"]["Pets"] then
            warn("[Error] No se encontraron mascotas")
            return false
        end
        
        -- Modificar stats de todas las mascotas
        local petCount = 0
        for i, v in pairs(Stats[playerName]["Save"]["Pets"]) do
            v.l = level  -- Nivel
            v.p = power  -- Poder
            petCount = petCount + 1
        end
        
        -- Enviar stats modificadas al servidor
        workspace.__REMOTES.Core["Set Stats"]:FireServer(Stats[playerName])
        
        print(string.format("[✓] Stats modificadas exitosamente: %d mascotas actualizadas", petCount))
        print(string.format("    └─ Nivel: %d | Poder: %d", level, power))
        return true
    end)
    
    if not success then
        warn("[Error] " .. tostring(err))
        return false
    end
    
    return success
end

-- Función para modificar stats específicas
local function ModifyCustomStats(modifications)
    local success, err = pcall(function()
        local Stats = workspace.__REMOTES.Core["Get Other Stats"]:InvokeServer()
        
        if Stats and Stats[playerName] and Stats[playerName]["Save"]["Pets"] then
            for i, pet in pairs(Stats[playerName]["Save"]["Pets"]) do
                for stat, value in pairs(modifications) do
                    pet[stat] = value
                end
            end
            
            workspace.__REMOTES.Core["Set Stats"]:FireServer(Stats[playerName])
            print("[✓] Stats personalizadas aplicadas")
            return true
        end
    end)
    
    if not success then
        warn("[Error] " .. tostring(err))
    end
    
    return success
end

-- Función para obtener stats actuales
local function GetCurrentStats()
    local success, result = pcall(function()
        local Stats = workspace.__REMOTES.Core["Get Other Stats"]:InvokeServer()
        
        if Stats and Stats[playerName] and Stats[playerName]["Save"]["Pets"] then
            print("\n=== STATS ACTUALES ===")
            local count = 0
            for i, pet in pairs(Stats[playerName]["Save"]["Pets"]) do
                count = count + 1
                print(string.format("Mascota #%d:", count))
                print(string.format("  Nivel (l): %s", tostring(pet.l)))
                print(string.format("  Poder (p): %s", tostring(pet.p)))
                
                -- Mostrar otros stats disponibles
                for key, value in pairs(pet) do
                    if key ~= "l" and key ~= "p" then
                        print(string.format("  %s: %s", key, tostring(value)))
                    end
                end
                print("---")
            end
            print(string.format("Total: %d mascotas\n", count))
        else
            warn("[Error] No se pudieron obtener las stats")
        end
    end)
    
    if not success then
        warn("[Error] " .. tostring(result))
    end
end

-- Sistema de auto-actualización
local autoUpdateRunning = false
local function StartAutoUpdate()
    if autoUpdateRunning then
        warn("[Advertencia] Auto-update ya está en ejecución")
        return
    end
    
    autoUpdateRunning = true
    print("[✓] Auto-update iniciado")
    
    spawn(function()
        while autoUpdateRunning and CONFIG.AutoUpdate do
            ModifyPetStats(CONFIG.PetLevel, CONFIG.PetPower)
            wait(CONFIG.UpdateInterval)
        end
    end)
end

local function StopAutoUpdate()
    autoUpdateRunning = false
    print("[✓] Auto-update detenido")
end

-- Función para resetear stats
local function ResetStats()
    ModifyPetStats(1, 0)
    print("[✓] Stats reseteadas a valores normales")
end

-- ============================================
-- INTERFAZ DE COMANDOS
-- ============================================

print("\n╔════════════════════════════════════════╗")
print("║   MODIFICADOR DE STATS - MASCOTAS     ║")
print("╚════════════════════════════════════════╝\n")
print("Comandos disponibles:")
print("  • ModifyPetStats(nivel, poder) - Modificar stats")
print("  • GetCurrentStats() - Ver stats actuales")
print("  • ResetStats() - Resetear a valores normales")
print("  • StartAutoUpdate() - Iniciar actualización automática")
print("  • StopAutoUpdate() - Detener actualización automática")
print("\nEjemplo: ModifyPetStats(999999, 999999)\n")

-- Ejecutar modificación inicial
print("Ejecutando modificación inicial...")
ModifyPetStats(CONFIG.PetLevel, CONFIG.PetPower)

-- Si auto-update está activado, iniciarlo
if CONFIG.AutoUpdate then
    StartAutoUpdate()
end

-- Retornar funciones para uso global
return {
    Modify = ModifyPetStats,
    GetStats = GetCurrentStats,
    Reset = ResetStats,
    StartAuto = StartAutoUpdate,
    StopAuto = StopAutoUpdate,
    CustomModify = ModifyCustomStats,
    Config = CONFIG
}
