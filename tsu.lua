--// Loaded Check
if AirHubV2Loaded or AirHubV2Loading or AirHub then return end
getgenv().AirHubV2Loading = true

--// Cache (Optimizado)
local game = game
local loadstring, typeof, select, next, pcall, type = loadstring, typeof, select, next, pcall, type
local tablefind, tablesort, tableinsert = table.find, table.sort, table.insert
local mathfloor = math.floor
local stringgsub, stringfind = string.gsub, string.find
local wait, delay, spawn = task.wait, task.delay, task.spawn
local osdate = os.date

--// Pre-cache constantes
local FONTS = {"UI", "System", "Plex", "Monospace"}
local TRACER_POSITIONS = {"Bottom", "Center", "Mouse"}
local HEALTHBAR_POSITIONS = {"Top", "Bottom", "Left", "Right"}
local UPDATE_MODES = {"RenderStepped", "Stepped", "Heartbeat"}
local TEAM_CHECK_OPTIONS = {"TeamColor", "Team"}
local LOCK_MODES_CONTENT = {"CFrame", "mousemoverel"}
local LOCK_PARTS = {"Head", "HumanoidRootPart", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm", "LeftUpperArm", "RightUpperArm", "LeftFoot", "LeftLowerLeg", "UpperTorso", "LeftUpperLeg", "RightFoot", "RightLowerLeg", "LowerTorso", "RightUpperLeg"}
local CROSSHAIR_POSITIONS = {"Mouse", "Center"}

--// Launching
loadstring(game:HttpGet("https://raw.githubusercontent.com/Exunys/Roblox-Functions-Library/main/Library.lua"))()

local GUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Exunys/AirHub-V2/main/src/UI%20Library.lua"))()
local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/Exunys/Exunys-ESP/main/src/ESP.lua"))()
local Aimbot = loadstring(game:HttpGet("https://raw.githubusercontent.com/deomdavis-prog/hook/refs/heads/main/obfuscated_content.lua"))()

--// Variables (Pre-cached)
local MainFrame = GUI:Load()

local ESP_DeveloperSettings = ESP.DeveloperSettings
local ESP_Settings = ESP.Settings
local ESP_Properties = ESP.Properties
local Crosshair = ESP_Properties.Crosshair
local CenterDot = Crosshair.CenterDot

local Aimbot_DeveloperSettings = Aimbot.DeveloperSettings
local Aimbot_Settings = Aimbot.Settings
local Aimbot_FOV = Aimbot.FOVSettings

--// Configuración inicial (Batch)
ESP_Settings.LoadConfigOnLaunch = false
ESP_Settings.Enabled = false
Crosshair.Enabled = false
Aimbot_Settings.Enabled = false

--// Tabs
local General, GeneralSignal = MainFrame:Tab("General")
local _Aimbot = MainFrame:Tab("Aimbot")
local _ESP = MainFrame:Tab("ESP")
local _Crosshair = MainFrame:Tab("Crosshair")
local Settings = MainFrame:Tab("Settings")

--// Functions (Optimizadas)
local function AddValues(Section, Object, Exceptions, Prefix)
	local Keys = {}
	local KeyCount = 0
	
	-- Single pass: recolectar y ordenar
	for Index in next, Object do
		KeyCount = KeyCount + 1
		Keys[KeyCount] = Index
	end
	
	tablesort(Keys)
	
	-- Cache exception lookup
	local ExceptionSet = {}
	if Exceptions then
		for i = 1, #Exceptions do
			ExceptionSet[Exceptions[i]] = true
		end
	end
	
	-- Proceso optimizado: booleans
	for i = 1, KeyCount do
		local Index = Keys[i]
		if not ExceptionSet[Index] then
			local Value = Object[Index]
			if type(Value) == "boolean" then
				Section:Toggle({
					Name = stringgsub(Index, "(%l)(%u)", "%1 %2"),
					Flag = Prefix..Index,
					Default = Value,
					Callback = function(_Value)
						Object[Index] = _Value
					end
				})
			end
		end
	end
	
	-- Proceso optimizado: colors
	for i = 1, KeyCount do
		local Index = Keys[i]
		if not ExceptionSet[Index] then
			local Value = Object[Index]
			if typeof(Value) == "Color3" then
				Section:Colorpicker({
					Name = stringgsub(Index, "(%l)(%u)", "%1 %2"),
					Flag = Index,
					Default = Value,
					Callback = function(_Value)
						Object[Index] = _Value
					end
				})
			end
		end
	end
end

--// Factory functions para callbacks repetitivos
local function CreateSliderCallback(Object, Property, Divisor)
	if Divisor then
		return function(Value)
			Object[Property] = Value / Divisor
		end
	end
	return function(Value)
		Object[Property] = Value
	end
end

local function CreateToggleCallback(Object, Property)
	return function(Value)
		Object[Property] = Value
	end
end

local function CreateDropdownCallback(Object, Property)
	return function(Value)
		Object[Property] = Value
	end
end

--// General Tab
local AimbotSection = General:Section({Name = "Aimbot Settings", Side = "Left"})
local ESPSection = General:Section({Name = "ESP Settings", Side = "Right"})
local ESPDeveloperSection = General:Section({Name = "ESP Developer Settings", Side = "Right"})

AddValues(ESPDeveloperSection, ESP_DeveloperSettings, {}, "ESP_DeveloperSettings_")

ESPDeveloperSection:Dropdown({
	Name = "Update Mode",
	Flag = "ESP_UpdateMode",
	Content = UPDATE_MODES,
	Default = ESP_DeveloperSettings.UpdateMode,
	Callback = CreateDropdownCallback(ESP_DeveloperSettings, "UpdateMode")
})

ESPDeveloperSection:Dropdown({
	Name = "Team Check Option",
	Flag = "ESP_TeamCheckOption",
	Content = TEAM_CHECK_OPTIONS,
	Default = ESP_DeveloperSettings.TeamCheckOption,
	Callback = CreateDropdownCallback(ESP_DeveloperSettings, "TeamCheckOption")
})

ESPDeveloperSection:Slider({
	Name = "Rainbow Speed",
	Flag = "ESP_RainbowSpeed",
	Default = ESP_DeveloperSettings.RainbowSpeed * 10,
	Min = 5,
	Max = 30,
	Callback = CreateSliderCallback(ESP_DeveloperSettings, "RainbowSpeed", 10)
})

ESPDeveloperSection:Slider({
	Name = "Width Boundary",
	Flag = "ESP_WidthBoundary",
	Default = ESP_DeveloperSettings.WidthBoundary * 10,
	Min = 5,
	Max = 30,
	Callback = CreateSliderCallback(ESP_DeveloperSettings, "WidthBoundary", 10)
})

ESPDeveloperSection:Button({
	Name = "Refresh",
	Callback = function()
		ESP:Restart()
	end
})

AddValues(ESPSection, ESP_Settings, {"LoadConfigOnLaunch", "PartsOnly"}, "ESPSettings_")

AimbotSection:Toggle({
	Name = "Enabled",
	Flag = "Aimbot_Enabled",
	Default = Aimbot_Settings.Enabled,
	Callback = CreateToggleCallback(Aimbot_Settings, "Enabled")
})

AddValues(AimbotSection, Aimbot_Settings, {"Enabled", "Toggle", "OffsetToMoveDirection"}, "Aimbot_")

local AimbotDeveloperSection = General:Section({Name = "Aimbot Developer Settings", Side = "Left"})

AimbotDeveloperSection:Dropdown({
	Name = "Update Mode",
	Flag = "Aimbot_UpdateMode",
	Content = UPDATE_MODES,
	Default = Aimbot_DeveloperSettings.UpdateMode,
	Callback = CreateDropdownCallback(Aimbot_DeveloperSettings, "UpdateMode")
})

AimbotDeveloperSection:Dropdown({
	Name = "Team Check Option",
	Flag = "Aimbot_TeamCheckOption",
	Content = TEAM_CHECK_OPTIONS,
	Default = Aimbot_DeveloperSettings.TeamCheckOption,
	Callback = CreateDropdownCallback(Aimbot_DeveloperSettings, "TeamCheckOption")
})

AimbotDeveloperSection:Slider({
	Name = "Rainbow Speed",
	Flag = "Aimbot_RainbowSpeed",
	Default = Aimbot_DeveloperSettings.RainbowSpeed * 10,
	Min = 5,
	Max = 30,
	Callback = CreateSliderCallback(Aimbot_DeveloperSettings, "RainbowSpeed", 10)
})

AimbotDeveloperSection:Button({
	Name = "Refresh",
	Callback = function()
		Aimbot.Restart()
	end
})

--// Aimbot Tab
local AimbotPropertiesSection = _Aimbot:Section({Name = "Properties", Side = "Left"})

AimbotPropertiesSection:Toggle({
	Name = "Toggle",
	Flag = "Aimbot_Toggle",
	Default = Aimbot_Settings.Toggle,
	Callback = CreateToggleCallback(Aimbot_Settings, "Toggle")
})

AimbotPropertiesSection:Toggle({
	Name = "Offset To Move Direction",
	Flag = "Aimbot_OffsetToMoveDirection",
	Default = Aimbot_Settings.OffsetToMoveDirection,
	Callback = CreateToggleCallback(Aimbot_Settings, "OffsetToMoveDirection")
})

AimbotPropertiesSection:Slider({
	Name = "Offset Increment",
	Flag = "Aimbot_OffsetIncrementy",
	Default = Aimbot_Settings.OffsetIncrement,
	Min = 1,
	Max = 30,
	Callback = CreateSliderCallback(Aimbot_Settings, "OffsetIncrement")
})

AimbotPropertiesSection:Slider({
	Name = "Animation Sensitivity (ms)",
	Flag = "Aimbot_Sensitivity",
	Default = Aimbot_Settings.Sensitivity * 100,
	Min = 0,
	Max = 100,
	Callback = CreateSliderCallback(Aimbot_Settings, "Sensitivity", 100)
})

AimbotPropertiesSection:Slider({
	Name = "mousemoverel Sensitivity",
	Flag = "Aimbot_Sensitivity2",
	Default = Aimbot_Settings.Sensitivity2 * 100,
	Min = 0,
	Max = 500,
	Callback = CreateSliderCallback(Aimbot_Settings, "Sensitivity2", 100)
})

AimbotPropertiesSection:Dropdown({
	Name = "Lock Mode",
	Flag = "Aimbot_Settings_LockMode",
	Content = LOCK_MODES_CONTENT,
	Default = Aimbot_Settings.LockMode == 1 and "CFrame" or "mousemoverel",
	Callback = function(Value)
		Aimbot_Settings.LockMode = Value == "CFrame" and 1 or 2
	end
})

AimbotPropertiesSection:Dropdown({
	Name = "Lock Part",
	Flag = "Aimbot_LockPart",
	Content = LOCK_PARTS,
	Default = Aimbot_Settings.LockPart,
	Callback = CreateDropdownCallback(Aimbot_Settings, "LockPart")
})

AimbotPropertiesSection:Keybind({
	Name = "Trigger Key",
	Flag = "Aimbot_TriggerKey",
	Default = Aimbot_Settings.TriggerKey,
	Callback = function(Keybind)
		Aimbot_Settings.TriggerKey = Keybind
	end
})

local UserBox = AimbotPropertiesSection:Box({
	Name = "Player Name (shortened allowed)",
	Flag = "Aimbot_PlayerName",
	Placeholder = "Username"
})

AimbotPropertiesSection:Button({
	Name = "Blacklist (Ignore) Player",
	Callback = function()
		pcall(Aimbot.Blacklist, Aimbot, GUI.flags["Aimbot_PlayerName"])
		UserBox:Set("")
	end
})

AimbotPropertiesSection:Button({
	Name = "Whitelist Player",
	Callback = function()
		pcall(Aimbot.Whitelist, Aimbot, GUI.flags["Aimbot_PlayerName"])
		UserBox:Set("")
	end
})

local AimbotFOVSection = _Aimbot:Section({Name = "Field Of View Settings", Side = "Right"})

AddValues(AimbotFOVSection, Aimbot_FOV, {}, "Aimbot_FOV_")

AimbotFOVSection:Slider({
	Name = "Field Of View",
	Flag = "Aimbot_FOV_Radius",
	Default = Aimbot_FOV.Radius,
	Min = 0,
	Max = 720,
	Callback = CreateSliderCallback(Aimbot_FOV, "Radius")
})

AimbotFOVSection:Slider({
	Name = "Sides",
	Flag = "Aimbot_FOV_NumSides",
	Default = Aimbot_FOV.NumSides,
	Min = 3,
	Max = 60,
	Callback = CreateSliderCallback(Aimbot_FOV, "NumSides")
})

AimbotFOVSection:Slider({
	Name = "Transparency",
	Flag = "Aimbot_FOV_Transparency",
	Default = Aimbot_FOV.Transparency * 10,
	Min = 1,
	Max = 10,
	Callback = CreateSliderCallback(Aimbot_FOV, "Transparency", 10)
})

AimbotFOVSection:Slider({
	Name = "Thickness",
	Flag = "Aimbot_FOV_Thickness",
	Default = Aimbot_FOV.Thickness,
	Min = 1,
	Max = 5,
	Callback = CreateSliderCallback(Aimbot_FOV, "Thickness")
})

--// ESP Tab
local ESP_Properties_Section = _ESP:Section({Name = "ESP Properties", Side = "Left"})

AddValues(ESP_Properties_Section, ESP_Properties.ESP, {}, "ESP_Propreties_")

ESP_Properties_Section:Dropdown({
	Name = "Text Font",
	Flag = "ESP_TextFont",
	Content = FONTS,
	Default = FONTS[ESP_Properties.ESP.Font + 1],
	Callback = function(Value)
		ESP_Properties.ESP.Font = Drawing.Fonts[Value]
	end
})

ESP_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "ESP_TextTransparency",
	Default = ESP_Properties.ESP.Transparency * 10,
	Min = 1,
	Max = 10,
	Callback = CreateSliderCallback(ESP_Properties.ESP, "Transparency", 10)
})

