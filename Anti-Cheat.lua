--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║       EXPERIMENTAL TOTAL-DUMP (ZERO FILTERS) - DELTA         ║
    ║   ADVERTENCIA: Este modo ignora protocolos de seguridad de   ║
    ║   memoria para intentar capturar el 100% del cliente.        ║
    ╚══════════════════════════════════════════════════════════════╝
]]

if not saveinstance then return warn("❌ Delta API no disponible.") end

-- [ CONFIGURACIÓN DE FUERZA BRUTA ]
local FullConfig = {
    FileName = "TOTAL_DUMP_" .. game.PlaceId .. "_" .. os.date("%H%M%S"),
    Decompile = true,
    DecompileTimeout = 9999,        -- Tiempo casi infinito por script
    DoNotDecompileAds = false,      -- Descompilar incluso basura publicitaria
    IsolatePlayers = false,         -- GUARDAR avatares, ropa y accesorios de todos
    RemovePlayerCharacters = false, -- Mantener cuerpos físicos en el Workspace
    SaveCacheProfile = false,       -- Forzar re-lectura de cada instancia
    IgnoreDefaultProps = false,     -- GUARDAR todas las propiedades (archivo muy pesado)
    ExtraInstances = {},
    -- Lista de ignorados reducida al mínimo absoluto (solo servicios que crashean el motor C++)
    IgnoreList = {
        "LogService", 
        "Stats", 
        "VoiceChatService", 
        "CoreGui" -- CoreGui se deja fuera para evitar errores de permisos de lectura de Roblox
    }
}

-- [[ 1. INYECCIÓN TOTAL DE NIL INSTANCES ]]
local function DeepNilRecovery()
    print("🧬 Escaneando ADN del juego (Nil Recovery)...")
    local folder = Instance.new("Folder")
    folder.Name = "TOTAL_RECOVERY_BIN"
    folder.Parent = game:GetService("ReplicatedStorage")
    
    if getnilinstances then
        local nilInsts = getnilinstances()
        for _, obj in ipairs(nilInsts) do
            pcall(function()
                -- Clonación sin filtros excepto por el propio juego
                if obj ~= game and obj ~= folder then
                    obj:Clone().Parent = folder
                end
            end)
        end
    end
    table.insert(FullConfig.ExtraInstances, folder)
    print("✅ Inyección de Nil completada.")
end

-- [[ 2. PREPARACIÓN DE ENTORNO ]]
local function MaximizePriority()
    print("⚡ Elevando prioridad de proceso...")
    settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
    -- Limpieza inicial para dar espacio al buffer de guardado
    collectgarbage("setpause", 100)
    collectgarbage("setstepmul", 5000)
    collectgarbage("collect")
end

-- [[ 3. EJECUCIÓN DEL VOLCADO ]]
local function ExecuteTotalDump()
    print("🔥 INICIANDO GUARDADO TOTAL. EL DISPOSITIVO PUEDE CONGELARSE.")
    print("⏳ Tiempo estimado: 1-5 minutos dependiendo del mapa.")
    
    task.wait(2)
    
    local startTime = tick()
    
    -- Usamos un hilo de alta prioridad
    task.spawn(function()
        local success, err = pcall(function()
            saveinstance(FullConfig)
        end)
        
        if success then
            local finishTime = math.floor(tick() - startTime)
            print("\n" .. string.rep("=", 35))
            print("🏆 VOLCADO TOTAL COMPLETADO")
            print("📁 Archivo: " .. FullConfig.FileName)
            print("⏱️ Duración: " .. finishTime .. "s")
            print("⚠️ Revisa tu carpeta de Delta para el archivo .rbxl")
            print(string.rep("=", 35))
        else
            warn("❌ CRASH DEL MOTOR NATIVO: " .. tostring(err))
            print("Sugerencia: Si falló por RAM, no hay nada más que hacer en este dispositivo.")
        end
        
        -- Limpieza de la carpeta temporal post-proceso
        pcall(function() game:GetService("ReplicatedStorage").TOTAL_RECOVERY_BIN:Destroy() end)
    end)
end

-- [ SECUENCIA ]
MaximizePriority()
DeepNilRecovery()
ExecuteTotalDump()
