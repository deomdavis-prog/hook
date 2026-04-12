--[[
    OMNI-DUMP V13 - ADAPTIVE EDITION
    Auto-regula: batch, delay, respiro y modo escritura
    según RAM disponible y velocidad del entorno.
]]

-- [ DETECCIÓN DE ENTORNO ]
local ENV = {
    hasWritefile  = (writefile ~= nil),
    hasAppendfile = (appendfile ~= nil),
    hasGcinfo     = (gcinfo ~= nil),
    hasDelta      = (delta ~= nil),
    decompiler    = decompile or (delta and delta.decompile),
}

if not ENV.decompiler then
    return warn("[OmniDump] Error: API de descompilación no disponible.")
end
if not ENV.hasAppendfile and not ENV.hasWritefile then
    return warn("[OmniDump] Error: Sin API de escritura disponible.")
end

-- [ CONFIGURACIÓN ADAPTATIVA BASE ]
-- Todos los valores se auto-ajustan durante el proceso.
local CONFIG = {
    FILE_NAME       = "DUMP_" .. game.PlaceId .. ".txt",

    -- Escritura
    BATCH_SIZE      = 10,     -- Se reduce si hay presión de RAM
    BATCH_MIN       = 2,      -- Mínimo absoluto de batch
    BATCH_MAX       = 30,     -- Máximo cuando hay RAM holgada

    -- Delays
    BASE_DELAY      = 0.05,   -- Se ajusta según velocidad de descompilación
    DELAY_MIN       = 0.02,
    DELAY_MAX       = 0.3,

    -- Respiros
    BREATHE_EVERY   = 500,    -- Se reduce si hay crash risk
    BREATHE_MIN     = 100,
    BREATHE_WAIT    = 1.0,    -- Se extiende si la RAM está alta

    -- Muestreo adaptativo
    SAMPLE_EVERY    = 50,     -- Cada N scripts re-evalúa el entorno
    RAM_HIGH        = 180,    -- MB considerado presión alta (gcinfo retorna KB)
    RAM_CRITICAL    = 280,    -- MB considerado crítico
}

-- [ MÉTRICAS EN TIEMPO REAL ]
local metrics = {
    ramSamples      = {},     -- Historial de RAM para tendencia
    timeSamples     = {},     -- Historial de tiempo por script
    lastRam         = 0,
    lastDecompTime  = 0,
    crashRisk       = 0,      -- 0.0 - 1.0
    adaptLog        = {},     -- Log de ajustes realizados
}

-- [ ESTADO GLOBAL ]
local state = {
    running    = false,
    idx        = 1,
    targets    = {},
    buffer     = {},
    total      = 0,
    errorCount = 0,
    startTime  = 0,
    lastBreathe = 0,
}

-- [ WRITER SEGURO ]
local function safeWrite(data, overwrite)
    if overwrite and ENV.hasWritefile then
        local ok = pcall(writefile, CONFIG.FILE_NAME, data)
        if ok then return true end
    end
    if ENV.hasAppendfile then
        local ok = pcall(appendfile, CONFIG.FILE_NAME, data)
        return ok
    end
    return false
end

local function flushBuffer()
    if #state.buffer == 0 then return end
    safeWrite(table.concat(state.buffer), false)
    table.clear(state.buffer)
end

-- [ MUESTREO DE RAM ]
local function sampleRam()
    if not ENV.hasGcinfo then return 0 end
    local ok, val = pcall(gcinfo)
    if not ok then return metrics.lastRam end
    -- gcinfo retorna KB en la mayoría de executors
    local mb = val / 1024
    metrics.lastRam = mb
    table.insert(metrics.ramSamples, mb)
    if #metrics.ramSamples > 10 then
        table.remove(metrics.ramSamples, 1)
    end
    return mb
end

