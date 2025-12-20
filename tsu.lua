-- ========================================
-- SCRIPT DUMPER OPTIMIZADO v2.0
-- Mejoras: Performance, Memory Management, Error Handling
-- ========================================

local s = {
	decompile = true,
	dump_debug = false,
	detailed_info = false,
	threads = 5,
	timeout = 5,
	delay = 0.05,
	include_nil = false,
	replace_username = true,
	disable_render = true,
	batch_size = 50, -- Procesar scripts en lotes para mejor memory management
}

-- ========================================
-- OPTIMIZACIONES: Cache y Referencias
-- ========================================
local decompile = decompile or disassemble
local getnilinstances = getnilinstances or get_nil_instances
local getscripthash = getscripthash or get_script_hash
local getscriptclosure = getscriptclosure
local getconstants = getconstants or debug.getconstants
local getprotos = getprotos or debug.getprotos
local getinfo = getinfo or debug.getinfo

-- String optimizations
local format = string.format
local concat = table.concat
local gsub = string.gsub
local find = string.find
local sub = string.sub
local len = string.len
local rep = string.rep

-- Table optimizations
local insert = table.insert
local remove = table.remove

-- Math optimizations
local max = math.max
local floor = math.floor

-- ========================================
-- VARIABLES GLOBALES
-- ========================================
local threads = 0
local scriptsdumped = 0
local timedoutscripts = {}
local decompilecache = {}
local pathcache = {} -- Nuevo: Cache de fullnames
local progressbind = Instance.new("BindableEvent")
local threadbind = Instance.new("BindableEvent")

-- Services (cachear para mejor performance)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local CoreGui = game:GetService("CoreGui")

local plr = Players.LocalPlayer.Name
local ignoredservices = {"Chat", "CoreGui", "CorePackages"}
local ignored = {"PlayerModule", "RbxCharacterSounds", "PlayerScriptsLoader", "ChatScript", "BubbleChat"}

-- Overlay optimizado
local overlay = Instance.new("Frame")
overlay.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
overlay.Size = UDim2.fromScale(1, 1)
overlay.Visible = false
overlay.BorderSizePixel = 0
overlay.Parent = CoreGui.RobloxGui

-- ========================================
-- CONFIGURACIÓN DE DIRECTORIOS
-- ========================================
local maindir = "Pro Script Dumper"
local placeid = game.PlaceId
local placename = MarketplaceService:GetProductInfo(placeid).Name:gsub("[\\/:*?\"<>|\n\r]", " ")
local foldername = format("%s/[%s] %s", maindir, placeid, placename)
local exploit, version = (identifyexecutor and identifyexecutor()) or "Unknown Exploit"

-- Pattern precompilado para mejor performance
local invalid_chars_pattern = "[\\/:*?\"<>|\n\r]"
local spaces_hyphens_pattern = "[%s%-]+"
local username_pattern = plr:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") -- Escape special chars

-- ========================================
-- FUNCIONES OPTIMIZADAS
-- ========================================

local function checkdirectories()
	if not isfolder(maindir) then
		makefolder(maindir)
	end
	if not isfolder(foldername) then
		makefolder(foldername)
	end
end

-- Optimizado: Usar tabla hash en lugar de loop
local ignoredservices_hash = {}
for _, v in next, ignoredservices do
	ignoredservices_hash[v] = true
end

local ignored_hash = {}
for _, v in next, ignored do
	ignored_hash[v] = true
end

local function isignored(a)
	-- Check name first (más rápido)
	if ignored_hash[a.Name] then
		return true
	end
	
	-- Check ancestors
	local ancestor = a.Parent
	while ancestor do
		if ignoredservices_hash[ancestor.Name] or ignored_hash[ancestor.Name] then
			return true
		end
		ancestor = ancestor.Parent
	end
	
	return false
end

local function delay()
	repeat task.wait(s.delay) until threads < s.threads
end

-- Optimizado: Cache de decompilación con límite de memoria
local MAX_CACHE_SIZE = 100
local cache_keys = {}

local function decomp(a)
	local hash = getscripthash(a)
	local cached = decompilecache[hash]
	
	if cached then
		return cached
	end

	local output = decompile(a)
	
	-- Memory management: Limitar tamaño del cache
	if #cache_keys >= MAX_CACHE_SIZE then
		local oldest = remove(cache_keys, 1)
		decompilecache[oldest] = nil
	end
	
	decompilecache[hash] = output
	insert(cache_keys, hash)
	
	return output
