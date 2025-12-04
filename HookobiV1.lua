-- ============================================================================
-- INTERCEPTOR Y LOGGER DE DESOFUSCACIÓN LURAPH (Optimized v2.0)
-- Objetivo: Capturar el proceso de reconstrucción de código en tiempo real.
-- ============================================================================

-- CONFIGURACIÓN
local CONFIG = {
    LogFile = "intercept_log.txt",
    DumpFile = "intercept_dump.lua",
    BinDumpFile = "intercept_bytecode.bin",
    BufferLimit = 50, -- Líneas a guardar en memoria antes de escribir (Optimización de I/O)
    MaxStringLogLen = 200, -- No loguear cadenas gigantes en el texto plano para no saturar
    DetectLuaHeader = true, -- Detectar cabeceras \27Lua automáticamente
}

-- ============================================================================
-- 1. SISTEMA DE LOGGING OPTIMIZADO (BUFFER)
-- ============================================================================

local Logger = {
    buffer = {},
    file_handle = nil
}

function Logger:init()
    self.file_handle = io.open(CONFIG.LogFile, "w")
    if self.file_handle then
        self.file_handle:write("--- INICIO DE INTERCEPTACIÓN ---\n" .. os.date() .. "\n\n")
        self.file_handle:flush()
    end
end

function Logger:log(msg, ...)
    local args = {...}
    for i, v in ipairs(args) do args[i] = tostring(v) end
    local full_msg = string.format("[%s] %s %s", os.date("%H:%M:%S"), msg, table.concat(args, "\t"))
    
    -- Imprimir en consola para feedback visual
    print(full_msg)
    
    -- Agregar al buffer
    table.insert(self.buffer, full_msg)
    
    -- Si el buffer se llena, escribir a disco
    if #self.buffer >= CONFIG.BufferLimit then
        self:flush()
    end
end

function Logger:flush()
    if self.file_handle then
        self.file_handle:write(table.concat(self.buffer, "\n") .. "\n")
        self.file_handle:flush()
        self.buffer = {} -- Limpiar buffer
    end
end

function Logger:save_payload(content, filename_prefix, extension)
    local fname = filename_prefix .. "_" .. os.time() .. (extension or ".lua")
    local f = io.open(fname, "wb")
    if f then
        f:write(content)
        f:close()
        self:log(">>> [SUCCESS] Payload guardado en:", fname)
        return true
    end
    return false
end

function Logger:close()
    self:flush()
    if self.file_handle then self.file_handle:close() end
end

Logger:init()

-- ============================================================================
-- 2. UTILIDADES DE ANÁLISIS
-- ============================================================================

local function is_lua_bytecode(str)
    return str:sub(1, 4) == "\27Lua"
end

local function is_readable_code(str)
    -- Heurística simple: busca palabras clave comunes
    if #str < 20 then return false end
    local keywords = {"local", "function", "return", "end", "if", "then"}
    local matches = 0
    for _, k in ipairs(keywords) do
        if str:find(k) then matches = matches + 1 end
    end
    return matches >= 2
end

