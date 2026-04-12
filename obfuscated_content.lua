--[[
    OMNI-DUMP V14 - ZERO-LEAK EDITION
    Fix crítico: libera referencias de targets después de usarlas.
    Procesa en chunks para nunca tener 19k objetos en RAM.
]]

-- [ DETECCIÓN DE ENTORNO ]
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

-- [ CONFIG ADAPTATIVA ]
local CONFIG = {
    FILE_NAME      = "DUMP_" .. game.PlaceId .. ".txt",
    CHUNK_SIZE     = 200,   -- Cuántos scripts carga en RAM a la vez
    BATCH_SIZE     = 5,     -- Scripts por flush (se adapta)
    BATCH_MIN      = 2,
    BATCH_MAX      = 15,
    BASE_DELAY     = 0.05,
    DELAY_MIN      = 0.02,
    DELAY_MAX      = 0.25,
    BREATHE_EVERY  = 100,
    BREATHE_MIN    = 50,
    BREATHE_WAIT   = 1.5,
    SAMPLE_EVERY   = 25,
    RAM_HIGH       = 150,
    RAM_CRITICAL   = 250,
}

-- [ MÉTRICAS ]
local metrics = {
    ramSamples = {},
    lastRam    = 0,
    crashRisk  = 0,
}

-- [ ESTADO ]
local state = {
    running      = false,
    globalIdx    = 1,    -- Índice global (1 a total)
    total        = 0,
    allPaths     = {},   -- Solo rutas (strings), NO objetos Instance
    buffer       = {},
    errorCount   = 0,
    startTime    = 0,
    lastBreathe  = 0,
}

-- ══════════════════════════════════
-- [ WRITER ]
-- ══════════════════════════════════

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

-- ══════════════════════════════════
-- [ RAM Y ADAPTACIÓN ]
-- ══════════════════════════════════

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
        risk = (ram - CONFIG.RAM_HIGH) / (CONFIG.RAM_CRITICAL - CONFIG.RAM_HIGH)
        risk = math.min(risk, 1.0)
    end
    if trend > 4 then risk = math.min(risk + 0.25, 1.0) end
    metrics.crashRisk = risk

    -- Batch
    if risk > 0.6 then
        CONFIG.BATCH_SIZE = CONFIG.BATCH_MIN
    elseif risk > 0.3 then
        CONFIG.BATCH_SIZE = math.max(CONFIG.BATCH_MIN, CONFIG.BATCH_SIZE - 1)
    elseif risk < 0.1 then
        CONFIG.BATCH_SIZE = math.min(CONFIG.BATCH_MAX, CONFIG.BATCH_SIZE + 1)
    end

    -- Delay
    if risk > 0.6 then
        CONFIG.BASE_DELAY = CONFIG.DELAY_MAX
    elseif risk > 0.3 then
        CONFIG.BASE_DELAY = math.min(CONFIG.DELAY_MAX, CONFIG.BASE_DELAY + 0.015)
    elseif risk < 0.1 then
        CONFIG.BASE_DELAY = math.max(CONFIG.DELAY_MIN, CONFIG.BASE_DELAY - 0.005)
    end

    -- Breathe
    if risk > 0.6 then
        CONFIG.BREATHE_EVERY = CONFIG.BREATHE_MIN
        CONFIG.BREATHE_WAIT  = 3.5
    elseif risk > 0.3 then
        CONFIG.BREATHE_EVERY = math.max(CONFIG.BREATHE_MIN, CONFIG.BREATHE_EVERY - 20)
        CONFIG.BREATHE_WAIT  = 2.0
    elseif risk < 0.1 then
        CONFIG.BREATHE_EVERY = math.min(200, CONFIG.BREATHE_EVERY + 5)
        CONFIG.BREATHE_WAIT  = math.max(0.8, CONFIG.BREATHE_WAIT - 0.1)
    end

    -- Chunk size
    if risk > 0.6 then
        CONFIG.CHUNK_SIZE = 50
    elseif risk > 0.3 then
        CONFIG.CHUNK_SIZE = 100
    else
        CONFIG.CHUNK_SIZE = 200
    end
end

-- ══════════════════════════════════
-- [ UI ]
-- ══════════════════════════════════

