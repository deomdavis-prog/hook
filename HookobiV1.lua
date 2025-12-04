-- ============================================================================
-- INTERCEPTOR LURAPH V4 - OPTIMIZADO E INTERACTIVO
-- Compatible con: Delta, Fluxus, KRNL, Synapse X
-- Características: Hooks avanzados, GUI interactiva, detección en tiempo real
-- ============================================================================

-- CONFIGURACIÓN INICIAL
local SCRIPT_IN_TEXT = [[ 
-- PEGAR AQUÍ EL CÓDIGO OFUSCADO COMPLETO
]]

local INPUT_FILENAME = "Cooooooontenido.txt"

local CONFIG = {
    LogFile = "luraph_log_v4.txt",
    UseConsole = true,
    MaxPayloadDisplay = 10000, -- Caracteres máximos a mostrar en GUI
    HookDepth = 5, -- Profundidad de hooks recursivos
    AutoSave = true,
    RealTimeDetection = true
}

-- ============================================================================
-- VARIABLES GLOBALES Y CACHÉ
-- ============================================================================
local CapturedPayloads = {}
local PayloadCache = {}
local DetectionStats = {
    loadstring_calls = 0,
    concat_calls = 0,
    char_calls = 0,
    bytecode_found = 0,
    source_found = 0
}

-- Referencias a funciones originales
local real_loadstring = loadstring
local real_pcall = pcall
local real_xpcall = xpcall
local real_string_char = string.char
local real_string_byte = string.byte
local real_table_concat = table.concat
local real_table_insert = table.insert
local real_getfenv = getfenv
local real_setfenv = setfenv
local real_assert = assert
local real_error = error

-- ============================================================================
-- SISTEMA DE LOGGING OPTIMIZADO
-- ============================================================================
local Logger = {
    buffer = {},
    lastFlush = tick()
}

local function safe_write(filename, content)
    local success = pcall(function()
        if writefile then
            writefile(filename, content)
        end
    end)
    return success
end

local function safe_append(filename, content)
    pcall(function()
        if appendfile then
            appendfile(filename, content)
        elseif writefile and readfile then
            local current = ""
            pcall(function() current = readfile(filename) end)
            writefile(filename, current .. content)
        end
    end)
end

function Logger:init()
    safe_write(CONFIG.LogFile, string.format("=== LURAPH INTERCEPTOR V4 ===\nInicio: %s\n\n", os.date("%c")))
    print("🔥 Interceptor V4 Inicializado")
end

function Logger:log(msg, level)
    level = level or "INFO"
    local timestamp = os.date("%H:%M:%S")
    local full_msg = string.format("[%s][%s] %s", timestamp, level, msg)
    
    if CONFIG.UseConsole then
        print(full_msg)
    end
    
    table.insert(self.buffer, full_msg)
    
    -- Flush automático cada 3 segundos o 50 mensajes
    if #self.buffer >= 50 or (tick() - self.lastFlush) > 3 then
        self:flush()
    end
end

function Logger:flush()
    if #self.buffer > 0 then
        safe_append(CONFIG.LogFile, table.concat(self.buffer, "\n") .. "\n")
        self.buffer = {}
        self.lastFlush = tick()
    end
end

