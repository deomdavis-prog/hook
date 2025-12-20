-- AntiTarget Unified - OPTIMIZADO v2.0
-- LocalScript (Luau)
-- Colocar en: StarterPlayerScripts
-- Propósito: detección, mitigación y recuperación client-side avanzadas contra exploits dirigidos al jugador.
-- Diseño: rendimiento, robustez y mínima latencia; API pública para integración.

-- =========================
-- IMPORTS / SERVICIOS
-- =========================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

-- =========================
-- REFERENCIAS PRINCIPALES
-- =========================
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- =========================
-- CONFIGURACIÓN (TUNING)
-- =========================
local CONFIG = {
    -- Detección (umbrales base y ventanas)
    HEALTH_SPIKE_BASE = 25,
    DAMAGE_SPIKE_WINDOW = 0.18,
    INSTANT_KILL_THRESHOLD = 0.85,
    INSTANT_KILL_TIME = 0.12,
    SUSTAINED_WINDOW = 1.2,

    -- Sistema de scoring de amenazas
    THREAT_SCORE_THRESHOLD = 75,
    THREAT_DECAY_RATE = 10, -- puntos por segundo

    -- Snapshots y recuperación
    SAFE_STATE_INTERVAL = 2.5,
    RECOVERY_BEHAVIOR = "RESPAWN", -- "RESPAWN" | "RESTORE" | "HYBRID"
    HYBRID_THRESHOLD = 0.3, -- ratio salud para RESTORE

    -- Reportes y logs
    REPORT_REMOTE_PATH = "ReplicatedStorage:AntiTargetReports",
    ALERT_UI = true,
    BATCH_REPORT_INTERVAL = 5.0,
    MAX_EVIDENCE_LOG = 50,
    COMPRESS_OLD_EVIDENCE = true,

    -- Mitigación de cámara
    CAMERA_JITTER = true,
    CAMERA_JITTER_MAG = 0.025,
    CAMERA_JITTER_FREQ = 0.04,
    CAMERA_SWAY = true,
    CAMERA_SWAY_MAG = 0.015,

    -- Detección avanzada de movimiento
    VELOCITY_ANOMALY_DETECTION = true,
    VELOCITY_SPIKE_THRESHOLD = 150, -- studs/s
    POSITION_TELEPORT_THRESHOLD = 100, -- studs
    HEADSHOT_PATTERN_DETECTION = true,

    -- Performance y optimizaciones
    UPDATE_RATE_LIMIT = 0.016, -- ~60 FPS
    USE_OBJECT_POOLING = true,
    CACHE_CALCULATIONS = true,

    -- Anti-tamper
    INTEGRITY_CHECK = true,
    INTEGRITY_CHECK_INTERVAL = 30,

    -- Auto-tuning
    AUTO_TUNE_THRESHOLDS = true,
    LEARNING_RATE = 0.05,
}

-- =========================
-- ESTADO GLOBAL
-- =========================
local State = {
    -- Economía de salud/posición
    lastHealth = humanoid.Health,
    lastHealthTime = tick(),
    lastPosition = rootPart.Position,
    lastVelocity = Vector3.zero,

    -- Scoring y contadores
    threatScore = 0,
    consecutiveSuspiciousEvents = 0,

    -- Historial y buffers
    damageHistory = {},
    velocityHistory = {},

    -- Safe states (buffer circular)
    safeStates = {},
    currentSafeStateIndex = 1,

    -- Evidencia / telemetría
    evidenceLog = {},
    evidenceCount = 0,
    stats = {
        totalDamageEvents = 0,
        suspiciousEvents = 0,
        falsePositiveEstimate = 0,
        recoveryAttempts = 0,
        avgDamagePerEvent = 0,
    },

    -- Flags y control
    isRecovering = false,
    lastRecoveryTime = 0,
    jitterEnabled = true,

    -- Whitelist de fuentes legítimas
    legitimateSources = {},

    -- Cache / optimización
    cachedThreshold = CONFIG.HEALTH_SPIKE_BASE,
    cachedThresholdTime = 0,

    -- Noise state para jitter
    noiseOffset = math.random() * 1000,
}

