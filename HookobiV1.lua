-- MOBILE HOOK SYSTEM v4.0 - Optimized Deep Hook for MoonSec Deobfuscation
-- Improvements: deep VM hooks, pattern extraction, multi-layer capture, memory optimization

local HookSystem = {
    Captures = {},
    DecodedStrings = {},
    VMInstructions = {},
    FullCaptureIndex = 0,
    Active = true,
    GUI = nil,
    _ui_initialized = false,
    _hook_depth = 0,
    _recursion_limit = 3
}

-- ========== CONFIG ==========
local Config = {
    UIScale = 1,
    AutoCapture = true,
    ShowNotifications = true,
    MaxCaptures = 50,
    SaveFullToDisk = true,
    MaxPreviewChars = 2000,
    MinSaveLength = 200,
    DefaultDumpPath = "moonsec_dumps.txt",
    NotifyCooldown = 0.5,
    DeepHook = true,              -- NEW: Enable deep VM hooks
    CaptureStringOps = true,      -- NEW: Capture string.char/byte operations
    CaptureTableOps = true,       -- NEW: Capture table.concat operations
    ExtractPatterns = true,       -- NEW: Extract obfuscation patterns
    DebugMode = false             -- NEW: Verbose logging
}

-- ========== SERVICES & UTILS ==========
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local writefile_supported = type(writefile) == "function"
local setclipboard_supported = type(setclipboard) == "function"
local protect_gui = (type(syn) == "table" and type(syn.protect_gui) == "function") and syn.protect_gui or nil

local last_notify = 0

-- Performance optimizations
local string_char = string.char
local string_byte = string.byte
local string_sub = string.sub
local string_find = string.find
local string_match = string.match
local string_gsub = string.gsub
local table_insert = table.insert
local table_concat = table.concat
local table_remove = table.remove
local os_clock = os.clock
local os_date = os.date

local function now() return os_clock() end

local function safe_notify(title, text, dur)
    if not Config.ShowNotifications then return end
    local current = now()
    if current - last_notify < Config.NotifyCooldown then return end
    last_notify = current
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "🔍 " .. tostring(title),
            Text = tostring(text),
            Duration = dur or 2
        })
    end)
end

local function debug_log(...)
    if Config.DebugMode then
        print("[HookSystem DEBUG]", ...)
    end
end

