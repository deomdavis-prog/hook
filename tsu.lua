--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║     OMNI-DECOMPILER V7 - STEALTH & DEEP EXTRACTION (CLIENT)  ║
    ║        Potenciado para máxima extracción y sigilo            ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- [ CONFIGURACIÓN ]
local FILE_NAME = "CLIENT_LOGIC_" .. game.PlaceId .. ".txt"
local DISABLE_SAFETY_PAUSES = true -- Ponlo en 'false' si experimentas crasheos o congelamientos
local INCLUDE_METATABLE_HOOKS = true -- Activar para rastrear accesos a propiedades
local OFUSCAR_STRINGS = true      -- Activar para evitar firmas de texto plano

-- [ API DE EJECUTOR - DETECCIÓN MEJORADA ]
local decompiler = nil
local writefile_func = writefile or (delta and delta.writefile) or (syn and syn.write) or (fluxus and fluxus.writefile)
local readfile_func = readfile or (delta and delta.readfile) or (syn and syn.read)
local appendfile_func = appendfile or (delta and delta.appendfile) or (fluxus and fluxus.appendfile)
local isfile_func = isfile or (delta and delta.isfile) or (syn and syn.isfile)
local getgc_func = getgc or (delta and delta.getgc)
local getloadedmodules_func = getloadedmodules or (delta and delta.getloadedmodules)

if not writefile_func or not appendfile_func then
    return warn("❌ [ERROR]: Funciones de archivo no disponibles.")
end

if not getgc_func then
    warn("⚠️ [ADVERTENCIA]: 'getgc' no disponible. El escaneo de memoria será limitado.")
end

-- [ SISTEMA DE OFUSCACIÓN BÁSICA (OPCIONAL) ]
local function ObfuscateString(str)
    if not OFUSCAR_STRINGS then return str end
    local bytes = {}
    for i = 1, #str do
        table.insert(bytes, string.byte(str, i))
    end
    return "string.char(" .. table.concat(bytes, ",") .. ")"
end

-- [ INTENTAR OBTENER EL DESCOMPILADOR ]
pcall(function()
    -- Primero, intentar con APIs comunes de Delta
    decompiler = delta and delta.decompile
    if not decompiler then
        -- Luego, buscar en el entorno global
        decompiler = decompile
    end
    if not decompiler and getgc_func then
        -- Último recurso: buscar en la memoria del GC
        for _, v in pairs(getgc_func()) do
            if type(v) == "function" and pcall(function() return v("print") end) then
                decompiler = v
                break
            end
        end
    end
end)

if not decompiler then
    return warn("❌ [ERROR]: El motor de descompilación no está disponible.")
end

-- [ MOTOR DE ESCRITURA SEGURO Y OPTIMIZADO ]
local function SafeWrite(content)
    pcall(function()
        if not isfile_func(FILE_NAME) then
            writefile_func(FILE_NAME, "=== INICIO DE VOLCADO TOTAL (CLIENTE) ===\n")
        end
        appendfile_func(FILE_NAME, content)
    end)
end

-- [ MOTOR DE EXTRACCIÓN MEJORADO ]
local function ExtractSource(obj)
    local header = "\n" .. string.rep("=", 60) .. "\n"
    header = header .. "NOMBRE: " .. tostring(obj.Name) .. "\n"
    header = header .. "RUTA: " .. obj:GetFullName() .. "\n"
    header = header .. "CLASE: " .. obj.ClassName .. "\n"
    header = header .. string.rep("=", 60) .. "\n"

    local success, result = pcall(function()
        -- Intentar descompilar con manejo de errores mejorado
        local bytecode = nil
        pcall(function() bytecode = obj.Bytecode end) -- Intentar obtener bytecode primero

        if bytecode then
            return decompiler(bytecode) -- Algunos decompiladores funcionan con bytecode
        else
            return decompiler(obj) -- Otros con el objeto en sí
        end
    end)

    if success and result and #result > 0 then
        return header .. result .. "\n"
    else
        return header .. "-- [ERROR]: Código protegido o API no disponible.\n"
    end
end

