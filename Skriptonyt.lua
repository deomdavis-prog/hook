--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║   OMNI-EXTRACTOR V8 - AUTÓNOMO (DUMP + URL MONITOR INTEGRADO)        ║
    ║   Ejecuta una vez -> Extrae toda lógica cliente + captura URLs       ║
    ╚══════════════════════════════════════════════════════════════════════╝
]]

-- [ CONFIGURACIÓN ]
local FILE_NAME = "CLIENT_FULL_DUMP_" .. game.PlaceId .. ".txt"
local DISABLE_SAFETY_PAUSES = true       -- false = más lento pero más estable
local ENABLE_HTTP_MONITOR = true         -- true = capturar URLs de peticiones HTTP

-- [ API DEL EJECUTOR - DETECCIÓN MEJORADA ]
local decompiler
local writefile_func = writefile or (delta and delta.writefile) or (syn and syn.write) or (fluxus and fluxus.writefile)
local appendfile_func = appendfile or (delta and delta.appendfile) or (fluxus and fluxus.appendfile)
local isfile_func = isfile or (delta and delta.isfile) or (syn and syn.isfile)
local getgc_func = getgc or (delta and delta.getgc)
local getloadedmodules_func = getloadedmodules or (delta and delta.getloadedmodules)

if not writefile_func or not appendfile_func then
    return print("❌ [ERROR]: Funciones de archivo no disponibles.")
end

-- [ DETECCIÓN DEL DESCOMPILADOR ]
pcall(function()
    decompiler = delta and delta.decompile
    if not decompiler then decompiler = decompile end
    if not decompiler and getgc_func then
        for _, v in pairs(getgc_func()) do
            if type(v) == "function" and pcall(function() return v("print") end) then
                decompiler = v
                break
            end
        end
    end
end)

if not decompiler then
    print("⚠️ [AVISO]: Descompilador no encontrado. Se extraerá solo metadatos.")
end

-- [ FUNCIONES DE ARCHIVO ]
local function SafeWrite(content)
    pcall(function()
        if not isfile_func(FILE_NAME) then
            writefile_func(FILE_NAME, "=== VOLCADO AUTÓNOMO - " .. os.date() .. " ===\n")
            writefile_func(FILE_NAME, "PlaceId: " .. game.PlaceId .. " | Game: " .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name .. "\n\n")
        end
        appendfile_func(FILE_NAME, content)
    end)
end

-- [ EXTRACCIÓN DE CÓDIGO FUENTE ]
local function ExtractSource(obj)
    local header = "\n" .. string.rep("=", 60) .. "\n"
    header = header .. "NOMBRE: " .. tostring(obj.Name) .. "\n"
    header = header .. "RUTA: " .. obj:GetFullName() .. "\n"
    header = header .. "CLASE: " .. obj.ClassName .. "\n"
    header = header .. string.rep("=", 60) .. "\n"

    if not decompiler then
        return header .. "-- [NO DECOMPILADOR] Bytecode no extraíble.\n"
    end

    local success, result = pcall(function()
        local bytecode = nil
        pcall(function() bytecode = obj.Bytecode end)
        if bytecode then
            return decompiler(bytecode)
        else
            return decompiler(obj)
        end
    end)

    if success and result and #result > 0 then
        return header .. result .. "\n"
    else
        return header .. "-- [ERROR]: Código protegido o inaccesible.\n"
    end
end

