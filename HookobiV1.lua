-- ============================================================================
-- INTERCEPTOR LURAPH PARA ROBLOX (DELTA / FLUXUS / KRNL)
-- ============================================================================

-- [OPCIÓN A] Si no puedes usar archivos, pega todo el código ofuscado de "Cooooooontenido.txt" aquí abajo:
-- Ponlo entre los corchetes dobles [[ PEGAR AQUI ]]
local SCRIPT_IN_TEXT = [[ 
-- PEGA AQUI EL CONTENIDO DE TU ARCHIVO OFUSCADO SI NO TE FUNCIONA READFILE
]]

-- [OPCIÓN B] Nombre del archivo en la carpeta 'workspace' de tu ejecutor
local INPUT_FILENAME = "Cooooooontenido.txt" 

-- CONFIGURACIÓN
local CONFIG = {
    LogFile = "luraph_log.txt",
    DumpFile = "luraph_dump.lua",
    UseConsole = true, -- Imprimir en la consola (F9)
}

-- ============================================================================
-- 1. SISTEMA DE LOGGING COMPATIBLE CON ROBLOX
-- ============================================================================

local Logger = {
    buffer = {}
}

-- Función segura para escribir archivos en Roblox
local function safe_write(filename, content)
    if writefile then
        writefile(filename, content)
    else
        print("ERROR: Tu ejecutor no soporta 'writefile'.")
    end
end

local function safe_append(filename, content)
    if appendfile then
        appendfile(filename, content)
    elseif writefile and readfile then
        -- Fallback si no existe appendfile
        local current = ""
        pcall(function() current = readfile(filename) end)
        writefile(filename, current .. content)
    end
end

function Logger:init()
    safe_write(CONFIG.LogFile, "--- INICIO DELTA LURAPH INTERCEPTOR ---\n\n")
    print(">>> Logger Inicializado. Revisa la carpeta workspace de Delta.")
end

function Logger:log(msg, ...)
    local args = {...}
    for i, v in ipairs(args) do args[i] = tostring(v) end
    local full_msg = string.format("[%s] %s %s", os.date("%X"), msg, table.concat(args, "\t"))
    
    if CONFIG.UseConsole then
        print("[-] " .. full_msg) -- Imprimir en la consola de Roblox
    end
    
    table.insert(self.buffer, full_msg)
    
    -- Guardar cada 20 líneas para no perder datos si crashea
    if #self.buffer >= 20 then
        self:flush()
    end
end

function Logger:flush()
    if #self.buffer > 0 then
        safe_append(CONFIG.LogFile, table.concat(self.buffer, "\n") .. "\n")
        self.buffer = {}
    end
end

function Logger:save_payload(content, name_suffix, ext)
    local fname = "dump_" .. name_suffix .. "_" .. math.random(1000,9999) .. (ext or ".lua")
    safe_write(fname, content)
    self:log(">>> [GUARDADO] Archivo creado:", fname)
    -- Intenta mostrar una alerta en pantalla si es posible (función extra de Delta)
    if messagebox then 
        pcall(function() messagebox("Luraph Dumped!", "Archivo guardado: " .. fname, 0) end)
    end
end

Logger:init()

-- ============================================================================
-- 2. ENTORNO VIRTUAL (SANDBOX)
-- ============================================================================

-- Guardamos las funciones reales antes de que el script ofuscado pueda tocarlas
local real_loadstring = loadstring
local real_pcall = pcall
local real_string_char = string.char

-- Detectar si es bytecode de Lua
local function is_lua_bytecode(str)
    return str:sub(1, 4) == "\27Lua"
end

local function is_readable_code(str)
    if #str < 50 then return false end
    if str:match("local%s+") or str:match("function%(") or str:match("return%s+") then
        return true
    end
    return false
end

-- Creamos el entorno falso
local VirtualEnv = {}

-- Copiamos globales necesarias
for k, v in pairs(getgenv and getgenv() or _G) do
    VirtualEnv[k] = v