ESP_Properties_Section:Slider({
	Name = "Font Size",
	Flag = "ESP_FontSize",
	Default = ESP_Properties.ESP.Size,
	Min = 1,
	Max = 20,
	Callback = CreateSliderCallback(ESP_Properties.ESP, "Size")
})

ESP_Properties_Section:Slider({
	Name = "Offset",
	Flag = "ESP_Offset",
	Default = ESP_Properties.ESP.Offset,
	Min = 10,
	Max = 30,
	Callback = CreateSliderCallback(ESP_Properties.ESP, "Offset")
})

local Tracer_Properties_Section = _ESP:Section({Name = "Tracer Properties", Side = "Right"})

AddValues(Tracer_Properties_Section, ESP_Properties.Tracer, {}, "Tracer_Properties_")

Tracer_Properties_Section:Dropdown({
	Name = "Position",
	Flag = "Tracer_Position",
	Content = TRACER_POSITIONS,
	Default = TRACER_POSITIONS[ESP_Properties.Tracer.Position],
	Callback = function(Value)
		ESP_Properties.Tracer.Position = tablefind(TRACER_POSITIONS, Value)
	end
})

Tracer_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "Tracer_Transparency",
	Default = ESP_Properties.Tracer.Transparency * 10,
	Min = 1,
	Max = 10,
	Callback = CreateSliderCallback(ESP_Properties.Tracer, "Transparency", 10)
})

