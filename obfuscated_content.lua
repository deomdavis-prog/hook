--[[
    OMNI-DUMP V12 - DELTA MOBILE EDITION
    Fixes: sin collectgarbage, sin os.date, writer seguro.
]]

-- [ CONFIGURACIÓN CENTRAL ]
local CONFIG = {
    FILE_NAME    = "DUMP_" .. game.PlaceId .. ".txt",
    BATCH_SIZE   = 20,
    BASE_DELAY   = 0.05,
    UPDATE_EVERY = 10,
}

-- [ VALIDACIÓN DE API ]
local decompiler = decompile or (delta and delta.decompile)
if not decompiler then
    return warn("[OmniDump] Error: API de descompilación no disponible.")
end

-- [ WRITER SEGURO ]
local function safeWrite(filename, data, overwrite)
    local ok
    if overwrite and writefile then
        ok = pcall(writefile, filename, data)
        if ok then return end
    end
    if appendfile then
        pcall(appendfile, filename, data)
    else
        warn("[OmniDump] Sin API de escritura disponible.")
    end
end

-- [ ESTADO GLOBAL ]
local state = {
    running    = false,
    idx        = 1,
    targets    = {},
    buffer     = {},
    total      = 0,
    errorCount = 0,
    startTime  = 0,
}

-- [ INTERFAZ ]
local CoreGui = game:GetService("CoreGui")

-- Destruye instancia previa si existe (al re-ejecutar)
local prev = CoreGui:FindFirstChild("OmniDumpUI")
if prev then prev:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name         = "OmniDumpUI"
sg.ResetOnSpawn = false
sg.Parent       = CoreGui

local frame = Instance.new("Frame", sg)
frame.Size             = UDim2.new(0, 160, 0, 80)
frame.Position         = UDim2.new(0.5, -80, 0.04, 0)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local lbl = Instance.new("TextLabel", frame)
lbl.Size               = UDim2.new(1, 0, 0, 20)
lbl.Position           = UDim2.new(0, 0, 0, 6)
lbl.BackgroundTransparency = 1
lbl.Text               = "OMNI-DUMP v12"
lbl.TextColor3         = Color3.fromRGB(160, 160, 170)
lbl.Font               = Enum.Font.SourceSansBold
lbl.TextSize           = 12

local btn = Instance.new("TextButton", frame)
btn.Size               = UDim2.new(1, -16, 0, 38)
btn.Position           = UDim2.new(0, 8, 0, 34)
btn.BackgroundColor3   = Color3.fromRGB(220, 60, 60)
btn.Text               = "INICIAR DUMP"
btn.TextColor3         = Color3.new(1, 1, 1)
btn.Font               = Enum.Font.SourceSansBold
btn.TextSize           = 16
btn.BorderSizePixel    = 0
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

-- [ HELPERS ]
local function setBtn(text, r, g, b)
    btn.Text             = text
    btn.BackgroundColor3 = Color3.fromRGB(r, g, b)
end

local function setStatus(text)
    lbl.Text = text
end

local function flushBuffer()
    if #state.buffer == 0 then return end
    safeWrite(CONFIG.FILE_NAME, table.concat(state.buffer), false)
    table.clear(state.buffer)
end

-- [ PURGA DE MEMORIA (sin collectgarbage) ]
local function PurgeSystem()
    setBtn("LIMPIANDO...", 255, 140, 0)
    setStatus("Purgando memoria...")
    flushBuffer()
    table.clear(state.buffer)
    task.wait(0.2)
    setStatus("Memoria liberada.")
    print("[OmniDump] Purga completa.")
end

-- [ RECOPILACIÓN DE OBJETIVOS ]
local function collectTargets()
    if #state.targets > 0 then return end
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("ModuleScript") then
            table.insert(state.targets, v)
        end
    end
    state.total = #state.targets
    local header = string.format(
        "-- OMNI-DUMP v12 | PlaceId: %d | Scripts: %d | tick: %d\n\n",
        game.PlaceId, state.total, math.floor(tick())
    )
    safeWrite(CONFIG.FILE_NAME, header, true)
    print(string.format("[OmniDump] %d scripts encontrados.", state.total))
end

-- [ MOTOR PRINCIPAL ]
local function StartProcess()
    state.running    = true
    state.startTime  = tick()
    state.errorCount = 0

    collectTargets()

    if state.total == 0 then
        setBtn("SIN SCRIPTS", 100, 100, 100)
        setStatus("No se hallaron scripts.")
        state.running = false
        return
    end

    setStatus(state.idx .. "/" .. state.total)
    print("[OmniDump] Iniciando desde script #" .. state.idx)

    while state.running and state.idx <= state.total do
        local scr = state.targets[state.idx]
        local ok, source = pcall(decompiler, scr)

        local entry
        if ok and type(source) == "string" and #source > 0 then
            entry = "\n\n-- [OK] " .. scr:GetFullName() .. "\n" .. source
        else
            state.errorCount += 1
            local reason = (type(source) == "string" and source) or "desconocido"
            entry = "\n\n-- [ERR] " .. scr:GetFullName() .. " | " .. reason
        end

        table.insert(state.buffer, entry)

        local isFinal = state.idx == state.total
        if #state.buffer >= CONFIG.BATCH_SIZE or isFinal then
            flushBuffer()
        end

        if state.idx % CONFIG.UPDATE_EVERY == 0 or isFinal then
            local pct = math.floor((state.idx / state.total) * 100)
            setBtn("STOP  " .. pct .. "%", 200, 50, 50)
            setStatus(state.idx .. "/" .. state.total)
        end

        state.idx += 1
        task.wait(CONFIG.BASE_DELAY)
    end

    if state.idx > state.total then
        local elapsed = math.floor(tick() - state.startTime)
        print(string.format(
            "[OmniDump] Completado: %d scripts en %ds. Errores: %d.",
            state.total, elapsed, state.errorCount
        ))
        setBtn("COMPLETADO", 40, 180, 80)
        setStatus("Listo. Errores: " .. state.errorCount)
        state.running = false
    end
end

-- [ LÓGICA DEL BOTÓN ]
btn.MouseButton1Click:Connect(function()
    if state.running then
        state.running = false
        task.spawn(function()
            PurgeSystem()
            setBtn("REANUDAR", 50, 140, 50)
            setStatus("Pausado en #" .. state.idx)
        end)
    else
        task.spawn(StartProcess)
    end
end)

print("[OmniDump] Listo. Usa el botón para iniciar.")
