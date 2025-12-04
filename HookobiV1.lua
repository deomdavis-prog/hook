-- ============================================================================
-- INTERCEPTOR LURAPH PARA ROBLOX (DELTA / FLUXUS / KRNL)
-- Versión con GUI y copia automática al portapapeles.
-- ============================================================================

-- !!! IMPORTANTE: PEGA TODO EL CÓDIGO OFUSCADO AQUÍ PARA MÁXIMA FIABILIDAD !!!
-- Asegúrate de que el código empiece y termine entre los corchetes dobles [[...]]
local SCRIPT_IN_TEXT = [[ 
-- PEGAR AQUÍ EL CONTENIDO COMPLETO DE "Cooooooontenido.txt"
]]

-- [OPCIÓN B] Nombre del archivo en la carpeta 'workspace' de tu ejecutor
local INPUT_FILENAME = "Cooooooontenido.txt" 

-- CONFIGURACIÓN
local CONFIG = {
    LogFile = "luraph_log_v3.txt",
    UseConsole = true, -- Imprimir en la consola (F9)
}

-- Variable global para guardar el payload más grande capturado
local LastPayload = ""

-- ============================================================================
-- 1. SISTEMA DE LOGGING COMPATIBLE CON ROBLOX
-- ============================================================================

local Logger = {
    buffer = {}
}

-- Funciones seguras para escribir archivos en Roblox (Delta/Fluxus)
local function safe_write(filename, content)
    if writefile then
        writefile(filename, content)
    else
        print("ERROR: Tu ejecutor no soporta 'writefile'.")
    end
end

local function safe_append(filename, content)
    if appendfile then
        appendfile(filename, content)
    elseif writefile and readfile then
        local current = ""
        pcall(function() current = readfile(filename) end)
        writefile(filename, current .. content)
    end
end

function Logger:init()
    safe_write(CONFIG.LogFile, "--- INICIO DELTA LURAPH INTERCEPTOR V3 ---\n\n")
    print(">>> Logger V3 Inicializado. Revisa la carpeta workspace de Delta.")
end

function Logger:log(msg, ...)
    local args = {...}
    for i, v in ipairs(args) do args[i] = tostring(v) end
    local full_msg = string.format("[%s] %s %s", os.date("%X"), msg, table.concat(args, "\t"))
    
    if CONFIG.UseConsole then
        print("[-] " .. full_msg)
    end
    
    table.insert(self.buffer, full_msg)
    
    if #self.buffer >= 20 then
        self:flush()
    end
end

function Logger:flush()
    if #self.buffer > 0 then
        safe_append(CONFIG.LogFile, table.concat(self.buffer, "\n") .. "\n")
        self.buffer = {}
    end
end

function Logger:save_payload(content, name_suffix, ext)
    local fname = "dump_" .. name_suffix .. "_" .. math.random(1000,9999) .. (ext or ".lua")
    safe_write(fname, content)

    -- Nuevo: guardar el payload más grande para la GUI de copia
    if #content > #LastPayload then
        LastPayload = content
    end

    self:log(">>> [PAYLOAD GUARDADO] Archivo creado:", fname)
    if messagebox then 
        pcall(function() messagebox("Luraph Dumped!", "Archivo guardado: " .. fname, 0) end)
    end
end

Logger:init()

-- ============================================================================
-- 2. ENTORNO VIRTUAL (SANDBOX)
-- ============================================================================

-- Guardamos las funciones reales
local real_loadstring = loadstring
local real_pcall = pcall
local real_string_char = string.char
local real_table_concat = table.concat

-- Detectores de código
local function is_lua_bytecode(str)
    return str:sub(1, 4) == "\27Lua"
end

local function is_readable_code(str)
    if #str < 50 then return false end
    if str:match("local%s+") or str:match("function%(") or str:match("return%s+") then
        return true
    end
    return false
end

-- Creamos el entorno falso (Sandbox)
local VirtualEnv = {}
for k, v in pairs(getgenv and getgenv() or _G) do
    VirtualEnv[k] = v
end