-- =========================
-- UTILIDADES / HELPERS
-- =========================
-- Perlin-like noise (simplificado) para jitter suave
local function perlinNoise(x, y)
    local n = x + y * 57
    n = bit32.bxor(n, bit32.lshift(n, 13))
    return (1.0 - bit32.band(n * (n * n * 15731 + 789221) + 1376312589, 0x7fffffff) / 1073741824.0)
end

local function smoothNoise(x)
    local t = x % 1
    local i = math.floor(x)
    local a = perlinNoise(i, 0)
    local b = perlinNoise(i + 1, 0)
    return a * (1 - t) + b * t
end

-- Object pooling simple para eventos de daño
local damageEventPool = {}
local function getDamageEvent()
    return table.remove(damageEventPool) or {}
end
local function recycleDamageEvent(evt)
    if CONFIG.USE_OBJECT_POOLING and #damageEventPool < 100 then
        table.insert(damageEventPool, evt)
    end
end

-- Notificaciones con cooldown para evitar spam UI
local lastNotifyTime = 0
local function notify(text, duration)
    if not CONFIG.ALERT_UI then return end
    local now = tick()
    if now - lastNotifyTime < 1.0 then return end
    lastNotifyTime = now
    task.spawn(function()
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "AntiTarget",
                Text = text,
                Duration = duration or 3,
                Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png"
            })
        end)
    end)
end

-- Memoización del RemoteEvent de reportes
local reportRemoteCache
local function getReportRemote()
    if reportRemoteCache then return reportRemoteCache end
    local path = CONFIG.REPORT_REMOTE_PATH
    if not path or path == "" then return nil end
    local serviceName, objName = path:match("^([^:]+):(.+)$")
    if serviceName and objName then
        local success, svc = pcall(game.GetService, game, serviceName)
        if success and svc then
            reportRemoteCache = svc:FindFirstChild(objName)
            return reportRemoteCache
        end
    end
    return nil
end

-- =========================
-- SISTEMA DE AMENAZAS (scoring)
-- =========================
local function addThreatScore(amount, reason)
    State.threatScore = math.min(100, State.threatScore + amount)
    if State.threatScore >= CONFIG.THREAT_SCORE_THRESHOLD then
        logEvidence("high_threat", { score = State.threatScore, reason = reason, consecutive = State.consecutiveSuspiciousEvents })
        return true
    end
    return false
end

local function decayThreatScore(dt)
    State.threatScore = math.max(0, State.threatScore - CONFIG.THREAT_DECAY_RATE * dt)
    if State.threatScore < 30 then
        State.consecutiveSuspiciousEvents = 0
    end
end