local function short(s, n)
    if type(s) ~= "string" then return tostring(s) end
    if #s <= n then return s end
    return string_sub(s, 1, n) .. string.format("\n...[+%d chars]", #s - n)
end

local function ring_push(tbl, value, max)
    table_insert(tbl, value)
    if #tbl > max then
        table_remove(tbl, 1)
    end
end

local function async_write(path, content)
    task.spawn(function()
        if not writefile_supported then return end
        local success, err = pcall(function()
            local existing = ""
            if isfile and isfile(path) then
                existing = readfile(path) .. "\n\n" .. string.rep("=", 80) .. "\n\n"
            end
            writefile(path, existing .. content)
            HookSystem.FullCaptureIndex = HookSystem.FullCaptureIndex + 1
        end)
        if not success then
            warn("HookSystem: Write failed ->", err)
        end
    end)
end

-- ========== PATTERN DETECTION (Enhanced) ==========
local obf_patterns = {
    {name = "MoonSec", patterns = {
        "IllIlllIllIlllIlllIlllIll",
        "l__",
        "_ENV",
        "getfenv",
        "LcCyGbVZzDFRqbUa"
    }},
    {name = "IronBrew", patterns = {
        "bit32%.bxor",
        "Stk%[",
        "Inst%[",
        "Proto%["
    }},
    {name = "PSU", patterns = {
        "Deserialize",
        "Chunk",
        "Constantinize"
    }},
    {name = "Luraph", patterns = {
        "Luraph",
        "VMCall",
        "FlatIdent"
    }},
    {name = "Custom VM", patterns = {
        "Upvalues%[",
        "Instr%[",
        "VIP%[",
        "Stack%["
    }}
}

local function detect_obfuscator(code)
    if type(code) ~= "string" then return "Unknown" end
    
    for _, obf in ipairs(obf_patterns) do
        for _, pattern in ipairs(obf.patterns) do
            if string_find(code, pattern, 1, true) then
                return obf.name
            end
        end
    end
    
    -- Heuristic checks
    if #code > 5000 and (string_find(code, "return function") or string_find(code, "local function")) then
        local var_count = 0
        for _ in string.gmatch(code, "local%s+%w+") do
            var_count = var_count + 1
            if var_count > 50 then return "Heavy Obfuscation" end
        end
    end
    
    return "None"
end

local function should_save(code)
    if type(code) ~= "string" then return false end
    if #code < Config.MinSaveLength then return false end
    
    local lower = string.lower(code)
    local keywords = {
        "moonsec", "loadstring", "getfenv", "setfenv",
        "game:httpget", "httpget", "request",
        "replicatedstorage", "serverstorage"
    }
    
    for _, keyword in ipairs(keywords) do
        if string_find(lower, keyword, 1, true) then
            return true
        end
    end
    
    return #code >= 1500
end

-- ========== PATTERN EXTRACTION ==========
local function extract_patterns(code)
    if not Config.ExtractPatterns or type(code) ~= "string" then return {} end
    
    local patterns = {}
    
    -- Extract variable naming patterns
    local vars = {}
    for var in string.gmatch(code, "local%s+([%w_]+)") do
        table_insert(vars, var)
        if #vars >= 20 then break end
    end
    if #vars > 0 then
        patterns.variable_pattern = table_concat(vars, ", ", 1, math.min(10, #vars))
    end
    
    -- Extract function patterns
    local func_count = select(2, string_gsub(code, "function%s*%(", ""))
    patterns.function_count = func_count
    
    -- Extract string operations
    local string_ops = select(2, string_gsub(code, "string%.", ""))
    patterns.string_operations = string_ops
    
    -- Extract table operations
    local table_ops = select(2, string_gsub(code, "table%.", ""))
    patterns.table_operations = table_ops
    
    -- Detect encoding patterns
    if string_find(code, "byte%(") and string_find(code, "char%(") then
        patterns.encoding_type = "char/byte manipulation"
    end
    
    if string_find(code, "bit32") or string_find(code, "bxor") then
        patterns.encoding_type = (patterns.encoding_type or "") .. " + XOR"
    end
    
    return patterns
end

-- ========== DEEP HOOKS (NEW) ==========
local original_funcs = {}

local function safe_hook_string_operations()
    if not Config.CaptureStringOps then return end
    
    -- Hook string.char (critical for MoonSec)
    original_funcs.string_char = string.char
    string.char = function(...)
        local args = {...}
        local result = original_funcs.string_char(...)
        
        -- Avoid deep recursion
        if HookSystem._hook_depth > HookSystem._recursion_limit then
            return result
        end
        
        HookSystem._hook_depth = HookSystem._hook_depth + 1
        
        pcall(function()
            -- Only capture if result looks like code
            if type(result) == "string" and #result > 100 then
                if string_find(result, "function") or string_find(result, "local") or string_find(result, "return") then
                    debug_log("string.char decoded:", #result, "bytes")
                    
                    local meta = {
                        type = "string.char decode",
                        content_preview = short(result, Config.MaxPreviewChars),
                        size = #result,
                        obfuscators = detect_obfuscator(result),
                        patterns = extract_patterns(result),
                        time = os_date("%Y-%m-%d %H:%M:%S"),
                        args_count = #args
                    }
                    
                    ring_push(HookSystem.DecodedStrings, meta, 30)
                    
                    if should_save(result) then
                        meta.full = result
                        ring_push(HookSystem.Captures, meta, Config.MaxCaptures)
                        
                        if Config.SaveFullToDisk then
                            local dump = string.format(
                                "-- STRING.CHAR DECODE CAPTURE --\n-- Time: %s\n-- Size: %d\n-- Obfuscator: %s\n\n%s",
                                meta.time, meta.size, meta.obfuscators, result
                            )
                            async_write(Config.DefaultDumpPath, dump)
                        end
                        
                        safe_notify("Decoded!", string.format("%s - %d bytes", meta.obfuscators, #result))
                    end
                end
            end
        end)
        
        HookSystem._hook_depth = HookSystem._hook_depth - 1
        return result
    end
    
    -- Hook string.byte (for pattern analysis)
    original_funcs.string_byte = string.byte
    string.byte = function(s, ...)
        local result = original_funcs.string_byte(s, ...)
        
        if HookSystem._hook_depth > HookSystem._recursion_limit then
            return result
        end
        
        -- Track byte operations for pattern recognition
        if type(s) == "string" and #s > 500 then
            debug_log("string.byte on large string:", #s)
        end
        
        return result
    end
end

local function safe_hook_table_operations()
    if not Config.CaptureTableOps then return end
    
    -- Hook table.concat (MoonSec uses this heavily)
    original_funcs.table_concat = table.concat
    table.concat = function(tbl, ...)
        local result = original_funcs.table_concat(tbl, ...)
        
        if HookSystem._hook_depth > HookSystem._recursion_limit then
            return result
        end
        
        HookSystem._hook_depth = HookSystem._hook_depth + 1
        
        pcall(function()
            if type(result) == "string" and #result > 200 then
                if string_find(result, "function") or string_find(result, "local") then
                    debug_log("table.concat produced code:", #result, "bytes")
                    
                    local meta = {
                        type = "table.concat decode",
                        content_preview = short(result, Config.MaxPreviewChars),
                        size = #result,
                        obfuscators = detect_obfuscator(result),
                        patterns = extract_patterns(result),
                        time = os_date("%Y-%m-%d %H:%M:%S"),
                        table_size = #tbl
                    }
                    
                    if should_save(result) then
                        meta.full = result
                        ring_push(HookSystem.Captures, meta, Config.MaxCaptures)
                        
                        if Config.SaveFullToDisk then
                            local dump = string.format(
                                "-- TABLE.CONCAT DECODE CAPTURE --\n-- Time: %s\n-- Size: %d\n-- Obfuscator: %s\n\n%s",
                                meta.time, meta.size, meta.obfuscators, result
                            )
                            async_write(Config.DefaultDumpPath, dump)
                        end
                        
                        safe_notify("Table decoded!", string.format("%d bytes", #result))
                    end
                end
            end
        end)
        
        HookSystem._hook_depth = HookSystem._hook_depth - 1
        return result
    end
end

local function safe_hook_load_funcs()
    original_funcs.loadstring = loadstring or load
    original_funcs.load = load
    
    -- Enhanced loadstring hook
    if type(original_funcs.loadstring) == "function" then
        _G.loadstring = function(src, ...)
            if Config.AutoCapture and type(src) == "string" then
                pcall(function()
                    local obf = detect_obfuscator(src)
                    local patterns = extract_patterns(src)
                    
                    local meta = {
                        type = "loadstring",
                        content_preview = short(src, Config.MaxPreviewChars),
                        full_saved = false,
                        size = #src,
                        obfuscators = obf,
                        patterns = patterns,
                        time = os_date("%Y-%m-%d %H:%M:%S")
                    }
                    
                    if should_save(src) then
                        meta.full = src
                        ring_push(HookSystem.Captures, meta, Config.MaxCaptures)
                        
                        if Config.SaveFullToDisk then
                            local dump = string.format(
                                "-- LOADSTRING CAPTURE --\n-- Time: %s\n-- Size: %d\n-- Obfuscator: %s\n-- Patterns: %s\n\n%s",
                                meta.time, meta.size, obf, 
                                HttpService:JSONEncode(patterns),
                                src
                            )
                            async_write(Config.DefaultDumpPath, dump)
                            meta.full_saved = true
                        end
                        
                        safe_notify("Loadstring", string.format("%s - %d bytes", obf, #src))
                    end
                end)
            end
            return original_funcs.loadstring(src, ...)
        end
    end
    
    -- Enhanced load hook
    if type(original_funcs.load) == "function" then
        _G.load = function(src, ...)
            if Config.AutoCapture and type(src) == "string" then
                pcall(function()
                    local obf = detect_obfuscator(src)
                    local patterns = extract_patterns(src)
                    
                    local meta = {
                        type = "load",
                        content_preview = short(src, Config.MaxPreviewChars),
                        size = #src,
                        obfuscators = obf,
                        patterns = patterns,
                        time = os_date("%Y-%m-%d %H:%M:%S")
                    }
                    
                    if should_save(src) then
                        meta.full = src
                        ring_push(HookSystem.Captures, meta, Config.MaxCaptures)
                        
                        if Config.SaveFullToDisk then
                            async_write(Config.DefaultDumpPath, string.format(
                                "-- LOAD CAPTURE --\n-- Time: %s\n-- Size: %d\n-- Obfuscator: %s\n\n%s",
                                meta.time, meta.size, obf, src
                            ))
                        end
                        
                        safe_notify("Load", string.format("%s - %d bytes", obf, #src))
                    end
                end)
            end
            return original_funcs.load(src, ...)
        end
    end
end

local function safe_hook_http()
    local success, mt = pcall(getrawmetatable, game)
    if success and mt and mt.__namecall then
        original_funcs.namecall = mt.__namecall
        
        pcall(function() setreadonly(mt, false) end)
        
        mt.__namecall = newcclosure and newcclosure(function(self, ...)
            local method = getnamecallmethod and getnamecallmethod() or ""
            local args = {...}
            
            if Config.AutoCapture and (method == "HttpGet" or method == "HttpGetAsync") then
                local url = args[1]
                local ok, res = pcall(original_funcs.namecall, self, ...)
                
                if ok and type(res) == "string" then
                    pcall(function()
                        local obf = detect_obfuscator(res)
                        local patterns = extract_patterns(res)
                        
                        local meta = {
                            type = "HttpGet",
                            url = tostring(url or "<unknown>"),
                            content_preview = short(res, Config.MaxPreviewChars),
                            size = #res,
                            obfuscators = obf,
                            patterns = patterns,
                            time = os_date("%Y-%m-%d %H:%M:%S")
                        }
                        
                        if should_save(res) then
                            meta.full = res
                            ring_push(HookSystem.Captures, meta, Config.MaxCaptures)
                            
                            if Config.SaveFullToDisk then
                                async_write(Config.DefaultDumpPath, string.format(
                                    "-- HTTP GET CAPTURE --\n-- URL: %s\n-- Time: %s\n-- Size: %d\n-- Obfuscator: %s\n\n%s",
                                    url, meta.time, meta.size, obf, res
                                ))
                            end
                            
                            safe_notify("HttpGet", string.format("%s - %d bytes", obf, #res))
                        end
                    end)
                end
                
                return res
            end
            
            return original_funcs.namecall(self, ...)
        end) or original_funcs.namecall
        
        pcall(function() setreadonly(mt, true) end)
    end
end

-- ========== UI (Optimized) ==========
function HookSystem:CreateUI()
    if self._ui_initialized then return end
    self._ui_initialized = true
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "HookSystemUI_v4"
    ScreenGui.ResetOnSpawn = false
    if protect_gui then pcall(protect_gui, ScreenGui) end
    ScreenGui.Parent = game:GetService("CoreGui")
    
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 380, 0, 500)
    Main.Position = UDim2.new(0.5, -190, 0.5, -250)
    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = Main
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 0, 40)
    Title.Position = UDim2.new(0, 10, 0, 10)
    Title.BackgroundTransparency = 1
    Title.Text = "🔍 MoonSec Deep Hook v4.0"
    Title.TextColor3 = Color3.fromRGB(100, 200, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Main
    
    local Stats = Instance.new("TextLabel")
    Stats.Name = "Stats"
    Stats.Size = UDim2.new(1, -20, 0, 20)
    Stats.Position = UDim2.new(0, 10, 0, 50)
    Stats.BackgroundTransparency = 1
    Stats.Text = "Captures: 0 | Decoded: 0"
    Stats.TextColor3 = Color3.fromRGB(180, 180, 180)
    Stats.Font = Enum.Font.Gotham
    Stats.TextSize = 13
    Stats.TextXAlignment = Enum.TextXAlignment.Left
    Stats.Parent = Main
    
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Name = "Scroll"
    Scroll.Size = UDim2.new(1, -20, 1, -140)
    Scroll.Position = UDim2.new(0, 10, 0, 75)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 8
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
    Scroll.Parent = Main
    
    local Layout = Instance.new("UIListLayout")
    Layout.Parent = Scroll
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, 10)
    
    -- Buttons
    local function create_button(text, pos_x, callback)
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(0.48, 0, 0, 36)
        Button.Position = UDim2.new(pos_x, 0, 1, -46)
        Button.BackgroundColor3 = Color3.fromRGB(70, 130, 230)
        Button.Text = text
        Button.Font = Enum.Font.GothamBold
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        Button.TextSize = 14
        Button.Parent = Main
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 8)
        Corner.Parent = Button
        
        Button.MouseButton1Click:Connect(callback)
        return Button
    end
    
    create_button("💾 Save All", 0, function() self:SaveToFile() end)
    create_button("📋 Copy", 0.52, function() self:CopyLatest() end)
    
    self.GUI = {
        ScreenGui = ScreenGui,
        Main = Main,
        Scroll = Scroll,
        Stats = Stats
    }
    
    -- Auto-update every 2 seconds
    task.spawn(function()
        while true do
            task.wait(2)
            if self.GUI then
                self:UpdateUI()
            end
        end
    end)
end

function HookSystem:UpdateUI()
    if not self.GUI then return end
    
    local Stats = self.GUI.Stats
    local Scroll = self.GUI.Scroll
    
    -- Update stats
    Stats.Text = string.format("Captures: %d | Decoded: %d | Saved: %d", 
        #self.Captures, #self.DecodedStrings, self.FullCaptureIndex)
    
    -- Clear old entries
    for _, child in ipairs(Scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    -- Add capture entries (most recent first)
    for i = #self.Captures, math.max(1, #self.Captures - 10), -1 do
        local cap = self.Captures[i]
        
        local Entry = Instance.new("Frame")
        Entry.Size = UDim2.new(1, -10, 0, 90)
        Entry.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        Entry.BorderSizePixel = 0
        Entry.Parent = Scroll
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 8)
        Corner.Parent = Entry
        
        local Header = Instance.new("TextLabel")
        Header.Size = UDim2.new(1, -10, 0, 20)
        Header.Position = UDim2.new(0, 5, 0, 5)
        Header.BackgroundTransparency = 1
        Header.Text = string.format("[%s] %s", cap.time:sub(12, 19), cap.type)
        Header.TextColor3 = Color3.fromRGB(100, 200, 255)
        Header.Font = Enum.Font.GothamBold
        Header.TextSize = 13
        Header.TextXAlignment = Enum.TextXAlignment.Left
        Header.Parent = Entry
        
        local Info = Instance.new("TextLabel")
        Info.Size = UDim2.new(1, -10, 0, 16)
        Info.Position = UDim2.new(0, 5, 0, 25)
        Info.BackgroundTransparency = 1
        Info.Text = string.format("Size: %d | Obf: %s", cap.size or 0, cap.obfuscators or "None")
        Info.TextColor3 = Color3.fromRGB(150, 150, 150)
        Info.Font = Enum.Font.Gotham
        Info.TextSize = 11
        Info.TextXAlignment = Enum.TextXAlignment.Left
        Info.Parent = Entry
        
        local Preview = Instance.new("TextLabel")
        Preview.Size = UDim2.new(1, -10, 0, 45)
        Preview.Position = UDim2.new(0, 5, 0, 42)
        Preview.BackgroundTransparency = 1
        Preview.Text = cap.content_preview or "No preview"
        Preview.TextColor3 = Color3.fromRGB(200, 200, 200)
        Preview.Font = Enum.Font.Code
        Preview.TextSize = 10
        Preview.TextWrapped = true
        Preview.TextXAlignment = Enum.TextXAlignment.Left
        Preview.TextYAlignment = Enum.TextYAlignment.Top
        Preview.Parent = Entry
        
        -- Click to copy
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(1, 0, 1, 0)
        Button.BackgroundTransparency = 1
        Button.Text = ""
        Button.Parent = Entry
        
        Button.MouseButton1Click:Connect(function()
            local content = cap.full or cap.content_preview or ""
            if setclipboard_supported then
                setclipboard(content)
                safe_notify("Copied!", string.format("%d bytes", #content))
            end
        end)
    end
    
    Scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(0, #self.Captures * 100))
end

-- ========== EXPORT FUNCTIONS ==========
function HookSystem:CopyLatest()
    if #self.Captures == 0 then
        safe_notify("Empty", "No captures available")
        return
    end
    
    local latest = self.Captures[#self.Captures]
    local content = latest.full or latest.content_preview or ""
    
    if setclipboard_supported then
        setclipboard(content)
        safe_notify("Copied!", string.format("Latest capture: %d bytes", #content))
    else
        safe_notify("Error", "Clipboard not supported")
    end
end

function HookSystem:SaveToFile()
    if #self.Captures == 0 then
        safe_notify("Empty", "No captures to save")
        return
    end
    
    local output = {}
    table_insert(output, string.rep("=", 80))
    table_insert(output, "MOONSEC DEEP HOOK EXPORT")
    table_insert(output, "Generated: " .. os_date("%Y-%m-%d %H:%M:%S"))
    table_insert(output, string.format("Total Captures: %d", #self.Captures))
    table_insert(output, string.rep("=", 80))
    
    for i, cap in ipairs(self.Captures) do
        table_insert(output, string.format("\n[CAPTURE %d]", i))
        table_insert(output, string.format("Type: %s", cap.type))
        table_insert(output, string.format("Time: %s", cap.time))
        table_insert(output, string.format("Size: %d bytes", cap.size or 0))
        table_insert(output, string.format("Obfuscator: %s", cap.obfuscators or "None"))
        
        if cap.patterns then
            table_insert(output, "Patterns: " .. HttpService:JSONEncode(cap.patterns))
        end
        
        if cap.url then
            table_insert(output, "URL: " .. cap.url)
        end
        
        table_insert(output, "\nCONTENT:")
        table_insert(output, string.rep("-", 80))
        table_insert(output, cap.full or cap.content_preview or "No content")
        table_insert(output, string.rep("-", 80))
    end
    
    local blob = table_concat(output, "\n")
    
    if writefile_supported then
        async_write(Config.DefaultDumpPath, blob)
        safe_notify("Saved!", string.format("Exported to %s", Config.DefaultDumpPath), 3)
    else
        if setclipboard_supported then
            setclipboard(short(blob, 10000))
            safe_notify("Copied", "Export copied to clipboard (file save unavailable)", 3)
        end
    end
end

-- ========== INIT ==========
local function Initialize()
    safe_notify("Initializing", "MoonSec Deep Hook v4.0...")
    
    if Config.DeepHook then
        safe_hook_string_operations()
        safe_hook_table_operations()
        debug_log("Deep hooks enabled")
    end
    
    safe_hook_load_funcs()
    safe_hook_http()
    
    task.wait(0.5)
    HookSystem:CreateUI()
    
    safe_notify("Ready!", "All hooks active. Waiting for captures...", 3)
    
    debug_log("Hook system initialized successfully")
    debug_log("Config:", HttpService:JSONEncode(Config))
end

Initialize()

return HookSystem
