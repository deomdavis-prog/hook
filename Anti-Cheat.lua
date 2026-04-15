--[[
    DESOFUSCADOR PROFUNDO v4.0 - Delta Executor (Luau/Roblox)
    Para uso exclusivo en scripts propios.
]]

-- ============================================================
--  PEGA TU SCRIPT OFUSCADO AQUÍ
-- ============================================================
local OBFUSCATED_SCRIPT = [[
    loadstring(game:HttpGet('https://api.luarmor.net/files/v3/loaders/49f02b0d8c1f60207c84ae76e12abc1e.lua'))()


]]
-- ============================================================

-- ===== SNAPSHOT DE FUNCIONES ORIGINALES =====
local _print        = print
local _warn         = warn
local _load         = load
local _loadstring   = loadstring
local _pcall        = pcall
local _tostring     = tostring
local _type         = type
local _pairs        = pairs
local _ipairs       = ipairs
local _select       = select
local _concat       = table.concat
local _insert       = table.insert
local _format       = string.format
local _rep          = string.rep
local _match        = string.match

-- ===== API DE DELTA (con fallbacks seguros) =====
local api = {
    getconstants  = getconstants  or function() return {} end,
    getupvalues   = getupvalues   or function() return {} end,
    getprotos     = getprotos     or function() return {} end,
    getinfo       = (debug and debug.getinfo) or function() return nil end,
    getupvalue    = (debug and debug.getupvalue) or function() return nil end,
}

-- Compatibilidad: Delta puede exponer getproto (singular) en lugar de getprotos
if not getprotos and getproto then
    api.getprotos = function(func)
        local results, i = {}, 0
        while true do
            local ok, p = _pcall(getproto, func, i, false)
            if not ok or not p then break end
            _insert(results, p)
            i = i + 1
        end
        return results
    end
end

-- ===== ALMACENAMIENTO =====
local Found = {
    loadstrings   = {},   -- código capturado vía loadstring/load
    upvalStrings  = {},   -- strings largas en upvalues
    constants     = {},   -- constantes largas de cualquier función
    prints        = {},   -- salidas de print interceptadas
    reconstructed = {},   -- fragmentos con pinta de código Lua
}

local visited = {}  -- evitar loops infinitos en recursión

-- ===== UTILIDADES =====
local function log(icon, msg)
    _print(_format("[%s] %s", icon, _tostring(msg)))
end

local function separator(title)
    local line = _rep("─", 55)
    _print("\n" .. line)
    if title then _print("  " .. title) end
    _print(line)
end

local function looksLikeLua(s)
    -- Heurística: detecta patrones comunes de código Lua/Luau
    local patterns = {
        "loadstring", "function%s*%(", "local%s+%w+%s*=",
        "require", "game%.", "workspace%.", "script%.",
        "pcall", "coroutine", "string%.%w+", "table%.%w+",
        "while%s+", "for%s+", "if%s+", "return%s+",
    }
    local score = 0
    for _, p in _ipairs(patterns) do
        if _match(s, p) then score = score + 1 end
    end
    return score >= 2  -- al menos 2 patrones = probablemente código
end

-- ===== EXTRACCIÓN RECURSIVA DE CONSTANTES Y PROTOS =====
local function deepExtract(func, depth)
    depth = depth or 0
    if depth > 10 then return end  -- límite de profundidad
    if visited[func] then return end
    visited[func] = true

    -- Constantes
    local ok, consts = _pcall(api.getconstants, func)
    if ok and consts then
        for _, v in _ipairs(consts) do
            if _type(v) == "string" and #v > 60 then
                _insert(Found.constants, {
                    src    = _format("proto@depth%d[%s]", depth, _tostring(func)),
                    value  = v,
                    len    = #v,
                    isCode = looksLikeLua(v),
                })
            end
        end
    end

    -- Upvalues de esta función específica
    local ok2, upvals = _pcall(api.getupvalues, func)
    if ok2 and upvals then
        for k, v in _pairs(upvals) do
            if _type(v) == "string" and #v > 60 then
                _insert(Found.upvalStrings, {
                    name  = _tostring(k),
                    value = v,
                    len   = #v,
                })
            elseif _type(v) == "function" and not visited[v] then
                deepExtract(v, depth + 1)
            end
        end
    end

    -- Funciones internas (protos)
    local ok3, protos = _pcall(api.getprotos, func)
    if ok3 and protos then
        for _, p in _ipairs(protos) do
            if _type(p) == "function" then
                deepExtract(p, depth + 1)
            end
        end
    end
end

