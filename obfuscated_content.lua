-- ========================================
-- VM & STRING DEOBFUSCATOR v3.0
-- Advanced VM Analysis + String Decryption
-- ========================================

local VMDeobfuscator = {}
VMDeobfuscator.__index = VMDeobfuscator

-- ========================================
-- CONFIGURACIÓN
-- ========================================
local config = {
	verbose = true,
	max_iterations = 1000,
	timeout = 10,
	deep_analysis = true,
	export_vm_map = true,
	auto_beautify = true,
}

-- ========================================
-- UTILIDADES DE STRING
-- ========================================
local StringDecryptor = {}

function StringDecryptor.detectEncryption(str)
	local patterns = {
		xor = str:match("bit%.bxor") or str:match("bit32%.bxor"),
		base64 = str:match("[A-Za-z0-9+/]+=*") and #str % 4 == 0,
		hex = str:match("^[0-9a-fA-F]+$"),
		char_array = str:match("%{%s*%d+%s*,%s*%d+"),
		substitution = str:match("string%.char") and str:match("%d+"),
		custom = str:match("decrypt") or str:match("decode"),
	}
	return patterns
end

function StringDecryptor.xorDecrypt(encrypted, key)
	if type(encrypted) ~= "string" or type(key) ~= "number" then
		return nil
	end
	
	local result = {}
	for i = 1, #encrypted do
		local byte = encrypted:byte(i)
		local decrypted = bit32 and bit32.bxor(byte, key) or (byte ~ key)
		table.insert(result, string.char(decrypted))
	end
	return table.concat(result)
end

function StringDecryptor.multiXorDecrypt(encrypted, keys)
	if type(keys) == "table" then
		local result = {}
		for i = 1, #encrypted do
			local byte = encrypted:byte(i)
			local keyIndex = ((i - 1) % #keys) + 1
			local key = keys[keyIndex]
			local decrypted = bit32 and bit32.bxor(byte, key) or (byte ~ key)
			table.insert(result, string.char(decrypted))
		end
		return table.concat(result)
	end
	return nil
end

function StringDecryptor.base64Decode(str)
	local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	str = str:gsub('[^'..b..'=]', '')
	
	return (str:gsub('.', function(x)
		if x == '=' then return '' end
		local r, f = '', (b:find(x) - 1)
		for i = 6, 1, -1 do
			r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0')
		end
		return r
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if #x ~= 8 then return '' end
		local c = 0
		for i = 1, 8 do
			c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0)
		end
		return string.char(c)
	end))
end

function StringDecryptor.charArrayDecode(arr)
	if type(arr) ~= "table" then return nil end
	local result = {}
	for _, v in ipairs(arr) do
		if type(v) == "number" then
			table.insert(result, string.char(v))
		end
	end
	return table.concat(result)
end

function StringDecryptor.substitutionDecode(str, map)
	if type(map) ~= "table" then return str end
	return str:gsub(".", function(c)
		return map[c] or c
	end)
end

-- Desencriptador inteligente que prueba múltiples métodos
function StringDecryptor.smartDecrypt(encrypted)
	local results = {}
	
	-- Intentar Base64
	local success, decoded = pcall(StringDecryptor.base64Decode, encrypted)
	if success and decoded and decoded ~= encrypted then
		table.insert(results, {method = "Base64", result = decoded, confidence = 0.8})
	end
	
	-- Intentar XOR con claves comunes
	local common_keys = {7, 13, 42, 69, 88, 123, 255}
	for _, key in ipairs(common_keys) do
		local success, decoded = pcall(StringDecryptor.xorDecrypt, encrypted, key)
		if success and decoded and decoded:match("[%w%s]+") then
			table.insert(results, {method = "XOR-"..key, result = decoded, confidence = 0.6})
		end
	end
	
	-- Intentar hex decode
	if encrypted:match("^[0-9a-fA-F]+$") and #encrypted % 2 == 0 then
		local decoded = encrypted:gsub("..", function(hex)
			return string.char(tonumber(hex, 16))
		end)
		if decoded:match("[%w%s]+") then
			table.insert(results, {method = "Hex", result = decoded, confidence = 0.7})
		end
	end
	
	return results
end

-- ========================================
-- ANÁLISIS DE VM (VIRTUAL MACHINE)
-- ========================================
local VMAnalyzer = {}

