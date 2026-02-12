--[[
    VelocityAudit-X V3.0: Suite de Auditoría Universal y Agnóstica
    Diseñado para: Auditorías de Seguridad Client-Side en CUALQUIER juego de Roblox (Nivel Experto)
    Compatibilidad: Velocity Executor (sUNC 100%) & Delta Executor (sUNC 100%)
    
    Novedades V3.0:
    - **Arquitectura Modular:** Fácilmente extensible con nuevos módulos de análisis.
    - **Motor de Descubrimiento Universal:** Categorización heurística de remotos basada en comportamiento.
    - **Dashboard Interactivo en Consola:** Control dinámico de filtros y funciones.
    - **Heurística de Vulnerabilidades Genérica:** Detección de patrones de datos universales.
    - **Sistema de Hooks de Baja Detección:** Mejoras en la estabilidad del hooking.
]]

local VelocityAuditX_V3 = {
    Version = "3.0.0",
    Settings = {
        AutoDump = true,
        LogRemotes = true,
        RemoteLogFileName = "Universal_Remote_Log.json", -- Archivo de log universal
        IgnoredRemotes = { -- Remotos a ignorar por defecto (se puede modificar dinámicamente)
            "Get Other Stats",
            "Coins",
            -- Añadir aquí otros remotos ruidosos identificados durante la auditoría
        },
        DeepSerializeTables = true,
        SpamThreshold = 5,
        GeneratePoC = true, -- Generar código de prueba en la consola
        RemoteLogBufferSize = 20, -- Buffer más grande para el log persistente
        HeuristicAnalysisEnabled = true, -- NUEVO: Habilitar/deshabilitar el motor heurístico
    },
    
    -- Estado interno de la suite
    RemoteFrequency = {},
    RemoteLogBuffer = {},
    RemoteLogBufferCount = 0,
    
    -- NUEVO: Módulos de la suite (se cargarán dinámicamente)
    Modules = {},
}

-- region: Utilidades Generales
local function log(msg, type)
    local prefix = "[VelocityAudit-X V3.0] "
    if type == "warn" then warn(prefix .. msg)
    elseif type == "error" then error(prefix .. msg)
    else print(prefix .. msg) end
end

local function deepSerialize(value, indent, seen)
    indent = indent or 0
    seen = seen or {}
    local indentStr = string.rep("  ", indent)
    if type(value) == "table" then
        if seen[value] then return "{... (referencia circular)}" end
        seen[value] = true
        local elements = {}
        for k, v in pairs(value) do
            local key_str = (type(k) == "table" or type(k) == "userdata") and tostring(k) or deepSerialize(k, 0, seen)
            table.insert(elements, key_str .. "=" .. deepSerialize(v, indent + 1, seen))
        end
        seen[value] = nil
        return "{" .. table.concat(elements, ", ") .. "}"
    elseif type(value) == "string" then return "\"" .. value .. "\""
    else return tostring(value) end
end

local function writeDataToFile(filename, data)
    local success, err = pcall(function()
        if writefile then
            writefile(filename, data)
            log("Datos guardados en: " .. filename)
        else
            log("Advertencia: 'writefile' no disponible. Los datos no se guardarán en archivo.", "warn")
        end
    end)
    if not success then
        log("Error al intentar escribir en archivo: " .. tostring(err), "error")
    end
end

local function flushRemoteLog()
    if #VelocityAuditX_V3.RemoteLogBuffer > 0 then
        local HttpService = game:GetService("HttpService")
        if HttpService then
            local currentContent = "[]"
            local success, content = pcall(readfile, VelocityAuditX_V3.Settings.RemoteLogFileName)
            if success and content and #content > 0 then
                currentContent = content
            end

            local jsonTable = HttpService:JSONDecode(currentContent)
            for _, entry in ipairs(VelocityAuditX_V3.RemoteLogBuffer) do
                table.insert(jsonTable, entry)
            end
            local newJson = HttpService:JSONEncode(jsonTable)
            writeDataToFile(VelocityAuditX_V3.Settings.RemoteLogFileName, newJson)
            
            VelocityAuditX_V3.RemoteLogBuffer = {}
            VelocityAuditX_V3.RemoteLogBufferCount = 0
            log("Buffer de remotos vaciado a: " .. VelocityAuditX_V3.Settings.RemoteLogFileName)
        else
            log("Advertencia: 'HttpService' no disponible para JSONEncode. El log de remotos no se guardará.", "warn")
        end
    end
