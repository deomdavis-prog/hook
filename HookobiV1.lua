-- ═══════════════════════════════════════════════════════════
-- MOBILE HOOK SYSTEM v3.0 - Delta/iOS Compatible
-- Interactive Menu with Touch-Friendly Interface
-- ═══════════════════════════════════════════════════════════

local HookSystem = {
    Captures = {},
    Logs = {},
    Active = true,
    GUI = nil
}

-- ═══════════════════════════════════════════════════════════
-- CONFIGURACIÓN
-- ═══════════════════════════════════════════════════════════

local Config = {
    UIScale = 1,
    AutoCapture = true,
    ShowNotifications = true,
    MaxCaptures = 50
}

-- ═══════════════════════════════════════════════════════════
-- SISTEMA DE NOTIFICACIONES
-- ═══════════════════════════════════════════════════════════

local function Notify(title, text, duration)
    if not Config.ShowNotifications then return end
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "🔍 " .. title,
        Text = text,
        Duration = duration or 3,
        Icon = "rbxassetid://7733717447"
    })
end

-- ═══════════════════════════════════════════════════════════
-- ANÁLISIS DE OFUSCACIÓN
-- ═══════════════════════════════════════════════════════════

local function DetectObfuscators(code)
    local detections = {}
    
    -- Moonsec
    if string.find(code, "IllIlllIllIlllIlllIlllIll") or 
       string.find(code, "l__") or 
       string.find(code, "repeat") and string.find(code, "until") then
        table.insert(detections, "Moonsec")
    end
    
    -- WeAreDevs
    if string.find(code, "getrenv") or string.find(code, "_G%[") then
        table.insert(detections, "WeAreDevs")
    end
    
    -- IronBrew
    if string.find(code, "bit32%.bxor") or string.find(code, "Stk%[") then
        table.insert(detections, "IronBrew")
    end
    
    -- PSU
    if string.find(code, "Deserialize") or string.find(code, "Chunk") then
        table.insert(detections, "PSU")
    end
    
    -- Generic VM
    if string.find(code, "Upvalues%[") or string.find(code, "Instr%[") then
        table.insert(detections, "Custom VM")
    end
    
    return (#detections > 0) and table.concat(detections, ", ") or "None"
end

-- ═══════════════════════════════════════════════════════════
-- HOOKS
-- ═══════════════════════════════════════════════════════════

local original_loadstring = loadstring
local original_httpget = game.HttpGet

-- Hook HttpGet
local function InstallHttpGetHook()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local old_namecall = mt.__namecall
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if (method == "HttpGet" or method == "HttpGetAsync") and Config.AutoCapture then
            local url = args[1]
            local success, response = pcall(old_namecall, self, ...)
            
            if success then
                local obf = DetectObfuscators(response)
                
                table.insert(HookSystem.Captures, {
                    type = "HttpGet",
                    url = url,
                    content = response,
                    size = #response,
                    obfuscators = obf,
                    time = os.date("%H:%M:%S")
                })
                
                Notify("HttpGet Captured", "Size: " .. #response .. " bytes\nObf: " .. obf)
                HookSystem:UpdateUI()
            end
            
            return response
        end
        
        return old_namecall(self, ...)
    end)
    
    setreadonly(mt, true)
end

-- Hook Loadstring
local function InstallLoadstringHook()
    getgenv().loadstring = newcclosure(function(source, chunkname)
        if Config.AutoCapture then
            local obf = DetectObfuscators(source)
            
            table.insert(HookSystem.Captures, {
                type = "Loadstring",
                chunkname = chunkname or "Unknown",
                content = source,
                size = #source,
                obfuscators = obf,
                time = os.date("%H:%M:%S")
            })
            
            Notify("Loadstring Captured", "Size: " .. #source .. " bytes\nObf: " .. obf)
            HookSystem:UpdateUI()
        end
        
        return original_loadstring(source, chunkname)
    end)
end

-- ═══════════════════════════════════════════════════════════
-- INTERFAZ GRÁFICA
-- ═══════════════════════════════════════════════════════════

function HookSystem:CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "HookSystemUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Protección
    if gethui then
        ScreenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = game:GetService("CoreGui")
    else
        ScreenGui.Parent = game:GetService("CoreGui")
    end
    
    -- Frame Principal
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 380, 0, 520)
    MainFrame.Position = UDim2.new(0.5, -190, 0.5, -260)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame
    
    -- Sombra
    local Shadow = Instance.new("ImageLabel")
    Shadow.Name = "Shadow"
    Shadow.Size = UDim2.new(1, 30, 1, 30)
    Shadow.Position = UDim2.new(0, -15, 0, -15)
    Shadow.BackgroundTransparency = 1
    Shadow.Image = "rbxassetid://5554236805"
    Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.ImageTransparency = 0.5
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    Shadow.Parent = MainFrame
    
    -- Header
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 50)
    Header.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 12)
    HeaderCorner.Parent = Header
    
    local HeaderFix = Instance.new("Frame")
    HeaderFix.Size = UDim2.new(1, 0, 0, 12)
    HeaderFix.Position = UDim2.new(0, 0, 1, -12)
    HeaderFix.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    HeaderFix.BorderSizePixel = 0
    HeaderFix.Parent = Header
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -60, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "🔍 Hook System"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 20
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header
    
    local CaptureCount = Instance.new("TextLabel")
    CaptureCount.Name = "CaptureCount"
    CaptureCount.Size = UDim2.new(0, 40, 0, 24)
    CaptureCount.Position = UDim2.new(1, -50, 0.5, -12)
    CaptureCount.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
    CaptureCount.Text = "0"
    CaptureCount.TextColor3 = Color3.fromRGB(255, 255, 255)
    CaptureCount.TextSize = 14
    CaptureCount.Font = Enum.Font.GothamBold
    CaptureCount.Parent = Header
    
    local CountCorner = Instance.new("UICorner")
    CountCorner.CornerRadius = UDim.new(0, 6)
    CountCorner.Parent = CaptureCount
    
    -- ScrollingFrame para capturas (ajustar tamaño para los botones)
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "ScrollFrame"
    ScrollFrame.Size = UDim2.new(1, -20, 1, -190)
    ScrollFrame.Position = UDim2.new(0, 10, 0, 60)
    ScrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 120, 255)
    ScrollFrame.Parent = MainFrame
    
    local ScrollCorner = Instance.new("UICorner")
    ScrollCorner.CornerRadius = UDim.new(0, 8)
    ScrollCorner.Parent = ScrollFrame
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 8)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = ScrollFrame
    
    -- Botones de Control
    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Name = "ButtonFrame"
    ButtonFrame.Size = UDim2.new(1, -20, 0, 110)
    ButtonFrame.Position = UDim2.new(0, 10, 1, -120)
    ButtonFrame.BackgroundTransparency = 1
    ButtonFrame.Parent = MainFrame
    
    local function CreateButton(text, icon, position, color, callback)
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(0.48, 0, 0, 50)
        Button.Position = position
        Button.BackgroundColor3 = color
        Button.Text = ""
        Button.AutoButtonColor = false
        Button.Parent = ButtonFrame
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 8)
        BtnCorner.Parent = Button
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, 0, 1, 0)
        Label.BackgroundTransparency = 1
        Label.Text = icon .. " " .. text
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextSize = 16
        Label.Font = Enum.Font.GothamBold
        Label.Parent = Button
        
        Button.MouseButton1Click:Connect(callback)
        
        -- Animación
        Button.MouseEnter:Connect(function()
            game:GetService("TweenService"):Create(Button, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(color.R * 255 * 1.2, 255),
                    math.min(color.G * 255 * 1.2, 255),
                    math.min(color.B * 255 * 1.2, 255)
                )
            }):Play()
        end)
        
        Button.MouseLeave:Connect(function()
            game:GetService("TweenService"):Create(Button, TweenInfo.new(0.2), {
                BackgroundColor3 = color
            }):Play()
        end)
        
        return Button
    end
    
    -- Fila 1 de botones
    local Button1 = CreateButton("Save File", "💾", UDim2.new(0, 0, 0, 0), 
        Color3.fromRGB(80, 200, 120), 
        function() self:SaveToFile() end
    )
    
    local Button2 = CreateButton("Export URL", "🔗", UDim2.new(0.52, 0, 0, 0), 
        Color3.fromRGB(150, 100, 255), 
        function() self:ExportToURL() end
    )
    
    -- Fila 2 de botones (con más espacio)
    local Button3 = CreateButton("Copy Part", "📋", UDim2.new(0, 0, 0, 60), 
        Color3.fromRGB(60, 120, 255), 
        function() self:CopyInParts() end
    )
    
    local Button4 = CreateButton("Clear All", "🗑️", UDim2.new(0.52, 0, 0, 60), 
        Color3.fromRGB(255, 60, 80), 
        function() self:ClearAll() end
    )
    
    -- Hacer draggable
    local dragging, dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    Header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
    
    self.GUI = ScreenGui
    self.ScrollFrame = ScrollFrame
    self.CaptureCount = CaptureCount
