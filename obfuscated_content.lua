--[[
    OMNI-DUMP V15 - INSTANCE-DIRECT EDITION
    Fix crítico: guarda referencias Instance reales (no paths),
    las libera con nil inmediatamente después de descompilar.
    Evita [GONE] en juegos con objetos dinámicos.
]]

local ENV = {
    hasWritefile  = (writefile ~= nil),
    hasAppendfile = (appendfile ~= nil),
    hasGcinfo     = (gcinfo ~= nil),
    decompiler    = decompile or (delta and delta.decompile),
}

if not ENV.decompiler then
    return warn("[OmniDump] Error: API de descompilación no disponible.")
end
if not ENV.hasAppendfile and not ENV.hasWritefile then
    return warn("[OmniDump] Error: Sin API de escritura disponible.")
end

local CONFIG = {
    FILE_NAME     = "DUMP_" .. game.PlaceId .. ".txt",
    BATCH_SIZE    = 5,
    BATCH_MIN     = 2,
    BATCH_MAX     = 15,
    BASE_DELAY    = 0.05,
    DELAY_MIN     = 0.02,
    DELAY_MAX     = 0.25,
    BREATHE_EVERY = 150,
    BREATHE_MIN   = 50,
    BREATHE_WAIT  = 1.5,
    SAMPLE_EVERY  = 30,
    RAM_HIGH      = 150,
    RAM_CRITICAL  = 250,
    -- Cuántas referencias Instance mantener vivas a la vez
    -- El resto se liberan con nil tras usarse
    WINDOW_SIZE   = 1,  -- Procesa de 1 en 1, libera inmediatamente
}

local metrics = {
    ramSamples = {},
    lastRam    = 0,
    crashRisk  = 0,
}

local state = {
    running     = false,
    idx         = 1,
    -- targets: tabla sparse — se va poniendo nil script a script
    targets     = {},
    total       = 0,
    buffer      = {},
    errorCount  = 0,
    startTime   = 0,
    lastBreathe = 0,
}

-- [ WRITER ]
local function safeWrite(data, overwrite)
    if overwrite and ENV.hasWritefile then
        local ok = pcall(writefile, CONFIG.FILE_NAME, data)
        if ok then return end
    end
    if ENV.hasAppendfile then
        pcall(appendfile, CONFIG.FILE_NAME, data)
    end
end

local function flushBuffer()
    if #state.buffer == 0 then return end
    safeWrite(table.concat(state.buffer), false)
    table.clear(state.buffer)
end

-- [ RAM ]
local function sampleRam()
    if not ENV.hasGcinfo then return 0 end
    local ok, val = pcall(gcinfo)
    if not ok then return metrics.lastRam end
    local mb = val / 1024
    metrics.lastRam = mb
    table.insert(metrics.ramSamples, mb)
    if #metrics.ramSamples > 8 then table.remove(metrics.ramSamples, 1) end
    return mb
end

