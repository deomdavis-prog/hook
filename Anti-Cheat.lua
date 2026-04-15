--[[
    ╔══════════════════════════════════════════════════════════╗
    ║   VM RECONSTRUCTOR v1.0 — Delta Executor (Luau/Roblox)  ║
    ║   General-purpose · Auto-detect · Output a .txt          ║
    ╚══════════════════════════════════════════════════════════╝

    Cubre:
      · VM con opcode-table personalizada
      · Bytecode Luau serializado/custom
      · Strings con XOR fijo, XOR variable, Base64, charset custom
      · Loop tipo while pc < #instructions
      · Wrappers con múltiples capas de loadstring
]]

-- ═══════════════════════════════════════════════
--  PEGA TU SCRIPT OFUSCADO AQUÍ
-- ═══════════════════════════════════════════════
local OBFUSCATED_SCRIPT = [[
    loadstring(game:HttpGet('https://api.luarmor.net/files/v3/loaders/49f02b0d8c1f60207c84ae76e12abc1e.lua'))()

]]
-- ═══════════════════════════════════════════════


-- ─────────────────────────────────────────────
--  SNAPSHOT TOTAL DEL ENTORNO (antes de hooks)
-- ─────────────────────────────────────────────
local ENV = {
    print       = print,
    warn        = warn,
    pcall       = pcall,
    xpcall      = xpcall,
    tostring    = tostring,
    tonumber    = tonumber,
    type        = type,
    pairs       = pairs,
    ipairs      = ipairs,
    select      = select,
    rawget      = rawget,
    rawset      = rawset,
    setmetatable= setmetatable,
    getmetatable= getmetatable,
    unpack      = table.unpack or unpack,
    load        = load,
    loadstring  = loadstring,
    writefile   = writefile,  -- API de Delta
    -- string
    sfmt  = string.format,
    srep  = string.rep,
    ssub  = string.sub,
    sbyte = string.byte,
    schar = string.char,
    sfind = string.find,
    smatch= string.match,
    sgmatch=string.gmatch,
    srep2 = string.rep,
    -- table
    tins  = table.insert,
    tcon  = table.concat,
    tsort = table.sort,
    -- math
    bxor  = bit32 and bit32.bxor or function(a,b)
        -- fallback manual XOR para entornos sin bit32
        local r, m = 0, 1
        while a > 0 or b > 0 do
            if (a % 2 + b % 2) == 1 then r = r + m end
            a, b, m = math.floor(a/2), math.floor(b/2), m*2
        end
        return r
    end,
    band  = bit32 and bit32.band or function(a,b) return a & b end,
    bor   = bit32 and bit32.bor  or function(a,b) return a | b end,
    brsh  = bit32 and bit32.rshift or function(a,b) return a >> b end,
    blsh  = bit32 and bit32.lshift or function(a,b) return a << b end,
}

-- APIs de debug/delta con fallbacks
local DAPI = {
    getconstants = (getconstants  or function() return {} end),
    getupvalues  = (getupvalues   or function() return {} end),
    getprotos    = (getprotos     or function() return {} end),
    getinfo      = (debug and debug.getinfo)    or function() return {} end,
    getupvalue   = (debug and debug.getupvalue) or function() return nil end,
    setupvalue   = (debug and debug.setupvalue) or function() end,
}

-- Compatibilidad getproto singular (algunas versiones de Delta)
if not getprotos and getproto then
    DAPI.getprotos = function(fn)
        local res, i = {}, 0
        while true do
            local ok, p = ENV.pcall(getproto, fn, i, false)
            if not ok or not p then break end
            ENV.tins(res, p)
            i = i + 1
        end
        return res
    end
end


-- ─────────────────────────────────────────────
--  ALMACÉN DE HALLAZGOS
-- ─────────────────────────────────────────────
local R = {
    -- Layers de ejecución capturadas
    layers       = {},   -- {layer=N, source=string, name=string}

    -- Constantes crudas (todas)
    rawConstants = {},   -- {depth, funcRef, value, decoded}

    -- Strings decodificadas
    decodedStrings = {},

    -- Instrucciones de VM detectadas
    vmInstructions = {},  -- {pc, opname, args}

    -- Opcode table detectada
    opcodeTable  = {},    -- {[num]=name}

    -- Fingerprint de la VM
    fingerprint  = {
        vmType      = "unknown",  -- "opcode_table" | "bytecode_custom" | "loadstring_layer"
        strEncoding = "none",     -- "xor_fixed" | "xor_variable" | "base64" | "custom" | "none"
        hasLoop     = false,
        loopStyle   = "unknown",  -- "while_pc" | "dispatch_table" | "recursive"
        layers      = 0,
    },

    -- Log de operaciones
    log = {},
}

