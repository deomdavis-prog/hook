--[[
    SISTEMA DE AUDITORÍA DE METATABLES (DELTA MOBILE COMPATIBLE)
    Propósito: Encontrar, desbloquear y extraer contenido de metatables bloqueadas.
    Características: GUI Interactiva, Desbloqueo de __metatable, Extracción Recursiva, Botón Copy All.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Verificar compatibilidad con Delta/Executor
local getrawmetatable = getrawmetatable or (debug and debug.getmetatable)
local setreadonly = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local setrawmetatable = setrawmetatable or (debug and debug.setmetatable)

if not getrawmetatable then
    warn("Executor no compatible: Se requiere getrawmetatable o debug.getmetatable")
    return
end

-- Variables de la GUI
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local ContentScroll = Instance.new("ScrollingFrame")
local UIListLayout = Instance.new("UIListLayout")
local CopyAllBtn = Instance.new("TextButton")
local CloseBtn = Instance.new("TextButton")
local StatusLabel = Instance.new("TextLabel")

-- Configuración de la GUI (Estilo Mobile Friendly)
ScreenGui.Name = "MetatableAuditor"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
MainFrame.Size = UDim2.new(0, 300, 0, 400)
MainFrame.Active = true
MainFrame.Draggable = true

Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.SourceSansBold
Title.Text = "Metatable Auditor - Delta"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18

ContentScroll.Name = "ContentScroll"
ContentScroll.Parent = MainFrame
ContentScroll.BackgroundTransparency = 1
ContentScroll.Position = UDim2.new(0, 5, 0, 35)
ContentScroll.Size = UDim2.new(1, -10, 1, -100)
ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentScroll.ScrollBarThickness = 4

UIListLayout.Parent = ContentScroll
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 5)

StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
StatusLabel.Position = UDim2.new(0, 5, 1, -60)
StatusLabel.Size = UDim2.new(1, -10, 0, 20)
StatusLabel.Font = Enum.Font.SourceSansItalic
StatusLabel.Text = "Listo para escanear..."
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextSize = 14

CopyAllBtn.Name = "CopyAllBtn"
CopyAllBtn.Parent = MainFrame
CopyAllBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
CopyAllBtn.Position = UDim2.new(0, 5, 1, -35)
CopyAllBtn.Size = UDim2.new(0.6, -10, 0, 30)
CopyAllBtn.Font = Enum.Font.SourceSansBold
CopyAllBtn.Text = "COPY ALL"
CopyAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyAllBtn.TextSize = 16

CloseBtn.Name = "CloseBtn"
CloseBtn.Parent = MainFrame
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
CloseBtn.Position = UDim2.new(0.6, 5, 1, -35)
CloseBtn.Size = UDim2.new(0.4, -10, 0, 30)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.Text = "CLOSE"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 16

-- Lógica de Auditoría
local full_dump = ""

local function tableToString(t, indent)
    indent = indent or ""
    local str = "{\n"
    for k, v in pairs(t) do
        local key = tostring(k)
        local val = ""
        if type(v) == "table" then
            val = tableToString(v, indent .. "  ")
        else
            val = tostring(v) .. " (" .. type(v) .. ")"
        end
        str = str .. indent .. "  [" .. key .. "] = " .. val .. ",\n"
    end
    return str .. indent .. "}"
end

local function auditMetatable(obj, name)
    StatusLabel.Text = "Auditando: " .. name
    local mt = getrawmetatable(obj)
    
    if mt then
        local result = "--- Metatable de " .. name .. " ---\n"
        
        -- Intentar desbloquear si está lockeada
        if mt.__metatable then
            result = result .. "[!] Detectado __metatable lock: " .. tostring(mt.__metatable) .. "\n"
            -- Técnica de bypass: Acceso directo vía getrawmetatable ya ignora __metatable en la mayoría de executors
            -- Pero si queremos modificarla, necesitamos setreadonly(mt, false)
            local success, err = pcall(function()
                if setreadonly then setreadonly(mt, false) end
            end)
            if success then
                result = result .. "[+] Metatable desbloqueada (Read-only OFF)\n"
            else
                result = result .. "[-] Fallo al desbloquear: " .. tostring(err) .. "\n"
            end
        end
        
        -- Extraer contenido
        local content = tableToString(mt)
        result = result .. content .. "\n\n"
        
        -- Mostrar en GUI
        local Entry = Instance.new("TextLabel")
        Entry.Parent = ContentScroll
        Entry.Size = UDim2.new(1, 0, 0, 100)
        Entry.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        Entry.TextColor3 = Color3.fromRGB(255, 255, 255)
        Entry.TextXAlignment = Enum.TextXAlignment.Left
        Entry.TextYAlignment = Enum.TextYAlignment.Top
        Entry.Text = name .. " MT Dump (Ver consola para detalles)"
        Entry.TextWrapped = true
        
        full_dump = full_dump .. result
        ContentScroll.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
        print(result)
    else
        StatusLabel.Text = name .. " no tiene metatable."
    end
end

-- Botones
CopyAllBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard(full_dump)
        StatusLabel.Text = "¡Copiado al portapapeles!"
    else
        StatusLabel.Text = "Error: setclipboard no soportado."
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Ejecución inicial (Ejemplos de auditoría)
task.spawn(function()
    -- Auditar objetos comunes que suelen tener metatables protegidas
    auditMetatable(game, "Game Object")
    auditMetatable(workspace, "Workspace")
    auditMetatable(Players.LocalPlayer, "LocalPlayer")
    
    -- Ejemplo con una tabla custom bloqueada
    local protected = setmetatable({}, {__metatable = "Esta metatable está bloqueada", secret = "12345"})
    auditMetatable(protected, "Custom Protected Table")
    
    StatusLabel.Text = "Auditoría completada."
end)
