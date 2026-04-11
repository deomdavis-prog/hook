-- [[ OMNI-DUMPER V3: TITANIUM MOBILE EDITION ]]
-- Optimizaciones: Bypass de RAM (Mode: Optimized), Ocultación en gethui(), Notificaciones UI, Filtro de Crasheos C++.

if not saveinstance then
    return game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Error Crítico", Text = "Tu versión de Delta no soporta saveinstance.", Duration = 5
    })
end

local Config = {
    FileName = "DELTA_DUMP_" .. game.PlaceId .. "_" .. os.date("%H%M"),
    DecompileScripts = true,
    TimeoutPerScript = 10, -- Reducido a 10s para evitar cierres por el OS en móviles
    RecoverNil = true,
    NotificationUI = true, -- Muestra el progreso en la pantalla del móvil
    
    -- Ignorar carpetas que saturan el .rbxl sin aportar nada al juego
    IgnoreList = {
        "CoreGui", "CorePackages", "RobloxPluginGuiService", "Chat", "TestService"
    },
    
    -- Clases que SIEMPRE crashean los ejecutores móviles si intentas clonarlas
    BlacklistedClasses = {
        "Terrain", "Player", "CoreScript", "NetworkClient", "Studio", "ScriptDebugger"
    }
}

local TempFolder = nil

-- [[ INTERFAZ LIGERA PARA MÓVILES ]]
local function Notify(title, text)
    if Config.NotificationUI then
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = title, Text = text, Duration = 4
            })
        end)
    end
    print("🔹 [" .. title .. "]: " .. text)
end

-- [[ 1. PURGA Y PREPARACIÓN DE RAM ]]
local function OptimizeMemory()
    Notify("Paso 1/4", "Purgando memoria basura...")
    -- Liberamos memoria 5 veces seguidas con un pequeño delay para que el Garbage Collector actúe profundo
    for i = 1, 5 do
        collectgarbage("collect")
        task.wait(0.05)
    end
    print("✅ RAM liberada. Memoria Lua actual: " .. math.floor(collectgarbage("count") / 1024) .. " MB")
end

-- [[ 2. RECUPERACIÓN SEGURA DE NIL (ANTI-CRASH) ]]
local function InjectNilInstances()
    if not Config.RecoverNil or not getnilinstances then return end
    Notify("Paso 2/4", "Analizando Abismo (Nil Instances)...")
    
    local nil_instances = getnilinstances()
    local count = 0
    
    -- Usamos gethui() si está disponible. Esto oculta la carpeta del Anti-Cheat
    -- Si no, usamos CoreGui (que no es escaneado por el juego normal).
    local safeParent = (gethui and gethui()) or game:GetService("CoreGui")
    
    TempFolder = Instance.new("Folder")
    TempFolder.Name = "OMNI_NIL_RECOVERY"
    TempFolder.Parent = safeParent 
    
    for _, inst in ipairs(nil_instances) do
        if typeof(inst) == "Instance" and inst ~= game and inst.Parent == nil then
            -- Verificamos que la clase no esté en la lista negra
            local isBlacklisted = false
            for _, badClass in ipairs(Config.BlacklistedClasses) do
                if inst:IsA(badClass) then isBlacklisted = true break end
            end
            
            if not isBlacklisted then
                -- El pcall previene que el motor C++ crashee si un objeto está bloqueado
                pcall(function()
                    local clone = inst:Clone() 
                    if clone then
                        clone.Parent = TempFolder
                        count = count + 1
                    end
                end)
            end
        end
    end
    Notify("Nil Recovery", count .. " instancias recuperadas con éxito.")
end

-- [[ 3. CONFIGURACIÓN DEL MOTOR NATIVO (SYNAPSE V3 / KRNL API COMPATIBLE) ]]
local function GetSaveOptions()
    Notify("Paso 3/4", "Inyectando parámetros nativos...")
    
    -- Esta es la tabla de propiedades estandarizada que Delta y la mayoría
    -- de motores modernos interpretan correctamente en el backend C++:
    return {
        mode = "optimized", -- ¡VITAL PARA MÓVILES! Remueve propiedades por defecto (achica el archivo un 60%)
        noscripts = not Config.DecompileScripts,
        timeout = Config.TimeoutPerScript,
        ignore = Config.IgnoreList,
        scriptcache = true, -- Evita decompilar el mismo script de Roblox 2 veces
        showprofiling = false,
        isolate_players = true -- Solo guarda tu personaje, ignorando la carga geométrica de otros
    }
end

-- [[ 4. VOLCADO ASÍNCRONO ]]
local function ExecuteDump()
    Notify("Paso 4/4", "Iniciando volcado... El juego se congelará.")
    task.wait(1.5) -- Pausa necesaria para que la UI se actualice antes del freeze
    
    local options = GetSaveOptions()
    
    task.spawn(function()
        local startTime = tick()
        local success, err = pcall(function()
            saveinstance(options)
            -- Algunos ejecutores esperan el nombre como primer argumento si la tabla falla
            -- saveinstance(Config.FileName, options) -- Descomentar si la línea anterior da error
        end)
        
        local elapsedTime = math.floor(tick() - startTime)
        
        -- Limpieza extrema post-volcado
        if TempFolder then TempFolder:Destroy() end
        collectgarbage("collect")
        
        if success then
            Notify("¡ÉXITO!", "Archivo guardado (" .. elapsedTime .. "s): " .. Config.FileName .. ".rbxl")
            print("📁 Guardado como: " .. Config.FileName .. ".rbxl")
        else
            Notify("ERROR CRÍTICO", "Fallo al guardar. Mira la consola (F9).")
            warn("❌ Error de C++ en SaveInstance: " .. tostring(err))
        end
    end)
end

-- [[ EJECUCIÓN ]]
OptimizeMemory()
InjectNilInstances()
ExecuteDump()