function VMAnalyzer.new()
	local self = setmetatable({}, {__index = VMAnalyzer})
	self.instructions = {}
	self.opcodes = {}
	self.constants = {}
	self.vm_structure = {}
	self.control_flow = {}
	return self
end

function VMAnalyzer:detectVMType(code)
	local vm_signatures = {
		luraph = {
			patterns = {"IL_%x+", "Luraph", "LL_%x+", "LLIL"},
			confidence = 0
		},
		ironbrew = {
			patterns = {"Instruction%[", "Enum%[", "Opcode", "Stack%["},
			confidence = 0
		},
		moonsec = {
			patterns = {"Inst%[", "Stk%[", "Enum%.OpCode"},
			confidence = 0
		},
		psu = {
			patterns = {"PSU", "Proto", "Chunk"},
			confidence = 0
		},
		custom = {
			patterns = {"VM_", "Execute", "Interpreter"},
			confidence = 0
		}
	}
	
	for vm_type, data in pairs(vm_signatures) do
		for _, pattern in ipairs(data.patterns) do
			local matches = select(2, code:gsub(pattern, ""))
			data.confidence = data.confidence + (matches * 0.2)
		end
	end
	
	local best_match = "unknown"
	local best_confidence = 0
	for vm_type, data in pairs(vm_signatures) do
		if data.confidence > best_confidence then
			best_match = vm_type
			best_confidence = data.confidence
		end
	end
	
	return best_match, best_confidence
end

function VMAnalyzer:extractOpcodes(code)
	local opcodes = {}
	
	-- Patrón para opcodes numéricos
	for opcode in code:gmatch("Opcode%s*=%s*(%d+)") do
		table.insert(opcodes, {type = "numeric", value = tonumber(opcode)})
	end
	
	-- Patrón para opcodes enum
	for opcode in code:gmatch("Enum%.OpCode%.(%w+)") do
		table.insert(opcodes, {type = "enum", value = opcode})
	end
	
	-- Patrón para arrays de opcodes
	for array in code:gmatch("%{([%d,%s]+)%}") do
		for num in array:gmatch("%d+") do
			table.insert(opcodes, {type = "array", value = tonumber(num)})
		end
	end
	
	self.opcodes = opcodes
	return opcodes
end

function VMAnalyzer:extractConstants(code)
	local constants = {}
	
	-- Strings
	for str in code:gmatch('"([^"]+)"') do
		table.insert(constants, {type = "string", value = str})
	end
	
	for str in code:gmatch("'([^']+)'") do
		table.insert(constants, {type = "string", value = str})
	end
	
	-- Numbers
	for num in code:gmatch("(%d+%.%d+)") do
		table.insert(constants, {type = "number", value = tonumber(num)})
	end
	
	-- Booleans
	for bool in code:gmatch("%f[%w](true)%f[%W]") do
		table.insert(constants, {type = "boolean", value = true})
	end
	
	for bool in code:gmatch("%f[%w](false)%f[%W]") do
		table.insert(constants, {type = "boolean", value = false})
	end
	
	self.constants = constants
	return constants
end

function VMAnalyzer:analyzeControlFlow(code)
	local flow = {
		loops = {},
		conditions = {},
		jumps = {},
		calls = {}
	}
	
	-- Detectar loops
	for loop_type in code:gmatch("(while)") do
		table.insert(flow.loops, {type = "while"})
	end
	for loop_type in code:gmatch("(repeat)") do
		table.insert(flow.loops, {type = "repeat"})
	end
	for loop_type in code:gmatch("(for)") do
		table.insert(flow.loops, {type = "for"})
	end
	
	-- Detectar condiciones
	for cond in code:gmatch("(if%s+.-%s+then)") do
		table.insert(flow.conditions, cond)
	end
	
	-- Detectar saltos (goto, break)
	for jump in code:gmatch("(goto%s+%w+)") do
		table.insert(flow.jumps, jump)
	end
	
	-- Detectar llamadas a funciones
	for call in code:gmatch("(%w+)%s*%(") do
		if not call:match("^(if|while|for|repeat)$") then
			table.insert(flow.calls, call)
		end
	end
	
	self.control_flow = flow
	return flow
end