local function sanitize_str(s)
    if type(s) ~= "string" then return tostring(s) end
    if #s > CONFIG.MaxStringLogLen then
        return string.format("%q (Truncado, len=%d)", s:sub(1, CONFIG.MaxStringLogLen), #s)
    end
    return string.format("%q", s)
end

-- ============================================================================
-- 3. INTERCEPTACIÓN DE CORE (ENV)
-- ============================================================================

-- Guardamos referencias originales para usarlas internamente
local real_load = loadstring or load
local real_pcall = pcall
local real_string_char = string.char
local real_table_concat = table.concat

-- Entorno virtual (Sandbox)
local VirtualEnv = {}

-- Clonar _G en VirtualEnv de forma segura
for k, v in pairs(_G) do
    VirtualEnv[k] = v
end

-- Sobrescribir funciones críticas en el entorno virtual

-- A. INTERCEPTAR LOAD/LOADSTRING (El punto más crítico)
local function intercepted_load(chunk, chunkname, ...)
    Logger:log("=== LOAD DETECTADO ===")
    Logger:log("Nombre:", chunkname or "N/A")
    
    if type(chunk) == "string" then
        Logger:log("Tamaño del chunk:", #chunk)
        
        -- Verificar si es Bytecode o Código Fuente
        if is_lua_bytecode(chunk) then
            Logger:log(">>> TIPO: LUA BYTECODE DETECTADO")
            Logger:save_payload(chunk, "luraph_bytecode", ".bin")
        elseif is_readable_code(chunk) then
            Logger:log(">>> TIPO: CÓDIGO FUENTE DETECTADO")
            Logger:save_payload(chunk, "luraph_source", ".lua")
        else
            Logger:log(">>> TIPO: DESCONOCIDO (Guardando por si acaso)")
            Logger:save_payload(chunk, "luraph_unknown", ".txt")
        end
    end
    
    return real_load(chunk, chunkname, ...)
end

VirtualEnv.loadstring = intercepted_load
VirtualEnv.load = intercepted_load

-- B. INTERCEPTAR STRING.CHAR (Usado para construir el script byte a byte)
VirtualEnv.string = {}
for k, v in pairs(string) do VirtualEnv.string[k] = v end

VirtualEnv.string.char = function(...)
    local args = {...}
    -- Luraph a veces llama string.char con cientos de argumentos para armar el script
    if #args > 50 then
        Logger:log("!!! string.char LLAMADO CON MUCHOS ARGUMENTOS:", #args)
        -- Podríamos reconstruir esto, pero generalmente table.concat captura el resultado final
    end
    return real_string_char(...)
end

-- C. INTERCEPTAR OPERACIONES BITWISE (Luraph usa esto para descifrar)
if bit32 then
    VirtualEnv.bit32 = {}
    for k, v in pairs(bit32) do
        VirtualEnv.bit32[k] = function(...)
            -- No loguear todo, sería demasiado spam. 
            -- Solo loguear si los argumentos son sospechosos o muy grandes si se desea.
            return v(...)
        end
    end
end

-- D. INTERCEPTAR GETFENV/SETFENV (Anti-Tamper)
VirtualEnv.getfenv = function(f)
    -- Luraph chequea esto para ver si está en un entorno sandbox
    -- Devolvemos el entorno virtual para engañarlo
    if not f or f == 0 then return VirtualEnv end
    return getfenv(f)
end

-- ============================================================================
-- 4. EJECUTOR
-- ============================================================================

local function Deobfuscate(script_content)
    Logger:log("Iniciando ejecución segura...")
    
    -- Preparamos el chunk con el entorno virtual
    local func, err = real_load(script_content, "Luraph_Obfuscated", "t", VirtualEnv)
    
    if not func then
        Logger:log("Error de sintaxis al cargar:", err)
        return
    end
    
    -- Establecer el entorno si load no lo hizo (para Lua 5.1/JIT)
    if setfenv then
        setfenv(func, VirtualEnv)
    end
    
    -- Ejecutar
    local status, result = real_pcall(func)
    
    if status then
        Logger:log("Ejecución finalizada con éxito.")
    else
        Logger:log("Error en tiempo de ejecución:", result)
    end
    
    -- Análisis Post-Ejecución: Buscar variables globales que quedaron en el env
    Logger:log("=== VARIABLES GLOBALES RESIDUALES ===")
    for k, v in pairs(VirtualEnv) do
        if _G[k] == nil then -- Si no estaba en el _G original
            if type(v) == "string" then
                if is_readable_code(v) then
                    Logger:log("Variable Global Sospechosa [STRING CODE]:", k)
                    Logger:save_payload(v, "global_var_"..tostring(k))
                else
                    Logger:log("Variable Global Nueva:", k, sanitize_str(v))
                end
            elseif type(v) == "function" then
                Logger:log("Nueva Función Global:", k)
            elseif type(v) == "table" then
                Logger:log("Nueva Tabla Global:", k, "(Table)")
            end
        end
    end
    
    Logger:close()
end

-- ============================================================================
-- 5. PUNTO DE ENTRADA (Cargar archivo)
-- ============================================================================

local input_file = "Cooooooontenido.txt" -- El archivo que subiste

local f = io.open(input_file, "r")
if not f then
    print("Error: No se encuentra el archivo " .. input_file)
    print("Asegúrate de que el archivo ofuscado esté en la misma carpeta.")
else
    local content = f:read("*a")
    f:close()
    print("Archivo cargado. Tamaño: " .. #content .. " bytes.")
    Deobfuscate(content)
end
```

### Principales Mejoras Realizadas:

1.  **Buffer de Logging (`Logger` Class):**
    * **Antes:** Se hacía `io.open` -> `write` -> `io.close` en CADA log. Esto mata el disco y ralentiza el script x100.
    * **Ahora:** Se acumulan los mensajes en una tabla (`self.buffer`) y solo se escriben en disco cada 50 mensajes o al final. Esto hace que la ejecución sea casi nativa.

2.  **Detección Inteligente (`intercepted_load`):**
    * El script verifica activamente si lo que se intenta cargar (`loadstring`) tiene la firma de **Bytecode Lua** (`\27Lua`) o si parece **Código Fuente** (contiene `local`, `function`, etc.).
    * Si detecta algo interesante, lo guarda automáticamente en un archivo `.bin` o `.lua` separado con el prefijo `luraph_source_` o `luraph_bytecode_`. **Este es el paso clave para obtener el código desofuscado.**

3.  **Engaño a `getfenv`:**
    * Luraph v14 intenta detectar si está siendo analizado llamando a `getfenv`. Si ve que el entorno no es el estándar, a veces falla a propósito o entra en un bucle infinito.
    * He "mokckeado" `getfenv` dentro del `VirtualEnv` para que se devuelva a sí mismo, engañando al script para que crea que está en un entorno normal.

4.  **Análisis Post-Ejecución:**
    * Al terminar de correr (o fallar), el script escanea el `VirtualEnv` buscando variables que **no** existían en el `_G` original. A menudo, el código desofuscado final se deja en una variable global antes de ejecutarse.

### Instrucciones de uso:

1.  Guarda el código de arriba como `desofuscador.lua`.
2.  Asegúrate de que tu archivo ofuscado se llame `Cooooooontenido.txt` (o cambia la variable `input_file` al final del script).
3.  Ejecuta el script: `lua5.1 desofuscador.lua` (o usando LuaJIT que es mejor).
4.  Observa la carpeta. Si tiene éxito, verás archivos generados como `luraph_source_[timestamp].lua` que contendrán las capas desofuscadas intermedias.