-- [ MONITOR DE PETICIONES HTTP - AUTÓNOMO ]
local function InstallHttpMonitor()
    if not ENABLE_HTTP_MONITOR then return end

    SafeWrite("\n\n" .. string.rep("#", 70) .. "\n")
    SafeWrite("=== SECCIÓN: MONITOR DE PETICIONES HTTP (Captura automática de URLs) ===\n")
    SafeWrite("(Los registros aparecerán aquí cuando se realice una solicitud)\n")
    SafeWrite(string.rep("#", 70) .. "\n")

    local requestFuncs = {"syn.request", "http_request", "request", "http.request", "fluxus.request"}
    local targetFunc, funcName = nil, nil

    for _, name in ipairs(requestFuncs) do
        local s, f = pcall(function() return loadstring("return " .. name)() end)
        if s and type(f) == "function" then
            targetFunc = f
            funcName = name
            break
        end
    end

    if not targetFunc then
        SafeWrite("⚠️ No se detectó ninguna función de solicitud HTTP en este ejecutor.\n")
        return
    end

    local oldRequest = targetFunc
    local hooked = function(options)
        local urlStr = "nil"
        local fullOpts = "nil"

        if type(options) == "table" then
            urlStr = options.Url or options.Url or options.url or options["Url"] or options["url"] or "URL_NO_ENCONTRADA"
            fullOpts = ""
            for k, v in pairs(options) do
                fullOpts = fullOpts .. tostring(k) .. "=" .. tostring(v) .. "; "
            end
        elseif type(options) == "string" then
            urlStr = options
            fullOpts = "string: " .. options
        end

        -- Registrar en archivo
        SafeWrite("\n[HTTP] " .. os.date("%X") .. " | Función: " .. funcName .. "\n")
        SafeWrite("   URL: " .. urlStr .. "\n")
        SafeWrite("   Opciones: " .. fullOpts .. "\n")

        -- Ejecutar original (incluso si falla por URL inválida)
        local success, result = pcall(oldRequest, options)
        if not success then
            SafeWrite("   ❌ Error en la solicitud: " .. tostring(result) .. "\n")
        else
            SafeWrite("   ✅ Solicitud completada.\n")
        end
        return result
    end

    -- Reemplazar la función globalmente
    pcall(function()
        local env = getfenv()
        for _, name in ipairs(requestFuncs) do
            if env[name] then
                env[name] = hooked
                print("🔗 HTTP Monitor instalado en '" .. name .. "'")
                SafeWrite("🔗 HTTP Monitor activo en función: " .. name .. "\n")
                break
            end
        end
    end)
end

-- [ ESCANEO PROFUNDO DE SCRIPTS ]
local function StartDeepScan()
    print("🚀 OMNI-EXTRACTOR V8 - Iniciando extracción autónoma...")

    SafeWrite("\n\n=== INICIO DE EXTRACCIÓN DE LÓGICA CLIENTE ===\n")
    SafeWrite("Hora: " .. os.date() .. "\n\n")

    local targets = {}
    local targetMap = {}

    -- 1. Scripts en el árbol del juego
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("ModuleScript") then
            if not targetMap[v] then
                targetMap[v] = true
                table.insert(targets, v)
            end
        end
    end

    -- 2. Módulos cargados en memoria
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

    -- 3. Basurero (GC)
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

    print("📜 Scripts encontrados: " .. #targets)

    for i, scr in ipairs(targets) do
        local data = ExtractSource(scr)
        SafeWrite(data)

        if not DISABLE_SAFETY_PAUSES then
            task.wait(1)
            if i % 10 == 0 then task.wait(2) end
        end
    end

    SafeWrite("\n\n=== EXTRACCIÓN FINALIZADA. Total scripts: " .. #targets .. " ===\n")
    print("✅ Extracción de scripts completada. Archivo: " .. FILE_NAME)
end

-- [ INICIO AUTÓNOMO ]
task.spawn(function()
    task.wait(1)
    -- Instalar monitor HTTP primero (quedará en segundo plano)
    InstallHttpMonitor()
    -- Iniciar volcado profundo
    StartDeepScan()
    print("🎯 OMNI-EXTRACTOR V8 está trabajando en segundo plano. Revisa el archivo al finalizar.")
end)

print("📁 Archivo de salida: " .. FILE_NAME)
print("⏳ El proceso puede tardar varios minutos. No cierres el juego.")
