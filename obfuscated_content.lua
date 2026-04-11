--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║        OMNI-DUMP V16 - KERNEL ADAPTIVE (FIXED)               ║
    ║   Fix: Sustitución de collectgarbage por gcinfo().           ║
    ║   Ingeniería: Monitoreo de Heap compatible con Luau.         ║
    ╚══════════════════════════════════════════════════════════════╝
]]

local FILE_NAME = "KERNEL_ADAPTIVE_DUMP_" .. game.PlaceId .. ".txt"
local decompiler = decompile or (delta and delta.decompile)

if not decompiler then return warn("❌ Error: API de descompilación no activa.") end

-- [ VARIABLES DE CONTROL ]
local isRunning = false
local currentIdx = 1
local targets = {}
local buffer = {}

-- [ UI DE CONTROL ]
local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
local frame = Instance.new("Frame", sg)
local btn = Instance.new("TextButton", frame)
local memLabel = Instance.new("TextLabel", frame)

frame.Size = UDim2.new(0, 160, 0, 80)
frame.Position = UDim2.new(0.5, -80, 0.1, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Draggable = true
frame.Active = true

btn.Size = UDim2.new(1, -10, 0, 40)
btn.Position = UDim2.new(0, 5, 0, 5)
btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
btn.Text = "START V16"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.Code

memLabel.Size = UDim2.new(1, 0, 0, 30)
memLabel.Position = UDim2.new(0, 0, 1, -35)
memLabel.BackgroundTransparency = 1
memLabel.Text = "RAM: 0 MB"
memLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
memLabel.TextSize = 12

-- [ MONITOREO DE MEMORIA (GC INFO) ]
local function UpdateMemUI()
    -- gcinfo() devuelve el uso de memoria en KB
    local mem = math.floor(gcinfo() / 1024)
    memLabel.Text = "RAM LUA: " .. mem .. " MB"
end

-- [ PURGA DE SISTEMA ADAPTATIVA ]
local function PurgeSystem()
    print("🧹 Vaciando Buffer y esperando recolección del motor...")
    
    -- Escribimos lo que haya antes de limpiar
    if #buffer > 0 then
        pcall(function() appendfile(FILE_NAME, table.concat(buffer)) end)
        table.clear(buffer)
    end
    
    -- En Luau no podemos forzar 'collect', así que hacemos que Lua pierda las referencias
    -- y esperamos a que el motor haga el trabajo solo.
    for i = 1, 5 do
        UpdateMemUI()
        task.wait(0.2) 
    end
end

-- [ MOTOR DE DUMP ]
local function StartProcess()
    if #targets == 0 then
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("LocalScript") or v:IsA("ModuleScript") then table.insert(targets, v) end
        end
        writefile(FILE_NAME, "-- V16 KERNEL DUMP START\n")
    end

    isRunning = true
    btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)

    while isRunning and currentIdx <= #targets do
        local scr = targets[currentIdx]
        UpdateMemUI()
        btn.Text = "STOP (" .. currentIdx .. ")"

        local success, source = pcall(function() return decompiler(scr) end)
        
        local data = "\n\n-- PATH: " .. scr:GetFullName() .. "\n" .. (success and source or "-- [ERROR HTTP/URL]")
        table.insert(buffer, data)

        -- Escritura por lotes pequeños
        if #buffer >= 20 or currentIdx == #targets then
            pcall(function() appendfile(FILE_NAME, table.concat(buffer)) end)
            table.clear(buffer)
            task.wait(0.05)
        end

        currentIdx = currentIdx + 1
        if currentIdx % 5 == 0 then task.wait() end
    end
end

-- [ LÓGICA DEL BOTÓN ]
btn.MouseButton1Click:Connect(function()
    if isRunning then
        isRunning = false
        btn.Text = "PURGANDO..."
        btn.BackgroundColor3 = Color3.fromRGB(255, 160, 0)
        PurgeSystem()
        btn.Text = "RESUME"
        btn.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
    else
        task.spawn(StartProcess)
    end
end)

-- Actualizar UI de memoria cada segundo incluso si está pausado
task.spawn(function()
    while true do
        UpdateMemUI()
        task.wait(1)
    end
end)