-- =========================
-- EVIDENCIA Y REPORTING
-- =========================
function logEvidence(kind, details)
    local evt = { t = tick(), k = kind, d = details }
    table.insert(State.evidenceLog, evt)
    State.evidenceCount += 1

    -- Comprimir logs antiguos si es necesario
    if CONFIG.COMPRESS_OLD_EVIDENCE and #State.evidenceLog > CONFIG.MAX_EVIDENCE_LOG then
        local compressed = {}
        for i = 1, 10 do
            if State.evidenceLog[i] then table.insert(compressed, State.evidenceLog[i]) end
        end
        for i = math.max(11, #State.evidenceLog - 39), #State.evidenceLog do
            table.insert(compressed, State.evidenceLog[i])
        end
        State.evidenceLog = compressed
    end

    -- Actualizar UI si está expuesta
    task.spawn(function()
        if _G.AntiTargetUI and _G.AntiTargetUI.updateEvidence then
            pcall(_G.AntiTargetUI.updateEvidence, State.evidenceLog)
        end
    end)
end

local pendingReports = {}
local function queueReport(data)
    table.insert(pendingReports, data)
end

local function flushReports()
    if #pendingReports == 0 then return end
    local remote = getReportRemote()
    if not remote then pendingReports = {} return end

    local batch = {
        player = player.UserId,
        time = os.time(),
        count = #pendingReports,
        evidence = State.evidenceLog,
        stats = State.stats,
        uuid = HttpService:GenerateGUID(false),
        reports = pendingReports,
    }

    task.spawn(function()
        pcall(function() remote:FireServer(batch) end)
    end)

    pendingReports = {}
end

-- =========================
-- SAFE STATES (snapshots circulares)
-- =========================
local function captureSafeState()
    if not rootPart or not humanoid then return end
    if humanoid.Health <= 0 then return end

    local state = {
        time = tick(),
        cframe = rootPart.CFrame,
        health = humanoid.Health,
        velocity = rootPart.AssemblyLinearVelocity or Vector3.zero,
        threat = State.threatScore,
    }

    State.safeStates[State.currentSafeStateIndex] = state
    State.currentSafeStateIndex = (State.currentSafeStateIndex % 5) + 1
end

local function getBestSafeState()
    local best, bestScore = nil, -math.huge
    for _, s in ipairs(State.safeStates) do
        if s then
            local age = tick() - s.time
            local score = s.health - age * 5 - s.threat
            if score > bestScore then bestScore = score; best = s end
        end
    end
    return best
end

-- =========================
-- UMBRALES ADAPTATIVOS (cache + auto-tune)
-- =========================
local function getDynamicThreshold()
    local now = tick()
    if CONFIG.CACHE_CALCULATIONS and now - State.cachedThresholdTime < 0.5 then
        return State.cachedThreshold
    end

    local health = humanoid.Health
    local maxHealth = humanoid.MaxHealth
    local healthRatio = (maxHealth > 0) and (health / maxHealth) or 1
    local base = CONFIG.HEALTH_SPIKE_BASE
    local threshold

    if healthRatio > 0.7 then
        threshold = base * 1.6
    elseif healthRatio > 0.4 then
        threshold = base * 1.2
    else
        threshold = base * 0.7
    end

    if CONFIG.AUTO_TUNE_THRESHOLDS and State.stats.totalDamageEvents > 20 then
        local suspiciousRatio = State.stats.suspiciousEvents / math.max(1, State.stats.totalDamageEvents)
        if suspiciousRatio > 0.3 then
            threshold = threshold * (1 + CONFIG.LEARNING_RATE)
        elseif suspiciousRatio < 0.05 then
            threshold = threshold * (1 - CONFIG.LEARNING_RATE)
        end
    end

    State.cachedThreshold = threshold
    State.cachedThresholdTime = now
    return threshold
end

-- =========================
-- ANÁLISIS DE PATRONES DE DAÑO
-- =========================
local function analyzeDamagePattern()
    local now = tick()
    local recentDamage, damageCount = 0, 0
    local intervals = {}

    for i = #State.damageHistory, 1, -1 do
        local evt = State.damageHistory[i]
        if now - evt.time > CONFIG.SUSTAINED_WINDOW then break end
        recentDamage = recentDamage + evt.delta
        damageCount = damageCount + 1
        if i > 1 then table.insert(intervals, evt.time - State.damageHistory[i-1].time) end
    end

    local avgInterval = 0
    if #intervals > 0 then
        local sum = 0 for _, v in ipairs(intervals) do sum = sum + v end
        avgInterval = sum / #intervals
    end

    local isMachineGun = damageCount >= 3 and avgInterval < 0.15 and avgInterval > 0.001
    local isBurst = recentDamage > getDynamicThreshold() * 1.5 and damageCount >= 2

    return {
        total = recentDamage,
        count = damageCount,
        avgInterval = avgInterval,
        isMachineGun = isMachineGun,
        isBurst = isBurst,
        isSuspicious = recentDamage > getDynamicThreshold()
    }
end

-- =========================
-- DETECCIÓN MOVIMIENTO/TELEPORT
-- =========================
local function checkVelocityAnomaly(dt)
    if not CONFIG.VELOCITY_ANOMALY_DETECTION or not rootPart then return false end
    local currentVel = rootPart.AssemblyLinearVelocity or Vector3.zero
    local velChange = (currentVel - State.lastVelocity).Magnitude

    if velChange / math.max(0.0001, dt) > CONFIG.VELOCITY_SPIKE_THRESHOLD then
        logEvidence("velocity_spike", { change = velChange, dt = dt, from = State.lastVelocity, to = currentVel })
        addThreatScore(15, "velocity_anomaly")
        State.lastVelocity = currentVel
        return true
    end

    State.lastVelocity = currentVel
    return false
end

local function checkPositionTeleport()
    if not rootPart then return false end
    local currentPos = rootPart.Position
    local displacement = (currentPos - State.lastPosition).Magnitude

    if displacement > CONFIG.POSITION_TELEPORT_THRESHOLD then
        logEvidence("position_teleport", { displacement = displacement, from = State.lastPosition, to = currentPos })
        addThreatScore(25, "position_anomaly")
        State.lastPosition = currentPos
        return true
    end

    State.lastPosition = currentPos
    return false
end

-- =========================
-- WHITELIST / LEGITIMIDAD DE FUENTES
-- =========================
local function registerLegitimateSources()
    task.spawn(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj ~= character then
                if obj:HasTag("Enemy") or obj:HasTag("NPC") or obj:HasTag("Monster") then
                    State.legitimateSources[obj] = true
                end
            end
        end
    end)
end

local function isLegitimateSource(source)
    if not source then return false end
    if State.legitimateSources[source] then return true end
    if typeof(source) == "Instance" and source:IsA("Model") and source:FindFirstChild("Humanoid") then
        if source:HasTag("Enemy") or source:HasTag("NPC") then
            State.legitimateSources[source] = true
            return true
        end
    end
    if typeof(source) == "Instance" and (source:HasTag("Hazard") or source:HasTag("Trap")) then return true end
    return false
end

-- =========================
-- RECUPERACIÓN (HYBRID / RESPAWN / RESTORE)
-- =========================
local function attemptRecovery(reason, severity)
    if State.isRecovering then return end
    if tick() - State.lastRecoveryTime < 3.0 then return end

    State.isRecovering = true
    State.lastRecoveryTime = tick()
    State.stats.recoveryAttempts = State.stats.recoveryAttempts + 1

    logEvidence("recovery_attempt", { reason = reason, severity = severity, threat = State.threatScore })
    queueReport({ type = "recovery", reason = reason, severity = severity })

    task.spawn(function()
        notify("⚠️ Comportamiento anómalo detectado - Recuperando...", 4)
        task.wait(0.1)

        local behavior = CONFIG.RECOVERY_BEHAVIOR
        if behavior == "HYBRID" then
            local healthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth)
            behavior = healthRatio < CONFIG.HYBRID_THRESHOLD and "RESPAWN" or "RESTORE"
        end

        if behavior == "RESPAWN" then
            pcall(function() player:LoadCharacter() end)
        else
            local safeState = getBestSafeState()
            if safeState and rootPart and character then
                pcall(function()
                    rootPart.CFrame = safeState.cframe
                    rootPart.AssemblyLinearVelocity = Vector3.zero
                    if humanoid and humanoid.Health < safeState.health then
                        humanoid.Health = math.min(safeState.health, humanoid.MaxHealth)
                    end
                end)
            end
        end

        task.wait(1)
        State.isRecovering = false
    end)
