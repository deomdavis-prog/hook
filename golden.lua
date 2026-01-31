-- Improved Console Interceptor GUI for Roblox (Optimized for Velocity/PC)
-- Features:
-- • Captures ALL output that the F9 dev console shows via LogService.MessageOut (print, warn, error, engine messages, tracebacks)
-- • Optional rconsoleprint hook for exploit-specific output
-- • Colored logs (white/print, cyan/info, yellow/warn, red/error)
-- • Timestamp on every line
-- • Draggable window
-- • Minimize/Maximize button
-- • Clear button
-- • Copy All button (now correctly detected)
-- • Close button
-- • Modern look with rounded corners
-- • Log limit (500 lines) for performance
-- • Auto-scroll to bottom
-- • Optimized layout using UIListLayout + AutomaticCanvasSize

local LogService = game:GetService("LogService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

-- Check clipboard support (CORREGIDO: detección segura)
local hasClipboard = typeof(setclipboard) == "function"

-- Colors per message type
local colors = {
    [Enum.MessageType.MessageOutput] = Color3.new(1, 1, 1),        -- Print (white)
    [Enum.MessageType.MessageInfo] = Color3.fromRGB(0, 200, 255), -- Info (cyan)
    [Enum.MessageType.MessageWarning] = Color3.fromRGB(255, 255, 0), -- Warn (yellow)
    [Enum.MessageType.MessageError] = Color3.fromRGB(255, 80, 80),   -- Error (red)
}

-- Create GUI (CoreGui for exploits like Velocity)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdvancedConsoleGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("CoreGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0.6, 0, 0.6, 0)
mainFrame.Position = UDim2.new(0.2, 0, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -260, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Advanced Console Interceptor"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Buttons (from right to left)
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -40, 0, 3)
closeButton.Text = "X"
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.SourceSansBold
closeButton.Parent = titleBar

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -75, 0, 3)
minimizeButton.Text = "−"
minimizeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.Font = Enum.Font.SourceSansBold
minimizeButton.Parent = titleBar

local copyButton = Instance.new("TextButton")
copyButton.Size = UDim2.new(0, 70, 0, 25)
copyButton.Position = UDim2.new(1, -150, 0, 5)
copyButton.Text = "Copy All"
copyButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
copyButton.TextColor3 = Color3.new(1, 1, 1)
copyButton.Visible = true  -- Siempre visible, pero solo funciona si hay soporte
copyButton.Parent = titleBar

local clearButton = Instance.new("TextButton")
clearButton.Size = UDim2.new(0, 70, 0, 25)
clearButton.Position = UDim2.new(1, -230, 0, 5)
clearButton.Text = "Clear"
clearButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
clearButton.TextColor3 = Color3.new(1, 1, 1)
clearButton.Parent = titleBar

-- Add corners to buttons
for _, btn in {closeButton, minimizeButton, copyButton, clearButton} do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
end

-- Log Area
local logContainer = Instance.new("ScrollingFrame")
logContainer.Size = UDim2.new(1, 0, 1, -35)
logContainer.Position = UDim2.new(0, 0, 0, 35)
logContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
logContainer.BorderSizePixel = 0
logContainer.ScrollBarThickness = 10
logContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
logContainer.Parent = mainFrame

local innerFrame = Instance.new("Frame")
innerFrame.Size = UDim2.new(1, 0, 0, 0)
innerFrame.BackgroundTransparency = 1
innerFrame.AutomaticSize = Enum.AutomaticSize.Y
innerFrame.Parent = logContainer

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 3)
listLayout.Parent = innerFrame

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.Parent = innerFrame

-- Storage
local logTexts = {}
local logLabels = {}
local maxLogs = 500

local function scrollToBottom()
    logContainer.CanvasPosition = Vector2.new(0, innerFrame.AbsoluteSize.Y)
end

local function addLog(message, msgType)
    local fullMessage = os.date("[%H:%M:%S] ") .. message
    
    table.insert(logTexts, fullMessage)
    if #logTexts > maxLogs then
        table.remove(logTexts, 1)
    end
    
    local label = Instance.new("TextLabel")
    label.Text = fullMessage
    label.TextColor3 = colors[msgType] or Color3.new(1, 1, 1)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Font = Enum.Font.Code
    label.TextSize = 14
    label.Parent = innerFrame
    
    table.insert(logLabels, label)
    if #logLabels > maxLogs then
        table.remove(logLabels, 1):Destroy()
    end
    
    task.defer(scrollToBottom)
end

-- Main interception via LogService (captures everything the F9 console sees)
LogService.MessageOut:Connect(function(message, msgType)
    addLog(message, msgType)
end)

-- Optional rconsoleprint hook (for exploit console output)
if rconsoleprint then
    local old = rconsoleprint
    rconsoleprint = function(msg)
        addLog("[RCONSOLE] " .. tostring(msg), Enum.MessageType.MessageOutput)
        return old(msg)
    end
end

-- GUI Logic
local minimized = false
minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    logContainer.Visible = not minimized
    mainFrame.Size = minimized and UDim2.new(0.6, 0, 0, 35) or UDim2.new(0.6, 0, 0.6, 0)
    minimizeButton.Text = minimized and "+" or "−"
end)

closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

clearButton.MouseButton1Click:Connect(function()
    for _, lbl in ipairs(logLabels) do
        lbl:Destroy()
    end
    logLabels = {}
    logTexts = {}
end)

-- Copy All con manejo seguro
copyButton.MouseButton1Click:Connect(function()
    if hasClipboard then
        setclipboard(table.concat(logTexts, "\n"))
        StarterGui:SetCore("SendNotification", {
            Title = "Console Interceptor",
            Text = "All logs copied to clipboard!",
            Duration = 3
        })
    else
        StarterGui:SetCore("SendNotification", {
            Title = "Console Interceptor",
            Text = "Clipboard not supported in this exploit",
            Duration = 3
        })
    end
end)

-- Draggable
local dragging, dragInput, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Initial message
addLog("Advanced Console Interceptor started - Capturing all F9 console output", Enum.MessageType.MessageInfo)

-- Test messages (puedes borrarlos si no los quieres)
print("Test print message")
warn("Test warning")
error("Test error (with traceback)")