end

function HookSystem:AddCaptureToUI(capture, index)
    local CaptureFrame = Instance.new("Frame")
    CaptureFrame.Name = "Capture_" .. index
    CaptureFrame.Size = UDim2.new(1, -12, 0, 100)
    CaptureFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    CaptureFrame.BorderSizePixel = 0
    CaptureFrame.Parent = self.ScrollFrame
    
    local FrameCorner = Instance.new("UICorner")
    FrameCorner.CornerRadius = UDim.new(0, 8)
    FrameCorner.Parent = CaptureFrame
    
    -- Info
    local TypeLabel = Instance.new("TextLabel")
    TypeLabel.Size = UDim2.new(0.5, -10, 0, 20)
    TypeLabel.Position = UDim2.new(0, 10, 0, 8)
    TypeLabel.BackgroundTransparency = 1
    TypeLabel.Text = "📦 " .. capture.type
    TypeLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    TypeLabel.TextSize = 13
    TypeLabel.Font = Enum.Font.GothamBold
    TypeLabel.TextXAlignment = Enum.TextXAlignment.Left
    TypeLabel.Parent = CaptureFrame
    
    local TimeLabel = Instance.new("TextLabel")
    TimeLabel.Size = UDim2.new(0.5, -10, 0, 20)
    TimeLabel.Position = UDim2.new(0.5, 0, 0, 8)
    TimeLabel.BackgroundTransparency = 1
    TimeLabel.Text = "⏰ " .. capture.time
    TimeLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    TimeLabel.TextSize = 11
    TimeLabel.Font = Enum.Font.Gotham
    TimeLabel.TextXAlignment = Enum.TextXAlignment.Right
    TimeLabel.Parent = CaptureFrame
    
    local SizeLabel = Instance.new("TextLabel")
    SizeLabel.Size = UDim2.new(1, -20, 0, 16)
    SizeLabel.Position = UDim2.new(0, 10, 0, 30)
    SizeLabel.BackgroundTransparency = 1
    SizeLabel.Text = "Size: " .. capture.size .. " bytes"
    SizeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    SizeLabel.TextSize = 11
    SizeLabel.Font = Enum.Font.Gotham
    SizeLabel.TextXAlignment = Enum.TextXAlignment.Left
    SizeLabel.Parent = CaptureFrame
    
    local ObfLabel = Instance.new("TextLabel")
    ObfLabel.Size = UDim2.new(1, -20, 0, 16)
    ObfLabel.Position = UDim2.new(0, 10, 0, 48)
    ObfLabel.BackgroundTransparency = 1
    ObfLabel.Text = "Obfuscators: " .. capture.obfuscators
    ObfLabel.TextColor3 = (capture.obfuscators ~= "None") and Color3.fromRGB(255, 150, 80) or Color3.fromRGB(100, 255, 100)
    ObfLabel.TextSize = 11
    ObfLabel.Font = Enum.Font.Gotham
    ObfLabel.TextXAlignment = Enum.TextXAlignment.Left
    ObfLabel.Parent = CaptureFrame
    
    -- Botón Copy
    local CopyButton = Instance.new("TextButton")
    CopyButton.Size = UDim2.new(1, -20, 0, 24)
    CopyButton.Position = UDim2.new(0, 10, 1, -32)
    CopyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    CopyButton.Text = "📋 Copy Script"
    CopyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CopyButton.TextSize = 12
    CopyButton.Font = Enum.Font.GothamBold
    CopyButton.Parent = CaptureFrame
    
    local CopyCorner = Instance.new("UICorner")
    CopyCorner.CornerRadius = UDim.new(0, 6)
    CopyCorner.Parent = CopyButton
    
    CopyButton.MouseButton1Click:Connect(function()
        setclipboard(capture.content)
        Notify("Copied!", "Script #" .. index .. " copied to clipboard")
        CopyButton.Text = "✅ Copied!"
        wait(1)
        CopyButton.Text = "📋 Copy Script"
    end)