end

-- =========================
-- DETECCIÓN DE SALUD PRINCIPAL
-- =========================
local function onHealthChanged(newHealth)
    local now = tick()
    local delta = State.lastHealth - newHealth
    local elapsed = now - State.lastHealthTime

    -- Ignorar curaciones y micro-deltas
    if delta <= 0 or delta < 0.1 then
        State.lastHealth = newHealth
        State.lastHealthTime = now
        return
    end

    -- Estadísticas y pooling
    State.stats.totalDamageEvents = State.stats.totalDamageEvents + 1
    State.stats.avgDamagePerEvent = (State.stats.avgDamagePerEvent * (State.stats.totalDamageEvents - 1) + delta) / State.stats.totalDamageEvents

    local evt = getDamageEvent()
    evt.time = now; evt.delta = delta; evt.elapsed = elapsed; evt.healthBefore = State.lastHealth; evt.healthAfter = newHealth
    table.insert(State.damageHistory, evt)

    -- Limpiar historial antiguo
    while #State.damageHistory > 0 and State.damageHistory[1].time < now - (CONFIG.SUSTAINED_WINDOW * 2) do
        local old = table.remove(State.damageHistory, 1)
        recycleDamageEvent(old)
    end

    -- Detección: daño súbito (spike)
    local threshold = getDynamicThreshold()
    if delta >= threshold and elapsed <= CONFIG.DAMAGE_SPIKE_WINDOW then
        State.consecutiveSuspiciousEvents = State.consecutiveSuspiciousEvents + 1
        State.stats.suspiciousEvents = State.stats.suspiciousEvents + 1
        logEvidence("damage_spike", { delta = delta, elapsed = elapsed, threshold = threshold, healthBefore = State.lastHealth, healthAfter = newHealth })
        if addThreatScore(30, "damage_spike") then attemptRecovery("damage_spike", "high") end
    end

    -- Detección: instant kill
    if State.lastHealth > 0 and newHealth <= 0 then
        local killRatio = State.lastHealth / math.max(1, humanoid.MaxHealth)
        if elapsed <= CONFIG.INSTANT_KILL_TIME and killRatio >= CONFIG.INSTANT_KILL_THRESHOLD then
            State.stats.suspiciousEvents = State.stats.suspiciousEvents + 1
            logEvidence("instant_kill", { from = State.lastHealth, to = newHealth, elapsed = elapsed, ratio = killRatio })
            addThreatScore(50, "instant_kill")
            attemptRecovery("instant_kill", "critical")
        end
    end

    -- Análisis de patrones (machine-gun / burst / sustained)
    local pattern = analyzeDamagePattern()
    if pattern.isSuspicious then
        if pattern.isMachineGun then logEvidence("machine_gun_pattern", pattern); addThreatScore(20, "machine_gun") end
        if pattern.isBurst then logEvidence("burst_damage", pattern); if addThreatScore(25, "burst_damage") then attemptRecovery("burst_damage", "high") end end
    end

    State.lastHealth = newHealth
    State.lastHealthTime = now