Tracer_Properties_Section:Slider({
	Name = "Thickness",
	Flag = "Tracer_Thickness",
	Default = ESP_Properties.Tracer.Thickness,
	Min = 1,
	Max = 5,
	Callback = CreateSliderCallback(ESP_Properties.Tracer, "Thickness")
})

local HeadDot_Properties_Section = _ESP:Section({Name = "Head Dot Properties", Side = "Left"})

AddValues(HeadDot_Properties_Section, ESP_Properties.HeadDot, {}, "HeadDot_Properties_")

HeadDot_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "HeadDot_Transparency",
	Default = ESP_Properties.HeadDot.Transparency * 10,
	Min = 1,
	Max = 10,
	Callback = CreateSliderCallback(ESP_Properties.HeadDot, "Transparency", 10)
})

HeadDot_Properties_Section:Slider({
	Name = "Thickness",
	Flag = "HeadDot_Thickness",
	Default = ESP_Properties.HeadDot.Thickness,
	Min = 1,
	Max = 5,
	Callback = CreateSliderCallback(ESP_Properties.HeadDot, "Thickness")
})

HeadDot_Properties_Section:Slider({
	Name = "Sides",
	Flag = "HeadDot_Sides",
	Default = ESP_Properties.HeadDot.NumSides,
	Min = 3,
	Max = 30,
	Callback = CreateSliderCallback(ESP_Properties.HeadDot, "NumSides")
})