local CoreGui = game:GetService("CoreGui")
local prev = CoreGui:FindFirstChild("OmniDumpUI")
if prev then prev:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name         = "OmniDumpUI"
sg.ResetOnSpawn = false
sg.Parent       = CoreGui

local frame = Instance.new("Frame", sg)
frame.Size             = UDim2.new(0, 185, 0, 105)
frame.Position         = UDim2.new(0.5, -92, 0.04, 0)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local function mkLabel(parent, pos, size, txt, color, fontSize, align)
    local l = Instance.new("TextLabel", parent)
    l.Size               = size
    l.Position           = pos
    l.BackgroundTransparency = 1
    l.Text               = txt
    l.TextColor3         = color
    l.Font               = Enum.Font.SourceSans
    l.TextSize           = fontSize or 11
    l.TextXAlignment     = align or Enum.TextXAlignment.Center
    return l
end

mkLabel(frame,
    UDim2.new(0,0,0,4), UDim2.new(1,0,0,16),
    "OMNI-DUMP v14  ZERO-LEAK",
    Color3.fromRGB(120,120,135), 11)

local lblProgress = mkLabel(frame,
    UDim2.new(0,8,0,22), UDim2.new(1,-16,0,15),
    "Listo", Color3.fromRGB(90,190,130), 11,
    Enum.TextXAlignment.Left)

local lblRam = mkLabel(frame,
    UDim2.new(0,8,0,38), UDim2.new(1,-16,0,14),
    "", Color3.fromRGB(160,160,80), 10,
    Enum.TextXAlignment.Left)