end

-- =========================
-- EFECTOS DE CÁMARA (JITTER + SWAY)
-- =========================
local jitterTime, swayTime = 0, 0
local function applyCameraEffects(dt)
    if not State.jitterEnabled or not CONFIG.CAMERA_JITTER then return end
    if not rootPart or not character then return end
    if State.threatScore < 20 then return end

    local cam = workspace.CurrentCamera
    if not cam or cam.CameraType ~= Enum.CameraType.Custom then return end

    jitterTime = jitterTime + dt
    swayTime = swayTime + dt * 0.6

    local jitterX = smoothNoise((jitterTime + State.noiseOffset) * 15) * CONFIG.CAMERA_JITTER_MAG
    local jitterY = smoothNoise((jitterTime + State.noiseOffset + 100) * 15) * CONFIG.CAMERA_JITTER_MAG

    local swayX, swayY = 0, 0
    if CONFIG.CAMERA_SWAY then
        swayX = math.sin(swayTime * 2.1) * CONFIG.CAMERA_SWAY_MAG
        swayY = math.cos(swayTime * 1.7) * CONFIG.CAMERA_SWAY_MAG
    end

    local intensity = math.min(1, State.threatScore / 100)
    local offsetX = (jitterX + swayX) * intensity
    local offsetY = (jitterY + swayY) * intensity

    pcall(function()
        local cf = cam.CFrame
        local offset = CFrame.new(offsetX, offsetY, 0)
        cam.CFrame = cf * offset
    end)
