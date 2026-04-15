-- [[ AUTO CAJERO OPTIMIZADO - WORK AT A PIZZA PLACE ]]
-- Basado en datos reales interceptados.
-- Optimizado para Delta Executor (Móvil).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local isActive = true -- Cambiar a false si quieres que empiece apagado

-- Función para enviar notificaciones
local function Notify(title, text)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = 3
    })
end

-- Función principal para atender al bot
local function AtenderBot(bot, registerName)
    if not bot or not bot:FindFirstChild("Head") then return end
    
    local head = bot.Head
    local dialogRemote = ReplicatedStorage:FindFirstChild("Dialog")
    local playerActionRemote = ReplicatedStorage:FindFirstChild("PlayerAction")
    
    -- Paso 1: Hacer clic en la burbuja del bot
    if dialogRemote and playerActionRemote then
        dialogRemote:FireServer("ClickedBubble", head)
        playerActionRemote:FireServer("ClickedBubble", true)
        task.wait(0.2) -- Pequeña espera para simular reacción humana
        
        -- Paso 2: Seleccionar la respuesta correcta
        dialogRemote:FireServer("ResponseSelected", "Correct", head)
        task.wait(0.2)
        
        -- Paso 3: Enviar la orden final al servidor
        -- El log muestra un RemoteEvent sin nombre o con nombre vacío, 
        -- esto suele ser un RemoteEvent dentro de una carpeta específica.
        -- Buscaremos el RemoteEvent que maneja las órdenes.
        local orderRemote = ReplicatedStorage:FindFirstChild("OrderRemote") or ReplicatedStorage:FindFirstChild("GiveOrder")
        
        -- Si no encontramos uno con nombre, buscaremos por estructura
        if not orderRemote then
            for _, v in pairs(ReplicatedStorage:GetChildren()) do
                if v:IsA("RemoteEvent") and v.Name == "" then
                    orderRemote = v
                    break
                end
            end
        end

        if orderRemote then
            -- Detectar qué orden quiere el bot (esto se extrae del DialogChoice del bot)
            local orderType = "CheesePizza" -- Valor por defecto
            local dialog = head:FindFirstChild("Dialog")
            if dialog and dialog:FindFirstChild("Correct") then
                local response = dialog.Correct.ResponseDialog
                if response:find("pepperoni") then orderType = "PepperoniPizza"
                elseif response:find("sausage") then orderType = "SausagePizza"
                elseif response:find("dew") or response:find("mountain") then orderType = "MountainDew"
                end
            end
            
            -- Enviar la orden (Template, Tipo de Pizza, Registradora)
            orderRemote:FireServer(bot, orderType, registerName)
        end
    end
end

-- Bucle de escaneo de bots en las registradoras
task.spawn(function()
    Notify("Auto Cajero Cargado", "Buscando bots en las cajas...")
    
    while true do
        task.wait(0.5)
        if isActive then
            -- Escanear las 3 registradoras principales
            for i = 1, 3 do
                local registerName = "Register" .. i
                -- Buscamos bots cerca de las registradoras en el Workspace
                for _, obj in pairs(Workspace:GetChildren()) do
                    if obj:IsA("Model") and obj.Name:find("Customer") then
                        local root = obj:FindFirstChild("HumanoidRootPart")
                        -- Si el bot está cerca de una registradora (ajustar posición si es necesario)
                        -- En este juego los bots suelen tener un atributo o estar en una carpeta
                        if root then
                            -- Verificamos si el bot tiene la burbuja activa (SimpleDialogBillboard)
                            local head = obj:FindFirstChild("Head")
                            if head and head:FindFirstChild("SimpleDialogBillboard") and head.SimpleDialogBillboard.Enabled then
                                AtenderBot(obj, registerName)
                                task.wait(1) -- Pausa entre bots
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Anti-AFK integrado para que no te saquen del juego
local VirtualUser = game:GetService("VirtualUser")
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
