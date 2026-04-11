--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║        OMNI-DUMP V12 - SAFE-DRIVE (AUTO-PURGE)               ║
    ║   Control: Botón dinámico STOP/START + Purga de RAM.         ║
    ║   Ingeniería: Persistencia de índice y vaciado de Buffer.    ║
    ╚══════════════════════════════════════════════════════════════╝
]]

local FILE_NAME = "SAFE_DRIVE_DUMP_" .. game.PlaceId .. ".txt"
local decompiler = decompile or (delta and delta.decompile)

if not decompiler then return warn("❌ Error: API de descompilación no activa.") end

-- [ VARIABLES DE ESTADO ]
local isRunning = false
local currentIdx = 1
local targets = {}
local buffer = {}
local batch_size = 30 -- Lote óptimo para velocidad/estabilidad

-- [ UI DE CONTROL - DRAGGABLE ]
local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
local frame = Instance.new("Frame", sg)
local btn = Instance.new("TextButton", frame)

frame.Size = UDim2.new(0, 140, 0, 50)
frame.Position = UDim2.new(0.5, -70, 0.1, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 2
frame.Active = true
frame.Draggable = true -- Para moverlo si estorba en la UI del juego

btn.Size = UDim2.new(1, -10, 1, -10)
btn.Position = UDim2.new(0, 5, 0, 5)
btn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
btn.Text = "INICIAR"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.Code
btn.TextSize = 16

-- [ FUNCIÓN DE LIMPIEZA CRÍTICA ]
local function PurgeMemory()
    print("🧹 [!] STOP IDENTIFICADO: Iniciando purga de emergencia...")
    
    -- 1. Vaciar lo que esté en el buffer ahora mismo al archivo
    if #buffer > 0 then
        pcall(function() appendfile(FILE_NAME, table.concat(buffer)) end)
        table.clear(buffer)
    end
    
    -- 2. Forzar limpieza de basura de Lua
    for i = 1, 3 do
        collectgarbage("collect")
        task.wait(0.1)
    end
    print("✅ RAM Liberada. Estado: Estable para continuar.")
end

-- [ MOTOR DE DUMP CON BUFFER Y SEGURIDAD ]
local function StartProcess()
    if #targets == 0 then
        print("🔍 Escaneando scripts iniciales...")
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("LocalScript") or v:IsA("ModuleScript") then table.insert(targets, v) end
        end
        writefile(FILE_NAME, "== START DUMP (PLACE " .. game.PlaceId .. ") ==\n")
    end

    isRunning = true
    btn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)

    while isRunning and currentIdx <= #targets do
        local scr = targets[currentIdx]
        btn.Text = "STOP [" .. currentIdx .. "]"

        -- Descompilación
        local success, source = pcall(function() return decompiler(scr) end)
        local data = "\n\n-- PATH: " .. scr:GetFullName() .. "\n" .. (success and source or "-- [ERROR]")
        
        table.insert(buffer, data)

        -- Lógica de escritura por lotes
        if #buffer >= batch_size or currentIdx == #targets then
            pcall(function() appendfile(FILE_NAME, table.concat(buffer)) end)
            table.clear(buffer)
            task.wait(0.01) -- Respiro mínimo para el bus de datos
        end

        currentIdx = currentIdx + 1
        
        -- Si no hay pausa, el botón no se puede clickear (Yield)
        if currentIdx % 5 == 0 then task.wait() end 
    end

    if currentIdx > #targets then
        btn.Text = "FINISH"
        btn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        isRunning = false
    end
end

-- [ EVENTO DEL BOTÓN ]
btn.MouseButton1Click:Connect(function()
    if isRunning then
        isRunning = false
        btn.Text = "PURGANDO..."
        btn.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
        PurgeMemory()
        btn.Text = "RESUME"
        btn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    else
        task.spawn(StartProcess)
    end
end)

print("🎯 Omni-Dump V12 Cargado. Botón listo en pantalla.")