end

-- INTERCEPTAR LOADSTRING (El corazón del desofuscador)
VirtualEnv.loadstring = function(chunk, chunkname)
    Logger:log("=== LOADSTRING LLAMADO ===")
    
    if type(chunk) == "string" then
        Logger:log("Longitud del chunk:", #chunk)
        
        if is_lua_bytecode(chunk) then
            Logger:log(">>> BYTECODE ENCONTRADO! Guardando...")
            Logger:save_payload(chunk, "bytecode", ".bin")
        elseif is_readable_code(chunk) then
            Logger:log(">>> CODIGO FUENTE ENCONTRADO! Guardando...")
            Logger:save_payload(chunk, "source", ".lua")
        else
            -- Guardar de todas formas por si acaso es el script final
            if #chunk > 500 then
                Logger:log(">>> Chunk grande detectado (posible script final). Guardando...")
                Logger:save_payload(chunk, "unknown", ".txt")
            end
        end
    end
    
    return real_loadstring(chunk, chunkname)
end

-- Alias para load
VirtualEnv.load = VirtualEnv.loadstring

-- Engañar a getfenv (Anti-tamper de Luraph)
VirtualEnv.getfenv = function(f)
    if not f or f == 0 then return VirtualEnv end
    return getfenv(f)
end

-- Interceptar string.char para ver cómo se construye el script
VirtualEnv.string = {}
for k, v in pairs(string) do VirtualEnv.string[k] = v end
VirtualEnv.string.char = function(...)
    local args = {...}
    if #args > 100 then
        -- Si llama string.char con muchos argumentos, está construyendo el payload
        Logger:log("!!! string.char masivo detectado ("..#args.." bytes)")
    end
    return real_string_char(...)
end

-- ============================================================================
-- 3. EJECUCIÓN
-- ============================================================================

local target_script = ""

-- Intentar leer del archivo primero
if isfile and isfile(INPUT_FILENAME) then
    Logger:log("Leyendo archivo desde workspace:", INPUT_FILENAME)
    target_script = readfile(INPUT_FILENAME)
elseif #SCRIPT_IN_TEXT > 20 then
    Logger:log("Usando script pegado en la variable SCRIPT_IN_TEXT")
    target_script = SCRIPT_IN_TEXT
else
    warn("ERROR: No se encontró '"..INPUT_FILENAME.."' en workspace y SCRIPT_IN_TEXT está vacío.")
    print("Coloca el archivo en la carpeta workspace de Delta o pega el código en la variable SCRIPT_IN_TEXT al inicio.")
    return
end

Logger:log("Iniciando ejecución protegida...")

-- Ejecutar el script ofuscado dentro de nuestro entorno virtual
-- Usamos loadstring estándar de Roblox pero le pasamos nuestro VirtualEnv como entorno si es posible
local func, err = real_loadstring(target_script, "Luraph_Target")

if not func then
    Logger:log("Error de sintaxis al cargar el script ofuscado:", err)
else
    -- Forzar el entorno (Lua 5.1 / Luau)
    setfenv(func, VirtualEnv)
    
    local success, result = real_pcall(func)
    
    if success then
        Logger:log("Script finalizó correctamente.")
    else
        Logger:log("Script falló (esto es normal si detectó el hook):", result)
    end
end

-- Ver si quedó algo interesante en el entorno
Logger:log("--- Escaneando variables globales residuales ---")
for k, v in pairs(VirtualEnv) do
    if not _G[k] and not (getgenv and getgenv()[k]) then
        if type(v) == "string" and #v > 100 then
            Logger:log("Variable global sospechosa encontrada:", k)
            Logger:save_payload(v, "global_"..tostring(k), ".lua")
        end
    end
end

Logger:flush()
print(">>> PROCESO TERMINADO. REVISA TUS ARCHIVOS EN WORKSPACE <<<")