local visited = {}


-- ══════════════════════════════════════════════
--  UTILIDADES
-- ══════════════════════════════════════════════

local function log(tag, msg)
    local line = ENV.sfmt("[%s] %s", tag, ENV.tostring(msg))
    ENV.tins(R.log, line)
    ENV.print(line)
end

local function section(title)
    local bar = ENV.srep("═", 56)
    ENV.print("\n" .. bar)
    ENV.print("  " .. title)
    ENV.print(bar)
end

-- Detecta si una string tiene alta entropía (pinta de encriptada)
local function highEntropy(s)
    if #s < 8 then return false end
    local freq = {}
    for i = 1, #s do
        local b = ENV.sbyte(s, i)
        freq[b] = (freq[b] or 0) + 1
    end
    local unique = 0
    for _ in ENV.pairs(freq) do unique = unique + 1 end
    return unique / math.min(#s, 256) > 0.6
end

-- Heurística: ¿parece código Lua?
local function looksLikeLua(s)
    local hits = 0
    local patterns = {
        "local%s+%w+", "function%s*[%w_%(]", "loadstring",
        "while%s+", "for%s+%w", "if%s+%w", "return%s+",
        "end%s*$", "game%.", "script%.", "workspace%.",
        "pcall", "require", "coroutine", "string%.",
    }
    for _, p in ENV.ipairs(patterns) do
        if ENV.smatch(s, p) then hits = hits + 1 end
    end
    return hits >= 2, hits
end


-- ══════════════════════════════════════════════
--  MÓDULO 1 — DETECCIÓN DE ENCODING DE STRINGS
-- ══════════════════════════════════════════════

local Decoder = {}

-- Base64 estándar
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_MAP = {}
for i = 1, #B64_CHARS do
    B64_MAP[ENV.ssub(B64_CHARS, i, i)] = i - 1
end

function Decoder.base64(s)
    s = s:gsub("[^%w%+%/%=]", "")
    local result, pad = {}, 0
    if s:sub(-1) == "=" then pad = pad + 1 end
    if s:sub(-2,-2) == "=" then pad = pad + 1 end
    for i = 1, #s - 3, 4 do
        local a = B64_MAP[s:sub(i,i)]   or 0
        local b = B64_MAP[s:sub(i+1,i+1)] or 0
        local c = B64_MAP[s:sub(i+2,i+2)] or 0
        local d = B64_MAP[s:sub(i+3,i+3)] or 0
        local n = ENV.blsh(a,18) + ENV.blsh(b,12) + ENV.blsh(c,6) + d
        ENV.tins(result, ENV.schar(ENV.brsh(n,16)))
        if s:sub(i+2,i+2) ~= "=" then ENV.tins(result, ENV.schar(ENV.band(ENV.brsh(n,8),0xFF))) end
        if s:sub(i+3,i+3) ~= "=" then ENV.tins(result, ENV.schar(ENV.band(n,0xFF))) end
    end
    return ENV.tcon(result)
end

function Decoder.isBase64(s)
    return #s % 4 == 0 and ENV.smatch(s, "^[A-Za-z0-9%+%/%=]+$") ~= nil
end

-- XOR con clave fija (prueba claves comunes 1-255)
function Decoder.xorFixed(s, key)
    local out = {}
    for i = 1, #s do
        ENV.tins(out, ENV.schar(ENV.bxor(ENV.sbyte(s,i), key)))
    end
    return ENV.tcon(out)
end

-- XOR con clave variable (rolling XOR, la clave varía con cada byte)
function Decoder.xorVariable(s, seed, step)
    step = step or 1
    local out, k = {}, seed
    for i = 1, #s do
        ENV.tins(out, ENV.schar(ENV.bxor(ENV.sbyte(s,i), k % 256)))
        k = k + step
    end
    return ENV.tcon(out)
end

-- Intenta todas las claves XOR fijas y devuelve la mejor
function Decoder.bruteXorFixed(s)
    local best, bestScore, bestKey = s, 0, 0
    for k = 1, 255 do
        local attempt = Decoder.xorFixed(s, k)
        local isCode, score = looksLikeLua(attempt)
        if isCode and score > bestScore then
            best, bestScore, bestKey = attempt, score, k
        end
    end
    return best, bestKey, bestScore
end

-- Intenta rolling XOR (seed 1-50, step 1-5)
function Decoder.bruteXorVariable(s)
    local best, bestScore, bestParams = s, 0, {}
    for seed = 1, 50 do
        for step = 1, 5 do
            local attempt = Decoder.xorVariable(s, seed, step)
            local isCode, score = looksLikeLua(attempt)
            if isCode and score > bestScore then
                best, bestScore, bestParams = attempt, score, {seed=seed, step=step}
            end
        end
    end
    return best, bestParams, bestScore
end

-- Auto-detector: prueba todos los métodos y devuelve el mejor resultado
function Decoder.auto(s)
    -- 1. ¿Ya es legible?
    local isCode, score = looksLikeLua(s)
    if isCode then return s, "plain", score end

    -- 2. Base64?
    if Decoder.isBase64(s) then
        local decoded = ENV.pcall(Decoder.base64, s)
        if decoded then
            local ok2, sc2 = looksLikeLua(decoded)
            if ok2 then return decoded, "base64", sc2 end
        end
        -- Base64 + XOR
        local b64dec = Decoder.base64(s)
        local xorResult, xorKey, xorScore = Decoder.bruteXorFixed(b64dec)
        if xorScore > 0 then
            return xorResult, ENV.sfmt("base64+xor(key=%d)", xorKey), xorScore
        end
    end

    -- 3. XOR fijo
    local xorR, xorK, xorS = Decoder.bruteXorFixed(s)
    if xorS > 0 then
        return xorR, ENV.sfmt("xor_fixed(key=%d)", xorK), xorS
    end

    -- 4. XOR variable
    local xorVR, xorVP, xorVS = Decoder.bruteXorVariable(s)
    if xorVS > 0 then
        return xorVR, ENV.sfmt("xor_variable(seed=%d,step=%d)", xorVP.seed, xorVP.step), xorVS
    end

    -- 5. No se pudo decodificar
    return s, "unknown", 0
end


-- ══════════════════════════════════════════════
--  MÓDULO 2 — FINGERPRINTING DE LA VM
-- ══════════════════════════════════════════════

local VMFinger = {}

-- Busca un loop PC en constantes/upvalues (indicador de VM bytecode-based)
function VMFinger.detectLoopStyle(consts)
    local pcPattern  = 0
    local dispPattern= 0
    for _, v in ENV.ipairs(consts) do
        if ENV.type(v) == "string" then
            if ENV.smatch(v, "pc") or ENV.smatch(v, "instructions") or ENV.smatch(v, "opcode") then
                pcPattern = pcPattern + 1
            end
            if ENV.smatch(v, "dispatch") or ENV.smatch(v, "handler") or ENV.smatch(v, "OP%[") then
                dispPattern = dispPattern + 1
            end
        end
    end
    if pcPattern > dispPattern then return "while_pc"
    elseif dispPattern > 0 then return "dispatch_table"
    else return "unknown" end
end

-- Detecta tabla de opcodes buscando tablas con claves numéricas y valores string cortos
function VMFinger.findOpcodeTable(func, depth)
    depth = depth or 0
    if depth > 6 then return nil end
    local ok, upvals = ENV.pcall(DAPI.getupvalues, func)
    if not ok or not upvals then return nil end

    for _, v in ENV.pairs(upvals) do
        if ENV.type(v) == "table" then
            local numKeys, strVals, total = 0, 0, 0
            for k, val in ENV.pairs(v) do
                total = total + 1
                if ENV.type(k) == "number" then numKeys = numKeys + 1 end
                if ENV.type(val) == "string" and #val <= 16 and #val >= 2 then
                    strVals = strVals + 1
                end
            end
            -- Heurística: >60% claves numéricas y >60% valores string cortos → opcode table
            if total > 4 and (numKeys/total) > 0.6 and (strVals/total) > 0.6 then
                return v
            end
        end
    end

    -- Recursión en protos
    local ok2, protos = ENV.pcall(DAPI.getprotos, func)
    if ok2 and protos then
        for _, p in ENV.ipairs(protos) do
            if ENV.type(p) == "function" then
                local found = VMFinger.findOpcodeTable(p, depth + 1)
                if found then return found end
            end
        end
    end
    return nil
end


-- ══════════════════════════════════════════════
--  MÓDULO 3 — EXTRACCIÓN PROFUNDA Y RECURSIVA
-- ══════════════════════════════════════════════

local function deepExtract(func, depth)
    depth = depth or 0
    if depth > 12 or visited[func] then return end
    visited[func] = true

    -- Constantes
    local ok1, consts = ENV.pcall(DAPI.getconstants, func)
    if ok1 and consts then
        for _, v in ENV.ipairs(consts) do
            if ENV.type(v) == "string" and #v > 20 then
                local decoded, method, score = Decoder.auto(v)
                ENV.tins(R.rawConstants, {
                    depth    = depth,
                    raw      = v,
                    decoded  = decoded,
                    method   = method,
                    score    = score,
                    len      = #v,
                })
                if score > 0 and decoded ~= v then
                    ENV.tins(R.decodedStrings, {
                        original = v,
                        decoded  = decoded,
                        method   = method,
                    })
                    log("🔓 DECODIFICADO", ENV.sfmt("método=%s score=%d len=%d", method, score, #v))
                end
            end
        end
    end

    -- Upvalues
    local ok2, upvals = ENV.pcall(DAPI.getupvalues, func)
    if ok2 and upvals then
        for k, v in ENV.pairs(upvals) do
            if ENV.type(v) == "string" and #v > 20 then
                local decoded, method, score = Decoder.auto(v)
                ENV.tins(R.rawConstants, {
                    depth   = depth,
                    raw     = v,
                    decoded = decoded,
                    method  = method,
                    score   = score,
                    len     = #v,
                    src     = "upvalue:" .. ENV.tostring(k),
                })
            elseif ENV.type(v) == "function" then
                deepExtract(v, depth + 1)
            end
        end
    end

    -- Funciones internas
    local ok3, protos = ENV.pcall(DAPI.getprotos, func)
    if ok3 and protos then
        for _, p in ENV.ipairs(protos) do
            if ENV.type(p) == "function" then
                deepExtract(p, depth + 1)
            end
        end
    end
end


-- ══════════════════════════════════════════════
--  MÓDULO 4 — HOOKS DE CAPTURA DE LAYERS
-- ══════════════════════════════════════════════

local layerCount = 0

local function makeHook(original, label)
    return function(code, name, ...)
        if ENV.type(code) == "string" and #code > 10 then
            layerCount = layerCount + 1
            local decoded, method, score = Decoder.auto(code)
            ENV.tins(R.layers, {
                layer   = layerCount,
                raw     = code,
                decoded = decoded,
                method  = method,
                score   = score,
                name    = name or label,
                len     = #code,
            })
            log("🎯 LAYER " .. layerCount, ENV.sfmt("%s | %d chars | encoding=%s", label, #code, method))

            -- Extraer estructura de la función que se va a ejecutar
            local ok, fn = ENV.pcall(original, code, name)
            if ok and fn and ENV.type(fn) == "function" then
                deepExtract(fn, 0)
            end
            return ok and fn or nil
        end
        return original(code, name, ...)
    end
end

loadstring = makeHook(ENV.loadstring, "loadstring")
load       = makeHook(ENV.load,       "load")

-- También hookear pcall para detectar ejecución de funciones obtenidas de loadstring
local _pcall_real = ENV.pcall
pcall = function(fn, ...)
    if ENV.type(fn) == "function" and not visited[fn] then
        deepExtract(fn, 0)
    end
    return _pcall_real(fn, ...)
end


-- ══════════════════════════════════════════════
--  MÓDULO 5 — EJECUCIÓN CONTROLADA
-- ══════════════════════════════════════════════

section("🚀 VM RECONSTRUCTOR v1.0 — Delta Executor")
log("⏳", "Compilando script ofuscado...")

local mainFunc, loadErr = ENV.loadstring(OBFUSCATED_SCRIPT)
if not mainFunc then
    log("❌ FALLO DE COMPILACIÓN", loadErr)
    -- Intentar con load como fallback
    mainFunc, loadErr = ENV.load(OBFUSCATED_SCRIPT)
    if not mainFunc then
        log("❌ FALLO TOTAL", loadErr)
        return
    end
end

log("✅", "Compilado OK. Extrayendo estructura pre-ejecución...")
deepExtract(mainFunc, 0)

-- Fingerprinting antes de ejecutar
local ok1, consts0 = ENV.pcall(DAPI.getconstants, mainFunc)
if ok1 and consts0 then
    R.fingerprint.loopStyle = VMFinger.detectLoopStyle(consts0)
end
local opcodeT = VMFinger.findOpcodeTable(mainFunc)
if opcodeT then
    R.fingerprint.vmType = "opcode_table"
    for k, v in ENV.pairs(opcodeT) do
        R.opcodeTable[k] = v
    end
    log("📋 OPCODE TABLE", ENV.sfmt("Encontrada con %d entradas", #R.opcodeTable))
end

log("⚙️", "Ejecutando en pcall controlado...")
local execOk, execErr = _pcall_real(mainFunc)
R.fingerprint.layers = layerCount

if execOk then
    log("✅", "Ejecución completada.")
else
    log("⚠️  ERROR DE EJECUCIÓN", execErr)
end

-- Restaurar entorno
loadstring = ENV.loadstring
load       = ENV.load
pcall      = ENV.pcall


-- ══════════════════════════════════════════════
--  MÓDULO 6 — CONSTRUCCIÓN DEL REPORTE .TXT
-- ══════════════════════════════════════════════

local OUT = {}  -- líneas del archivo de salida

local function out(line)
    ENV.tins(OUT, ENV.tostring(line or ""))
end

local function outSep(title)
    out("")
    out(ENV.srep("═", 60))
    if title then out("  " .. title) end
    out(ENV.srep("═", 60))
end

local function outSub(title)
    out("")
    out(ENV.srep("─", 50))
    out("  " .. title)
    out(ENV.srep("─", 50))
end

-- ── HEADER ──
out("╔══════════════════════════════════════════════════════════╗")
out("║          VM RECONSTRUCTOR — REPORTE DE ANÁLISIS         ║")
out("╚══════════════════════════════════════════════════════════╝")
out(ENV.sfmt("Fecha/Hora  : %s", os.date and os.date("%Y-%m-%d %H:%M:%S") or "N/A"))
out(ENV.sfmt("Capas detectadas : %d", R.fingerprint.layers))

-- ── FINGERPRINT ──
outSep("1. FINGERPRINT DE LA VM")
out(ENV.sfmt("Tipo de VM      : %s", R.fingerprint.vmType))
out(ENV.sfmt("Encoding string : %s", R.fingerprint.strEncoding))
out(ENV.sfmt("Estilo de loop  : %s", R.fingerprint.loopStyle))
out(ENV.sfmt("Layers de exec  : %d", R.fingerprint.layers))
out(ENV.sfmt("Opcode entries  : %d", #R.opcodeTable))

-- ── OPCODE TABLE ──
if #R.opcodeTable > 0 then
    outSep("2. TABLA DE OPCODES DETECTADA")
    ENV.tsort(R.opcodeTable, function(a,b) return a < b end)
    for k, v in ENV.pairs(R.opcodeTable) do
        out(ENV.sfmt("  [%3s] = %s", ENV.tostring(k), ENV.tostring(v)))
    end
end

-- ── LAYERS (código real capturado) ──
outSep("3. LAYERS DE EJECUCIÓN CAPTURADAS")
if #R.layers > 0 then
    for _, lay in ENV.ipairs(R.layers) do
        outSub(ENV.sfmt("Layer #%d | %s | %d chars | encoding=%s | score=%d",
            lay.layer, lay.name, lay.len, lay.method, lay.score))
        out("")
        -- Si se decodificó, mostrar decodificado; si no, el raw
        if lay.score > 0 and lay.decoded ~= lay.raw then
            out("── DECODIFICADO ──")
            out(lay.decoded)
            out("")
            out("── RAW (ofuscado) ──")
            out(lay.raw)
        else
            out(lay.raw)
        end
    end
else
    out("  ⚠ No se capturaron layers. El script puede no usar loadstring.")
end

-- ── STRINGS DECODIFICADAS ──
outSep("4. STRINGS DECODIFICADAS AUTOMÁTICAMENTE")
if #R.decodedStrings > 0 then
    for i, item in ENV.ipairs(R.decodedStrings) do
        outSub(ENV.sfmt("String #%d | método=%s", i, item.method))
        out("ORIGINAL : " .. item.original)
        out("DECODED  : " .. item.decoded)
    end
else
    out("  ⚠ No se decodificaron strings automáticamente.")
    out("    → Posible VM con XOR de clave larga o charset completamente custom.")
end

-- ── CONSTANTES LARGAS ──
outSep("5. CONSTANTES LARGAS (>20 chars, ordenadas por longitud)")
ENV.tsort(R.rawConstants, function(a, b) return a.len > b.len end)
if #R.rawConstants > 0 then
    for i, item in ENV.ipairs(R.rawConstants) do
        if i > 60 then out("  ... (truncado a 60 entradas)") break end
        outSub(ENV.sfmt("Const #%d | len=%d | depth=%d | encoding=%s | score=%d",
            i, item.len, item.depth, item.method, item.score))
        out("RAW     : " .. ENV.ssub(item.raw, 1, 300))
        if item.decoded ~= item.raw then
            out("DECODED : " .. ENV.ssub(item.decoded, 1, 300))
        end
    end
else
    out("  ⚠ Sin constantes extraídas.")
end

-- ── LOG COMPLETO ──
outSep("6. LOG DE OPERACIONES")
for _, line in ENV.ipairs(R.log) do
    out(line)
end

-- ── GUÍA DE RECONSTRUCCIÓN MANUAL ──
outSep("7. GUÍA DE RECONSTRUCCIÓN MANUAL")
out([[
PRIORIDAD DE LECTURA:
  1. Sección 3 (Layers) → Es el código real si el ofuscador usa loadstring.
  2. Sección 4 (Strings decodificadas) → Constantes del código real.
  3. Sección 5 (Constantes largas) → Busca las de score > 0.

SI SECTION 3 ESTÁ VACÍA:
  → El ofuscador tiene una VM propia sin loadstring.
  → El bytecode está codificado dentro de una constante larga (Sección 5).
  → Busca la constante más larga — es el bytecode serializado.
  → El formato suele ser: número de instrucciones | instrucciones | pool de strings

SI EL ENCODING ES "unknown":
  → XOR con clave más larga que 1 byte.
  → Prueba extraer la clave del pool de constantes (strings cortas de 4-32 chars).
  → Aplica XOR cíclico: decoded[i] = raw[i] XOR key[i % #key]

INDICADORES DE VM OPCODE-TABLE:
  → Tabla con entradas como [1]="MOVE", [2]="LOADK", etc.
  → Loop while pc <= #code do ... end
  → Variables llamadas: instructions, proto, pc, stack, upvals, constants

RECONSTRUCCIÓN DE INSTRUCCIONES (VM bytecode-based):
  → Cada instrucción suele ser: {opcode, A, B, C} o un número de 32 bits
  → Los campos se extraen con bit shifts: op = inst >> 26, A = (inst >> 18) & 0xFF
  → Mapear opcode a nombre con la tabla de la Sección 2
]])

-- ── FOOTER ──
out("")
out(ENV.srep("═", 60))
out("  FIN DEL REPORTE — VM RECONSTRUCTOR v1.0")
out(ENV.srep("═", 60))


-- ══════════════════════════════════════════════
--  ESCRITURA DEL ARCHIVO DE SALIDA
-- ══════════════════════════════════════════════

local finalText = ENV.tcon(OUT, "\n")

local writeOk, writeErr = ENV.pcall(function()
    ENV.writefile("vm_reconstructed.txt", finalText)
end)

if writeOk then
    ENV.print("\n✅ REPORTE GUARDADO EN: vm_reconstructed.txt")
    ENV.print("📂 Encuéntralo en la carpeta 'workspace' de Delta Executor")
else
    ENV.print("\n⚠️  No se pudo escribir el archivo: " .. ENV.tostring(writeErr))
    ENV.print("📋 Imprimiendo reporte en consola...")
    ENV.print(finalText)
end