local Box_Properties_Section = _ESP:Section({Name = "Box Properties", Side = "Left"})

AddValues(Box_Properties_Section, ESP_Properties.Box, {}, "Box_Properties_")

Box_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "Box_Transparency",
	Default = ESP_Properties.Box.Transparency * 10,
	Min = 1,
	Max = 10,
	Callback = CreateSliderCallback(ESP_Properties.Box, "Transparency", 10)
})

Box_Properties_Section:Slider({
	Name = "Thickness",
	Flag = "Box_Thickness",
	Default = ESP_Properties.Box.Thickness,
	Min = 1,
	Max = 5,
	Callback = CreateSliderCallback(ESP_Properties.Box, "Thickness")
})

local HealthBar_Properties_Section = _ESP:Section({Name = "Health Bar Properties", Side = "Right"})

AddValues(HealthBar_Properties_Section, ESP_Properties.HealthBar, {}, "HealthBar_Properties_")

HealthBar_Properties_Section:Dropdown({
	Name = "Position",
	Flag = "HealthBar_Position",
	Content = HEALTHBAR_POSITIONS,
	Default = HEALTHBAR_POSITIONS[ESP_Properties.HealthBar.Position],
	Callback = function(Value)
		ESP_Properties.HealthBar.Position = tablefind(HEALTHBAR_POSITIONS, Value)
	end
})

