--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║        OMNI-DUMP V17 - CYBER-SHIELD (ULTRA-RESILIENT)        ║
    ║   Ingeniería: Aislamiento por task.defer y Cola de Tareas.   ║
    ║   Objetivo: Ignorar errores de URL y continuar el volcado.   ║
    ╚══════════════════════════════════════════════════════════════╝
]]

local FILE_NAME = "CYBER_SHIELD_DUMP_" .. game.PlaceId .. ".txt"
local decompiler = decompile or (delta and delta.decompile)

if not decompiler then return warn("❌ API No Detectada") end

-- [ VARIABLES DE INGENIERÍA ]
local isRunning = false
local queue = {}
local currentIndex = 1
local successCount = 0
local errorCount = 0

-- [ UI DE MONITOREO EN TIEMPO REAL ]
local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
local frame = Instance.new("Frame", sg)
local btn = Instance.new("TextButton", frame)
local logLabel = Instance.new("TextLabel", frame)
local memLabel = Instance.new("TextLabel", frame)

frame.Size = UDim2.new(0, 200, 0, 100)
frame.Position = UDim2.new(0.5, -100, 0.1, 0)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BorderSizePixel = 2
frame.Draggable = true
frame.Active = true

btn.Size = UDim2.new(1, -10, 0, 35)
btn.Position = UDim2.new(0, 5, 0, 5)
btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
btn.Text = "INICIAR V17"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.Code

logLabel.Size = UDim2.new(1, -10, 0, 25)
logLabel.Position = UDim2.new(0, 5, 0, 45)
logLabel.Text = "Esperando..."
logLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
logLabel.TextSize = 12

memLabel.Size = UDim2.new(1, -10, 0, 25)
memLabel.Position = UDim2.new(0, 5, 0, 70)
memLabel.Text = "OK: 0 | ERR: 0"
memLabel.TextColor3 = Color3.new(0.4, 0.8, 0.4)
memLabel.TextSize = 12

-- [ PROCESADOR ASÍNCRONO ]
local function ProcessScript(scr)
    -- Usamos task.defer para que si el motor de Delta crashea en este script,
    -- no afecte al bucle principal del dump.
    task.defer(function()
        local header = "\n\n" .. string.rep("=", 30) .. "\nPATH: " .. scr:GetFullName() .. "\n" .. string.rep("=", 30) .. "\n"
        
        local success, result = pcall(function()
            return decompiler(scr)
        end)

        if success and result and #result > 0 then
            appendfile(FILE_NAME, header .. result)
            successCount = successCount + 1
        else
            -- Si da el error de InvalidUrl, guardamos que falló pero seguimos.
            appendfile(FILE_NAME, header .. "-- [!] ERROR DE MOTOR: URL Inválida o Servidor Caído.\n")
            errorCount = errorCount + 1
        end
        
        memLabel.Text = "OK: " .. successCount .. " | ERR: " .. errorCount
    end)
end

-- [ BUCLE MAESTRO ]
local function MainLoop()
    if #queue == 0 then
        logLabel.Text = "Escaneando..."
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("LocalScript") or v:IsA("ModuleScript") then table.insert(queue, v) end
        end
        writefile(FILE_NAME, "-- CYBER SHIELD START --\n")
    end

    isRunning = true
    btn.Text = "DETENER"
    btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)

    while isRunning and currentIndex <= #queue do
        local currentScript = queue[currentIndex]
        logLabel.Text = "Script " .. currentIndex .. "/" .. #queue
        
        ProcessScript(currentScript)

        currentIndex = currentIndex + 1
        
        -- Control de velocidad: 0.05s es suficiente para no saturar la red
        task.wait(0.05)
        
        -- Si detectamos que los errores suben demasiado rápido, pausamos automáticamente
        if errorCount > 0 and errorCount % 50 == 0 then
            print("⚠️ Alta tasa de errores de red. Autopausa de seguridad.")
            task.wait(1)
        end
    end
end

-- [ BOTÓN ]
btn.MouseButton1Click:Connect(function()
    if isRunning then
        isRunning = false
        btn.Text = "REANUDAR"
        btn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
    else
        task.spawn(MainLoop)
    end
end)