end

-- Optimizado: Cache de fullnames con pre-procesamiento
local function getfullname(a)
	-- Check cache primero
	local cached = pathcache[a]
	if cached then
		return cached
	end
	
	local name = a:GetFullName()
	
	if not a:IsDescendantOf(game) then
		pathcache[a] = name
		return name
	end
	
	local split = name:split(".")
	local parts = {}
	
	-- Optimizado: Pre-alocar tabla y procesar en un solo paso
	for i, v in next, split do
		if find(v, spaces_hyphens_pattern) then
			parts[i] = format("['%s']", v)
		else
			parts[i] = v
		end
	end
	
	name = concat(parts, ".")
	local service = parts[1]
	local fullname = format("game:GetService(\"%s\")%s", service, sub(name, len(service) + 1, -1))
	fullname = gsub(fullname, "%.%[", "[")
	
	if s.replace_username then
		fullname = gsub(fullname, username_pattern, "LocalPlayer")
	end
	
	pathcache[a] = fullname
	return fullname
end

-- Optimizado: Construir contenido más eficientemente
local function buildcontent(name, path, class, decomp_time, output, constants_num, protos_num, constants, protos, gotclosure)
	local content = {
		format("-- Name: %s", name),
		format("-- Path: %s", path),
		format("-- Class: %s", class),
		format("-- Exploit: %s %s", exploit, version or ""),
		format("-- Time to decompile: %s", decomp_time)
	}
	
	if s.dump_debug then
		if gotclosure then
			insert(content, "\n-- Debug Info")
			insert(content, format("-- # of Constants: %s", constants_num))
			insert(content, format("-- # of Protos: %s", protos_num))
			
			if s.detailed_info then
				insert(content, "\n-- Constants")
				
				local function searchconstants(t, count)
					for i, v in next, t do
						local i_type = typeof(i)
						local v_type = typeof(v)
						
						if v_type ~= "table" then
							v = gsub(tostring(v), "%%", "%%%%")
						end
						
						insert(content, format("-- %s[%s%s%s] (%s) = %s (%s)",
							rep("  ", count),
							(i_type == "string" and "'" or ""),
							(i_type == "Instance" and getfullname(i) or tostring(i)),
							(i_type == "string" and "'" or ""),
							i_type,
							tostring(v),
							v_type
						))
						
						if v_type == "table" then
							searchconstants(v, count + 1)
						end
					end
				end
				
				searchconstants(constants, 0)
				
				insert(content, "\n-- Proto Info")
				
				for _, v in next, protos do
					local info = getinfo(v)
					insert(content, format("-- '%s'", info.name))
					
					for i2, v2 in next, info do
						v2 = gsub(tostring(v2), "%%", "%%%%")
						insert(content, format("--   ['%s'] = %s", i2, v2))
					end
				end
			end
		else
			insert(content, "\n-- Debug Info (Could not get script closure)")
		end
	end
	
	insert(content, "\n" .. output)
	
	return concat(content, "\n")
end

-- Optimizado: Manejo de filename más eficiente
local function sanitizefilename(filename)
	filename = gsub(filename, invalid_chars_pattern, " ")
	filename = gsub(filename, "%.%.", ". .")
	
	if len(filename) > 199 then
		filename = sub(filename, 1, 195) .. ".lua"
	end
	
	return filename
end