-- ======================================
-- A. INTERCEPTAR LOADSTRING/LOAD
-- ======================================
VirtualEnv.loadstring = function(chunk, chunkname)
    Logger:log("=== LOADSTRING LLAMADO ===")
    
    if type(chunk) == "string" then
        Logger:log("Longitud del chunk:", #chunk)
        
        if is_lua_bytecode(chunk) then
            Logger:log(">>> BYTECODE ENCONTRADO! (Loadstring)")
            Logger:save_payload(chunk, "bytecode", ".bin")
        elseif is_readable_code(chunk) then
            Logger:log(">>> CODIGO FUENTE ENCONTRADO! (Loadstring)")
            Logger:save_payload(chunk, "source_loadstring", ".lua")
        else
            if #chunk > 500 then
                Logger:log(">>> Chunk grande. (Loadstring)")
                Logger:save_payload(chunk, "unknown_loadstring", ".txt")
            end
        end
    end
    
    return real_loadstring(chunk, chunkname)
end
VirtualEnv.load = VirtualEnv.loadstring


-- ======================================
-- B. INTERCEPTAR TABLE.CONCAT (HOOK CLAVE)
-- ======================================
VirtualEnv.table = {}
for k, v in pairs(table) do VirtualEnv.table[k] = v end

VirtualEnv.table.concat = function(tbl, sep, i, j)
    local result = real_table_concat(tbl, sep, i, j)
    
    if type(result) == "string" and #result > 1000 then
        -- Esta es la etapa de ensamblaje del script desofuscado
        if is_readable_code(result) or is_lua_bytecode(result) then
            Logger:log("!!! PAYLOAD CONCATENADO DETECTADO (len=" .. #result .. ")")
            Logger:save_payload(result, "concat_payload", ".lua")
        end
    end
    return result
end


-- ======================================
-- C. INTERCEPTAR FUNCIONES DE SISTEMA
-- ======================================
-- Engañar a getfenv (Anti-tamper de Luraph)
VirtualEnv.getfenv = function(f)
    if not f or f == 0 then return VirtualEnv end
    return getfenv(f)
end

-- Interceptar string.char
VirtualEnv.string = {}
for k, v in pairs(string) do VirtualEnv.string[k] = v end
VirtualEnv.string.char = function(...)
    local args = {...}
    if #args > 100 then
        Logger:log("!!! string.char masivo detectado ("..#args.." bytes)")
    end
    return real_string_char(...)
end

-- ============================================================================
-- 3. EJECUCIÓN DEL SCRIPT OBJETIVO
-- ============================================================================

local target_script = ""

-- Opción 1: Usar el código pegado (más seguro en Delta)
if #SCRIPT_IN_TEXT > 50 then
    Logger:log("Usando script PEADO EN EL CÓDIGO (SCRIPT_IN_TEXT)")
    target_script = SCRIPT_IN_TEXT
-- Opción 2: Intentar leer el archivo (Solo si el pegado está vacío)
elseif isfile and isfile(INPUT_FILENAME) then
    Logger:log("Leyendo archivo desde workspace:", INPUT_FILENAME)
    target_script = readfile(INPUT_FILENAME)
else
    warn("ERROR: No se encontró el script. Asegúrate de pegar el código en SCRIPT_IN_TEXT.")
    return
end

Logger:log("Longitud del script ofuscado:", #target_script)
Logger:log("Iniciando ejecución protegida...")

-- Ejecutar el script ofuscado
local func, err = real_loadstring(target_script, "Luraph_Target")

if not func then
    Logger:log("Error de sintaxis al cargar:", err)
else
    setfenv(func, VirtualEnv)
    
    local success, result = real_pcall(func)
    
    if success then
        Logger:log("Script finalizó correctamente.")
    else
        Logger:log("Script falló (revisa el error):", result)
    end
end

-- Escaneo de variables residuales (captura final de posibles payloads)
Logger:log("--- Escaneando variables globales residuales ---")
for k, v in pairs(VirtualEnv) do
    if not _G[k] and not (getgenv and getgenv()[k]) then
        if type(v) == "string" and #v > 100 then
            Logger:log("Variable global sospechosa encontrada:", k)
            Logger:save_payload(v, "global_residual_"..tostring(k), ".lua")
        end
    end
end

Logger:flush()
print(">>> PROCESO TERMINADO. REVISA TUS ARCHIVOS EN WORKSPACE <<<")


-- ============================================================================
-- 4. FUNCIÓN Y ACTIVACIÓN DE LA GUI DE COPIA
-- ============================================================================

local function ShowCopyGUI(payload)
    -- Intenta acceder al entorno de Roblox. Si falla, solo usamos setclipboard.
    if not pcall(function() return game and game.CoreGui end) then
        if setclipboard then
            setclipboard(payload)
            print(">>> FALLO LA GUI. EL PAYLOAD HA SIDO COPIADO AUTOMÁTICAMENTE AL PORTAPAPELES. <<<")
        end
        return
    end

    -- Obtener el contenedor principal de la GUI
    local PlayerGui = game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui") or game.CoreGui
    if not PlayerGui then return end

    -- Contenedor principal
    local MainFrame = Instance.new("ScreenGui")
    MainFrame.Name = "Luraph_CopyGUI"
    MainFrame.DisplayOrder = 999 

    -- Marco de la ventana
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0.5, 0, 0.5, 0)
    Frame.Position = UDim2.new(0.5, 0, 0.5, 0) -- Centrado
    Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    Frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    Frame.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
    Frame.BorderSizePixel = 2
    Frame.Parent = MainFrame
    
    -- Título
    local Title = Instance.new("TextLabel")
    Title.Text = "LURAPH PAYLOAD CAPTURADO"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.BackgroundTransparency = 1
    Title.Size = UDim2.new(1, 0, 0.1, 0)
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 20
    Title.Parent = Frame

    -- Área de texto para el Payload (muestra el código o un mensaje si es muy largo)
    local PayloadTextBox = Instance.new("TextBox")
    PayloadTextBox.Text = (#payload < 5000) and payload or "Payload Capturado. Demasiado grande para mostrar. ¡Usa el botón Copiar!"
    PayloadTextBox.PlaceholderText = "Payload copiado, pero no visible (demasiado largo)."
    PayloadTextBox.TextEditable = false
    PayloadTextBox.MultiLine = true
    PayloadTextBox.BackgroundTransparency = 0.9
    PayloadTextBox.BackgroundColor3 = Color3.new(0, 0, 0)
    PayloadTextBox.Size = UDim2.new(1, -20, 0.7, 0)
    PayloadTextBox.Position = UDim2.new(0.5, 0, 0.55, 0)
    PayloadTextBox.AnchorPoint = Vector2.new(0.5, 0.5)
    PayloadTextBox.Parent = Frame
    
    -- Botón de Copiar
    local CopyButton = Instance.new("TextButton")
    CopyButton.Text = "Copiar al Portapapeles"
    CopyButton.BackgroundColor3 = Color3.new(0, 0.5, 0)
    CopyButton.Size = UDim2.new(0.9, 0, 0.1, 0)
    CopyButton.Position = UDim2.new(0.5, 0, 0.9, 0)
    CopyButton.AnchorPoint = Vector2.new(0.5, 0.5)
    CopyButton.Parent = Frame
    CopyButton.Font = Enum.Font.SourceSansBold
    CopyButton.TextSize = 20

    -- Botón de Cerrar
    local CloseButton = Instance.new("TextButton")
    CloseButton.Text = "X"
    CloseButton.BackgroundColor3 = Color3.new(0.8, 0.1, 0.1)
    CloseButton.Size = UDim2.new(0.1, 0, 0.1, 0)
    CloseButton.Position = UDim2.new(1, -10, 0, 10)
    CloseButton.AnchorPoint = Vector2.new(1, 0)
    CloseButton.Parent = Frame

    -- Lógica de los botones
    CopyButton.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(payload)
            CopyButton.Text = "¡COPIADO! (Revisa tu portapapeles)"
            wait(2)
            CopyButton.Text = "Copiar al Portapapeles"
        else
            warn("ERROR: Tu ejecutor (Delta) no tiene la función 'setclipboard'.")
        end
    end)
    
    CloseButton.MouseButton1Click:Connect(function()
        MainFrame:Destroy()
    end)

    MainFrame.Parent = PlayerGui
    
    -- Copiar inmediatamente si es posible
    if setclipboard then
        setclipboard(payload)
        CopyButton.Text = "¡COPIADO AUTOMÁTICO!"
        wait(2)
        CopyButton.Text = "Copiar al Portapapeles"
    end
end

-- Chequeo final para mostrar la GUI
if #LastPayload > 100 then
    print(">>> PAYLOAD GRANDE CAPTURADO. MOSTRANDO GUI DE COPIA Y COPIANDO AL PORTAPAPELES. <<<")
    ShowCopyGUI(LastPayload)
end
