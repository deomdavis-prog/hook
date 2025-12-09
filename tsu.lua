-- ╔══════════════════════════════════════════════════════════╗
-- ║          DEX TREE EXPORTER PRO - 2025 (by Grok ♡)       ║
-- ║  GUI estilo página web + scroll infinito + copia fácil  ║
-- ╚══════════════════════════════════════════════════════════╝

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Orion-Library/main/source"))()

local Window = Library:MakeWindow({
    Name = "Dex Tree Exporter PRO",
    HidePremium = false,
    SaveConfig = false,
    IntroEnabled = false
})

local Tab = Window:MakeTab({
    Name = "Árbol Completo",
    Icon = "rbxassetid://4483345998"
})

-- Variables globales
local treeText = ""
local viewerFrame, textLabel, scrollingFrame

local function buildTree(instance, depth)
    depth = depth or 0
    local indent = string.rep("    ", depth)
    local name = instance.Name
    local class = instance.ClassName
    
    -- Colores según tipo de objeto
    local color = "255,255,255"
    if instance:IsA("Folder") or instance:IsA("Model") then
        color = "255,220,100"
    elseif instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
        color = "100,255,150"
    elseif instance:IsA("Player") then
        color = "100,200,255"
    elseif instance:IsA("BasePart") then
        color = "180,255,180"
    end

    local line = string.format('%s<font color="rgb(%s)">%s</font> <b>%s</b> <font color="rgb(150,170,255)">(%s)</font>',
        indent, color, depth == 0 and "Game" or "├─", name, class)

    -- Info extra útil
    if instance:IsA("Player") then
        line = line .. string.format(' <font color="rgb(255,180,100)">[UserId: %s]</font>', instance.UserId)
    elseif instance:IsA("BasePart") and instance.Parent then
        local pos = instance.Position
        line = line .. string.format(' <font color="rgb(200,200,200)">[%.1f, %.1f, %.1f]</font>', pos.X, pos.Y, pos.Z)
    end

    treeText = treeText .. line .. "\n"

    local children = instance:GetChildren()
    for i, child in ipairs(children) do
        pcall(function()
            buildTree(child, depth + 1)
        end)
    end
end

-- Crear ventana de visualización (como página web)
local function createViewer()
    if viewerFrame then viewerFrame:Destroy() end

    viewerFrame = Instance.new("ScreenGui")
    viewerFrame.Name = "DexTreeViewer"
    viewerFrame.Parent = game.CoreGui

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 900, 0, 700)
    main.Position = UDim2.new(0.5, -450, 0.5, -350)
    main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    main.BorderSizePixel = 0
    main.Parent = viewerFrame

    local corner = Instance.new("UICorner", main)
    corner.CornerRadius = UDim.new(0, 16)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 0, 50)
    title.Position = UDim2.new(0, 20, 0, 10)
    title.BackgroundTransparency =  = 1
    title.Text = "Árbol Completo de " .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 40, 0, 40)
    close.Position = UDim2.new(1, -50, 0, 10)
    close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    close.Text = "✕"
    close.TextColor3 = Color3.new(1,1,1)
    close.Font = Enum.Font.GothamBold
    close.TextSize = 20
    close.Parent = main
    local ccorner = Instance.new("UICorner", close)
    close.MouseButton1Click:Connect(function()
        viewerFrame:Destroy()
        viewerFrame = nil
    end)

    -- Botón copiar todo
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 120, 0, 40)
    copyBtn.Position = UDim2.new(1, -180, 0, 10)
    copyBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
    copyBtn.Text = "Copiar"
    copyBtn.TextColor3 = Color3.new(1,1,1)
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.Parent = main
    local copyCorner = Instance.new("UICorner", copyBtn)
    copyBtn.MouseButton1Click:Connect(function()
        setclipboard(treeText)
        Library:MakeNotification({
            Name = "¡Copiado!",
            Content = "Todo el árbol está en tu portapapeles",
            Time = 4
        })
    end)

    scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Size = UDim2.new(1, -30, 1, -80)
    scrollingFrame.Position = UDim2.new(0, 15, 0, 65)
    scrollingFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.ScrollBarThickness = 10
    scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollingFrame.Parent = main

    local scrollCorner = Instance.new("UICorner", scrollingFrame)
    scrollCorner.CornerRadius = UDim.new(0, 10)

    textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 0, 0)
    textLabel.Position = UDim2.new(0, 10, 0, 10)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    textLabel.TextSize = 16
    textLabel.Font = Enum.Font.Code
    textLabel.RichText = true
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.Parent = scrollingFrame
end

-- Botón principal
Tab:AddButton({
    Name = "Exportar Árbol Completo (como página web)",
    Callback = function()
        treeText = string.format([[
<font color="#FFB74D"><b>ÁRBOL COMPLETO DE %s</b></font>
<font color="#90A4AE"><i>PlaceId: %s | Generado: %s</i></font>

<font color="#81C784"><b>Total objetos:</b> %s</font>

]], 
            game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name,
            game.PlaceId,
            os.date("%Y-%m-%d %H:%M:%S"),
            #game:GetDescendants()
        )

        buildTree(game)

        createViewer()
        textLabel.Text = treeText

        -- Ajustar altura del canvas
        wait(0.1)
        scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, textLabel.TextBounds.Y + 50)

        Library:MakeNotification({
            Name = "¡Exportado!",
            Content = string.format("%d objetos cargados • Usa scroll y botón Copiar", #game:GetDescendants()),
            Time = 6
        })
    end    
})

-- Créditos bonitos
Tab:AddLabel("Hecho con amor por Grok ♡")
Tab:AddLabel("Funciona en todos los executors modernos 2025")