-- ========================================
-- FUNCIÓN PRINCIPAL DE DUMP (OPTIMIZADA)
-- ========================================
local function dumpscript(v, isnil)
	checkdirectories()
	
	task.spawn(function()
		local function dump()
			threads = threads + 1
			threadbind:Fire("Active Threads:", threads)
			
			local success, err = pcall(function()
				-- File Name
				local id = v:GetDebugId()
				local name = v.Name
				local path = (isnil and "[nil] " or "") .. v:GetFullName()
				
				if s.replace_username then
					path = gsub(path, username_pattern, "LocalPlayer")
				end
				
				local filename = format("%s/%s (%s).lua", foldername, path, id)
				filename = sanitizefilename(filename)
				
				-- Script Output
				local time = os.clock()
				local output
				
				if s.decompile then
					local attempts = 0
					local max_attempts = 3
					
					repeat
						local success, result = pcall(decomp, v)
						output = success and result or "-- Failed to decompile script"
						attempts = attempts + 1
						
						if (os.clock() - time) > s.timeout then
							output = "-- Decompilation timed out"
							insert(timedoutscripts, format("Name: %s\nPath: %s\nClass: %s\nDebug Id: %s", name, path, v.ClassName, id))
							break
						end
						
						if output == "-- Failed to decompile script" and attempts < max_attempts then
							task.wait(0.1)
						end
					until output ~= "-- Failed to decompile script" or attempts >= max_attempts
					
					if gsub(output, " ", "") == "" then
						output = "-- Decompiler returned nothing. This script may not have bytecode or has anti-decompile implemented."
					end
				else
					output = "-- Script decompilation is disabled"
				end
				
				local decomp_time = format("%s seconds", os.clock() - time)
				
				-- Debug Info
				local gotclosure, closure = pcall(getscriptclosure, v)
				local constants, constants_num, protos, protos_num
				
				if s.dump_debug and gotclosure then
					constants = getconstants(closure)
					constants_num = #constants
					protos = getprotos(closure)
					protos_num = #protos
				end
				
				-- Build and write content
				local content = buildcontent(
					name,
					getfullname(v),
					v.ClassName,
					decomp_time,
					output,
					constants_num,
					protos_num,
					constants,
					protos,
					gotclosure
				)
				
				writefile(filename, content)
				scriptsdumped = scriptsdumped + 1
				progressbind:Fire(scriptsdumped)
			end)
			
			if not success then
				warn(format("Error dumping script %s: %s", v:GetFullName(), tostring(err)))
			end
			
			threads = threads - 1
			threadbind:Fire("Active Threads:", threads)
		end
		
		local function queue()
			delay()
			if threads < s.threads then
				dump()
			else
				queue()
			end
		end
		
		if threads < s.threads then
			dump()
		else
			queue()
		end
	end)
	
	delay()
end

-- ========================================
-- INTERFAZ GRÁFICA
-- ========================================
local Material = loadstring(game:HttpGet("https://raw.githubusercontent.com/zzerexx/scripts/main/MaterialLuaRemake.lua"))()
local UI = Material.Load({
	Title = "Script Dumper v2.0 Optimized",
	Style = 3,
	SizeX = 400,
	SizeY = 515,
	Theme = "Dark"
})

local page = UI.new("zzerexx was here")

page.Toggle({
	Text = "Decompile Scripts",
	Callback = function(value)
		s.decompile = value
	end,
	Enabled = s.decompile
})

page.Toggle({
	Text = "Dump Debug Info",
	Callback = function(value)
		s.dump_debug = value
	end,
	Enabled = s.dump_debug,
	Menu = {
		Info = function()
			UI.Banner("If enabled, output will include debug info such as constants, upvalues, and protos.")
		end
	}
})

page.Toggle({
	Text = "Detailed Debug Info",
	Callback = function(value)
		s.detailed_info = value
	end,
	Enabled = s.detailed_info,
	Menu = {
		Info = function()
			UI.Banner("<b>This feature may crash the game. Increase the <u>Delay</u> and decrease the # of <u>Max Threads</u> if needed.</b><br />If <b>Dump Debug Info</b> is enabled, it will dump more, detailed debug info.")
		end
	}
})

page.Slider({
	Text = "Max Threads",
	Callback = function(value)
		s.threads = value
	end,
	Min = 1,
	Max = 20,
	Def = s.threads,
	Suffix = " threads",
	Menu = {
		Info = function()
			UI.Banner("This determines how many scripts can be decompiled at the same time.\n<b>Having more threads active at once will utilize more of your computer's resources and may increase the amount of timed-out decompilations.</b>")
		end
	}
})

page.Slider({
	Text = "Delay",
	Callback = function(value)
		s.delay = value
	end,
	Min = 0,
	Max = 1,
	Def = s.delay,
	Decimals = 2,
	Suffix = " seconds"
})

page.Slider({
	Text = "Decompile Timeout",
	Callback = function(value)
		s.timeout = value
	end,
	Min = 5,
	Max = 30,
	Def = s.timeout,
	Suffix = " seconds",
	Decimals = 2,
	Menu = {
		Info = function()
			UI.Banner("If the decompile time exceeds this duration, it will be skipped.")
		end
	}
})

