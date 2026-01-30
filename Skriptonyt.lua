--[[
    SISTEMA DE AUDITORÍA EXPERTO - PS1 EDITION
    Compatible con Delta Mobile
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- APIs de Nivel Bajo
local getrawmetatable = getrawmetatable or (debug and debug.getmetatable)
local setreadonly = setreadonly or (make_writeable and function(t, b) if b then make_writeable(t) else make_readonly(t) end end)
local getupvalues = debug.getupvalues or getupvalues
local getreg = debug.getregistry or getreg
local getconstants = debug.getconstants or getconstants
local setclipboard = setclipboard or print

-- GUI Setup
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "PS1_Final_Auditor"

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 350, 0, 450)
Main.Position = UDim2.new(0.5, -175, 0.5, -225)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
Main.Active = true
Main.Draggable = true

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Title.Text = "PS1 METATABLE AUDITOR - FINAL"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.Code
Title.TextSize = 14
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

local LogScroll = Instance.new("ScrollingFrame", Main)
LogScroll.Size = UDim2.new(1, -20, 1, -140)
LogScroll.Position = UDim2.new(0, 10, 0, 55)
LogScroll.BackgroundTransparency = 1
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.ScrollBarThickness = 2

local UIList = Instance.new("UIListLayout", LogScroll)
UIList.Padding = UDim.new(0, 5)

local Status = Instance.new("TextLabel", Main)
Status.Size = UDim2.new(1, -20, 0, 20)
Status.Position = UDim2.new(0, 10, 1, -80)
Status.BackgroundTransparency = 1
Status.Text = "Listo para auditoría final."
Status.TextColor3 = Color3.fromRGB(0, 255, 150)
Status.TextSize = 12

local CopyBtn = Instance.new("TextButton", Main)
CopyBtn.Size = UDim2.new(0.45, 0, 0, 40)
CopyBtn.Position = UDim2.new(0.05, 0, 1, -50)
CopyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
CopyBtn.Text = "COPY ALL"
CopyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 8)

local ScanBtn = Instance.new("TextButton", Main)
ScanBtn.Size = UDim2.new(0.45, 0, 0, 40)
ScanBtn.Position = UDim2.new(0.5, 0, 1, -50)
ScanBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
ScanBtn.Text = "DEEP AUDIT"
ScanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", ScanBtn).CornerRadius = UDim.new(0, 8)

-- Serializador de Luau Puro
local function serialize(v, d, s)
    d = d or 0
    s = s or {}
    if type(v) == "string" then return "'" .. v .. "'" end
    if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
    if type(v) == "table" then
        if d > 2 then return "{...}" end
        if s[v] then return "{CIRC}" end
        s[v] = true
        local r = "{\n"
        local i = string.rep(" ", (d + 1) * 2)
        pcall(function() if setreadonly then setreadonly(v, false) end end)
        for k, val in pairs(v) do
            local ok, res = pcall(function() return serialize(val, d + 1, s) end)
            r = r .. i .. "[" .. tostring(k) .. "] = " .. (ok and res or "ERR") .. ",\n"
        end
        return r .. string.rep(" ", d * 2) .. "}"
    end
    if type(v) == "function" then
        local info = "func("
        pcall(function()
            if getconstants then
                for _, c in pairs(getconstants(v)) do
                    if type(c) == "string" and #c > 1 then info = info .. "'" .. c .. "'," end
                end
            end
        end)
        return info .. ")"
    end
    return tostring(v)
end

local full_dump = ""

local function addLog(name, content)
    local label = Instance.new("TextLabel", LogScroll)
    label.Size = UDim2.new(1, 0, 0, 30)
    label.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    label.Text = " [!] " .. name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Code
    label.TextSize = 10
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
    full_dump = full_dump .. "\n--- " .. name .. " ---\n" .. content .. "\n"
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
end

ScanBtn.MouseButton1Click:Connect(function()
    for _, v in pairs(LogScroll:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    full_dump = ""
    Status.Text = "Infiltrando Registro..."
    
    -- 1. Registro Scan
    local reg = getreg()
    for k, v in pairs(reg) do
        if type(v) == "table" then
            local is_big = false
            pcall(function() if v.Network or v.Library or v.GetPetData then is_big = true end end)
            if is_big then addLog("RegTable_" .. k, serialize(v)) end
        end
    end
    
    -- 2. Upvalue Scan en Library
    local lib = ReplicatedStorage:FindFirstChild("Library")
    if lib then
        for _, m in pairs(lib:GetDescendants()) do
            if m:IsA("ModuleScript") then
                pcall(function()
                    local res = require(m)
                    if type(res) == "table" then
                        for _, f in pairs(res) do
                            if type(f) == "function" then
                                for i, up in pairs(getupvalues(f)) do
                                    if type(up) == "table" then addLog(m.Name .. "_UP_" .. i, serialize(up)) end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
    Status.Text = "Auditoría completada."
end)

CopyBtn.MouseButton1Click:Connect(function()
    setclipboard(full_dump)
    Status.Text = "Copiado al portapapeles."
end)