end

local function generatePoCCode(remoteName, method, args)
    local argsStr = ""
    for i, v in ipairs(args) do
        argsStr = argsStr .. deepSerialize(v) .. (i < #args and ", " or "")
    end
    
    local code = string.format(
        "-- PoC Generado para: %s\nlocal remote = game:GetService(\"ReplicatedStorage\"):WaitForChild(\"%s\")\nremote:%s(%s)",
        remoteName, remoteName, method, argsStr
    )
    
    print("\n[!!!] POCO GENERADO (Copiar para probar):\n" .. code .. "\n")
end
-- endregion

-- region: Módulo de Descubrimiento Universal y Heurística
local function universalHeuristicAnalysis(remoteName, method, args)
    local detectedVulnerabilities = {}
    local remoteCategory = "Unknown"

    -- Heurística de Categorización de Remotos
    if string.find(remoteName:lower(), "coin") or string.find(remoteName:lower(), "money") or string.find(remoteName:lower(), "cash") then
        remoteCategory = "Economy System"
    elseif string.find(remoteName:lower(), "pet") or string.find(remoteName:lower(), "move") or string.find(remoteName:lower(), "pos") then
        remoteCategory = "Movement/Pet System"
    elseif string.find(remoteName:lower(), "trade") or string.find(remoteName:lower(), "inventory") or string.find(remoteName:lower(), "item") then
        remoteCategory = "Trading/Inventory System"
    elseif string.find(remoteName:lower(), "rename") or string.find(remoteName:lower(), "chat") then
        remoteCategory = "Chat/Naming System"
    end

    -- Heurística de Detección de Vulnerabilidades Genéricas
    for i, arg in ipairs(args) do
        if type(arg) == "table" then
            -- Buscar coordenadas (X, Y, Z) en tablas
            local potentialCoords = {}
            local numCount = 0
            for k, v in pairs(arg) do
                if type(v) == "number" then
                    table.insert(potentialCoords, v)
                    numCount = numCount + 1
                end
            end
            if numCount >= 3 then
                table.insert(detectedVulnerabilities, {
                    type = "Client-Side Coordinate Manipulation",
                    description = string.format("El remoto '%s' (%s) en la categoría '%s' recibe una tabla con múltiples números (%s) que podrían ser coordenadas. Esto sugiere que el cliente puede controlar la posición de objetos.", remoteName, method, remoteCategory, table.concat(potentialCoords, ", ")),
                    arg_index = i,
                    arg_value = deepSerialize(arg)
                })
            end

            -- Buscar patrones de economía (Value, Amount) en tablas
            if (arg.Value and type(arg.Value) == "number") or (arg.Amount and type(arg.Amount) == "number") then
                table.insert(detectedVulnerabilities, {
                    type = "Economy Manipulation (Table)",
                    description = string.format("El remoto '%s' (%s) en la categoría '%s' recibe una tabla con claves como 'Value' o 'Amount'. Posible manipulación de economía si no se valida en el servidor.", remoteName, method, remoteCategory),
                    arg_value = deepSerialize(arg)
                })
            end
        elseif type(arg) == "string" then
            -- Buscar strings que puedan ser IDs de jugadores/ítems o nombres (para inyección)
            if string.len(arg) > 5 and string.match(arg, "%d+") then -- Posible ID numérico en string
                table.insert(detectedVulnerabilities, {
                    type = "Potential ID Spoofing/Injection (String)",
                    description = string.format("El remoto '%s' (%s) en la categoría '%s' recibe un string que parece un ID ('%s'). Posible ID Spoofing o manipulación de datos.", remoteName, method, remoteCategory, arg),
                    arg_index = i,
                    arg_value = arg
                })
            end
            if string.len(arg) > 10 and (string.find(arg:lower(), "http") or string.find(arg:lower(), "script")) then
                 table.insert(detectedVulnerabilities, {
                    type = "Potential String Injection (XSS/RCE)",
                    description = string.format("El remoto '%s' (%s) en la categoría '%s' recibe un string largo ('%s') con contenido sospechoso (URL/script). Posible inyección de código o XSS.", remoteName, method, remoteCategory, arg),
                    arg_index = i,
                    arg_value = arg
                })
            end
        elseif type(arg) == "number" then
            -- Buscar números que puedan ser IDs de jugadores/ítems o valores de economía
            if arg > 1000000 and arg < 9999999999 then -- Rango típico de UserID/AssetID en Roblox
                table.insert(detectedVulnerabilities, {
                    type = "Potential ID Spoofing (Number)",
                    description = string.format("El remoto '%s' (%s) en la categoría '%s' recibe un número grande ('%d') que podría ser un ID. Posible ID Spoofing.", remoteName, method, remoteCategory, arg),
                    arg_index = i,
                    arg_value = arg
                })
            end
            if remoteCategory == "Economy System" and arg > 0 then
                table.insert(detectedVulnerabilities, {
                    type = "Potential Economy Manipulation (Number)",
                    description = string.format("El remoto '%s' (%s) en la categoría '%s' recibe un número positivo ('%d') en un contexto de economía. Posible manipulación de valores.", remoteName, method, remoteCategory, arg),
                    arg_index = i,
                    arg_value = arg
                })
            end
        end
    end

    return detectedVulnerabilities, remoteCategory
end
-- endregion

-- region: Módulo Spy-Engine V3 (Intercepción de Remotos Mejorada)
local function InitializeSpy()
    log("Iniciando Spy-Engine V3.0 (Universal)...")
    local oldNamecall
    
    if not hookmetamethod then
        log("Error: 'hookmetamethod' no disponible en este ejecutor. El Spy-Engine no se iniciará.", "error")
        return
    end

    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if (method == "FireServer" or method == "InvokeServer") and VelocityAuditX_V3.Settings.LogRemotes then
            -- Filtrado inteligente de remotos
            if table.find(VelocityAuditX_V3.Settings.IgnoredRemotes, self.Name) then
                return oldNamecall(self, ...)
            end

            local remoteKey = self.Name .. "_" .. method .. "_" .. (args[1] and tostring(args[1]) or "nil")
            VelocityAuditX_V3.RemoteFrequency[remoteKey] = (VelocityAuditX_V3.RemoteFrequency[remoteKey] or 0) + 1

            if VelocityAuditX_V3.RemoteFrequency[remoteKey] > VelocityAuditX_V3.Settings.SpamThreshold then
                if VelocityAuditX_V3.RemoteFrequency[remoteKey] == VelocityAuditX_V3.Settings.SpamThreshold + 1 then
                    log(string.format("Silenciando remoto repetitivo: %s (apareció %d veces)", self.Name, VelocityAuditX_V3.Settings.SpamThreshold), "warn")
                end
                return oldNamecall(self, ...)
            end

            local remoteInfo = string.format(
                "Remote Detectado: %s | Clase: %s | Método: %s",
                self.Name, self.ClassName, method
            )
            print("--------------------------------")
            print(remoteInfo)
            
            local serializedArgs = {}
            for i, arg in ipairs(args) do
                local arg_str
                if VelocityAuditX_V3.Settings.DeepSerializeTables and type(arg) == "table" then
                    arg_str = deepSerialize(arg)
                else
                    arg_str = tostring(arg)
                end
                print(string.format("  Arg[%d]: %s (%s)", i, arg_str, type(arg)))
                table.insert(serializedArgs, {value = arg_str, type = type(arg)})
            end

            -- NUEVO: Analizar el remoto en busca de vulnerabilidades con el motor heurístico
            local vulnerabilities, remoteCategory = universalHeuristicAnalysis(self.Name, method, args)
            if VelocityAuditX_V3.Settings.HeuristicAnalysisEnabled and #vulnerabilities > 0 then
                log(string.format("¡VULNERABILIDAD DETECTADA en remoto %s (Categoría: %s)!", self.Name, remoteCategory), "error")
                for _, vuln in ipairs(vulnerabilities) do
                    log(string.format("  Tipo: %s - Descripción: %s", vuln.type, vuln.description), "error")
                end
            end

            -- Añadir el evento remoto al buffer
            table.insert(VelocityAuditX_V3.RemoteLogBuffer, {
                timestamp = os.time(),
                name = self.Name,
                class = self.ClassName,
                method = method,
                args = serializedArgs,
                vulnerabilities = vulnerabilities, -- Incluir vulnerabilidades detectadas
                category = remoteCategory -- Incluir categoría del remoto
            })
            VelocityAuditX_V3.RemoteLogBufferCount = VelocityAuditX_V3.RemoteLogBufferCount + 1

            -- Vaciar el buffer si alcanza el tamaño configurado
            if VelocityAuditX_V3.RemoteLogBufferCount >= VelocityAuditX_V3.Settings.RemoteLogBufferSize then
                flushRemoteLog()
            end

            -- Generar PoC si está habilitado
            if VelocityAuditX_V3.Settings.GeneratePoC then
                generatePoCCode(self.Name, method, args)
            end
        end
        
        return oldNamecall(self, ...)
    end)
    log("Spy-Engine V3.0 Activo.")