page.Toggle({
	Text = "Include Nil Scripts",
	Callback = function(value)
		s.include_nil = value
	end,
	Enabled = s.include_nil,
	Menu = {
		Info = function()
			UI.Banner("If enabled, scripts parented to nil will also be decompiled.")
		end
	}
})

page.Toggle({
	Text = "Replace Username",
	Callback = function(value)
		s.replace_username = value
	end,
	Enabled = s.replace_username,
	Menu = {
		Info = function()
			UI.Banner("If enabled, all objects that contain your username will be replaced to <b>LocalPlayer</b>.")
		end
	}
})

page.Toggle({
	Text = "Disable 3D Rendering",
	Callback = function(value)
		s.disable_render = value
	end,
	Enabled = s.disable_render,
	Menu = {
		Info = function()
			UI.Banner("If enabled, 3D rendering will be disabled temporarily while the script dumper is active. Allows more resources to be utilized towards decompiling.")
		end
	}
})

-- ========================================
-- BOTÓN DE INICIO OPTIMIZADO
-- ========================================
local progressbar = nil

page.Button({
	Text = "Start Dumping",
	Callback = function()
		if progressbar then 
			UI.Banner("A script dump is still currently in progress!") 
			return 
		end
		
		-- Preparación
		if s.disable_render then
			overlay.Visible = true
			RunService:Set3dRenderingEnabled(false)
		end
		
		-- Reset variables
		local scripts = {}
		local nilscripts = {}
		timedoutscripts = {}
		scriptsdumped = 0
		decompilecache = {} -- Limpiar cache
		pathcache = {} -- Limpiar cache
		cache_keys = {}
		
		-- Recolectar scripts con filtro optimizado
		local start_collect = os.clock()
		
		for _, v in next, game:GetDescendants() do
			if (v:IsA("LocalScript") or v:IsA("ModuleScript")) and not isignored(v) then
				insert(scripts, v)
			end
		end
		
		if s.include_nil and getnilinstances then
			for _, v in next, getnilinstances() do
				if (v:IsA("LocalScript") or v:IsA("ModuleScript")) and not isignored(v) then
					insert(nilscripts, v)
				end
			end
		end
		
		print(format("Script collection took %.2f seconds", os.clock() - start_collect))
		
		local total = #scripts + #nilscripts
		
		progressbar = page.ProgressBar({
			Text = "Progress",
			Event = progressbind,
			Min = 0,
			Max = total,
			Def = 0,
			Suffix = "/" .. total .. " scripts",
			Percent = false
		})
		
		UI.Banner(format("%d scripts found. Starting dump...", total))
		
		local time = os.clock()
		
		-- Procesar scripts en lotes para mejor gestión de memoria
		task.spawn(function()
			for i = 1, #scripts, s.batch_size do
				local batch_end = max(i + s.batch_size - 1, #scripts)
				
				for j = i, batch_end do
					dumpscript(scripts[j])
				end
				
				-- Esperar que se procese el lote actual
				repeat task.wait(0.1) until threads < s.threads / 2
			end
			
			if s.include_nil and getnilinstances then
				for _, v in next, nilscripts do
					dumpscript(v, true)
				end
			end
			
			-- Esperar finalización
			repeat task.wait(0.1) until threads == 0
			
			-- Resultados
			local elapsed = os.clock() - time
			local result = format("Successfully dumped %d scripts in %.2f seconds (%.2f scripts/sec).%s", 
				scriptsdumped, 
				elapsed,
				scriptsdumped / elapsed,
				#timedoutscripts > 0 and format("\n%d scripts timed out.", #timedoutscripts) or ""
			)
			
			UI.Banner(result)
			
			if #timedoutscripts > 0 then
				writefile(format("%s/! Timed out scripts.txt", foldername), concat(timedoutscripts, "\n\n"))
			end
			
			if s.disable_render then
				RunService:Set3dRenderingEnabled(true)
				overlay.Visible = false
			end
			
			task.wait(1)
			if progressbar then
				progressbar:Destroy()
				progressbar = nil
			end
		end)
	end
})

page.Label({
	Text = "Active Threads: 0",
	Event = threadbind
})