function VMAnalyzer:disassembleVM(code)
	if config.verbose then
		print("[VM Analyzer] Iniciando desarme de VM...")
	end
	
	local vm_type, confidence = self:detectVMType(code)
	print(string.format("[VM Analyzer] Tipo detectado: %s (%.1f%% confianza)", vm_type, confidence * 100))
	
	self:extractOpcodes(code)
	print(string.format("[VM Analyzer] Opcodes encontrados: %d", #self.opcodes))
	
	self:extractConstants(code)
	print(string.format("[VM Analyzer] Constantes encontradas: %d", #self.constants))
	
	self:analyzeControlFlow(code)
	print(string.format("[VM Analyzer] Estructuras de control: %d loops, %d condiciones", 
		#self.control_flow.loops, #self.control_flow.conditions))
	
	return {
		vm_type = vm_type,
		confidence = confidence,
		opcodes = self.opcodes,
		constants = self.constants,
		control_flow = self.control_flow
	}
end

function VMAnalyzer:generateVMMap()
	local map = {
		"=== VM STRUCTURE MAP ===\n",
		string.format("VM Type: %s\n", self.vm_structure.vm_type or "Unknown"),
		string.format("Confidence: %.1f%%\n\n", (self.vm_structure.confidence or 0) * 100),
		
		"=== OPCODES ===\n"
	}
	
	local opcode_counts = {}
	for _, opcode in ipairs(self.opcodes) do
		local key = tostring(opcode.value)
		opcode_counts[key] = (opcode_counts[key] or 0) + 1
	end
	
	for opcode, count in pairs(opcode_counts) do
		table.insert(map, string.format("  %s: %d occurrences\n", opcode, count))
	end
	
	table.insert(map, "\n=== CONSTANTS ===\n")
	local const_by_type = {}
	for _, const in ipairs(self.constants) do
		const_by_type[const.type] = (const_by_type[const.type] or 0) + 1
	end
	
	for ctype, count in pairs(const_by_type) do
		table.insert(map, string.format("  %s: %d\n", ctype, count))
	end
	
	table.insert(map, "\n=== CONTROL FLOW ===\n")
	table.insert(map, string.format("  Loops: %d\n", #self.control_flow.loops))
	table.insert(map, string.format("  Conditions: %d\n", #self.control_flow.conditions))
	table.insert(map, string.format("  Jumps: %d\n", #self.control_flow.jumps))
	table.insert(map, string.format("  Function Calls: %d\n", #self.control_flow.calls))
	
	return table.concat(map)
end

-- ========================================
-- DEOBFUSCATOR PRINCIPAL
-- ========================================
function VMDeobfuscator.new()
	local self = setmetatable({}, VMDeobfuscator)
	self.vm_analyzer = VMAnalyzer.new()
	self.string_decryptor = StringDecryptor
	self.output = {}
	return self
end

function VMDeobfuscator:findEncryptedStrings(code)
	local encrypted_strings = {}
	
	-- Patrón 1: string.char con números
	for chars in code:gmatch("string%.char%s*%(([%d,%s]+)%)") do
		local numbers = {}
		for num in chars:gmatch("%d+") do
			table.insert(numbers, tonumber(num))
		end
		local decoded = self.string_decryptor.charArrayDecode(numbers)
		if decoded then
			table.insert(encrypted_strings, {
				original = "string.char(" .. chars .. ")",
				decoded = decoded,
				method = "char_array"
			})
		end
	end
	
	-- Patrón 2: Arrays de bytes
	for array in code:gmatch("%{([%d,%s]+)%}") do
		if #array > 20 then -- Solo arrays grandes
			local numbers = {}
			for num in array:gmatch("%d+") do
				table.insert(numbers, tonumber(num))
			end
			if #numbers > 5 then
				local decoded = self.string_decryptor.charArrayDecode(numbers)
				if decoded and decoded:match("[%w%s]+") then
					table.insert(encrypted_strings, {
						original = "{" .. array .. "}",
						decoded = decoded,
						method = "byte_array"
					})
				end
			end
		end
	end
	
	-- Patrón 3: Strings con escape hex
	for hex_string in code:gmatch('"([^"]*\\x%x%x[^"]*)"') do
		local decoded = hex_string:gsub("\\x(%x%x)", function(hex)
			return string.char(tonumber(hex, 16))
		end)
		if decoded ~= hex_string then
			table.insert(encrypted_strings, {
				original = '"' .. hex_string .. '"',
				decoded = decoded,
				method = "hex_escape"
			})
		end
	end
	
	-- Patrón 4: Funciones de desencriptación personalizadas
	for var, func in code:gmatch("local%s+(%w+)%s*=%s*function%((.-)%)") do
		if func:match("bxor") or func:match("byte") or func:match("char") then
			table.insert(encrypted_strings, {
				original = var,
				decoded = "[CUSTOM DECRYPT FUNCTION: " .. var .. "]",
				method = "custom_function"
			})
		end
	end
	
	return encrypted_strings
end

function VMDeobfuscator:replaceEncryptedStrings(code, encrypted_strings)
	local replaced_code = code
	local replacements = 0
	
	for _, entry in ipairs(encrypted_strings) do
		if entry.method ~= "custom_function" then
			local escaped_original = entry.original:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
			local new_code, count = replaced_code:gsub(escaped_original, '"' .. entry.decoded .. '"')
			if count > 0 then
				replaced_code = new_code
				replacements = replacements + count
			end
		end
	end
	
	if config.verbose then
		print(string.format("[String Decryptor] Reemplazados %d strings", replacements))
	end
	
	return replaced_code, replacements
end

function VMDeobfuscator:simplifyVM(code)
	local simplified = code
	
	-- Remover llamadas redundantes a VM
	simplified = simplified:gsub("VM%[%d+%]%s*%(%)%s*;?", "")
	
	-- Simplificar accesos a stack
	simplified = simplified:gsub("Stk%[(%d+)%]", "var_%1")
	
	-- Simplificar instrucciones
	simplified = simplified:gsub("Inst%[(%d+)%]", "inst_%1")
	
	-- Remover código muerto
	simplified = simplified:gsub("if%s+false%s+then.-%s+end", "")
	simplified = simplified:gsub("while%s+false%s+do.-%s+end", "")
	
	return simplified
end

function VMDeobfuscator:beautify(code)
	if not config.auto_beautify then
		return code
	end
	
	local lines = {}
	local indent = 0
	
	for line in code:gmatch("[^\n]+") do
		local trimmed = line:match("^%s*(.-)%s*$")
		
		-- Reducir indentación
		if trimmed:match("^end") or trimmed:match("^else") or trimmed:match("^elseif") or trimmed:match("^until") then
			indent = math.max(0, indent - 1)
		end
		
		-- Agregar línea con indentación
		if trimmed ~= "" then
			table.insert(lines, string.rep("    ", indent) .. trimmed)
		end
		
		-- Aumentar indentación
		if trimmed:match("then%s*$") or trimmed:match("do%s*$") or trimmed:match("repeat%s*$") or trimmed:match("function") then
			indent = indent + 1
		end
		
		-- Reducir después de end
		if trimmed:match("^end") then
			indent = math.max(0, indent - 1)
		end
	end
	
	return table.concat(lines, "\n")
end

function VMDeobfuscator:deobfuscate(code)
	if config.verbose then
		print("\n" .. string.rep("=", 50))
		print("INICIANDO DEOBFUSCACIÓN AVANZADA")
		print(string.rep("=", 50))
	end
	
	local start_time = os.clock()
	local original_length = #code
	
	-- 1. Análisis de VM
	print("\n[1/5] Analizando estructura de VM...")
	self.vm_analyzer.vm_structure = self.vm_analyzer:disassembleVM(code)
	
	-- 2. Encontrar strings encriptados
	print("\n[2/5] Buscando strings encriptados...")
	local encrypted_strings = self:findEncryptedStrings(code)
	print(string.format("[String Decryptor] Encontrados %d strings encriptados", #encrypted_strings))
	
	-- 3. Reemplazar strings
	print("\n[3/5] Desencriptando strings...")
	code, replacements = self:replaceEncryptedStrings(code, encrypted_strings)
	
	-- 4. Simplificar VM
	print("\n[4/5] Simplificando lógica de VM...")
	code = self:simplifyVM(code)
	
	-- 5. Beautify
	print("\n[5/5] Mejorando formato...")
	code = self:beautify(code)
	
	local elapsed = os.clock() - start_time
	local final_length = #code
	local reduction = ((original_length - final_length) / original_length) * 100
	
	-- Generar reporte
	local report = {
		vm_type = self.vm_analyzer.vm_structure.vm_type,
		vm_confidence = self.vm_analyzer.vm_structure.confidence,
		strings_found = #encrypted_strings,
		strings_replaced = replacements,
		opcodes_found = #self.vm_analyzer.opcodes,
		constants_found = #self.vm_analyzer.constants,
		original_length = original_length,
		final_length = final_length,
		reduction_percent = reduction,
		time_elapsed = elapsed
	}
	
	if config.verbose then
		print("\n" .. string.rep("=", 50))
		print("DEOBFUSCACIÓN COMPLETADA")
		print(string.rep("=", 50))
		print(string.format("VM Tipo: %s (%.1f%% confianza)", report.vm_type, report.vm_confidence * 100))
		print(string.format("Strings desencriptados: %d", report.strings_replaced))
		print(string.format("Opcodes encontrados: %d", report.opcodes_found))
		print(string.format("Tiempo: %.2fs", elapsed))
		print(string.rep("=", 50) .. "\n")
	end
	
	-- Generar VM map
	local vm_map = ""
	if config.export_vm_map then
		vm_map = self.vm_analyzer:generateVMMap()
	end
	
	return {
		code = code,
		report = report,
		vm_map = vm_map,
		encrypted_strings = encrypted_strings
	}
end

-- ========================================
-- FUNCIONES DE EXPORTACIÓN
-- ========================================
function VMDeobfuscator:saveResults(filename, result)
	-- Guardar código deobfuscado
	local code_file = filename:gsub("%.lua$", "_deobfuscated.lua")
	if writefile then
		writefile(code_file, result.code)
		print("[Export] Código guardado en: " .. code_file)
	end
	
	-- Guardar VM map
	if config.export_vm_map and result.vm_map then
		local map_file = filename:gsub("%.lua$", "_vm_map.txt")
		if writefile then
			writefile(map_file, result.vm_map)
			print("[Export] VM map guardado en: " .. map_file)
		end
	end
	
	-- Guardar reporte JSON
	local report_file = filename:gsub("%.lua$", "_report.txt")
	local report_text = string.format([[
=== REPORTE DE DEOBFUSCACIÓN ===
Archivo: %s
VM Tipo: %s
Confianza: %.1f%%
Strings desencriptados: %d
Opcodes: %d
Constantes: %d
Tamaño original: %d bytes
Tamaño final: %d bytes
Reducción: %.2f%%
Tiempo: %.2fs
]], filename, result.report.vm_type, result.report.vm_confidence * 100,
	result.report.strings_replaced, result.report.opcodes_found,
	result.report.constants_found, result.report.original_length,
	result.report.final_length, result.report.reduction_percent,
	result.report.time_elapsed)
	
	if writefile then
		writefile(report_file, report_text)
		print("[Export] Reporte guardado en: " .. report_file)
	end
	
	-- Guardar strings encontrados
	if #result.encrypted_strings > 0 then
		local strings_file = filename:gsub("%.lua$", "_strings.txt")
		local strings_text = {"=== STRINGS ENCRIPTADOS ENCONTRADOS ===\n"}
		
		for i, entry in ipairs(result.encrypted_strings) do
			table.insert(strings_text, string.format("\n[%d] Método: %s\n", i, entry.method))
			table.insert(strings_text, string.format("Original: %s\n", entry.original:sub(1, 100)))
			table.insert(strings_text, string.format("Decodificado: %s\n", entry.decoded))
		end
		
		if writefile then
			writefile(strings_file, table.concat(strings_text))
			print("[Export] Strings guardados en: " .. strings_file)
		end
	end
end

-- ========================================
-- INTERFAZ DE USO
-- ========================================
local function main()
	print([[
╔═══════════════════════════════════════════╗
║   VM & STRING DEOBFUSCATOR v3.0          ║
║   Advanced VM Analysis + Decryption       ║
╚═══════════════════════════════════════════╝
]])
	
	-- Ejemplo de uso
	local deobfuscator = VMDeobfuscator.new()
	
	-- Si estás en un executor de Roblox
	if game then
		print("\n[Modo Roblox] Listo para deobfuscar scripts")
		print("Uso: deobfuscator:deobfuscate(script_code)")
		
		-- Exponer globalmente
		_G.VMDeobfuscator = VMDeobfuscator
		_G.deobfuscator = deobfuscator
		
		print("\nComandos disponibles:")
		print("  _G.deobfuscator:deobfuscate(code)")
		print("  _G.deobfuscator:saveResults(filename, result)")
	else
		-- Modo standalone
		print("\n[Modo Standalone]")
		print("Proporciona el código a deobfuscar...")
	end
	
	return deobfuscator
end

-- ========================================
-- EJECUCIÓN
-- ========================================
return main()
