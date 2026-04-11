--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║        OMNI-DECOMPILER V6 - DEEP LOG (ULTRA-PERSISTENCE)     ║
    ║   Objetivo: Extracción total de lógica a archivo .txt        ║
    ║   Método: Escaneo de GC + Estructura + Append Directo        ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- [ CONFIGURACIÓN ]
local FILE_NAME = "TOTAL_LOG_" .. game.PlaceId .. ".txt"
local decompiler = decompile or (delta and delta.decompile) or (fluxus and fluxus.decompile)

if not decompiler then
    return warn("❌ [ERROR]: El motor de descompilación no está disponible en esta build de Delta.")
end

-- [ MOTOR DE ESCRITURA SEGURO ]
local function SafeWrite(content)
    pcall(function()
        if not readfile(FILE_NAME) then
            writefile(FILE_NAME, "=== INICIO DE VOLCADO TOTAL ===\n")
        end
        appendfile(FILE_NAME, content)
    end)
end

-- [ MOTOR DE EXTRACCIÓN ]
local function ExtractSource(obj)
    local header = "\n" .. string.rep("=", 60) .. "\n"
    header = header .. "NOMBRE: " .. tostring(obj.Name) .. "\n"
    header = header .. "RUTA: " .. obj:GetFullName() .. "\n"
    header = header .. "CLASE: " .. obj.ClassName .. "\n"
    header = header .. string.rep("=", 60) .. "\n"
    
    local success, result = pcall(function() return decompiler(obj) end)
    
    if success and result and #result > 0 then
        return header .. result .. "\n"
    else
        return header .. "-- [ERROR]: No se pudo extraer código (Bytecode protegido o API deshabilitada).\n"
    end
end

-- [ ESCANEO MAESTRO - MODO LENTO EXTREMO ]
local function StartDeepScan()
    print("🚀 Iniciando Minería Profunda... No toques nada.")
    print("⏳ Modo ultra lento activado. Este proceso tomará mucho tiempo.")
    SafeWrite("\nFECHA: " .. os.date("%X") .. " | PLACE ID: " .. game.PlaceId .. "\n")
    
    -- Pausa inicial de cortesía
    task.wait(3)

    local processed = 0
    local targets = {}

    -- 1. Captura de Scripts en el Árbol del Juego
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("ModuleScript") then
            table.insert(targets, v)
        end
    end

    -- 2. Captura de Scripts en Memoria Volátil (Garbage Collector)
    if getgc then
        for _, v in pairs(getgc()) do
            if type(v) == "userdata" then
                pcall(function()
                    if typeof(v) == "Instance" and (v:IsA("LocalScript") or v:IsA("ModuleScript")) then
                        -- Evitar duplicados
                        local found = false
                        for _, existing in ipairs(targets) do
                            if existing == v then found = true break end
                        end
                        if not found then table.insert(targets, v) end
                    end
                end)
            end
        end
    end

    print("📜 Total de scripts identificados: " .. #targets)
    task.wait(2)

    for i, scr in ipairs(targets) do
        print("🛠️ [" .. i .. "/" .. #targets .. "] Minando: " .. scr.Name)
        
        local data = ExtractSource(scr)
        SafeWrite(data)
        
        processed = processed + 1
        
        -- ✅ Pausa larga después de CADA script (3 segundos)
        task.wait(3)
        
        -- ✅ Pausa extra cada 5 scripts (5 segundos adicionales)
        if i % 5 == 0 then
            print("⏸️  Pausa de mantenimiento cada 5 scripts...")
            task.wait(5)
        end
    end

    -- Pausa final antes de mostrar el mensaje de éxito
    task.wait(2)
    print("🏁 PROCESO FINALIZADO. Total procesados: " .. processed)
    print("📁 Archivo guardado como: " .. FILE_NAME)
end

-- Ejecución en hilo separado (con un pequeño retraso inicial)
task.wait(2)
task.spawn(StartDeepScan)
