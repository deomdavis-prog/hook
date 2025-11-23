-- MOBILE HOOK SYSTEM v3.1 - Optimized for Mobile Executors (Delta / Hydrogen / Arceus / Codex)
-- Improvements: ring buffer, background file writes, lightweight UI updates, robust fallbacks.

local HookSystem = {
    Captures = {},            -- ring buffer of light metadata (full content may be saved to disk)
    FullCaptureIndex = 0,     -- counter for saved full dumps
    Active = true,
    GUI = nil,
    _ui_initialized = false
}

-- ========== CONFIG ==========
local Config = {
    UIScale = 1,
    AutoCapture = true,
    ShowNotifications = true,
    MaxCaptures = 40,           -- ring-buffer size (keeps memory bounded)
    SaveFullToDisk = true,      -- whether to attempt writefile
    MaxPreviewChars = 1200,     -- preview shown in UI / clipboard
    MinSaveLength = 140,        -- min length to consider saving full file
    DefaultDumpPath = "/mnt/data/contenidowuwuw.txt", -- default output path (change if needed). See uploaded file. :contentReference[oaicite:1]{index=1}
    NotifyCooldown = 1.0        -- seconds between notifications at most
}

-- ========== LOCALS & HELPERS ==========
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local writefile_supported = (type(writefile) == "function")
local setclipboard_supported = (type(setclipboard) == "function")
local protect_gui = (type(syn) == "table" and type(syn.protect_gui) == "function") and syn.protect_gui or nil

local last_notify = 0

local function now() return os.clock() end
local function safe_notify(title, text, dur)
    if not Config.ShowNotifications then return end
    if now() - last_notify < Config.NotifyCooldown then return end
    last_notify = now()
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "🔍 "..tostring(title),
            Text = tostring(text),
            Duration = dur or 3
        })
    end)
end