end

function HookSystem:UpdateUI()
    if not self.GUI then return end
    
    -- Actualizar contador
    self.CaptureCount.Text = tostring(#self.Captures)
    
    -- Limpiar scroll
    for _, child in ipairs(self.ScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Agregar capturas
    for i, capture in ipairs(self.Captures) do
        self:AddCaptureToUI(capture, i)
    end
    
    -- Actualizar tamaño del canvas
    self.ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, (#self.Captures * 108))
end

function HookSystem:CopyInParts()
    if #self.Captures == 0 then
        Notify("Empty", "No captures to copy", 2)
        return
    end
    
    if not self.currentPartIndex then
        self.currentPartIndex = 1
    end
    
    local maxChars = 3000 -- Límite seguro para clipboard móvil
    local output = ""
    local capturesCopied = 0
    
    -- Header solo en la primera parte
    if self.currentPartIndex == 1 then
        output = "═══════════════════════════════════════\n"
        output = output .. "🔍 HOOK SYSTEM - PART " .. self.currentPartIndex .. "\n"
        output = output .. "═══════════════════════════════════════\n\n"
    end
    
    while self.currentPartIndex <= #self.Captures and #output < maxChars do
        local capture = self.Captures[self.currentPartIndex]
        local captureText = string.format("═══ CAPTURE #%d ═══\n", self.currentPartIndex)
        captureText = captureText .. "Type: " .. capture.type .. "\n"
        captureText = captureText .. "Time: " .. capture.time .. "\n"
        captureText = captureText .. "Size: " .. capture.size .. " bytes\n"
        captureText = captureText .. "Obf: " .. capture.obfuscators .. "\n\n"
        captureText = captureText .. "--- CODE ---\n" .. capture.content .. "\n\n"
        
        -- Verificar si cabe
        if #output + #captureText > maxChars and capturesCopied > 0 then
            break
        end
        
        output = output .. captureText
        capturesCopied = capturesCopied + 1
        self.currentPartIndex = self.currentPartIndex + 1
    end
    
    setclipboard(output)
    
    if self.currentPartIndex > #self.Captures then
        Notify("Complete!", "All captures copied. Resetting...", 3)
        self.currentPartIndex = 1
    else
        local remaining = #self.Captures - self.currentPartIndex + 1
        Notify("Part Copied!", capturesCopied .. " scripts copied\n" .. remaining .. " remaining", 3)
    end
end

function HookSystem:SaveToFile()
    if #self.Captures == 0 then
        Notify("Empty", "No captures to save", 2)
        return
    end
    
    local output = "═══════════════════════════════════════\n"
    output = output .. "🔍 HOOK SYSTEM - FULL EXPORT\n"
    output = output .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    output = output .. "Total Captures: " .. #self.Captures .. "\n"
    output = output .. "═══════════════════════════════════════\n\n"
    
    for i, capture in ipairs(self.Captures) do
        output = output .. string.format("═══ CAPTURE #%d ═══\n", i)
        output = output .. "Type: " .. capture.type .. "\n"
        output = output .. "Time: " .. capture.time .. "\n"
        output = output .. "Size: " .. capture.size .. " bytes\n"
        output = output .. "Obfuscators: " .. capture.obfuscators .. "\n"
        
        if capture.url then output = output .. "URL: " .. capture.url .. "\n" end
        if capture.chunkname then output = output .. "Chunk: " .. capture.chunkname .. "\n" end
        
        output = output .. "\n--- CODE START ---\n"
        output = output .. capture.content .. "\n"
        output = output .. "--- CODE END ---\n\n"
    end
    
    local filename = "HookCaptures_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    writefile(filename, output)
    
    Notify("Saved!", "File: " .. filename .. "\nCheck workspace folder", 4)
end

function HookSystem:ExportToURL()
    if #self.Captures == 0 then
        Notify("Empty", "No captures to export", 2)
        return
    end
    
    Notify("Uploading...", "Creating shareable link...", 2)
    
    local output = "═══════════════════════════════════════\n"
    output = output .. "🔍 HOOK SYSTEM EXPORT\n"
    output = output .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    output = output .. "═══════════════════════════════════════\n\n"
    
    for i, capture in ipairs(self.Captures) do
        output = output .. string.format("═══ CAPTURE #%d ═══\n", i)
        output = output .. "Type: " .. capture.type .. "\n"
        output = output .. "Obf: " .. capture.obfuscators .. "\n"
        output = output .. "Size: " .. capture.size .. " bytes\n\n"
        output = output .. capture.content .. "\n\n"
    end
    
    -- Usar servicio de paste (Pastebin alternativo)
    local success, result = pcall(function()
        local response = request({
            Url = "https://api.paste.ee/v1/pastes",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = game:GetService("HttpService"):JSONEncode({
                description = "Hook System Export - " .. os.date("%Y-%m-%d"),
                sections = {{
                    name = "Captures",
                    syntax = "text",
                    contents = output
                }}
            })
        })
        
        if response.StatusCode == 201 then
            local data = game:GetService("HttpService"):JSONDecode(response.Body)
            return "https://paste.ee/p/" .. data.id
        end
        return nil
    end)
    
    if success and result then
        setclipboard(result)
        Notify("Success!", "URL copied to clipboard!\nShare this link", 5)
    else
        Notify("Failed", "Could not upload. Try 'Save File' instead", 3)
    end
end

function HookSystem:ClearAll()
    if #self.Captures == 0 then
        Notify("Already Empty", "No captures to clear", 2)
        return
    end
    
    local count = #self.Captures
    self.Captures = {}
    self:UpdateUI()
    Notify("Cleared!", count .. " captures removed", 2)
end

-- ═══════════════════════════════════════════════════════════
-- INICIALIZACIÓN
-- ═══════════════════════════════════════════════════════════

function HookSystem:Initialize()
    Notify("Hook System", "Initializing...", 2)
    
    InstallHttpGetHook()
    InstallLoadstringHook()
    
    self:CreateUI()
    
    Notify("Ready!", "System active - Captures: 0", 3)
end

-- Iniciar automáticamente
HookSystem:Initialize()

return HookSystem