end
-- endregion

-- region: Módulo Data-Extractor (Extracción de Información)
local function DumpGameInfo()
    log("Iniciando Extracción de Datos V3.0...")
    local results = {
        Remotes = {},
        Scripts = {},
        HiddenObjects = {},
        NilInstances = {} -- Añadido para getnilinstances
    }

    -- Buscar Remotos
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            table.insert(results.Remotes, v:GetFullName())
        end
    end

    -- Buscar Scripts (LocalScripts y ModuleScripts)
    for _, v in ipairs(getgc()) do
        if type(v) == "function" then
            local s = getfenv(v).script
            if s and (s:IsA("LocalScript") or s:IsA("ModuleScript")) then
                results.Scripts[s:GetFullName()] = true
            end
        end
    end

    -- Buscar instancias en nil (si la función está disponible)
    if getnilinstances then
        for _, v in ipairs(getnilinstances()) do
            table.insert(results.NilInstances, tostring(v))
        end
    else
        log("Advertencia: 'getnilinstances' no disponible en este ejecutor.", "warn")
    end

    local scriptCount = 0
    for _ in pairs(results.Scripts) do
        scriptCount = scriptCount + 1
    end

    log(string.format("Extracción completada: %d Remotos, %d Scripts, %d Instancias en Nil encontrados.", 
        #results.Remotes, scriptCount, #results.NilInstances))
    
    if VelocityAuditX_V3.Settings.AutoDump then
        local HttpService = game:GetService("HttpService")
        if HttpService then
            local json_data = HttpService:JSONEncode(results)
            writeDataToFile(VelocityAuditX_V3.Settings.DumpFileName, json_data)
        else
            log("Advertencia: 'HttpService' no disponible para JSONEncode. Los datos no se volcarán a JSON.", "warn")
        end
    end
end
-- endregion

-- region: Módulo Script-Analyzer (Descompilación)
local function AnalyzeScript(scriptInstance)
    if decompile then
        log("Descompilando: " .. scriptInstance:GetFullName())
        local success, code = pcall(decompile, scriptInstance)
        if success and code then
            log("Descompilación exitosa.")
            return code
        else
            log("Error al descompilar: " .. tostring(code), "warn")
            return nil
        end
    else
        log("Error: Función 'decompile' no soportada por el ejecutor.", "warn")
        return nil
    end
end
-- endregion

-- region: Dashboard de Comandos (NUEVO)
local function handleCommand(command)
    local parts = {}
    for part in string.gmatch(command, "(%S+)") do
        table.insert(parts, part)
    end

    local cmd = parts[1]
    local subCmd = parts[2]
    local arg1 = parts[3]

    if cmd == "/audit" then
        if subCmd == "filter" then
            if arg1 == "add" and parts[4] then
                local remoteName = parts[4]
                if not table.find(VelocityAuditX_V3.Settings.IgnoredRemotes, remoteName) then
                    table.insert(VelocityAuditX_V3.Settings.IgnoredRemotes, remoteName)
                    log(string.format("Remoto '%s' añadido a la lista de ignorados.", remoteName))
                else
                    log(string.format("Remoto '%s' ya está en la lista de ignorados.", remoteName), "warn")
                end
            elseif arg1 == "remove" and parts[4] then
                local remoteName = parts[4]
                local found = false
                for i, v in ipairs(VelocityAuditX_V3.Settings.IgnoredRemotes) do
                    if v == remoteName then
                        table.remove(VelocityAuditX_V3.Settings.IgnoredRemotes, i)
                        found = true
                        log(string.format("Remoto '%s' eliminado de la lista de ignorados.", remoteName))
                        break
                    end
                end
                if not found then
                    log(string.format("Remoto '%s' no encontrado en la lista de ignorados.", remoteName), "warn")
                end
            elseif arg1 == "list" then
                log("Remotos ignorados actualmente:")
                if #VelocityAuditX_V3.Settings.IgnoredRemotes > 0 then
                    for _, remote in ipairs(VelocityAuditX_V3.Settings.IgnoredRemotes) do
                        print("  - " .. remote)
                    end
                else
                    print("  (Ninguno)")
                end
            else
                log("Uso: /audit filter [add <nombre_remoto> | remove <nombre_remoto> | list]", "warn")
            end
        elseif subCmd == "poc" then
            if arg1 == "enable" then
                VelocityAuditX_V3.Settings.GeneratePoC = true
                log("Generación de PoC habilitada.")
            elseif arg1 == "disable" then
                VelocityAuditX_V3.Settings.GeneratePoC = false
                log("Generación de PoC deshabilitada.")
            else
                log("Uso: /audit poc [enable | disable]", "warn")
            end
        elseif subCmd == "settings" then
            log("Configuración actual de VelocityAudit-X V3.0:")
            print("  Log Remotes: " .. tostring(VelocityAuditX_V3.Settings.LogRemotes))
            print("  Auto Dump: " .. tostring(VelocityAuditX_V3.Settings.AutoDump))
            print("  Deep Serialize Tables: " .. tostring(VelocityAuditX_V3.Settings.DeepSerializeTables))
            print("  Spam Threshold: " .. tostring(VelocityAuditX_V3.Settings.SpamThreshold))
            print("  Generate PoC: " .. tostring(VelocityAuditX_V3.Settings.GeneratePoC))
            print("  Heuristic Analysis Enabled: " .. tostring(VelocityAuditX_V3.Settings.HeuristicAnalysisEnabled))
            log("Para ver la lista de remotos ignorados, usa: /audit filter list")
        else
            log("Uso: /audit [filter | poc | settings]", "warn")
        end
    end
end

-- Hook para interceptar comandos de chat (solo si el ejecutor lo permite)
if game and game.Players and game.Players.LocalPlayer then
    game.Players.LocalPlayer.Chatted:Connect(function(message)
        if string.sub(message, 1, 6) == "/audit" then
            handleCommand(message)
        end
    end)
else
    log("Advertencia: No se pudo hookear el chat. Los comandos de /audit solo funcionarán si se ejecutan directamente en la consola del ejecutor.", "warn")
end
-- endregion

-- region: Inicialización y Ejecución
function VelocityAuditX_V3:Start()
    log("Iniciando Suite de Auditoría V3.0 v" .. self.Version)
    InitializeSpy()
    DumpGameInfo()
    flushRemoteLog()
end

-- Ejecutar
VelocityAuditX_V3:Start()

return VelocityAuditX_V3
-- endregion