local lblAdapt = mkLabel(frame,
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

local function updateUI(idx, total, risk, ram)
    local pct = math.floor((idx / total) * 100)
    lblProgress.Text = string.format("%d/%d  (%d%%)", idx, total, pct)

    if risk > 0.6 then
        lblRam.Text      = string.format("RAM %.0f MB  ⚠ CRITICO", ram)
        lblRam.TextColor3 = Color3.fromRGB(220, 70, 70)
    elseif risk > 0.3 then
        lblRam.Text      = string.format("RAM %.0f MB  ~ moderado", ram)
        lblRam.TextColor3 = Color3.fromRGB(220, 160, 60)
    else
        lblRam.Text      = string.format("RAM %.0f MB  estable", ram)
        lblRam.TextColor3 = Color3.fromRGB(80, 190, 120)
    end

    lblAdapt.Text = string.format(
        "batch:%d  delay:%.2f  breathe:%d",
        CONFIG.BATCH_SIZE, CONFIG.BASE_DELAY, CONFIG.BREATHE_EVERY)
end

-- ══════════════════════════════════════════════════
-- [ CARGA DE PATHS (solo strings, NO Instances) ]
-- Guarda solo el path string de cada script.
-- Los objetos Instance se resuelven al momento de usar.
-- ══════════════════════════════════════════════════

local function buildPathIndex()
    if #state.allPaths > 0 then return end
    local count = 0
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("ModuleScript") then
            table.insert(state.allPaths, v:GetFullName())
            count += 1
        end
    end
    state.total = count
    local header = string.format(
        "-- OMNI-DUMP v14 | PlaceId: %d | Scripts: %d | tick: %d\n\n",
        game.PlaceId, count, math.floor(tick())
    )
    safeWrite(header, true)
    print(string.format("[OmniDump] %d scripts indexados (solo paths).", count))
end

-- Resuelve un path de vuelta a su Instance en tiempo real
local function resolvePath(fullName)
    local parts = string.split(fullName, ".")
    local obj = game
    for i = 2, #parts do  -- saltar "game"
        local ok, child = pcall(function()
            return obj:FindFirstChild(parts[i])
        end)
        if not ok or not child then return nil end
        obj = child
    end
    return obj
end

-- ══════════════════════════════════════════════════
-- [ CARGA DE CHUNK: N objetos a la vez ]
-- ══════════════════════════════════════════════════

local function loadChunk(fromIdx, toIdx)
    local chunk = {}
    for i = fromIdx, toIdx do
        if state.allPaths[i] then
            local obj = resolvePath(state.allPaths[i])
            chunk[i] = obj  -- puede ser nil si fue destruido
        end
    end
    return chunk
end

-- ══════════════════════════════════════════════════
-- [ MOTOR PRINCIPAL ]
-- ══════════════════════════════════════════════════

local function StartProcess()
    state.running     = true
    state.startTime   = tick()
    state.errorCount  = 0
    state.lastBreathe = state.globalIdx

    buildPathIndex()

    if state.total == 0 then
        setBtn("SIN SCRIPTS", 100, 100, 100)
        lblProgress.Text = "No se hallaron scripts."
        state.running = false
        return
    end

    print("[OmniDump] Iniciando desde #" .. state.globalIdx)

    while state.running and state.globalIdx <= state.total do

        -- Cargar chunk actual
        local chunkEnd = math.min(
            state.globalIdx + CONFIG.CHUNK_SIZE - 1,
            state.total
        )
        local chunk = loadChunk(state.globalIdx, chunkEnd)

        -- Procesar chunk
        for i = state.globalIdx, chunkEnd do
            if not state.running then break end

            local scr = chunk[i]
            chunk[i]  = nil  -- ← libera referencia inmediatamente tras tomar

            local entry
            if scr then
                local ok, source = pcall(ENV.decompiler, scr)
                scr = nil  -- ← libera referencia al objeto Roblox

                if ok and type(source) == "string" and #source > 0 then
                    entry = "\n\n-- [OK] " .. state.allPaths[i] .. "\n" .. source
                else
                    state.errorCount += 1
                    local reason = (type(source) == "string" and source) or "error"
                    entry = "\n\n-- [ERR] " .. state.allPaths[i] .. " | " .. reason
                end
                source = nil  -- ← libera el string grande
            else
                -- Script destruido/no encontrado
                entry = "\n\n-- [GONE] " .. (state.allPaths[i] or "?")
            end

            table.insert(state.buffer, entry)
            entry = nil

            -- Flush por batch
            local isFinal = i == state.total
            if #state.buffer >= CONFIG.BATCH_SIZE or isFinal then
                flushBuffer()
            end

            -- Adaptación periódica
            if i % CONFIG.SAMPLE_EVERY == 0 then
                adapt()
                updateUI(i, state.total, metrics.crashRisk, metrics.lastRam)
                setBtn("STOP " .. math.floor((i/state.total)*100) .. "%", 190, 45, 45)
            end

            -- Respiro adaptativo
            if (i - state.lastBreathe) >= CONFIG.BREATHE_EVERY then
                state.lastBreathe = i
                flushBuffer()
                setBtn("RESPIRANDO...", 70, 70, 170)
                task.wait(CONFIG.BREATHE_WAIT)
                setBtn("STOP " .. math.floor((i/state.total)*100) .. "%", 190, 45, 45)
            end

            state.globalIdx = i + 1
            task.wait(CONFIG.BASE_DELAY)
        end

        -- Libera el chunk completo de RAM antes del siguiente
        chunk = nil
        flushBuffer()
        task.wait(0.1)  -- micro-pausa entre chunks
    end

    -- Final
    if state.globalIdx > state.total then
        local elapsed = math.floor(tick() - state.startTime)
        print(string.format(
            "[OmniDump] Completado: %d scripts en %ds. Errores: %d.",
            state.total, elapsed, state.errorCount
        ))
        setBtn("COMPLETADO", 35, 175, 75)
        lblProgress.Text = string.format(
            "Listo: %d scripts en %ds", state.total, elapsed)
        lblRam.Text  = "Errores: " .. state.errorCount
        lblAdapt.Text = ""
        state.running = false
    end
end

-- ══════════════════════════════════
-- [ PURGA ]
-- ══════════════════════════════════

local function PurgeSystem()
    setBtn("LIMPIANDO...", 240, 130, 0)
    lblProgress.Text = "Purgando..."
    flushBuffer()
    table.clear(state.buffer)
    table.clear(metrics.ramSamples)
    task.wait(0.3)
    lblProgress.Text = "Pausado en #" .. state.globalIdx
    print("[OmniDump] Purga completa.")
end

-- ══════════════════════════════════
-- [ BOTÓN ]
-- ══════════════════════════════════

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