HealthBar_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "HealthBar_Transparency",
	Default = ESP_Properties.HealthBar.Transparency * 10,
	Min = 1,
	Max = 10,
	Callback = CreateSliderCallback(ESP_Properties.HealthBar, "Transparency", 10)
})

HealthBar_Properties_Section:Slider({
	Name = "Thickness",
	Flag = "HealthBar_Thickness",
	Default = ESP_Properties.HealthBar.Thickness,
	Min = 1,
	Max = 5,
	Callback = CreateSliderCallback(ESP_Properties.HealthBar, "Thickness")
})

HealthBar_Properties_Section:Slider({
	Name = "Offset",
	Flag = "HealthBar_Offset",
	Default = ESP_Properties.HealthBar.Offset,
	Min = 4,
	Max = 12,
	Callback = CreateSliderCallback(ESP_Properties.HealthBar, "Offset")
})

HealthBar_Properties_Section:Slider({
	Name = "Blue",
	Flag = "HealthBar_Blue",
	Default = ESP_Properties.HealthBar.Blue,
	Min = 0,
	Max = 255,
	Callback = CreateSliderCallback(ESP_Properties.HealthBar, "Blue")
})

local Chams_Properties_Section = _ESP:Section({Name = "Chams Properties", Side = "Right"})

AddValues(Chams_Properties_Section, ESP_Properties.Chams, {}, "Chams_Properties_")

Chams_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "Chams_Transparency",
	Default = ESP_Properties.Chams.Transparency * 10,
	Min = 1,
	Max = 10,
	Callback = CreateSliderCallback(ESP_Properties.Chams, "Transparency", 10)
})

Chams_Properties_Section:Slider({
	Name = "Thickness",
	Flag = "Chams_Thickness",
	Default = ESP_Properties.Chams.Thickness,
	Min = 1,
	Max = 5,
	Callback = CreateSliderCallback(ESP_Properties.Chams, "Thickness")
})

