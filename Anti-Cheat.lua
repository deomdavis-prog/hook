-- Script de Automatización de Cajero para Work at a Pizza Place (Roblox)
-- Optimizado para Delta Executor (Móvil)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local isActive = false
local TOGGLE_KEY = Enum.KeyCode.P -- Tecla para activar/desactivar el script

-- Función para enviar notificaciones al usuario
local function Notify(title, text)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = 3
    })
end

-- Función para interactuar con el cliente (tomar orden y cobrar)
local function HandleCustomer(customer)
    if not customer or not customer:FindFirstChild("Head") then return end

    local dialog = customer.Head:FindFirstChild("Dialog")
    local simpleDialogBillboard = customer.Head:FindFirstChild("SimpleDialogBillboard")

    if dialog and simpleDialogBillboard and simpleDialogBillboard.Enabled then
        local correctChoice = dialog:FindFirstChild("Correct")
        if correctChoice then
            -- Simular clic en la opción de diálogo correcta
            -- Esto puede variar dependiendo de cómo el juego maneje la interacción del diálogo.
            -- Algunos juegos usan RemoteEvents directamente, otros esperan una interacción UI.
            -- Intentaremos simular un clic en el botón de diálogo si existe.
            local clickableBubble = simpleDialogBillboard:FindFirstChild("ClickableBubble")
            if clickableBubble and clickableBubble:IsA("ImageLabel") then
                -- Si hay un botón visual, intentamos simular un clic en él.
                -- Esto es una aproximación y puede requerir ajustes.
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0,0)) -- Clic en el centro de la pantalla, asumiendo que el botón está centrado o es el único interactuable.
                task.wait(0.1)
                VirtualUser:ReleaseController()
            end

            -- Intentar disparar el RemoteEvent si se conoce su nombre
            -- Basado en la investigación, 
            -- scripts de terceros a menudo usan un RemoteEvent para "tomar" la orden.
            -- Un nombre común podría ser "OrderRemote" o "CashierRemote".
            -- Si el juego usa un RemoteEvent específico para el cajero, se debería llamar aquí.
            -- Por ahora, asumiremos que la interacción con el diálogo es suficiente o que el juego lo maneja automáticamente.
            
            -- Buscar un RemoteEvent para el cajero si existe
            local cashierRemote = ReplicatedStorage:FindFirstChild("CashierRemote") or ReplicatedStorage:FindFirstChild("OrderRemote")
            if cashierRemote and cashierRemote:IsA("RemoteEvent") then
                -- Intentar disparar el RemoteEvent con el cliente como argumento, si es necesario.
                -- La forma exacta de los argumentos puede variar.
                pcall(function() cashierRemote:FireServer(customer) end)
            end

            -- También, el script de TrixAde mencionaba `UIEvents.ListItemPressed:Fire(a3,a4,a5,a6)`
            -- Esto sugiere que hay un evento local que se dispara cuando se selecciona un ítem.
            -- Si el juego usa un sistema de UI para la orden, podríamos necesitar simular esa interacción.
            local UIEvents = player.PlayerGui:FindFirstChild("UIEvents")
            if UIEvents and UIEvents:FindFirstChild("ListItemPressed") then
                -- Esto es más complejo ya que requiere los argumentos correctos (a3, a4, a5, a6).
                -- Sin una inspección directa del juego, es difícil saber qué valores pasar.
                -- Por ahora, lo dejaremos como un comentario y nos centraremos en RemoteEvents o interacción de diálogo.
                -- UIEvents.ListItemPressed:Fire(customer, orderDetails, etc.)
            end
        end
    end
end

-- Bucle principal de automatización
task.spawn(function()
    while true do
        task.wait(0.5) -- Esperar un poco para evitar sobrecargar el servidor

        if isActive then
            -- Buscar clientes en el área del cajero
            local cashierArea = workspace:FindFirstChild("CashierArea") -- Asumiendo que existe un modelo/parte llamada CashierArea
            if cashierArea then
                for _, child in pairs(cashierArea:GetChildren()) do
                    if child:IsA("Model") and child:FindFirstChild("Humanoid") and child.Name ~= player.Name then
                        -- Encontrado un bot/cliente
                        HandleCustomer(child)
                    end
                end
            else
                -- Si no hay un CashierArea definido, buscar clientes cerca del jugador
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") then
                        local dist = (rootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
                        if dist < 15 then -- Clientes a 15 studs de distancia
                            HandleCustomer(p.Character)
                        end
                    end
                end
            end

            -- Lógica para cobrar (si es un proceso separado)
            -- En muchos juegos, tomar la orden y cobrar se maneja en la misma interacción.
            -- Si hay un botón de "Cash Out" o similar, se necesitaría simular un clic.
            local pg = player.PlayerGui
            if pg:FindFirstChild("GuiTop") and pg.GuiTop:FindFirstChild("Paycheck") then
                local btn = pg.GuiTop.Paycheck:FindFirstChild("CashOut")
                if btn and btn.Visible then
                    -- Simular clic en el botón de cobrar
                    pcall(function()
                        if btn.MouseButton1Click then
                            btn.MouseButton1Click:Fire()
                        end
                    end)
                end
            end
        end
    end
end)

-- Manejo de la tecla para activar/desactivar
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == TOGGLE_KEY then
        isActive = not isActive
        if isActive then
            Notify("✅ Auto Cajero Activado", "El script está atendiendo a los bots.")
        else
            Notify("🛑 Auto Cajero Desactivado", "El script está en pausa.")
        end
    end
end)

Notify("Script de Auto Cajero Cargado", "Presiona 'P' para activar/desactivar.")