local function ramTrend()
    local s = metrics.ramSamples
    if #s < 3 then return 0 end
    return s[#s] - s[#s - 2]
end

local function adapt()
    local ram   = sampleRam()
    local trend = ramTrend()
    local risk  = 0
    if ram > CONFIG.RAM_HIGH then
        risk = math.min((ram - CONFIG.RAM_HIGH) / (CONFIG.RAM_CRITICAL - CONFIG.RAM_HIGH), 1.0)
    end
    if trend > 4 then risk = math.min(risk + 0.25, 1.0) end
    metrics.crashRisk = risk

    if risk > 0.6 then
        CONFIG.BATCH_SIZE    = CONFIG.BATCH_MIN
        CONFIG.BASE_DELAY    = CONFIG.DELAY_MAX
        CONFIG.BREATHE_EVERY = CONFIG.BREATHE_MIN
        CONFIG.BREATHE_WAIT  = 3.5
    elseif risk > 0.3 then
        CONFIG.BATCH_SIZE    = math.max(CONFIG.BATCH_MIN, CONFIG.BATCH_SIZE - 1)
        CONFIG.BASE_DELAY    = math.min(CONFIG.DELAY_MAX, CONFIG.BASE_DELAY + 0.015)
        CONFIG.BREATHE_EVERY = math.max(CONFIG.BREATHE_MIN, CONFIG.BREATHE_EVERY - 20)
        CONFIG.BREATHE_WAIT  = 2.0
    elseif risk < 0.1 then
        CONFIG.BATCH_SIZE    = math.min(CONFIG.BATCH_MAX, CONFIG.BATCH_SIZE + 1)
        CONFIG.BASE_DELAY    = math.max(CONFIG.DELAY_MIN, CONFIG.BASE_DELAY - 0.005)
        CONFIG.BREATHE_EVERY = math.min(300, CONFIG.BREATHE_EVERY + 5)
        CONFIG.BREATHE_WAIT  = math.max(0.8, CONFIG.BREATHE_WAIT - 0.1)
    end
end

-- [ UI ]
local CoreGui = game:GetService("CoreGui")
local prev = CoreGui:FindFirstChild("OmniDumpUI")
if prev then prev:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name         = "OmniDumpUI"
sg.ResetOnSpawn = false
sg.Parent       = CoreGui

local frame = Instance.new("Frame", sg)
frame.Size             = UDim2.new(0, 190, 0, 108)
frame.Position         = UDim2.new(0.5, -95, 0.04, 0)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local function mkLbl(parent, pos, size, txt, color, fs, align)
    local l = Instance.new("TextLabel", parent)
    l.Size               = size
    l.Position           = pos
    l.BackgroundTransparency = 1
    l.Text               = txt
    l.TextColor3         = color
    l.Font               = Enum.Font.SourceSans
    l.TextSize           = fs or 11
    l.TextXAlignment     = align or Enum.TextXAlignment.Center
    return l
end

mkLbl(frame,
    UDim2.new(0,0,0,4), UDim2.new(1,0,0,16),
    "OMNI-DUMP v15  DIRECT",
    Color3.fromRGB(120,120,140), 11)

local lblProg = mkLbl(frame,
    UDim2.new(0,8,0,22), UDim2.new(1,-16,0,15),
    "Listo", Color3.fromRGB(90,190,130), 11,
    Enum.TextXAlignment.Left)

local lblRam = mkLbl(frame,
    UDim2.new(0,8,0,38), UDim2.new(1,-16,0,14),
    "", Color3.fromRGB(160,160,80), 10,
    Enum.TextXAlignment.Left)

local lblAdapt = mkLbl(frame,
    UDim2.new(0,8,0,52), UDim2.new(1,-16,0,12),
    "", Color3.fromRGB(100,140,200), 10,
    Enum.TextXAlignment.Left)

local btn = Instance.new("TextButton", frame)
btn.Size             = UDim2.new(1,-16,0,34)
btn.Position         = UDim2.new(0,8,0,66)
btn.BackgroundColor3 = Color3.fromRGB(200,50,50)
btn.Text             = "INICIAR DUMP"
btn.TextColor3       = Color3.new(1,1,1)
btn.Font             = Enum.Font.SourceSansBold
btn.TextSize         = 15
btn.BorderSizePixel  = 0
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

local function setBtn(text, r, g, b)
    btn.Text             = text
    btn.BackgroundColor3 = Color3.fromRGB(r, g, b)
end

local function updateUI(i)
    local pct  = math.floor((i / state.total) * 100)
    local risk = metrics.crashRisk
    local ram  = metrics.lastRam
    lblProg.Text  = string.format("%d/%d  (%d%%)", i, state.total, pct)
    setBtn("STOP  " .. pct .. "%", 190, 45, 45)
    if risk > 0.6 then
        lblRam.Text       = string.format("RAM %.0fMB  CRITICO", ram)
        lblRam.TextColor3 = Color3.fromRGB(220, 60, 60)
    elseif risk > 0.3 then
        lblRam.Text       = string.format("RAM %.0fMB  moderado", ram)
        lblRam.TextColor3 = Color3.fromRGB(220, 160, 60)
    else
        lblRam.Text       = string.format("RAM %.0fMB  estable", ram)
        lblRam.TextColor3 = Color3.fromRGB(80, 190, 120)
    end
    lblAdapt.Text = string.format(
        "batch:%d  delay:%.2f  breathe:%d",
        CONFIG.BATCH_SIZE, CONFIG.BASE_DELAY, CONFIG.BREATHE_EVERY)
end

-- [ RECOPILACIÓN: guarda Instance refs, en una sola pasada rápida ]
local function collectTargets()
    if #state.targets > 0 then return end
    -- Una sola iteración, inmediata, antes de que el juego destruya objetos
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("ModuleScript") then
            table.insert(state.targets, v)
        end
    end
    state.total = #state.targets
    local header = string.format(
        "-- OMNI-DUMP v15 | PlaceId: %d | Scripts: %d | tick: %d\n\n",
        game.PlaceId, state.total, math.floor(tick())
    )
    safeWrite(header, true)
    print(string.format("[OmniDump] %d scripts capturados.", state.total))
end

-- [ MOTOR PRINCIPAL ]
local function StartProcess()
    state.running     = true
    state.startTime   = tick()
    state.errorCount  = 0
    state.lastBreathe = state.idx

    collectTargets()

    if state.total == 0 then
        setBtn("SIN SCRIPTS", 100, 100, 100)
        lblProg.Text = "No se hallaron scripts."
        state.running = false
        return
    end

    print("[OmniDump] Iniciando desde #" .. state.idx)

    while state.running and state.idx <= state.total do
        local i   = state.idx
        local scr = state.targets[i]

        -- ★ LIBERA la referencia inmediatamente — no espera al final
        state.targets[i] = nil

        local entry
        if scr and scr.Parent then
            -- Script aún vivo
            local fullName = scr:GetFullName()
            local ok, source = pcall(ENV.decompiler, scr)
            scr = nil  -- libera la Instance

            if ok and type(source) == "string" and #source > 0 then
                entry = "\n\n-- [OK] " .. fullName .. "\n" .. source
            else
                state.errorCount += 1
                local reason = (type(source) == "string" and source ~= "") 
                    and source or "sin respuesta"
                entry = "\n\n-- [ERR] " .. fullName .. " | " .. reason
            end
            source = nil
        else
            -- Script destruido antes de procesarse
            scr = nil
            -- No cuenta como error, simplemente lo omite del archivo
            state.idx += 1
            task.wait()
            continue
        end

        table.insert(state.buffer, entry)
        entry = nil

        local isFinal = i == state.total
        if #state.buffer >= CONFIG.BATCH_SIZE or isFinal then
            flushBuffer()
        end

        if i % CONFIG.SAMPLE_EVERY == 0 then
            adapt()
            updateUI(i)
        end

        if (i - state.lastBreathe) >= CONFIG.BREATHE_EVERY then
            state.lastBreathe = i
            flushBuffer()
            setBtn("RESPIRANDO...", 70, 70, 170)
            task.wait(CONFIG.BREATHE_WAIT)
            local pct = math.floor((i / state.total) * 100)
            setBtn("STOP  " .. pct .. "%", 190, 45, 45)
        end

        state.idx += 1
        task.wait(CONFIG.BASE_DELAY)
    end

    if state.idx > state.total then
        -- Limpia la tabla targets completamente
        table.clear(state.targets)
        local elapsed = math.floor(tick() - state.startTime)
        print(string.format(
            "[OmniDump] Completado: %d scripts en %ds. Errores: %d.",
            state.total, elapsed, state.errorCount
        ))
        setBtn("COMPLETADO", 35, 175, 75)
        lblProg.Text  = string.format("Listo: %d en %ds", state.total, elapsed)
        lblRam.Text   = "Errores: " .. state.errorCount
        lblAdapt.Text = ""
        state.running = false
    end
end

-- [ PURGA ]
local function PurgeSystem()
    setBtn("LIMPIANDO...", 240, 130, 0)
    lblProg.Text = "Purgando..."
    flushBuffer()
    table.clear(state.buffer)
    table.clear(metrics.ramSamples)
    task.wait(0.3)
    lblProg.Text = "Pausado en #" .. state.idx
    print("[OmniDump] Purga completa.")
end

-- [ BOTÓN ]
btn.MouseButton1Click:Connect(function()
    if state.running then
        state.running = false
        task.spawn(function()
            PurgeSystem()
            setBtn("REANUDAR", 45, 130, 45)
        end)
    else
        task.spawn(StartProcess)
    end
end)

print("[OmniDump] Listo. Usa el botón para iniciar.")