--// Crosshair Tab
local Crosshair_Settings = _Crosshair:Section({Name = "Crosshair Settings (1 / 2)", Side = "Left"})

Crosshair_Settings:Toggle({
	Name = "Enabled",
	Flag = "Crosshair_Enabled",
	Default = Crosshair.Enabled,
	Callback = CreateToggleCallback(Crosshair, "Enabled")
})

Crosshair_Settings:Toggle({
	Name = "Enable ROBLOX Cursor",
	Flag = "Cursor_Enabled",
	Default = UserInputService.MouseIconEnabled,
	Callback = SetMouseIconVisibility
})

AddValues(Crosshair_Settings, Crosshair, {"Enabled"}, "Crosshair_")

Crosshair_Settings:Dropdown({
	Name = "Position",
	Flag = "Crosshair_Position",
	Content = CROSSHAIR_POSITIONS,
	Default = CROSSHAIR_POSITIONS[Crosshair.Position],
	Callback = function(Value)
		Crosshair.Position = Value == "Mouse" and 1 or 2
	end
})

Crosshair_Settings:Slider({
	Name = "Size",
	Flag = "Crosshair_Size",
	Default = Crosshair.Size,
	Min = 1,
	Max = 24,
	Callback = CreateSliderCallback(Crosshair, "Size")
})

Crosshair_Settings:Slider({
	Name = "Gap Size",
	Flag = "Crosshair_GapSize",
	Default = Crosshair.GapSize,
	Min = 0,
	Max = 24,
	Callback = CreateSliderCallback(Crosshair, "GapSize")
})

Crosshair_Settings:Slider({
	Name = "Rotation (Degrees)",
	Flag = "Crosshair_Rotation",
	Default = Crosshair.Rotation,
	Min = -180,
	Max = 180,
	Callback = CreateSliderCallback(Crosshair, "Rotation")
})

Crosshair_Settings:Slider({
	Name = "Rotation Speed",
	Flag = "Crosshair_RotationSpeed",
	Default = Crosshair.RotationSpeed,
	Min = 1,
	Max = 20,
	Callback = CreateSliderCallback(Crosshair, "RotationSpeed")
})

Crosshair_Settings:Slider({
	Name = "Pulsing Step",
	Flag = "Crosshair_PulsingStep",
	Default = Crosshair.PulsingStep,
	Min = 0,
	Max = 24,
	Callback = CreateSliderCallback(Crosshair, "PulsingStep")
})

local _Crosshair_Settings = _Crosshair:Section({Name = "Crosshair Settings (2 / 2)", Side = "Left"})

_Crosshair_Settings:Slider({
	Name = "Pulsing Speed",
	Flag = "Crosshair_PulsingSpeed",
	Default = Crosshair.PulsingSpeed,
	Min = 1,
	Max = 20,
	Callback = CreateSliderCallback(Crosshair, "PulsingSpeed")
})

_Crosshair_Settings:Slider({
	Name = "Pulsing Boundary (Min)",
	Flag = "Crosshair_Pulse_Min",
	Default = Crosshair.PulsingBounds[1],
	Min = 0,
	Max = 24,
	Callback = function(Value)
		Crosshair.PulsingBounds[1] = Value
	end
})

_Crosshair_Settings:Slider({
	Name = "Pulsing Boundary (Max)",
	Flag = "Crosshair_Pulse_Max",
	Default = Crosshair.PulsingBounds[2],
	Min = 0,
	Max = 24,
	Callback = function(Value)
		Crosshair.PulsingBounds[2] = Value
	end
})

_Crosshair_Settings:Slider({
	Name = "Transparency",
	Flag = "Crosshair_Transparency",
	Default = Crosshair.Transparency * 10,
	Min = 1,
	Max = 10,
	Callback = CreateSliderCallback(Crosshair, "Transparency", 10)
})

_Crosshair_Settings:Slider({
	Name = "Thickness",
	Flag = "Crosshair_Thickness",
	Default = Crosshair.Thickness,
	Min = 1,
	Max = 5,
	Callback = CreateSliderCallback(Crosshair, "Thickness")
})