function Logger:save_payload(content, name_suffix)
    local fname = string.format("payload_%s_%d_%d.lua", name_suffix, os.time(), math.random(1000,9999))
    
    if CONFIG.AutoSave then
        safe_write(fname, content)
        self:log(string.format("✅ Payload guardado: %s (%d bytes)", fname, #content), "SUCCESS")
    end
    
    -- Agregar a la lista de payloads capturados
    table.insert(CapturedPayloads, {
        content = content,
        timestamp = os.time(),
        filename = fname,
        size = #content,
        type = name_suffix
    })
    
    return fname
end

Logger:init()

-- ============================================================================
-- DETECTORES MEJORADOS
-- ============================================================================
local Detector = {}

function Detector:is_bytecode(str)
    if type(str) ~= "string" or #str < 4 then return false end
    return str:sub(1, 4) == "\27Lua" or str:sub(1, 3) == "LuaQ"
end

function Detector:is_readable_code(str)
    if type(str) ~= "string" or #str < 100 then return false end
    
    -- Patrones comunes de código Lua
    local patterns = {
        "local%s+%w+%s*=",
        "function%s*%(",
        "return%s+",
        "if%s+.+%s+then",
        "for%s+%w+%s*=",
        "while%s+.+%s+do",
        "%w+%s*=%s*function",
        "game[%.:]",
        "script[%.:]"
    }
    
    local matches = 0
    for _, pattern in ipairs(patterns) do
        if str:match(pattern) then
            matches = matches + 1
            if matches >= 3 then return true end
        end
    end
    
    return false
end

function Detector:analyze_payload(content)
    local analysis = {
        is_bytecode = self:is_bytecode(content),
        is_source = self:is_readable_code(content),
        size = #content,
        has_game_refs = content:match("game") ~= nil,
        has_script_refs = content:match("script") ~= nil,
        line_count = select(2, content:gsub('\n', '\n')) + 1
    }
    
    -- Calcular score de confianza
    analysis.confidence = 0
    if analysis.is_bytecode then analysis.confidence = 100 end
    if analysis.is_source then analysis.confidence = analysis.confidence + 80 end
    if analysis.size > 1000 then analysis.confidence = analysis.confidence + 10 end
    if analysis.has_game_refs then analysis.confidence = analysis.confidence + 5 end
    
    return analysis
end

-- ============================================================================
-- HOOKS OPTIMIZADOS Y AVANZADOS
-- ============================================================================
local HookSystem = {}

function HookSystem:create_loadstring_hook()
    return function(chunk, chunkname)
        DetectionStats.loadstring_calls = DetectionStats.loadstring_calls + 1
        
        if type(chunk) == "string" and #chunk > 50 then
            -- Evitar procesar el mismo payload dos veces
            local hash = tostring(#chunk) .. tostring(chunk:sub(1,20))
            if not PayloadCache[hash] then
                PayloadCache[hash] = true
                
                local analysis = Detector:analyze_payload(chunk)
                
                if analysis.confidence > 50 then
                    Logger:log(string.format("🎯 LOADSTRING: %d bytes, Confianza: %d%%", #chunk, analysis.confidence), "DETECT")
                    
                    if analysis.is_bytecode then
                        DetectionStats.bytecode_found = DetectionStats.bytecode_found + 1
                        Logger:save_payload(chunk, "bytecode")
                        UpdateGUIStats()
                    elseif analysis.is_source then
                        DetectionStats.source_found = DetectionStats.source_found + 1
                        Logger:save_payload(chunk, "source")
                        UpdateGUIStats()
                    end
                end
            end
        end
        
        return real_loadstring(chunk, chunkname)
    end
end

function HookSystem:create_concat_hook()
    return function(tbl, sep, i, j)
        DetectionStats.concat_calls = DetectionStats.concat_calls + 1
        
        -- Optimización: solo analizar si la tabla es grande
        if type(tbl) == "table" and #tbl > 10 then
            local result = real_table_concat(tbl, sep, i, j)
            
            if type(result) == "string" and #result > 500 then
                local hash = tostring(#result) .. tostring(result:sub(1,20))
                if not PayloadCache[hash] then
                    PayloadCache[hash] = true
                    
                    local analysis = Detector:analyze_payload(result)
                    
                    if analysis.confidence > 60 then
                        Logger:log(string.format("🔗 CONCAT: %d bytes, Confianza: %d%%", #result, analysis.confidence), "DETECT")
                        Logger:save_payload(result, "concat")
                        UpdateGUIStats()
                    end
                end
            end
            
            return result
        end
        
        return real_table_concat(tbl, sep, i, j)
    end
end

function HookSystem:create_char_hook()
    local char_buffer = {}
    local last_flush = tick()
    
    return function(...)
        DetectionStats.char_calls = DetectionStats.char_calls + 1
        local args = {...}
        
        -- Si hay muchos bytes, puede ser ensamblaje de código
        if #args > 50 then
            for _, byte_val in ipairs(args) do
                table.insert(char_buffer, byte_val)
            end
            
            -- Flush cada segundo o cuando buffer es grande
            if #char_buffer > 500 or (tick() - last_flush) > 1 then
                local assembled = real_string_char(unpack(char_buffer))
                
                if #assembled > 100 then
                    local analysis = Detector:analyze_payload(assembled)
                    if analysis.confidence > 40 then
                        Logger:log(string.format("🔤 STRING.CHAR: %d bytes ensamblados", #assembled), "DETECT")
                        Logger:save_payload(assembled, "charcode")
                        UpdateGUIStats()
                    end
                end
                
                char_buffer = {}
                last_flush = tick()
            end
        end
        
        return real_string_char(...)
    end
end

-- ============================================================================
-- GUI INTERACTIVA Y MODERNA
-- ============================================================================
local GUI = {}
GUI.Instance = nil
GUI.Minimized = false
GUI.DragStart = nil
GUI.StartPos = nil

function GUI:Create()
    local PlayerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Limpiar GUI anterior si existe
    local oldGui = PlayerGui:FindFirstChild("LuraphInterceptorGUI")
    if oldGui then oldGui:Destroy() end
    
    -- ScreenGui principal
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LuraphInterceptorGUI"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    
    -- Frame principal
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 500, 0, 400)
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    
    -- Sombra
    local Shadow = Instance.new("ImageLabel")
    Shadow.Name = "Shadow"
    Shadow.BackgroundTransparency = 1
    Shadow.Position = UDim2.new(0, -15, 0, -15)
    Shadow.Size = UDim2.new(1, 30, 1, 30)
    Shadow.ZIndex = 0
    Shadow.Image = "rbxasset://textures/ui/InspectMenu/Shadow.png"
    Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.ImageTransparency = 0.5
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    Shadow.Parent = MainFrame
    
    -- Barra de título
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 35)
    TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -80, 1, 0)
    TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "🔥 LURAPH INTERCEPTOR V4"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 16
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar
    
    -- Botón Minimizar
    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Name = "MinimizeBtn"
    MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    MinimizeBtn.Position = UDim2.new(1, -70, 0, 2.5)
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    MinimizeBtn.BorderSizePixel = 0
    MinimizeBtn.Text = "—"
    MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeBtn.TextSize = 18
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.Parent = TitleBar
    
    -- Botón Cerrar
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -35, 0, 2.5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 18
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = TitleBar
    
    -- Contenedor de contenido
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, 0, 1, -35)
    ContentFrame.Position = UDim2.new(0, 0, 0, 35)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame
    
    -- Panel de estadísticas
    local StatsFrame = Instance.new("Frame")
    StatsFrame.Name = "StatsFrame"
    StatsFrame.Size = UDim2.new(1, -20, 0, 120)
    StatsFrame.Position = UDim2.new(0, 10, 0, 10)
    StatsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    StatsFrame.BorderSizePixel = 0
    StatsFrame.Parent = ContentFrame
    
    local StatsTitle = Instance.new("TextLabel")
    StatsTitle.Size = UDim2.new(1, -10, 0, 25)
    StatsTitle.Position = UDim2.new(0, 5, 0, 5)
    StatsTitle.BackgroundTransparency = 1
    StatsTitle.Text = "📊 ESTADÍSTICAS EN TIEMPO REAL"
    StatsTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
    StatsTitle.TextSize = 14
    StatsTitle.Font = Enum.Font.GothamBold
    StatsTitle.TextXAlignment = Enum.TextXAlignment.Left
    StatsTitle.Parent = StatsFrame
    
    local StatsText = Instance.new("TextLabel")
    StatsText.Name = "StatsText"
    StatsText.Size = UDim2.new(1, -10, 1, -35)
    StatsText.Position = UDim2.new(0, 5, 0, 30)
    StatsText.BackgroundTransparency = 1
    StatsText.Text = "Iniciando..."
    StatsText.TextColor3 = Color3.fromRGB(220, 220, 220)
    StatsText.TextSize = 12
    StatsText.Font = Enum.Font.Gotham
    StatsText.TextXAlignment = Enum.TextXAlignment.Left
    StatsText.TextYAlignment = Enum.TextYAlignment.Top
    StatsText.Parent = StatsFrame
    
    -- Panel de payloads
    local PayloadFrame = Instance.new("Frame")
    PayloadFrame.Name = "PayloadFrame"
    PayloadFrame.Size = UDim2.new(1, -20, 1, -220)
    PayloadFrame.Position = UDim2.new(0, 10, 0, 140)
    PayloadFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    PayloadFrame.BorderSizePixel = 0
    PayloadFrame.Parent = ContentFrame
    
    local PayloadTitle = Instance.new("TextLabel")
    PayloadTitle.Size = UDim2.new(1, -10, 0, 25)
    PayloadTitle.Position = UDim2.new(0, 5, 0, 5)
    PayloadTitle.BackgroundTransparency = 1
    PayloadTitle.Text = "📦 PAYLOADS CAPTURADOS (0)"
    PayloadTitle.TextColor3 = Color3.fromRGB(100, 255, 100)
    PayloadTitle.TextSize = 14
    PayloadTitle.Font = Enum.Font.GothamBold
    PayloadTitle.TextXAlignment = Enum.TextXAlignment.Left
    PayloadTitle.Parent = PayloadFrame
    
    local PayloadScroll = Instance.new("ScrollingFrame")
    PayloadScroll.Name = "PayloadScroll"
    PayloadScroll.Size = UDim2.new(1, -10, 1, -35)
    PayloadScroll.Position = UDim2.new(0, 5, 0, 30)
    PayloadScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    PayloadScroll.BorderSizePixel = 0
    PayloadScroll.ScrollBarThickness = 6
    PayloadScroll.Parent = PayloadFrame
    
    -- Botones de acción
    local ButtonsFrame = Instance.new("Frame")
    ButtonsFrame.Name = "ButtonsFrame"
    ButtonsFrame.Size = UDim2.new(1, -20, 0, 40)
    ButtonsFrame.Position = UDim2.new(0, 10, 1, -50)
    ButtonsFrame.BackgroundTransparency = 1
    ButtonsFrame.Parent = ContentFrame
    
    local CopyAllBtn = Instance.new("TextButton")
    CopyAllBtn.Name = "CopyAllBtn"
    CopyAllBtn.Size = UDim2.new(0.48, 0, 1, 0)
    CopyAllBtn.Position = UDim2.new(0, 0, 0, 0)
    CopyAllBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    CopyAllBtn.BorderSizePixel = 0
    CopyAllBtn.Text = "📋 COPIAR TODO"
    CopyAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CopyAllBtn.TextSize = 14
    CopyAllBtn.Font = Enum.Font.GothamBold
    CopyAllBtn.Parent = ButtonsFrame
    
    local SaveAllBtn = Instance.new("TextButton")
    SaveAllBtn.Name = "SaveAllBtn"
    SaveAllBtn.Size = UDim2.new(0.48, 0, 1, 0)
    SaveAllBtn.Position = UDim2.new(0.52, 0, 0, 0)
    SaveAllBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
    SaveAllBtn.BorderSizePixel = 0
    SaveAllBtn.Text = "💾 GUARDAR TODO"
    SaveAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SaveAllBtn.TextSize = 14
    SaveAllBtn.Font = Enum.Font.GothamBold
    SaveAllBtn.Parent = ButtonsFrame
    
    -- Funcionalidad de arrastre
    local dragging, dragInput, dragStart, startPos
    
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Funcionalidad de minimizar
    MinimizeBtn.MouseButton1Click:Connect(function()
        GUI.Minimized = not GUI.Minimized
        if GUI.Minimized then
            MainFrame:TweenSize(UDim2.new(0, 500, 0, 35), "Out", "Quad", 0.3, true)
            MinimizeBtn.Text = "□"
        else
            MainFrame:TweenSize(UDim2.new(0, 500, 0, 400), "Out", "Quad", 0.3, true)
            MinimizeBtn.Text = "—"
        end
    end)
    
    -- Funcionalidad de cerrar
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        GUI.Instance = nil
        Logger:log("❌ GUI cerrada por el usuario", "INFO")
    end)
    
    -- Copiar todo
    CopyAllBtn.MouseButton1Click:Connect(function()
        if #CapturedPayloads > 0 then
            local combined = ""
            for i, payload in ipairs(CapturedPayloads) do
                combined = combined .. string.format("\n-- PAYLOAD %d (%s) --\n%s\n", i, payload.type, payload.content)
            end
            
            if setclipboard then
                setclipboard(combined)
                CopyAllBtn.Text = "✅ COPIADO!"
                wait(1)
                CopyAllBtn.Text = "📋 COPIAR TODO"
            end
        end
    end)
    
    -- Guardar todo
    SaveAllBtn.MouseButton1Click:Connect(function()
        local fname = string.format("all_payloads_%d.lua", os.time())
        local combined = ""
        for i, payload in ipairs(CapturedPayloads) do
            combined = combined .. string.format("\n-- PAYLOAD %d (%s) --\n%s\n", i, payload.type, payload.content)
        end
        safe_write(fname, combined)
        SaveAllBtn.Text = "✅ GUARDADO!"
        wait(1)
        SaveAllBtn.Text = "💾 GUARDAR TODO"
    end)
    
    ScreenGui.Parent = PlayerGui
    GUI.Instance = ScreenGui
    GUI.StatsText = StatsText
    GUI.PayloadScroll = PayloadScroll
    GUI.PayloadTitle = PayloadTitle
    
    Logger:log("✅ GUI Interactiva creada", "SUCCESS")
end

function GUI:UpdateStats()
    if not self.Instance or not self.StatsText then return end
    
    local statsText = string.format(
        "Llamadas Loadstring: %d\n" ..
        "Llamadas Concat: %d\n" ..
        "Llamadas String.char: %d\n" ..
        "Bytecode encontrado: %d | Código fuente: %d",
        DetectionStats.loadstring_calls,
        DetectionStats.concat_calls,
        DetectionStats.char_calls,
        DetectionStats.bytecode_found,
        DetectionStats.source_found
    )
    
    self.StatsText.Text = statsText
end

function GUI:AddPayloadToList(payload)
    if not self.Instance or not self.PayloadScroll then return end
    
    local index = #CapturedPayloads
    self.PayloadTitle.Text = string.format("📦 PAYLOADS CAPTURADOS (%d)", index)
    
    -- Crear botón para cada payload
    local PayloadBtn = Instance.new("TextButton")
    PayloadBtn.Name = "Payload_" .. index
    PayloadBtn.Size = UDim2.new(1, -10, 0, 30)
    PayloadBtn.Position = UDim2.new(0, 5, 0, (index - 1) * 35)
    PayloadBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    PayloadBtn.BorderSizePixel = 0
    PayloadBtn.Text = string.format("Payload #%d [%s] - %d bytes", index, payload.type, payload.size)
    PayloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    PayloadBtn.TextSize = 12
    PayloadBtn.Font = Enum.Font.Gotham
    PayloadBtn.TextXAlignment = Enum.TextXAlignment.Left
    PayloadBtn.Parent = self.PayloadScroll
    
    PayloadBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(payload.content)
            PayloadBtn.Text = string.format("✅ COPIADO - Payload #%d", index)
            wait(2)
            PayloadBtn.Text = string.format("Payload #%d [%s] - %d bytes", index, payload.type, payload.size)
        end
    end)
    
    self.PayloadScroll.CanvasSize = UDim2.new(0, 0, 0, index * 35)
end

-- Función global para actualizar stats desde hooks
function UpdateGUIStats()
    if GUI.Instance then
        GUI:UpdateStats()
        if #CapturedPayloads > 0 then
            GUI:AddPayloadToList(CapturedPayloads[#CapturedPayloads])
        end
    end
end

-- ============================================================================
-- ENTORNO VIRTUAL CON HOOKS APLICADOS
-- ============================================================================
local VirtualEnv = {}
for k, v in pairs(getgenv and getgenv() or _G) do
    VirtualEnv[k] = v
end

-- Aplicar hooks optimizados
VirtualEnv.loadstring = HookSystem:create_loadstring_hook()
VirtualEnv.load = VirtualEnv.loadstring

VirtualEnv.table = {}
for k, v in pairs(table) do VirtualEnv.table[k] = v end
VirtualEnv.table.concat = HookSystem:create_concat_hook()

VirtualEnv.string = {}
for k, v in pairs(string) do VirtualEnv.string[k] = v end
VirtualEnv.string.char = HookSystem:create_char_hook()

VirtualEnv.getfenv = function(f)
    if not f or f == 0 then return VirtualEnv end
    return real_getfenv(f)
end

-- ============================================================================
-- EJECUCIÓN DEL SCRIPT Y GUI
-- ============================================================================

-- Crear GUI antes de ejecutar
task.spawn(function()
    wait(0.5)
    GUI:Create()
end)

Logger:log("🚀 Preparando ejecución del script ofuscado...", "INFO")

local target_script = ""

if #SCRIPT_IN_TEXT > 50 then
    target_script = SCRIPT_IN_TEXT
    Logger:log("📄 Usando script pegado en SCRIPT_IN_TEXT", "INFO")
elseif isfile and isfile(INPUT_FILENAME) then
    target_script = readfile(INPUT_FILENAME)
    Logger:log(string.format("📂 Leyendo desde archivo: %s", INPUT_FILENAME), "INFO")
else
    warn("❌ ERROR: No se encontró el script. Pega el código en SCRIPT_IN_TEXT.")
    return
end

Logger:log(string.format("📊 Tamaño del script: %d bytes", #target_script), "INFO")

local func, err = real_loadstring(target_script, "Luraph_Target")

if not func then
    Logger:log(string.format("❌ Error de sintaxis: %s", tostring(err)), "ERROR")
else
    real_setfenv(func, VirtualEnv)
    
    local success, result = real_pcall(func)
    
    if success then
        Logger:log("✅ Script ejecutado correctamente", "SUCCESS")
    else
        Logger:log(string.format("⚠️ Error en ejecución: %s", tostring(result)), "WARN")
    end
end

-- Escaneo final de variables globales
Logger:log("🔍 Escaneando variables globales residuales...", "INFO")
for k, v in pairs(VirtualEnv) do
    if not _G[k] and type(v) == "string" and #v > 100 then
        local analysis = Detector:analyze_payload(v)
        if analysis.confidence > 30 then
            Logger:log(string.format("🎯 Variable sospechosa: %s (%d bytes)", tostring(k), #v), "DETECT")
            Logger:save_payload(v, "global_" .. tostring(k))
            UpdateGUIStats()
        end
    end
end

Logger:flush()

-- Mensaje final
task.wait(1)
if #CapturedPayloads > 0 then
    Logger:log(string.format("🎉 PROCESO COMPLETADO - %d payloads capturados", #CapturedPayloads), "SUCCESS")
    print(string.format("\n✅ INTERCEPTOR FINALIZADO\n📦 Payloads capturados: %d\n💾 Revisa tu carpeta workspace\n", #CapturedPayloads))
else
    Logger:log("⚠️ No se detectaron payloads grandes. Revisa el log para más detalles.", "WARN")
    print("\n⚠️ NO SE DETECTARON PAYLOADS\nPosibles causas:\n1. El código no fue pegado correctamente\n2. El ofuscador detectó los hooks\n3. El script no ejecuta código dinámico\n")
end