local function short(s, n)
    if type(s) ~= "string" then return tostring(s) end
    if #s <= n then return s end
    return s:sub(1, n) .. ("\n\n...[truncated %d chars]"):format(#s - n)
end

local function ring_push(tbl, value)
    table.insert(tbl, value)
    if #tbl > Config.MaxCaptures then
        table.remove(tbl, 1)
    end
end

local function async_write(path, content)
    -- Non-blocking save (best-effort)
    task.spawn(function()
        if not writefile_supported then
            -- If not supported, keep at most a short preview in memory (already done) and bail
            return
        end
        local ok, err = pcall(function()
            -- append if file exists (keeps a running log) otherwise write new
            if isfile and isfile(path) then
                local prev = readfile(path)
                writefile(path, prev .. "\n\n" .. content)
            else
                writefile(path, content)
            end
            HookSystem.FullCaptureIndex = HookSystem.FullCaptureIndex + 1
        end)
        if not ok then
            warn("HookSystem: failed to write dump -> "..tostring(err))
        end
    end)
end

-- Quick heuristic: cheap string checks (order matters for speed)
local function should_save_full(code)
    if type(code) ~= "string" then return false end
    if #code >= 1200 then return true end
    local s = code:lower()
    -- cheap substring checks
    if s:find("moonsec",1,true) or s:find("loadstring",1,true) or s:find("replicatedstorage",1,true)
       or s:find("players",1,true) or s:find("http",1,true) then
        return true
    end
    return false
end

-- ========== DETECTION (fast / conservative) ==========
local function DetectObfuscatorsFast(code)
    if type(code) ~= "string" then return "Unknown" end
    local s = code
    -- Patterns kept minimal to avoid expensive checks
    if s:find("IllIlllIllIlllIlllIlllIll",1,true) or s:find("l__") then
        return "Moonsec"
    end
    if s:find("getrenv",1,true) or s:find("_G[",1,true) then
        return "WeAreDevs"
    end
    if s:find("bit32.bxor",1,true) or s:find("Stk[",1,true) then
        return "IronBrew"
    end
    if s:find("Deserialize",1,true) or s:find("Chunk",1,true) then
        return "PSU"
    end
    if s:find("Upvalues[",1,true) or s:find("Instr[",1,true) then
        return "Custom VM"
    end
    return "None"
end

-- ========== SAFE HOOK INSTALLERS ==========
local function safe_hook_load_funcs()
    -- Preserve originals
    local orig_loadstring = _G.loadstring or _G.load
    local orig_load = _G.load

    -- loadstring
    if type(orig_loadstring) == "function" then
        _G.loadstring = function(src, ...)
            pcall(function()
                if Config.AutoCapture and type(src) == "string" then
                    local obf = DetectObfuscatorsFast(src)
                    local meta = {
                        type = "Loadstring",
                        content_preview = short(src, Config.MaxPreviewChars),
                        full_saved = false,
                        size = #src,
                        obfuscators = obf,
                        time = os.date("%Y-%m-%d %H:%M:%S")
                    }
                    ring_push(HookSystem.Captures, meta)
                    if should_save_full(src) then
                        if Config.SaveFullToDisk and writefile_supported then
                            local dump = ("-- Dumped capture: %s\n-- Type: %s\n-- Size: %d\n\n%s"):format(meta.time, meta.type, meta.size, src)
                            async_write(Config.DefaultDumpPath, dump)
                            meta.full_saved = true
                        else
                            -- keep small full in memory only if small
                            meta.full = (#src <= Config.MinSaveLength) and src or nil
                        end
                    end
                    safe_notify("Loadstring captured", ("%s — %d bytes"):format(obf, #src), 2)
                end
            end)
            return orig_loadstring(src, ...)
        end
    end

    -- load (fallback)
    if type(orig_load) == "function" then
        _G.load = function(src, ...)
            pcall(function()
                if Config.AutoCapture and type(src) == "string" then
                    local obf = DetectObfuscatorsFast(src)
                    local meta = {
                        type = "Load",
                        content_preview = short(src, Config.MaxPreviewChars),
                        full_saved = false,
                        size = #src,
                        obfuscators = obf,
                        time = os.date("%Y-%m-%d %H:%M:%S")
                    }
                    ring_push(HookSystem.Captures, meta)
                    if should_save_full(src) then
                        if Config.SaveFullToDisk and writefile_supported then
                            async_write(Config.DefaultDumpPath, ("-- Dumped capture: %s\n-- Type: %s\n-- Size: %d\n\n%s"):format(meta.time, meta.type, meta.size, src))
                            meta.full_saved = true
                        else
                            meta.full = (#src <= Config.MinSaveLength) and src or nil
                        end
                    end
                    safe_notify("Load captured", ("%s — %d bytes"):format(obf, #src), 2)
                end
            end)
            return orig_load(src, ...)
        end
    end
end

local function safe_hook_http()
    -- Try namecall metatable hook for game:HttpGet
    local success, mt = pcall(function() return getrawmetatable(game) end)
    if success and mt and mt.__namecall then
        local old_nc = mt.__namecall
        local protected = pcall(function() setreadonly(mt, false) end)
        mt.__namecall = newcclosure and newcclosure(function(self, ...)
            local method = getnamecallmethod and getnamecallmethod() or ""
            local args = {...}
            if Config.AutoCapture and (method == "HttpGet" or method == "HttpGetAsync") then
                local url = args[1]
                local ok, res = pcall(old_nc, self, ...)
                if ok and type(res) == "string" then
                    pcall(function()
                        local obf = DetectObfuscatorsFast(res)
                        local meta = {
                            type = "HttpGet",
                            url = tostring(url or "<unknown>"),
                            content_preview = short(res, Config.MaxPreviewChars),
                            full_saved = false,
                            size = #res,
                            obfuscators = obf,
                            time = os.date("%Y-%m-%d %H:%M:%S")
                        }
                        ring_push(HookSystem.Captures, meta)
                        if should_save_full(res) then
                            if Config.SaveFullToDisk and writefile_supported then
                                async_write(Config.DefaultDumpPath, ("-- Dumped capture: %s\n-- URL: %s\n-- Size: %d\n\n%s"):format(meta.time, meta.url, meta.size, res))
                                meta.full_saved = true
                            else
                                meta.full = (#res <= Config.MinSaveLength) and res or nil
                            end
                        end
                        safe_notify("HttpGet captured", ("%s — %d bytes"):format(obf, #res), 2)
                    end)
                end
                return res
            end
            return old_nc(self, ...)
        end) or old_nc
        if protected then pcall(function() setreadonly(mt, true) end) end
    else
        -- Fallback: override game.HttpGet method directly (less stealthy, but works)
        pcall(function()
            if type(game.HttpGet) == "function" then
                local orig = game.HttpGet
                game.HttpGet = function(self, url, ...)
                    local res = orig(self, url, ...)
                    if Config.AutoCapture and type(res) == "string" then
                        local obf = DetectObfuscatorsFast(res)
                        local meta = {
                            type = "HttpGet",
                            url = tostring(url or "<unknown>"),
                            content_preview = short(res, Config.MaxPreviewChars),
                            full_saved = false,
                            size = #res,
                            obfuscators = obf,
                            time = os.date("%Y-%m-%d %H:%M:%S")
                        }
                        ring_push(HookSystem.Captures, meta)
                        if should_save_full(res) and Config.SaveFullToDisk and writefile_supported then
                            async_write(Config.DefaultDumpPath, ("-- Dumped capture: %s\n-- URL: %s\n-- Size: %d\n\n%s"):format(meta.time, meta.url, meta.size, res))
                            meta.full_saved = true
                        end
                        safe_notify("HttpGet captured", ("%s — %d bytes"):format(obf, #res), 2)
                    end
                    return res
                end
            end
        end)
    end
end

-- ========== LIGHTWEIGHT UI (lazy init + incremental update) ==========
local function make_text_label(parent, props)
    local t = Instance.new("TextLabel")
    for k,v in pairs(props) do t[k] = v end
    t.Parent = parent
    return t
end

function HookSystem:CreateUI()
    if self._ui_initialized then return end
    self._ui_initialized = true

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "HookSystemUI_v3_1"
    ScreenGui.ResetOnSpawn = false
    if protect_gui then
        pcall(protect_gui, ScreenGui)
    end
    ScreenGui.Parent = game:GetService("CoreGui")

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 360, 0, 460)
    Main.Position = UDim2.new(0.5, -180, 0.5, -230)
    Main.BackgroundColor3 = Color3.fromRGB(24,24,32)
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui

    local Title = make_text_label(Main, {
        Name = "Title",
        Size = UDim2.new(1, -16, 0, 36),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundTransparency = 1,
        Text = "🔍 Hook System v3.1",
        TextColor3 = Color3.fromRGB(255,255,255),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    local CountLabel = make_text_label(Main, {
        Name = "Count",
        Size = UDim2.new(1, -16, 0, 18),
        Position = UDim2.new(0, 8, 0, 44),
        BackgroundTransparency = 1,
        Text = "Captures: 0",
        TextColor3 = Color3.fromRGB(170,170,170),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Name = "Scroll"
    Scroll.Size = UDim2.new(1, -16, 1, -110)
    Scroll.Position = UDim2.new(0, 8, 0, 68)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 6
    Scroll.Parent = Main

    local Layout = Instance.new("UIListLayout")
    Layout.Parent = Scroll
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, 8)

    -- Buttons (small set)
    local function btn(text, posY, cb)
        local B = Instance.new("TextButton")
        B.Size = UDim2.new(0.48, 0, 0, 34)
        B.Position = UDim2.new(posY, 0, 1, -42)
        B.AnchorPoint = Vector2.new(0,0)
        B.Text = text
        B.Parent = Main
        B.BackgroundColor3 = Color3.fromRGB(60,120,220)
        B.Font = Enum.Font.GothamBold
        B.TextColor3 = Color3.fromRGB(255,255,255)
        B.TextSize = 13
        B.MouseButton1Click:Connect(cb)
        return B
    end

    btn("Save all", 0, function() HookSystem:SaveToFile() end)
    btn("Copy part", 0.52, function() HookSystem:CopyInParts() end)

    self.GUI = {
        ScreenGui = ScreenGui,
        Main = Main,
        Scroll = Scroll,
        CountLabel = CountLabel
    }
    self:UpdateUI()
end

function HookSystem:UpdateUI()
    if not self.GUI then return end
    local Scroll = self.GUI.Scroll
    local CountLabel = self.GUI.CountLabel

    -- update count
    CountLabel.Text = "Captures: "..tostring(#self.Captures)

    -- incremental refresh: clear and re-add (keeps simple and fast for small buffer)
    for _, child in ipairs(Scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for i = #self.Captures, 1, -1 do
        local cap = self.Captures[i]
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -8, 0, 72)
        Frame.BackgroundTransparency = 1
        Frame.Parent = Scroll

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, -8, 0, 18)
        Title.Position = UDim2.new(0, 4, 0, 4)
        Title.BackgroundTransparency = 1
        Title.Text = ("[%s] %s"):format(cap.time:sub(12,19), cap.type)
        Title.TextColor3 = Color3.fromRGB(200,200,255)
        Title.Font = Enum.Font.GothamBold
        Title.TextSize = 12
        Title.Parent = Frame

        local Preview = Instance.new("TextLabel")
        Preview.Size = UDim2.new(1, -8, 0, 46)
        Preview.Position = UDim2.new(0, 4, 0, 22)
        Preview.BackgroundTransparency = 1
        Preview.Text = cap.content_preview or ("size: "..(cap.size or 0))
        Preview.TextColor3 = Color3.fromRGB(200,200,200)
        Preview.Font = Enum.Font.Gotham
        Preview.TextSize = 12
        Preview.TextWrapped = true
        Preview.TextXAlignment = Enum.TextXAlignment.Left
        Preview.Parent = Frame

        -- quick copy on tap
        Preview.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                local full = cap.full or cap.content_preview or ""
                if setclipboard_supported then
                    setclipboard(full)
                    safe_notify("Copied", "Script preview copied to clipboard", 2)
                else
                    safe_notify("Copy unavailable", "Executor doesn't support setclipboard", 2)
                end
            end
        end)
    end

    -- update canvas size
    self.GUI.Scroll.CanvasSize = UDim2.new(0,0,0, math.max(0, (#self.Captures * 80)))
end

-- ========== EXPORT / UTILITIES ==========
function HookSystem:CopyInParts()
    if #self.Captures == 0 then safe_notify("Empty","No captures to copy",2) return end
    local idx = 1
    local maxChars = 3000
    local output = ""
    while idx <= #self.Captures do
        local c = self.Captures[idx]
        local block = string.format("=== Capture %d ===\nType: %s\nTime: %s\nSize: %d\nObf: %s\n\n%s\n\n", idx, c.type, c.time, c.size or 0, c.obfuscators or "None", c.full or c.content_preview or "")
        if #output + #block > maxChars then break end
        output = output .. block
        idx = idx + 1
    end
    if setclipboard_supported then setclipboard(output) safe_notify("Copied", "Part copied to clipboard", 2)
    else safe_notify("Copy unavailable", "Executor doesn't support setclipboard", 2) end
end

function HookSystem:SaveToFile()
    if #self.Captures == 0 then safe_notify("Empty","No captures to save",2) return end
    local out = {}
    table.insert(out, "==== HOOK CAPTURES EXPORT ====")
    table.insert(out, "Date: "..os.date("%Y-%m-%d %H:%M:%S"))
    for i,c in ipairs(self.Captures) do
        table.insert(out, string.format("\n--- Capture %d ---\nType: %s\nTime: %s\nSize: %d\nObf: %s\n", i, c.type, c.time, c.size or 0, c.obfuscators or "None"))
        table.insert(out, c.full or c.content_preview or "No content available")
    end
    local blob = table.concat(out, "\n")
    if writefile_supported then
        async_write(Config.DefaultDumpPath, blob)
        safe_notify("Saved", "Export appended to: "..Config.DefaultDumpPath, 4)
    else
        safe_notify("Save unavailable", "Executor doesn't support writefile, copying preview", 3)
        if setclipboard_supported then setclipboard(short(blob, Config.MaxPreviewChars)) end
    end
end

-- ========== INIT ==========
local function Initialize()
    safe_notify("Hook System", "Initializing...", 2)
    safe_hook_load_funcs()
    safe_hook_http()
    HookSystem:CreateUI()
    safe_notify("Ready", "Hook System active (mobile-optimized)", 3)
end

Initialize()

return HookSystem