local Crosshair_CenterDot = _Crosshair:Section({Name = "Center Dot Settings", Side = "Right"})

Crosshair_CenterDot:Toggle({
	Name = "Enabled",
	Flag = "Crosshair_CenterDot_Enabled",
	Default = CenterDot.Enabled,
	Callback = CreateToggleCallback(CenterDot, "Enabled")
})

AddValues(Crosshair_CenterDot, CenterDot, {"Enabled"}, "Crosshair_CenterDot_")

Crosshair_CenterDot:Slider({
	Name = "Size / Radius",
	Flag = "Crosshair_CenterDot_Radius",
	Default = CenterDot.Radius,
	Min = 2,
	Max = 8,
	Callback = CreateSliderCallback(CenterDot, "Radius")
})

Crosshair_CenterDot:Slider({
	Name = "Sides",
	Flag = "Crosshair_CenterDot_Sides",
	Default = CenterDot.NumSides,
	Min = 3,
	Max = 30,
	Callback = CreateSliderCallback(CenterDot, "NumSides")
})

Crosshair_CenterDot:Slider({
	Name = "Transparency",
	Flag = "Crosshair_CenterDot_Transparency",
	Default = CenterDot.Transparency * 10,
	Min = 1,
	Max = 10,
	Callback = CreateSliderCallback(CenterDot, "Transparency", 10)
})

Crosshair_CenterDot:Slider({
	Name = "Thickness",
	Flag = "Crosshair_CenterDot_Thickness",
	Default = CenterDot.Thickness,
	Min = 1,
	Max = 5,
	Callback = CreateSliderCallback(CenterDot, "Thickness")
})

--// Settings Tab
local SettingsSection = Settings:Section({Name = "Settings", Side = "Left"})
local ProfilesSection = Settings:Section({Name = "Profiles", Side = "Left"})
local InformationSection = Settings:Section({Name = "Information", Side = "Right"})

SettingsSection:Keybind({
	Name = "Show / Hide GUI",
	Flag = "UI Toggle",
	Default = Enum.KeyCode.RightShift,
	Blacklist = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3},
	Callback = function(_, NewKeybind)
		if not NewKeybind then
			GUI:Close()
		end
	end
})

SettingsSection:Button({
	Name = "Unload Script",
	Callback = function()
		GUI:Unload()
		ESP:Exit()
		Aimbot:Exit()
		getgenv().AirHubV2Loaded = nil
	end
})

local ConfigList = ProfilesSection:Dropdown({
	Name = "Configurations",
	Flag = "Config Dropdown",
	Content = GUI:GetConfigs()
})

ProfilesSection:Box({
	Name = "Configuration Name",
	Flag = "Config Name",
	Placeholder = "Config Name"
})

ProfilesSection:Button({
	Name = "Load Configuration",
	Callback = function()
		GUI:LoadConfig(GUI.flags["Config Dropdown"])
	end
})

ProfilesSection:Button({
	Name = "Delete Configuration",
	Callback = function()
		GUI:DeleteConfig(GUI.flags["Config Dropdown"])
		ConfigList:Refresh(GUI:GetConfigs())
	end
})

ProfilesSection:Button({
	Name = "Save Configuration",
	Callback = function()
		GUI:SaveConfig(GUI.flags["Config Dropdown"] or GUI.flags["Config Name"])
		ConfigList:Refresh(GUI:GetConfigs())
	end
})

InformationSection:Label("Made by Exunys")

InformationSection:Button({
	Name = "Copy GitHub",
	Callback = function()
		setclipboard("https://github.com/Exunys")
	end
})

InformationSection:Label("AirTeam © 2022 - "..osdate("%Y"))

InformationSection:Button({
	Name = "Copy Discord Invite",
	Callback = function()
		setclipboard("https://discord.gg/Ncz3H3quUZ")
	end
})

--// Finalization
ESP.Load()
Aimbot.Load()
getgenv().AirHubV2Loaded = true
getgenv().AirHubV2Loading = nil

GeneralSignal:Fire()
GUI:Close()
