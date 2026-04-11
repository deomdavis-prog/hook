--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║        OMNI-DUMP V15 - THE OMNI-REACTOR (FINAL)              ║
    ║   Ingeniería: Aislamiento HTTP + Control de Flujo Manual.    ║
    ║   Velocidad: Turbo-Asíncrono con Buffer de Seguridad.        ║
    ╚══════════════════════════════════════════════════════════════╝
]]

local FILE_NAME = "OMNI_REACTOR_DUMP_" .. game.PlaceId .. ".txt"
local decompiler = decompile or (delta and delta.decompile)

if not decompiler then return warn("❌ API de descompilación no disponible.") end

-- [ VARIABLES MAESTRAS ]
local isRunning = false
local currentIdx = 1
local targets = {}
local batch_buffer = {}

-- [ UI DE ALTA RESPUESTA ]
local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
local frame = Instance.new("Frame", sg)
local btn = Instance.new("TextButton", frame)
local status = Instance.new("TextLabel", frame)

frame.Size = UDim2.new(0, 180, 0, 80)
frame.Position = UDim2.new(0.5, -90, 0.15, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 2
frame.Draggable = true
frame.Active = true

btn.Size = UDim2.new(1, -10, 0, 40)
btn.Position = UDim2.new(0, 5, 0, 5)
btn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
btn.Text = "INICIAR REACTOR"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.Code
btn.TextSize = 14

status.Size = UDim2.new(1, 0, 0, 25)
status.Position = UDim2.new(0, 0, 1, -30)
status.BackgroundTransparency = 1
status.Text = "IDLE - Listo"
status.TextColor3 = Color3.new(0.7, 0.7, 0.7)
status.Font = Enum.Font.SourceSansItalic
status.TextSize = 13

-- [ SISTEMA DE ESCRITURA Y PURGA ]
local function FlushAndPurge()
    if #batch_buffer > 0 then
        local data = table.concat(batch_buffer)
        pcall(function() appendfile(FILE_NAME, data) end)
        table.clear(batch_buffer)
    end
    collectgarbage("collect")
end

-- [ MOTOR DE INGENIERÍA ]
local function ReactorProcess()
    if #targets == 0 then
        status.Text = "Escaneando memoria..."
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("LocalScript") or v:IsA("ModuleScript") then table.insert(targets, v) end
        end
        writefile(FILE_NAME, "-- REACTOR START: " .. os.date("%X") .. "\n")
    end

    isRunning = true
    btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)

    while isRunning and currentIdx <= #targets do
        local s = targets[currentIdx]
        status.Text = "BATCH: " .. currentIdx .. "/" .. #targets
        btn.Text = "STOP REACTOR"

        -- Aislamiento de Error HTTP (InvalidUrl Bypass)
        local success, source = pcall(function() 
            return decompiler(s) 
        end)
        
        local header = "\n\n[" .. string.rep("-", 15) .. "]\nPATH: " .. s:GetFullName() .. "\n"
        local code = (success and source and #source > 0) and source or "-- [!] SERVER ERROR (InvalidUrl/API Down)"
        
        table.insert(batch_buffer, header .. code)

        -- Control de Lote (Rápido pero seguro)
        if #batch_buffer >= 25 or currentIdx == #targets then
            FlushAndPurge()
            task.wait(0.1) -- Pausa necesaria para que el sistema de archivos no se bloquee
        end

        currentIdx = currentIdx + 1
        
        -- Cero tirones: devolvemos control al motor cada 3 scripts
        if currentIdx % 3 == 0 then task.wait() end
    end

    if currentIdx > #targets then
        btn.Text = "DUMP FINALIZADO"
        btn.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
        isRunning = false
    end
end

-- [ CONTROL DEL BOTÓN ]
btn.MouseButton1Click:Connect(function()
    if isRunning then
        isRunning = false
        btn.Text = "PAUSANDO..."
        btn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
        FlushAndPurge()
        task.wait(0.5)
        btn.Text = "REANUDAR"
        btn.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
        status.Text = "Pausado en script " .. currentIdx
    else
        task.spawn(ReactorProcess)
    end
end)

print("🚀 Reactor V15 cargado. Botón listo.")