-- [ ESCANEO MAESTRO - VERSIÓN POTENCIADA ]
local function StartDeepScan()
    local function _log(msg)
        print("🚀 " .. msg)
    end

    _log("Iniciando Minería Profunda... No toques nada.")
    SafeWrite("\nFECHA: " .. os.date("%X") .. " | PLACE ID: " .. game.PlaceId .. "\n")

    local processed = 0
    local targets = {}
    local targetMap = {} -- Para evitar duplicados

    -- 1. Captura de Scripts en el Árbol del Juego (Método Tradicional)
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("ModuleScript") then
            if not targetMap[v] then
                targetMap[v] = true
                table.insert(targets, v)
            end
        end
    end

    -- 2. Captura de Scripts Cargados en Memoria (Módulos) - MUY IMPORTANTE
    if getloadedmodules_func then
        pcall(function()
            for _, v in ipairs(getloadedmodules_func()) do
                if type(v) == "userdata" and typeof(v) == "Instance" then
                    if v:IsA("ModuleScript") and not targetMap[v] then
                        targetMap[v] = true
                        table.insert(targets, v)
                    end
                end
            end
        end)
    end

    -- 3. Captura de Scripts en el Garbage Collector (GC)
    if getgc_func then
        pcall(function()
            for _, v in pairs(getgc_func()) do
                if type(v) == "userdata" then
                    pcall(function()
                        if typeof(v) == "Instance" and (v:IsA("LocalScript") or v:IsA("ModuleScript")) then
                            if not targetMap[v] then
                                targetMap[v] = true
                                table.insert(targets, v)
                            end
                        end
                    end)
                end
            end
        end)
    end

    _log("Total de scripts identificados: " .. #targets)
    if not DISABLE_SAFETY_PAUSES then task.wait(2) end

    for i, scr in ipairs(targets) do
        _log("[" .. i .. "/" .. #targets .. "] Minando: " .. scr.Name)

        local data = ExtractSource(scr)
        SafeWrite(data)

        processed = processed + 1

        -- Pausas de seguridad (desactivadas por defecto para velocidad)
        if not DISABLE_SAFETY_PAUSES then
            task.wait(1)
            if i % 10 == 0 then
                _log("⏸️  Pausa de mantenimiento...")
                task.wait(2)
            end
        end
    end

    -- 4. CAPTURA DE LOGICA POR METATABLES (OPCIONAL)
    if INCLUDE_METATABLE_HOOKS then
        SafeWrite("\n\n" .. string.rep("#", 60) .. "\n")
        SafeWrite("=== INICIO DE REGISTRO DE ACCESOS A PROPIEDADES (METATABLES) ===\n")
        SafeWrite("(Esta sección registra interacciones con objetos clave del juego)\n")
        SafeWrite(string.rep("#", 60) .. "\n")

        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer

        -- Función para crear un hook sigiloso en una tabla
        local function HookTableForLogging(tbl, name)
            local mt = getrawmetatable(tbl) or {}
            local old_index = mt.__index
            local old_newindex = mt.__newindex

            mt.__index = function(t, k)
                SafeWrite("[INDEX] " .. name .. "." .. tostring(k) .. " (Lectura)\n")
                if type(old_index) == "function" then
                    return old_index(t, k)
                elseif type(old_index) == "table" then
                    return old_index[k]
                else
                    return rawget(t, k)
                end
            end

            mt.__newindex = function(t, k, v)
                SafeWrite("[NEWINDEX] " .. name .. "." .. tostring(k) .. " = " .. tostring(v) .. " (Escritura)\n")
                if type(old_newindex) == "function" then
                    return old_newindex(t, k, v)
                else
                    return rawset(t, k, v)
                end
            end

            setreadonly(mt, false) -- Necesario para modificar la metatable
            setrawmetatable(tbl, mt)
            setreadonly(mt, true)
        end

        -- Hookear objetos clave del cliente (ej: Player, Character, Backpack)
        pcall(function() HookTableForLogging(LocalPlayer, "LocalPlayer") end)
        if LocalPlayer.Character then
            pcall(function() HookTableForLogging(LocalPlayer.Character, "Character") end)
        end
        LocalPlayer.CharacterAdded:Connect(function(char)
            pcall(function() HookTableForLogging(char, "Character") end)
        end)
        pcall(function() HookTableForLogging(LocalPlayer:WaitForChild("Backpack"), "Backpack") end)
        pcall(function() HookTableForLogging(LocalPlayer:WaitForChild("PlayerGui"), "PlayerGui") end)
        pcall(function() HookTableForLogging(game:GetService("ReplicatedStorage"), "ReplicatedStorage") end)
    end

    _log("🏁 PROCESO FINALIZADO. Total procesados: " .. processed)
    _log("📁 Archivo guardado como: " .. FILE_NAME)
end

-- Ejecución en hilo separado (con un pequeño retraso inicial)
task.wait(2)
task.spawn(StartDeepScan)
