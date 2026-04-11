--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║        OMNI-DUMP V13 - ZERO-ERROR (ULTRA REILIENT)           ║
    ║   Fix: Manejo de errores de descompilación y Buffer TXT.     ║
    ║   Control: Botón inteligente con auto-limpieza de caché.     ║
    ╚══════════════════════════════════════════════════════════════╝
]]

local FILE_NAME = "FINAL_DEEP_DUMP_" .. game.PlaceId .. ".txt"
local decompiler = decompile or (delta and delta.decompile)

if not decompiler then return warn("❌ Error: Decompiler no hallado.") end

-- [ VARIABLES DE ESTADO ]
local isRunning = false
local currentIdx = 1
local targets = {}

-- [ UI DE CONTROL MEJORADA ]
local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
local frame = Instance.new("Frame", sg)
local btn = Instance.new("TextButton", frame)
local status = Instance.new("TextLabel", frame)

frame.Size = UDim2.new(0, 160, 0, 70)
frame.Position = UDim2.new(0.5, -80, 0.1, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 2
frame.Draggable = true
frame.Active = true

btn.Size = UDim2.new(1, -10, 0, 35)
btn.Position = UDim2.new(0, 5, 0, 5)
btn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
btn.Text = "INICIAR DUMP"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.Code
btn.TextSize = 14

status.Size = UDim2.new(1, 0, 0, 20)
status.Position = UDim2.new(0, 0, 1, -25)
status.BackgroundTransparency = 1
status.Text = "Esperando..."
status.TextColor3 = Color3.new(0.8, 0.8, 0.8)
status.Font = Enum.Font.SourceSans
status.TextSize = 12

-- [ ESCRITURA SEGURA A PRUEBA DE CRASH ]
local function SafeAppend(content)
    local success, err = pcall(function()
        if not readfile(FILE_NAME) then
            writefile(FILE_NAME, "-- DUMP INICIADO\n")
        end
        appendfile(FILE_NAME, tostring(content))
    end)
    if not success then
        warn("⚠️ Error al escribir en archivo: " .. tostring(err))
    end
end

-- [ MOTOR DE EXTRACCIÓN UNITARIO ]
local function StartProcess()
    if #targets == 0 then
        status.Text = "Escaneando..."
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("LocalScript") or v:IsA("ModuleScript") then table.insert(targets, v) end
        end
    end

    isRunning = true
    btn.Text = "PAUSE"
    btn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)

    while isRunning and currentIdx <= #targets do
        local scr = targets[currentIdx]
        status.Text = "Procesando: " .. currentIdx .. "/" .. #targets
        
        -- Ingeniería Inversa de Bytecode
        local success, source = pcall(function() return decompiler(scr) end)
        
        local header = "\n\n" .. string.rep("-", 40) .. "\n"
        header = header .. "PATH: " .. scr:GetFullName() .. "\n"
        header = header .. string.rep("-", 40) .. "\n\n"
        
        local code = (success and source and #source > 0) and source or "-- [ERROR DE LECTURA]"
        
        -- Escribimos script por script para no saturar el buffer de Delta
        SafeAppend(header .. code)

        currentIdx = currentIdx + 1
        
        -- Respiro para el motor de UI
        if currentIdx % 3 == 0 then 
            task.wait(0.05) 
        end
    end

    if currentIdx > #targets then
        btn.Text = "COMPLETADO"
        btn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        isRunning = false
    end
end

-- [ LÓGICA DEL BOTÓN ]
btn.MouseButton1Click:Connect(function()
    if isRunning then
        isRunning = false
        btn.Text = "PURGANDO..."
        btn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
        collectgarbage("collect")
        task.wait(0.5)
        btn.Text = "REANUDAR"
        btn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
        status.Text = "Pausado en " .. currentIdx
    else
        task.spawn(StartProcess)
    end
end)

print("✅ V13 Cargada. Si el juego se congela, presiona STOP de inmediato.")
