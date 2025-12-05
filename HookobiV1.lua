local SCRIPT_OFUSCADO = [[ 



]]

local PayloadsCapturados = {}
local loadstring_original = loadstring
local pcall_original = pcall
local concat_original = table.concat
local char_original = string.char
local hashes = {}
local buffer = {}

local function es_bytecode(t)
    if type(t) ~= "string" or #t < 4 then return false end
    return t:sub(1,4) == "\27Lua"
end

local function es_codigo(t)
    if type(t) ~= "string" or #t < 80 then return false end
    local p = 0
    if t:find("local") then p = p + 1 end
    if t:find("function") then p = p + 1 end
    if t:find("return") then p = p + 1 end
    return p >= 2
end

local function guardar(c, tp)
    if type(c) ~= "string" or #c < 50 then return end
    if es_bytecode(c) or es_codigo(c) then
        table.insert(PayloadsCapturados, {c=c, t=tp, s=#c})
        return true
    end
end

local function hook_loadstring(cd, nm)
    if type(cd) == "string" and #cd > 50 then
        local h = tostring(#cd)
        if not hashes[h] then
            hashes[h] = true
            guardar(cd, "loadstring")
        end
    end
    return loadstring_original(cd, nm)
end

local function hook_char(...)
    local b = {...}
    if #b > 50 then
        for i = 1, #b do
            buffer[#buffer + 1] = b[i]
        end
        if #buffer > 400 then
            local txt = char_original(unpack(buffer))
            guardar(txt, "char")
            buffer = {}
        end
    end
    return char_original(...)
end

local function hook_concat(tb, sp, i, j)
    if type(tb) == "table" and #tb > 8 then
        local r = concat_original(tb, sp, i, j)
        if type(r) == "string" and #r > 400 then
            guardar(r, "concat")
        end
        return r
    end
    return concat_original(tb, sp, i, j)
end

local env = {}
for k, v in pairs(_G) do env[k] = v end

env.loadstring = hook_loadstring
env.load = hook_loadstring
env.table = {}
for k, v in pairs(table) do env.table[k] = v end
env.table.concat = hook_concat
env.string = {}
for k, v in pairs(string) do env.string[k] = v end
env.string.char = hook_char
env.getfenv = function(n)
    if not n or n == 0 then return env end
    return getfenv(n)
end

if #SCRIPT_OFUSCADO < 50 then
    warn("ERROR: Pega el codigo ofuscado en SCRIPT_OFUSCADO entre [[ ]]")
    return
end

local func, err = loadstring_original(SCRIPT_OFUSCADO, "Target")
if not func then
    warn("ERROR DE COMPILACION: " .. tostring(err))
    return
end

setfenv(func, env)
local ok, res = pcall_original(func)

for n, v in pairs(env) do
    if type(v) == "string" and #v > 100 and not _G[n] then
        guardar(v, "var")
    end
end

print("=================================")
print("PAYLOADS CAPTURADOS: " .. #PayloadsCapturados)
print("=================================")

if #PayloadsCapturados > 0 then
    local grande = PayloadsCapturados[1]
    for i = 2, #PayloadsCapturados do
        if PayloadsCapturados[i].s > grande.s then
            grande = PayloadsCapturados[i]
        end
    end
    
    print("PAYLOAD MAS GRANDE: " .. grande.s .. " bytes [" .. grande.t .. "]")
    
    if setclipboard then
        pcall(function() setclipboard(grande.c) end)
        print("COPIADO AL PORTAPAPELES")
    end
    
    if grande.s < 2000 then
        print("PREVIEW:")
        print(grande.c:sub(1, 500))
    end
else
    print("NO SE CAPTURARON PAYLOADS")
    print("Asegurate de pegar el codigo en SCRIPT_OFUSCADO")
end

_G.Payloads = PayloadsCapturados