-- Tendencia: positivo = RAM subiendo, negativo = bajando
local function ramTrend()
    local s = metrics.ramSamples
    if #s < 3 then return 0 end
    return s[#s] - s[#s - 2]
end

-- [ MOTOR ADAPTATIVO ]
local function adapt(idx)
    local ram = sampleRam()
    local trend = ramTrend()

    -- Calcular crash risk (0.0 - 1.0)
    local risk = 0
    if ram > CONFIG.RAM_HIGH then
        risk = (ram - CONFIG.RAM_HIGH) / (CONFIG.RAM_CRITICAL - CONFIG.RAM_HIGH)
        risk = math.min(risk, 1.0)
    end
    if trend > 5 then risk = math.min(risk + 0.2, 1.0) end  -- RAM subiendo rápido
    metrics.crashRisk = risk

    -- [ AJUSTE DE BATCH_SIZE ]
    if risk > 0.7 then
        CONFIG.BATCH_SIZE = CONFIG.BATCH_MIN
    elseif risk > 0.4 then
        CONFIG.BATCH_SIZE = math.max(CONFIG.BATCH_MIN, math.floor(CONFIG.BATCH_SIZE * 0.7))
    elseif risk < 0.1 and trend < 1 then
        CONFIG.BATCH_SIZE = math.min(CONFIG.BATCH_MAX, CONFIG.BATCH_SIZE + 1)
    end

    -- [ AJUSTE DE BASE_DELAY ]
    if risk > 0.7 then
        CONFIG.BASE_DELAY = CONFIG.DELAY_MAX
    elseif risk > 0.4 then
        CONFIG.BASE_DELAY = math.min(CONFIG.DELAY_MAX,
            CONFIG.BASE_DELAY + 0.02)
    elseif risk < 0.1 then
        CONFIG.BASE_DELAY = math.max(CONFIG.DELAY_MIN,
            CONFIG.BASE_DELAY - 0.005)
    end

    -- [ AJUSTE DE BREATHE_EVERY ]
    if risk > 0.6 then
        CONFIG.BREATHE_EVERY = CONFIG.BREATHE_MIN
        CONFIG.BREATHE_WAIT  = 3.0
    elseif risk > 0.3 then
        CONFIG.BREATHE_EVERY = math.max(CONFIG.BREATHE_MIN,
            math.floor(CONFIG.BREATHE_EVERY * 0.8))
        CONFIG.BREATHE_WAIT  = 2.0
    elseif risk < 0.1 then
        CONFIG.BREATHE_EVERY = math.min(500,
            CONFIG.BREATHE_EVERY + 10)
        CONFIG.BREATHE_WAIT  = math.max(0.5, CONFIG.BREATHE_WAIT - 0.1)
    end

    -- Log del ajuste (solo si cambió algo notable)
    if risk > 0.4 then
        local msg = string.format(
            "[Adapt #%d] RAM:%.0fMB Risk:%.0f%% Batch:%d Delay:%.2f Breathe:%d",
            idx, ram, risk * 100,
            CONFIG.BATCH_SIZE, CONFIG.BASE_DELAY, CONFIG.BREATHE_EVERY
        )
        table.insert(metrics.adaptLog, msg)
        print(msg)
    end
end

-- [ RESPIRO ADAPTATIVO ]
local function breathe(idx)
    local shouldBreathe = (idx - state.lastBreathe) >= CONFIG.BREATHE_EVERY
    if not shouldBreathe then return end
    state.lastBreathe = idx
    flushBuffer()
    task.wait(CONFIG.BREATHE_WAIT)
end

-- ══════════════════════════════════════════
-- [ INTERFAZ ]
-- ══════════════════════════════════════════

local CoreGui = game:GetService("CoreGui")
local prev = CoreGui:FindFirstChild("OmniDumpUI")
if prev then prev:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name         = "OmniDumpUI"
sg.ResetOnSpawn = false
sg.Parent       = CoreGui

-- Frame principal
local frame = Instance.new("Frame", sg)
frame.Size             = UDim2.new(0, 180, 0, 100)
frame.Position         = UDim2.new(0.5, -90, 0.04, 0)
frame.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

-- Label título
local lblTitle = Instance.new("TextLabel", frame)
lblTitle.Size               = UDim2.new(1, 0, 0, 18)
lblTitle.Position           = UDim2.new(0, 0, 0, 5)
lblTitle.BackgroundTransparency = 1
lblTitle.Text               = "OMNI-DUMP v13"
lblTitle.TextColor3         = Color3.fromRGB(140, 140, 155)
lblTitle.Font               = Enum.Font.SourceSansBold
lblTitle.TextSize           = 11

-- Label estado (RAM / progreso)
local lblStatus = Instance.new("TextLabel", frame)
lblStatus.Size               = UDim2.new(1, -16, 0, 16)
lblStatus.Position           = UDim2.new(0, 8, 0, 24)
lblStatus.BackgroundTransparency = 1
lblStatus.Text               = "Listo"
lblStatus.TextColor3         = Color3.fromRGB(100, 200, 140)
lblStatus.Font               = Enum.Font.SourceSans
lblStatus.TextSize           = 11
lblStatus.TextXAlignment     = Enum.TextXAlignment.Left

-- Label riesgo
local lblRisk = Instance.new("TextLabel", frame)
lblRisk.Size               = UDim2.new(1, -16, 0, 14)
lblRisk.Position           = UDim2.new(0, 8, 0, 40)
lblRisk.BackgroundTransparency = 1
lblRisk.Text               = ""
lblRisk.TextColor3         = Color3.fromRGB(200, 140, 60)
lblRisk.Font               = Enum.Font.SourceSans
lblRisk.TextSize           = 10
lblRisk.TextXAlignment     = Enum.TextXAlignment.Left

-- Botón principal
local btn = Instance.new("TextButton", frame)
btn.Size               = UDim2.new(1, -16, 0, 36)
btn.Position           = UDim2.new(0, 8, 0, 57)
btn.BackgroundColor3   = Color3.fromRGB(210, 55, 55)
btn.Text               = "INICIAR DUMP"
btn.TextColor3         = Color3.new(1, 1, 1)
btn.Font               = Enum.Font.SourceSansBold
btn.TextSize           = 15
btn.BorderSizePixel    = 0
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

local function setBtn(text, r, g, b)
    btn.Text             = text
    btn.BackgroundColor3 = Color3.fromRGB(r, g, b)
end

local function setStatus(text, r, g, b)
    lblStatus.Text      = text
    lblStatus.TextColor3 = Color3.fromRGB(r or 100, g or 200, b or 140)
end

local function setRisk(risk, ram)
    if risk > 0.6 then
        lblRisk.Text       = string.format("⚠ RAM %.0fMB  RIESGO ALTO", ram)
        lblRisk.TextColor3 = Color3.fromRGB(220, 80, 80)
    elseif risk > 0.3 then
        lblRisk.Text       = string.format("~ RAM %.0fMB  moderado", ram)
        lblRisk.TextColor3 = Color3.fromRGB(220, 160, 60)
    else
        lblRisk.Text       = string.format("RAM %.0fMB  estable", ram)
        lblRisk.TextColor3 = Color3.fromRGB(80, 180, 120)
    end
end

-- ══════════════════════════════════════════
-- [ RECOPILACIÓN DE OBJETIVOS ]
-- ══════════════════════════════════════════

local function collectTargets()
    if #state.targets > 0 then return end
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("ModuleScript") then
            table.insert(state.targets, v)
        end
    end
    state.total = #state.targets
    local header = string.format(
        "-- OMNI-DUMP v13 ADAPTIVE | PlaceId: %d | Scripts: %d | tick: %d\n\n",
        game.PlaceId, state.total, math.floor(tick())
    )
    safeWrite(header, true)
    print(string.format("[OmniDump] %d scripts encontrados.", state.total))
end

-- ══════════════════════════════════════════
-- [ MOTOR PRINCIPAL ]
-- ══════════════════════════════════════════

local function StartProcess()
    state.running    = true
    state.startTime  = tick()
    state.errorCount = 0
    state.lastBreathe = state.idx

    collectTargets()

    if state.total == 0 then
        setBtn("SIN SCRIPTS", 100, 100, 100)
        setStatus("No se hallaron scripts.")
        state.running = false
        return
    end

    print("[OmniDump] Iniciando desde script #" .. state.idx)

    while state.running and state.idx <= state.total do
        local scr = state.targets[state.idx]

        -- Medir tiempo de descompilación
        local t0 = tick()
        local ok, source = pcall(ENV.decompiler, scr)
        metrics.lastDecompTime = tick() - t0

        -- Construir entrada
        local entry
        if ok and type(source) == "string" and #source > 0 then
            entry = "\n\n-- [OK] " .. scr:GetFullName() .. "\n" .. source
        else
            state.errorCount += 1
            local reason = (type(source) == "string" and source) or "desconocido"
            entry = "\n\n-- [ERR] " .. scr:GetFullName() .. " | " .. reason
        end
        source = nil  -- Libera referencia grande inmediatamente

        table.insert(state.buffer, entry)
        entry = nil

        -- Flush adaptativo
        local isFinal = state.idx == state.total
        if #state.buffer >= CONFIG.BATCH_SIZE or isFinal then
            flushBuffer()
        end

        -- Actualizar UI cada UPDATE_EVERY scripts
        if state.idx % 10 == 0 or isFinal then
            local pct = math.floor((state.idx / state.total) * 100)
            setBtn("STOP  " .. pct .. "%", 200, 50, 50)
            setStatus(state.idx .. "/" .. state.total .. "  batch:" .. CONFIG.BATCH_SIZE)
            setRisk(metrics.crashRisk, metrics.lastRam)
        end

        -- Re-evaluar entorno cada SAMPLE_EVERY scripts
        if state.idx % CONFIG.SAMPLE_EVERY == 0 then
            adapt(state.idx)
        end

        -- Respiro adaptativo
        breathe(state.idx)

        state.idx += 1
        task.wait(CONFIG.BASE_DELAY)
    end

    -- Resultado final
    if state.idx > state.total then
        local elapsed = math.floor(tick() - state.startTime)
        local summary = string.format(
            "[OmniDump] Completado: %d scripts en %ds. Errores: %d.",
            state.total, elapsed, state.errorCount
        )
        print(summary)

        -- Log de adaptaciones al archivo
        if #metrics.adaptLog > 0 then
            local logHeader = "\n\n-- === LOG ADAPTATIVO ===\n"
            safeWrite(logHeader .. table.concat(metrics.adaptLog, "\n"), false)
        end

        setBtn("COMPLETADO", 40, 180, 80)
        setStatus("Listo en " .. elapsed .. "s  Errores:" .. state.errorCount, 40, 180, 80)
        lblRisk.Text = ""
        state.running = false
    end
end

-- ══════════════════════════════════════════
-- [ PURGA ]
-- ══════════════════════════════════════════

local function PurgeSystem()
    setBtn("LIMPIANDO...", 255, 140, 0)
    setStatus("Purgando...", 255, 140, 0)
    flushBuffer()
    table.clear(state.buffer)
    table.clear(metrics.ramSamples)
    table.clear(metrics.timeSamples)
    task.wait(0.3)
    setStatus("Memoria liberada.", 100, 200, 140)
    print("[OmniDump] Purga completa.")
end

-- ══════════════════════════════════════════
-- [ BOTÓN ]
-- ══════════════════════════════════════════

btn.MouseButton1Click:Connect(function()
    if state.running then
        state.running = false
        task.spawn(function()
            PurgeSystem()
            setBtn("REANUDAR", 50, 140, 50)
            setStatus("Pausado en #" .. state.idx, 160, 160, 80)
        end)
    else
        task.spawn(StartProcess)
    end
end)

print("[OmniDump] Listo. Usa el botón para iniciar.")
