-- Sistema Avanzado de Intercepción y Desofuscación
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

-- Configuración
local TARGET_URLS = {
    "https://gist.githubusercontent.com/robloxclips/652550ce3cb81b9b9bccde75383d3299/raw/61387f95dc83caf5f2665054246fabc2f0186daa/bruhware.lua",
    -- Otros patrones comunes
    "https://raw.githubusercontent.com/",
    "https://pastebin.com/raw/",
    "https://paste.ee/",
    "https://cdn.discordapp.com/attachments/"
}

local INTERCEPT_KEYS = {"bruhwarekey", "_G.key", "getgenv().key", "shared.key"}

-- Almacenamiento de datos
local interceptedData = {
    keys = {},
    httpRequests = {},
    loadedStrings = {},
    environmentChanges = {},
    hooks = {},
    patterns = {}
}

-- Configuración de análisis
local analysisSettings = {
    deepAnalysis = true,
    decodeBase64 = true,
    detectObfuscators = true,
    trackStringCalls = true,
    monitorBytecode = false,
    logAllCalls = true
}

-- Crear GUI avanzada
local function createAdvancedGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AdvancedInterceptorGUI"
    screenGui.Parent = CoreGui
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false

    -- Frame principal
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 800, 0, 700)
    mainFrame.Position = UDim2.new(0.5, -400, 0.5, -350)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    -- Barra de título
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "🛡️ Advanced Interceptor v2.0"
    title.TextColor3 = Color3.fromRGB(0, 255, 255)
    title.Font = Enum.Font.Code
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    -- Botones de control
    local controlButtons = {
        {name = "▶️", color = Color3.fromRGB(0, 200, 0), tooltip = "Iniciar intercepción"},
        {name = "⏸️", color = Color3.fromRGB(255, 200, 0), tooltip = "Pausar intercepción"},
        {name = "⏹️", color = Color3.fromRGB(255, 50, 50), tooltip = "Detener intercepción"},
        {name = "📊", color = Color3.fromRGB(100, 150, 255), tooltip = "Estadísticas"},
        {name = "⚙️", color = Color3.fromRGB(150, 150, 150), tooltip = "Configuración"}
    }

    local buttonX = 700
    for i, btn in ipairs(controlButtons) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 30, 0, 30)
        button.Position = UDim2.new(0, buttonX, 0.5, -15)
        button.BackgroundColor3 = btn.color
        button.Text = btn.name
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.GothamBold
        button.TextSize = 14
        button.Parent = titleBar
        
        local tooltip = Instance.new("TextLabel")
        tooltip.Size = UDim2.new(0, 100, 0, 25)
        tooltip.Position = UDim2.new(0, 0, 1, 5)
        tooltip.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        tooltip.Text = btn.tooltip
        tooltip.TextColor3 = Color3.fromRGB(200, 200, 200)
        tooltip.Visible = false
        tooltip.Parent = button
        
        button.MouseEnter:Connect(function()
            tooltip.Visible = true
        end)
        
        button.MouseLeave:Connect(function()
            tooltip.Visible = false
        end)
        
        buttonX = buttonX + 35
    end

    -- Panel de pestañas
    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, 0, 0, 30)
    tabFrame.Position = UDim2.new(0, 0, 0, 40)
    tabFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    tabFrame.Parent = mainFrame

    local tabs = {
        {name = "🔑 Keys", id = "keys"},
        {name = "🌐 HTTP", id = "http"},
        {name = "📝 Strings", id = "strings"},
        {name = "🔧 Hooks", id = "hooks"},
        {name = "🔍 Analysis", id = "analysis"},
        {name = "📊 Stats", id = "stats"}
    }

    local tabButtons = {}
    local contentFrames = {}

    for i, tab in ipairs(tabs) do
        local tabButton = Instance.new("TextButton")
        tabButton.Size = UDim2.new(0, 100, 1, 0)
        tabButton.Position = UDim2.new(0, (i-1)*100, 0, 0)
        tabButton.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        tabButton.Text = tab.name
        tabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        tabButton.Font = Enum.Font.Gotham
        tabButton.TextSize = 12
        tabButton.Parent = tabFrame

        local contentFrame = Instance.new("ScrollingFrame")
        contentFrame.Size = UDim2.new(1, -20, 1, -110)
        contentFrame.Position = UDim2.new(0, 10, 0, 80)
        contentFrame.BackgroundTransparency = 1
        contentFrame.Visible = i == 1
        contentFrame.ScrollBarThickness = 8
        contentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
        contentFrame.Parent = mainFrame

        tabButtons[tab.id] = tabButton
        contentFrames[tab.id] = contentFrame

        tabButton.MouseButton1Click:Connect(function()
            for _, frame in pairs(contentFrames) do
                frame.Visible = false
            end
            contentFrame.Visible = true
            
            for _, btn in pairs(tabButtons) do
                btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
            end
            tabButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
        end)
    end

    -- Panel de estado
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 30)
    statusBar.Position = UDim2.new(0, 0, 1, -30)
    statusBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    statusBar.Parent = mainFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.7, 0, 1, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "🟢 Sistema activo | Interceptando..."
    statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
    statusLabel.Font = Enum.Font.Code
    statusLabel.TextSize = 12
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusBar

    local statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(0.3, 0, 1, 0)
    statsLabel.Position = UDim2.new(0.7, 0, 0, 0)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Text = "Keys: 0 | HTTP: 0 | Strings: 0"
    statsLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    statsLabel.Font = Enum.Font.Code
    statsLabel.TextSize = 11
    statsLabel.TextXAlignment = Enum.TextXAlignment.Right
    statsLabel.Parent = statusBar

    -- Funciones de utilidad para la GUI
    local function createDataCard(title, content, color, parent)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -10, 0, 100)
        card.Position = UDim2.new(0, 5, 0, #parent:GetChildren() * 110 + 5)
        card.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        card.BorderSizePixel = 0
        
        local titleBar = Instance.new("Frame")
        titleBar.Size = UDim2.new(1, 0, 0, 25)
        titleBar.BackgroundColor3 = color
        titleBar.Parent = card
        
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -10, 1, 0)
        titleLabel.Position = UDim2.new(0, 5, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 12
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = titleBar
        
        local contentBox = Instance.new("TextBox")
        contentBox.Size = UDim2.new(1, -10, 1, -35)
        contentBox.Position = UDim2.new(0, 5, 0, 30)
        contentBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        contentBox.TextColor3 = Color3.fromRGB(220, 220, 220)
        contentBox.Text = content
        contentBox.TextSize = 11
        contentBox.Font = Enum.Font.RobotoMono
        contentBox.TextWrapped = true
        contentBox.TextXAlignment = Enum.TextXAlignment.Left
        contentBox.TextYAlignment = Enum.TextYAlignment.Top
        contentBox.ClearTextOnFocus = false
        contentBox.TextEditable = false
        contentBox.Parent = card
        
        card.Parent = parent
        
        local textSize = TextService:GetTextSize(content, 11, Enum.Font.RobotoMono, Vector2.new(760, math.huge))
        card.Size = UDim2.new(1, -10, 0, math.min(math.max(textSize.Y + 45, 100), 300))
        
        return card
    end

    local function updateStats()
        statsLabel.Text = string.format("Keys: %d | HTTP: %d | Strings: %d | Hooks: %d",
            #interceptedData.keys, #interceptedData.httpRequests,
            #interceptedData.loadedStrings, #interceptedData.hooks)
    end

    local function updateContent(tabId, dataList, color)
        local frame = contentFrames[tabId]
        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        for i, data in ipairs(dataList) do
            createDataCard(data.title or ("Item " .. i), data.content, color, frame)
        end
    end

    return {
        screenGui = screenGui,
        updateStats = updateStats,
        updateContent = updateContent,
        statusLabel = statusLabel,
        tabs = tabs,
        contentFrames = contentFrames
    }
end

-- Funciones avanzadas de desofuscación
local deobfuscator = {
    patterns = {
        base64 = "[A-Za-z0-9+/]+=*",
        hex = "0x[%x]+",
        charCodes = "char%((%d+)%)",
        stringChar = "string%.char%(([^)]+)%)",
        concatenation = "\".*\"%.%.%(\".*\"%)",
        encodedLoadstring = "loadstring%(.*decode%)",
        getfenvCalls = "getfenv%(%)",
        metatableManipulation = "setmetatable%("
    },
    
    commonObfuscators = {
        "Fate's Admin",
        "V.G Hub",
        "DarkHub",
        "Eclipse",
        "SirHurt",
        "Nexus"
    },
    
    decodeBase64 = function(str)
        local success, result = pcall(function()
            local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
            str = string.gsub(str, '[^'..b..'=]', '')
            return (str:gsub('.', function(x)
                if (x == '=') then return '' end
                local r,f='',(b:find(x)-1)
                for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
                return r;
            end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
                if (#x ~= 8) then return '' end
                local c=0
                for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
                return string.char(c)
            end))
        end)
        return success and result or str
    end,
    
    decodeHex = function(str)
        return str:gsub("0x(%x+)", function(hex)
            return string.char(tonumber(hex, 16))
        end)
    end,
    
    evaluateCharCodes = function(str)
        return str:gsub("char%((%d+)%)", function(num)
            return string.char(tonumber(num))
        end):gsub("string%.char%(([^)]+)%)", function(nums)
            local result = ""
            for num in nums:gmatch("%d+") do
                result = result .. string.char(tonumber(num))
            end
            return result
        end)
    end,
    
    analyzeObfuscationLevel = function(code)
        local score = 0
        local indicators = {}
        
        -- Verificar patrones de ofuscación
        if code:find("getfenv%(%)") then score = score + 1; table.insert(indicators, "getfenv usage") end
        if code:find("loadstring") then score = score + 1; table.insert(indicators, "loadstring calls") end
        if code:find("%.%.%."):len() > 3 then score = score + 2; table.insert(indicators, "excessive concatenation") end
        if code:find("%[%[.-%]%]") then score = score + 1; table.insert(indicators, "long strings") end
        if #code > 10000 then score = score + 2; table.insert(indicators, "large script size") end
        
        -- Buscar ofuscadores conocidos
        for _, obf in ipairs(deobfuscator.commonObfuscators) do
            if code:find(obf) then
                score = score + 3
                table.insert(indicators, "Known obfuscator: " .. obf)
            end
        end
        
        return score, indicators
    end,
    
    deobfuscateStepByStep = function(code)
        local steps = {}
        local current = code
        
        -- Paso 1: Decodificar Base64
        local base64Matches = {}
        for match in current:gmatch("[A-Za-z0-9+/]+=*=*=*") do
            if #match > 20 and #match % 4 == 0 then
                table.insert(base64Matches, match)
            end
        end
        
        for _, match in ipairs(base64Matches) do
            local decoded = deobfuscator.decodeBase64(match)
            if decoded ~= match and #decoded > 10 then
                current = current:gsub(match, function()
                    return "\n-- [BASE64 DECODED]:\n" .. decoded .. "\n-- [END BASE64]"
                end)
            end
        end
        
        table.insert(steps, {name = "Base64 Decoded", content = current})
        
        -- Paso 2: Decodificar Hex
        local hexDecoded = deobfuscator.decodeHex(current)
        if hexDecoded ~= current then
            current = hexDecoded
            table.insert(steps, {name = "Hex Decoded", content = current})
        end
        
        -- Paso 3: Evaluar char codes
        local charDecoded = deobfuscator.evaluateCharCodes(current)
        if charDecoded ~= current then
            current = charDecoded
            table.insert(steps, {name = "Char Codes Evaluated", content = current})
        end
        
        -- Paso 4: Simplificar concatenaciones
        local simplified = current:gsub('"([^"]+)"%.%.%("([^"]+)"%)', '"%1%2"')
        simplified = simplified:gsub('"([^"]+)"%.%.%(\'([^\']+)\'%)', '"%1%2"')
        if simplified ~= current then
            current = simplified
            table.insert(steps, {name = "Concatenation Simplified", content = current})
        end
        
        -- Paso 5: Identificar y marcar funciones peligrosas
        local dangerousFunctions = {
            "getfenv", "setfenv", "getreg", "getgc", "hookfunction",
            "newcclosure", "checkcaller", "setreadonly", "setidentity",
            "firetouchinterest", "fireproximityprompt", "getconnections"
        }
        
        for _, func in ipairs(dangerousFunctions) do
            current = current:gsub(func, "⚠️ " .. func:upper() .. " ⚠️")
        end
        
        table.insert(steps, {name = "Security Analysis", content = current})
        
        return steps, current
    end
}

-- Sistema de hooks avanzado
local hookSystem = {
    original = {},
    active = true,
    
    hookFunction = function(funcName, hookFunc)
        local original = _G[funcName] or getfenv()[funcName]
        if not original then return false end
        
        hookSystem.original[funcName] = original
        _G[funcName] = function(...)
            if hookSystem.active then
                return hookFunc(original, ...)
            end
            return original(...)
        end
        
        return true
    end,
    
    hookMethod = function(object, methodName, hookFunc)
        local original = object[methodName]
        if type(original) ~= "function" then return false end
        
        local key = tostring(object) .. "." .. methodName
        hookSystem.original[key] = original
        
        object[methodName] = function(self, ...)
            if hookSystem.active then
                return hookFunc(original, self, ...)
            end
            return original(self, ...)
        end
        
        return true
    },
    
    hookGetEnv = function()
        local originalGetEnv = getfenv or function() return _G end
        local originalSetEnv = setfenv or function(f, env) return f end
        
        getfenv = function(level)
            local env = originalGetEnv(level or 0)
            if hookSystem.active then
                interceptedData.environmentChanges[#interceptedData.environmentChanges + 1] = {
                    type = "getfenv",
                    level = level or 0,
                    timestamp = os.time(),
                    stack = debug.traceback()
                }
            end
            return env
        end
        
        setfenv = function(f, env)
            if hookSystem.active then
                interceptedData.environmentChanges[#interceptedData.environmentChanges + 1] = {
                    type = "setfenv",
                    target = tostring(f),
                    env = env,
                    timestamp = os.time(),
                    stack = debug.traceback()
                }
            end
            return originalSetEnv(f, env)
        end
    end,
    
    hookGlobalAssignment = function()
        local originalGlobal = getfenv()
        local globalMeta = getmetatable(originalGlobal) or {}
        local originalNewIndex = globalMeta.__newindex
        
        globalMeta.__newindex = function(t, k, v)
            if hookSystem.active then
                for _, keyPattern in ipairs(INTERCEPT_KEYS) do
                    if tostring(k):find(keyPattern) then
                        interceptedData.keys[#interceptedData.keys + 1] = {
                            key = k,
                            value = v,
                            timestamp = os.time(),
                            stack = debug.traceback(),
                            type = "global_assignment"
                        }
                    end
                end
            end
            
            if originalNewIndex then
                originalNewIndex(t, k, v)
            else
                rawset(t, k, v)
            end
        end
        
        setmetatable(originalGlobal, globalMeta)
    end
}

-- Inicializar hooks
local function initializeHooks(gui)
    -- Hook para getgenv
    local originalGetGenv = getgenv or function() return _G end
    getgenv = function()
        local env = originalGetGenv()
        
        if hookSystem.active then
            local meta = getmetatable(env) or {}
            local originalNewIndex = meta.__newindex
            
            meta.__newindex = function(t, k, v)
                if hookSystem.active then
                    for _, keyPattern in ipairs(INTERCEPT_KEYS) do
                        if tostring(k):lower():find(keyPattern:lower()) then
                            local data = {
                                title = "🔑 Key Assignment Detected",
                                content = string.format("Key: %s\nValue: %s\nType: %s\nTime: %s\n\nStack Trace:\n%s",
                                    k, tostring(v), type(v), os.date("%X"), debug.traceback())
                            }
                            interceptedData.keys[#interceptedData.keys + 1] = data
                            gui.updateContent("keys", interceptedData.keys, Color3.fromRGB(0, 150, 255))
                            gui.updateStats()
                        end
                    end
                end
                
                if originalNewIndex then
                    originalNewIndex(t, k, v)
                else
                    rawset(t, k, v)
                end
            end
            
            setmetatable(env, meta)
        end
        
        return env
    end

    -- Hook para HttpGet
    if game.HttpGet then
        hookSystem.original.HttpGet = game.HttpGet
        game.HttpGet = function(url, ...)
            local result = hookSystem.original.HttpGet(url, ...)
            
            if hookSystem.active then
                for _, targetUrl in ipairs(TARGET_URLS) do
                    if url:find(targetUrl) or url:match("https?://[^/]+/.+%.lua") then
                        local data = {
                            title = "🌐 HTTP Request: " .. url,
                            content = string.format("URL: %s\nResponse Length: %d\nTimestamp: %s\n\nResponse Preview:\n%s",
                                url, #result, os.date("%X"), result:sub(1, 1000) .. (#result > 1000 and "\n... [TRUNCATED]" or ""))
                        }
                        interceptedData.httpRequests[#interceptedData.httpRequests + 1] = data
                        
                        -- Análisis del contenido
                        local obfuscationScore, indicators = deobfuscator.analyzeObfuscationLevel(result)
                        if obfuscationScore > 0 then
                            data.content = data.content .. string.format("\n\n🔍 Obfuscation Analysis:\nScore: %d/10\nIndicators: %s",
                                obfuscationScore, table.concat(indicators, ", "))
                            
                            -- Desofuscación paso a paso
                            local steps, final = deobfuscator.deobfuscateStepByStep(result)
                            for i, step in ipairs(steps) do
                                interceptedData.loadedStrings[#interceptedData.loadedStrings + 1] = {
                                    title = string.format("Step %d: %s", i, step.name),
                                    content = step.content
                                }
                            end
                        end
                        
                        gui.updateContent("http", interceptedData.httpRequests, Color3.fromRGB(255, 150, 0))
                        gui.updateContent("strings", interceptedData.loadedStrings, Color3.fromRGB(0, 200, 100))
                        gui.updateStats()
                        gui.statusLabel.Text = string.format("🟡 HTTP Request Intercepted: %s", url:match("[^/]+$") or url)
                    end
                end
            end
            
            return result
        end
    end

    -- Hook para HttpService
    hookSystem.hookMethod(game:GetService("HttpService"), "GetAsync", function(original, self, url, ...)
        local result = original(self, url, ...)
        
        if hookSystem.active then
            for _, targetUrl in ipairs(TARGET_URLS) do
                if url:find(targetUrl) or url:match("https?://[^/]+/.+%.lua") then
                    local data = {
                        title = "🌐 HttpService.GetAsync: " .. url,
                        content = string.format("URL: %s\nResponse Length: %d\nTimestamp: %s\n\nResponse Preview:\n%s",
                            url, #result, os.date("%X"), result:sub(1, 1000) .. (#result > 1000 and "\n... [TRUNCATED]" or ""))
                    }
                    interceptedData.httpRequests[#interceptedData.httpRequests + 1] = data
                    gui.updateContent("http", interceptedData.httpRequests, Color3.fromRGB(255, 150, 0))
                    gui.updateStats()
                end
            end
        end
        
        return result
    end)

    -- Hook para loadstring
    hookSystem.hookFunction("loadstring", function(original, code, chunkname)
        if hookSystem.active and type(code) == "string" then
            local data = {
                title = "📝 loadstring Called",
                content = string.format("Chunk Name: %s\nCode Length: %d\nTimestamp: %s\n\nCode Preview:\n%s",
                    chunkname or "N/A", #code, os.date("%X"), code:sub(1, 2000) .. (#code > 2000 and "\n... [TRUNCATED]" or ""))
            }
            interceptedData.loadedStrings[#interceptedData.loadedStrings + 1] = data
            gui.updateContent("strings", interceptedData.loadedStrings, Color3.fromRGB(0, 200, 100))
            gui.updateStats()
        end
        
        return original(code, chunkname)
    end)

    -- Hook para require
    local originalRequire = require
    _G.require = function(module)
        if hookSystem.active then
            local data = {
                title = "📦 require Called",
                content = string.format("Module: %s\nType: %s\nTimestamp: %s\nStack:\n%s",
                    tostring(module), type(module), os.date("%X"), debug.traceback())
            }
            interceptedData.hooks[#interceptedData.hooks + 1] = data
            gui.updateContent("hooks", interceptedData.hooks, Color3.fromRGB(200, 100, 255))
            gui.updateStats()
        end
        
        return originalRequire(module)
    end

    -- Hook para getfenv/setfenv
    hookSystem.hookGetEnv()
    
    -- Hook para asignaciones globales
    hookSystem.hookGlobalAssignment()

    -- Hook para llamadas a función
    local function hookFunctionCalls()
        local originalCall = nil
        local function traceCall(func, ...)
            if hookSystem.active and debug.info(func, "n") ~= "traceCall" then
                local funcName = debug.info(func, "n") or "anonymous"
                local data = {
                    title = "⚡ Function Call: " .. funcName,
                    content = string.format("Function: %s\nArgs Count: %d\nTimestamp: %s\nStack:\n%s",
                        funcName, select("#", ...), os.date("%X"), debug.traceback())
                }
                interceptedData.hooks[#interceptedData.hooks + 1] = data
                gui.updateContent("hooks", interceptedData.hooks, Color3.fromRGB(200, 100, 255))
                gui.updateStats()
            end
            return originalCall(func, ...)
        end
        
        originalCall = pcall
        pcall = traceCall
    end

    hookFunctionCalls()

    gui.statusLabel.Text = "🟢 Todos los hooks instalados | Sistema activo"
end

-- Sistema de monitoreo en tiempo real
local monitor = {
    performance = {
        startTime = os.clock(),
        requests = 0,
        hooks = 0
    },
    
    start = function(gui)
        spawn(function()
            while wait(5) and hookSystem.active do
                -- Actualizar análisis de patrones
                local analysisData = {}
                
                table.insert(analysisData, {
                    title = "📈 Performance Stats",
                    content = string.format("Uptime: %.1f seconds\nHTTP Requests: %d\nHooks Triggered: %d\nMemory Usage: %d KB",
                        os.clock() - monitor.performance.startTime,
                        #interceptedData.httpRequests,
                        #interceptedData.hooks,
                        collectgarbage("count"))
                })
                
                table.insert(analysisData, {
                    title = "🔍 Pattern Detection",
                    content = string.format("Base64 Patterns: %d\nHex Encodings: %d\nLoadstring Calls: %d\nGetfenv Usage: %d",
                        0, 0, #interceptedData.loadedStrings, #interceptedData.environmentChanges)
                })
                
                gui.updateContent("analysis", analysisData, Color3.fromRGB(150, 255, 150))
                
                -- Estadísticas detalladas
                local statsData = {}
                table.insert(statsData, {
                    title = "📊 System Statistics",
                    content = string.format("Total Keys: %d\nTotal HTTP Requests: %d\nTotal Strings Loaded: %d\nTotal Hooks: %d\nEnvironment Changes: %d",
                        #interceptedData.keys,
                        #interceptedData.httpRequests,
                        #interceptedData.loadedStrings,
                        #interceptedData.hooks,
                        #interceptedData.environmentChanges)
                })
                
                gui.updateContent("stats", statsData, Color3.fromRGB(255, 200, 100))
            end
        end)
    end
}

-- Inicialización principal
local gui = createAdvancedGUI()
initializeHooks(gui)
monitor.start(gui)

-- Ejecutar código de prueba automáticamente
spawn(function()
    wait(3)
    
    gui.statusLabel.Text = "🎯 Ejecutando código de prueba..."
    
    -- Simular el código objetivo
    local testCode = [[
        -- Este es un script ofuscado de ejemplo
        getgenv().bruhwarekey = '6EZQSPs27L3IUj10P0A0'
        
        local encoded = "Z2V0Z2VudiAoKS5rZXkgPSAnNkVaUVNQczI3TDNJVWoxMFAwQTAn"
        local decoded = string.char(103,101,116,103,101,110,118,40,41,46,107,101,121,32,61,32,39,54,69,90,81,83,80,115,50,55,76,51,73,85,106,49,48,80,48,65,48,39)
        
        -- Código ofuscado con concatenación
        local part1 = "load"
        local part2 = "string"
        local part3 = part1 .. part2
        
        -- URL ofuscada
        local urlBase = "https://gist.githubusercontent.com/"
        local urlPath = "robloxclips/652550ce3cb81b9b9bccde75383d3299/raw/"
        local urlFile = "61387f95dc83caf5f2665054246fabc2f0186daa/bruhware.lua"
        local fullUrl = urlBase .. urlPath .. urlFile
        
        -- Llamada final
        loadstring(game:HttpGet(fullUrl))()
    ]]
    
    -- Ejecutar el código de prueba
    local success, err = pcall(function()
        loadstring(testCode)()
    end)
    
    if not success then
        gui.statusLabel.Text = "⚠️ Error en código de prueba: " .. tostring(err)
    else
        gui.statusLabel.Text = "✅ Código de prueba ejecutado"
    end
end)

-- Hacer la ventana arrastrable
local dragging = false
local dragInput
local dragStart
local startPos

gui.screenGui:WaitForChild("Frame").InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = gui.screenGui.Frame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

gui.screenGui.Frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

RunService.RenderStepped:Connect(function()
    if dragging then
        local delta = dragInput.Position - dragStart
        gui.screenGui.Frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- Función para exportar todos los datos
local function exportAllData()
    local export = "=== ADVANCED INTERCEPTOR EXPORT ===\n"
    export = export .. string.format("Export Time: %s\n", os.date("%Y-%m-%d %H:%M:%S"))
    export = export .. string.rep("=", 40) .. "\n\n"
    
    -- Keys
    export = export .. "🔑 KEYS INTERCEPTED:\n"
    for i, key in ipairs(interceptedData.keys) do
        export = export .. string.format("[%d] %s\n\n", i, key.content)
    end
    
    -- HTTP Requests
    export = export .. "\n🌐 HTTP REQUESTS:\n"
    for i, req in ipairs(interceptedData.httpRequests) do
        export = export .. string.format("[%d] %s\n\n", i, req.content)
    end
    
    -- Loaded Strings
    export = export .. "\n📝 LOADED STRINGS:\n"
    for i, str in ipairs(interceptedData.loadedStrings) do
        export = export .. string.format("[%d] %s\n\n", i, str.content)
    end
    
    -- Hooks
    export = export .. "\n🔧 HOOKS TRIGGERED:\n"
    for i, hook in ipairs(interceptedData.hooks) do
        export = export .. string.format("[%d] %s\n\n", i, hook.content)
    end
    
    export = export .. string.rep("=", 40) .. "\n"
    export = export .. "END OF EXPORT"
    
    print("\n" .. string.rep("=", 80))
    print("EXPORT DATA (Copy from console):")
    print(string.rep("=", 80))
    print(export)
    print(string.rep("=", 80))
    
    return export
end

-- Crear botón de exportación
local exportButton = Instance.new("TextButton")
exportButton.Size = UDim2.new(0, 150, 0, 35)
exportButton.Position = UDim2.new(0.5, -75, 1, -80)
exportButton.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
exportButton.Text = "📤 Export All Data"
exportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
exportButton.Font = Enum.Font.GothamBold
exportButton.TextSize = 14
exportButton.Parent = gui.screenGui.Frame

exportButton.MouseButton1Click:Connect(function()
    exportAllData()
    exportButton.Text = "✅ Exported!"
    exportButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    
    wait(2)
    
    exportButton.Text = "📤 Export All Data"
    exportButton.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
end)

-- Inicialización final
gui.updateStats()
gui.statusLabel.Text = "🟢 Sistema completamente inicializado"