-- ===== HOOKS DE INTERCEPCIÓN =====
local function makeLoadHook(original, label)
    return function(code, name, ...)
        if _type(code) == "string" and #code > 10 then
            _insert(Found.loadstrings, {
                source = code,
                name   = name or ("=(" .. label .. ")"),
                len    = #code,
            })
            log("🎯 CAPTURADO", _format("%s interceptado — %d caracteres", label, #code))
        end
        return original(code, name, ...)
    end
end

loadstring = makeLoadHook(_loadstring, "loadstring")
load       = makeLoadHook(_load,       "load")

print = function(...)
    local parts = {}
    for i = 1, _select("#", ...) do
        _insert(parts, _tostring(_select(i, ...)))
    end
    local msg = _concat(parts, "\t")
    _insert(Found.prints, msg)
    _print("[🖨️ PRINT]", msg)
end

-- ===== EJECUCIÓN CONTROLADA =====
separator("🚀 DESOFUSCADOR PROFUNDO v4.0 — Delta Executor")
log("⏳", "Compilando script ofuscado...")

local mainFunc, loadErr = _loadstring(OBFUSCATED_SCRIPT)
if not mainFunc then
    log("❌ ERROR DE CARGA", loadErr)
    return
end

log("✅", "Compilado OK. Extrayendo estructura interna...")
deepExtract(mainFunc)

log("⚙️", "Ejecutando en entorno controlado (pcall)...")
local execOk, execErr = _pcall(mainFunc)
if execOk then
    log("✅", "Ejecución completada sin errores.")
else
    log("⚠️ ERROR DE EJECUCIÓN", execErr)
end

-- Restaurar funciones originales inmediatamente después
loadstring = _loadstring
load       = _load
print      = _print

-- ===== RECONSTRUCCIÓN DE FRAGMENTOS =====
for _, item in _ipairs(Found.constants) do
    if item.isCode then
        _insert(Found.reconstructed, {
            method = "Constant (looksLikeLua)",
            code   = item.value,
        })
    end
end
for _, item in _ipairs(Found.upvalStrings) do
    if looksLikeLua(item.value) then
        _insert(Found.reconstructed, {
            method = "Upvalue '" .. item.name .. "'",
            code   = item.value,
        })
    end
end

-- ===== REPORTE FINAL =====
separator("🧩 RESULTADOS")

-- [1] Loadstrings interceptadas — CANDIDATO PRINCIPAL
separator("🔍 [1] LOADSTRINGS INTERCEPTADAS (candidato principal)")
if #Found.loadstrings > 0 then
    for i, data in _ipairs(Found.loadstrings) do
        _print(_format("\n--- #%d | %s | %d chars ---", i, data.name, data.len))
        _print(data.source)
    end
else
    _print("⚠️  Ninguna loadstring capturada.")
end

-- [2] Fragmentos reconstruidos
separator("🔍 [2] FRAGMENTOS CON PINTA DE CÓDIGO LUA")
if #Found.reconstructed > 0 then
    for i, rec in _ipairs(Found.reconstructed) do
        _print(_format("\n--- #%d | Método: %s ---", i, rec.method))
        _print(rec.code)
    end
else
    _print("⚠️  No se reconstruyeron fragmentos.")
end

-- [3] Todas las constantes largas
separator("🔍 [3] CONSTANTES LARGAS (>60 chars)")
if #Found.constants > 0 then
    for i, item in _ipairs(Found.constants) do
        _print(_format("\n[%d] src=%s | len=%d | isCode=%s",
            i, item.src, item.len, _tostring(item.isCode)))
        _print(item.value)
    end
else
    _print("⚠️  Sin constantes largas.")
end

-- [4] Upvalues con strings
separator("🔍 [4] UPVALUES CON STRINGS LARGAS")
if #Found.upvalStrings > 0 then
    for i, uv in _ipairs(Found.upvalStrings) do
        _print(_format("\n[%d] upvalue='%s' | len=%d", i, uv.name, uv.len))
        _print(uv.value)
    end
else
    _print("⚠️  Sin upvalues relevantes.")
end

-- [5] Prints sospechosas
local suspiciousPrints = {}
for _, msg in _ipairs(Found.prints) do
    if looksLikeLua(msg) or #msg > 200 then
        _insert(suspiciousPrints, msg)
    end
end
separator("🔍 [5] PRINTS SOSPECHOSAS")
if #suspiciousPrints > 0 then
    for i, msg in _ipairs(suspiciousPrints) do
        _print(_format("\n--- Print #%d ---", i))
        _print(msg)
    end
else
    _print("⚠️  Sin prints sospechosas.")
end

separator("🏁 FIN DEL ANÁLISIS")
_print("👉 Prioridad: sección [1] → [2] → [3] → [4]")
_print("👉 Si [1] está vacía, tu ofuscador probablemente usa XOR/VM custom.")
_print(_rep("─", 55))
