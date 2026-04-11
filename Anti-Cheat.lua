--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║        OMNI-DUMPER V3 (ULTIMATE ADAPTIVE EDITION)            ║
    ║   Bypass de API, Recuperación Total y Prioridad Crítica      ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- [ 1. BUSCADOR DE API NATIVA ]
local save_func = saveinstance or (delta and delta.saveinstance) or syn_save_instance or (fluxus and fluxus.save_instance)

if not save_func then
    print("⚠️ API estándar no hallada. Intentando puente alternativo...")
    -- Intento de recuperación si la función está oculta en el entorno global
    for k, v in pairs(getfenv()) do
        if k:lower():find("save") and k:lower():find("inst") then
            save_func = v
            print("✅ API recuperada bajo el nombre: " .. k)
            break
        end
    end
end

if not save_func then
    return warn("❌ [ERROR FATAL]: Delta ha deshabilitado 'saveinstance' en esta build. No se puede proceder sin el motor C++.")
end

-- [ 2. CONFIGURACIÓN SIN LÍMITES ]
local DumpConfig = {
    FileName = "FULL_EXTRACT_" .. game.PlaceId .. "_" .. math.random(1000, 9999),
    Decompile = true,
    DecompileTimeout = 10000, -- Tiempo extremo
    IsolatePlayers = false,   -- No aislar nada, copiar todo
    SaveCacheProfile = false,
    IgnoreDefaultProps = false,
    -- Solo omitimos lo que causa cierre inmediato por falta de permisos de Roblox
    IgnoreList = {"LogService", "Stats", "VoiceChatService", "VersionControlService"}
}

-- [ 3. RECOLECCIÓN PROFUNDA DE NIL ]
local function GetEverything()
    local container = Instance.new("Folder")
    container.Name = "CORE_DUMP_RECOVERY"
    container.Parent = game:GetService("ReplicatedStorage")
    
    if getnilinstances then
        print("🌀 Extrayendo instancias del Limbo (Nil)...")
        for _, obj in ipairs(getnilinstances()) do
            pcall(function()
                if obj ~= game and not obj:IsDescendantOf(game) then
                    obj:Clone().Parent = container
                end
            end)
        end
    end
    return container
end

-- [ 4. PROTOCOLO DE EJECUCIÓN ]
local function Execute()
    print("🔥 PREPARANDO VOLCADO TOTAL...")
    local recovery = GetEverything()
    
    -- Ajuste de rendimiento para evitar que el OS mate a Delta
    if setfpscap then setfpscap(10) end -- Baja los FPS para dedicar la CPU al Dump
    
    task.wait(1)
    
    local success, err = pcall(function()
        save_func(DumpConfig)
    end)
    
    if success then
        print("\n" .. string.rep("⭐", 10))
        print("VOLCADO EXITOSO")
        print("Archivo guardado en la carpeta de Delta")
        print(string.rep("⭐", 10))
    else
        warn("❌ Error en el motor: " .. tostring(err))
        print("Intentando volcado de emergencia (Sin Scripts)...")
        DumpConfig.Decompile = false
        pcall(function() save_func(DumpConfig) end)
    end
    
    if setfpscap then setfpscap(60) end
    pcall(function() recovery:Destroy() end)
end

-- Iniciar proceso
Execute()