end

-- =========================
-- ANTI-TAMPER / INTEGRIDAD
-- =========================
local lastIntegrityCheck = tick()
local function checkIntegrity()
    if not CONFIG.INTEGRITY_CHECK then return true end
    local now = tick()
    if now - lastIntegrityCheck < CONFIG.INTEGRITY_CHECK_INTERVAL then return true end
    lastIntegrityCheck = now

    if not player or not player.Parent then return false end
    if not character or not character.Parent then return false end
    if not humanoid or not humanoid.Parent then return false end
    if not rootPart or not rootPart.Parent then return false end

    if not script or not script.Parent then logEvidence("tamper_detected", { reason = "script_removed" }); return false end
    return true
end

-- =========================
-- BUCLE PRINCIPAL OPTIMIZADO
-- =========================
local lastUpdateTime = 0
local batchTimer, safeStateTimer = 0, 0
RunService.Heartbeat:Connect(function(dt)
    local now = tick()
    if now - lastUpdateTime < CONFIG.UPDATE_RATE_LIMIT then return end
    lastUpdateTime = now

    if not checkIntegrity() then attemptRecovery("tamper_detected", "critical") return end

    decayThreatScore(dt)

    safeStateTimer = safeStateTimer + dt
    if safeStateTimer >= CONFIG.SAFE_STATE_INTERVAL then safeStateTimer = 0; captureSafeState() end

    batchTimer = batchTimer + dt
    if batchTimer >= CONFIG.BATCH_REPORT_INTERVAL then batchTimer = 0; task.spawn(flushReports) end

    if checkVelocityAnomaly(dt) then State.consecutiveSuspiciousEvents = State.consecutiveSuspiciousEvents + 1 end
    if checkPositionTeleport() then State.consecutiveSuspiciousEvents = State.consecutiveSuspiciousEvents + 1 end

    applyCameraEffects(dt)

    if State.threatScore >= 90 and not State.isRecovering then attemptRecovery("critical_threat_level", "critical") end
end)

-- =========================
-- INICIALIZACIÓN
-- =========================
local function initialize()
    registerLegitimateSources()
    captureSafeState()

    humanoid.HealthChanged:Connect(onHealthChanged)

    player.CharacterAdded:Connect(function(char)
        character = char
        humanoid = character:WaitForChild("Humanoid")
        rootPart = character:WaitForChild("HumanoidRootPart")

        State.lastHealth = humanoid.Health
        State.lastHealthTime = tick()
        State.lastPosition = rootPart.Position
        State.lastVelocity = Vector3.zero
        State.threatScore = 0
        State.consecutiveSuspiciousEvents = 0
        State.isRecovering = false
        State.safeStates = {}
        State.currentSafeStateIndex = 1

        captureSafeState()
        humanoid.HealthChanged:Connect(onHealthChanged)
    end)

    notify("✅ AntiTarget activo - Protección optimizada cargada", 3)
end

initialize()

-- =========================
-- API PÚBLICA
-- =========================
local AntiTarget = {
    version = "2.0",
    getEvidence = function() return State.evidenceLog end,
    getStats = function() return State.stats end,
    getThreatScore = function() return State.threatScore end,
    forceSaveSafeState = function() captureSafeState() end,
    forceRecovery = function(reason) attemptRecovery(reason or "manual", "medium") end,
    setConfig = function(newConfig) for k, v in pairs(newConfig) do CONFIG[k] = v end; reportRemoteCache = nil end,
    toggleJitter = function(enabled) State.jitterEnabled = enabled end,
    whitelistSource = function(source) if source then State.legitimateSources[source] = true end end,
    resetStats = function() State.stats = { totalDamageEvents = 0, suspiciousEvents = 0, falsePositiveEstimate = 0, recoveryAttempts = 0, avgDamagePerEvent = 0 } end,
    getConfig = function() return CONFIG end,
}

_G.AntiTarget = AntiTarget
return AntiTarget
