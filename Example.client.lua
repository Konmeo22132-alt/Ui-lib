--[[
	HuneUI example — reproduces the "MyHub v2.0" reference mockup.

	Install:
	  1. Put HuneUI.lua into ReplicatedStorage as a ModuleScript named "HuneUI".
	  2. Put this file into StarterPlayerScripts as a LocalScript named "Example".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HuneUI = require(ReplicatedStorage:WaitForChild("HuneUI"))

local Window = HuneUI.Create({
	Title = "MyHub v2.0",
	Subtitle = "by KONMEO",
	Size = UDim2.fromOffset(940, 712),
	Backdrop = true, -- #0D0D0F viewport background, as in the reference
})

-- Navigation rail tabs (Combat is created first, so it starts active)
local combat = Window:Tab("Combat", "zap")
Window:Tab("Defense", "shield")
Window:Tab("Settings", "settings")
Window:Tab("Profile", "user")

-- Control group 1: Speed Hack (ON by default)
combat:Toggle({
	Name = "Speed Hack",
	Description = "Increase your movement speed.",
	Default = true,
	Callback = function(enabled)
		print("[MyHub] Speed Hack:", enabled)
	end,
})

-- Control group 2: Walk Speed (250 / 350 -> thumb at ~70%)
combat:Slider({
	Name = "Walk Speed",
	Min = 0,
	Max = 350,
	Default = 250,
	Suffix = "stud/s",
	Callback = function(value)
		print("[MyHub] Walk Speed:", value)
	end,
})

-- Control group 3: Aura Type
combat:Dropdown({
	Name = "Aura Type",
	Options = { "Ring", "Nova", "Pulse", "Orbit" },
	Default = "Ring",
	Callback = function(option)
		print("[MyHub] Aura Type:", option)
	end,
})

-- Control group 4: Action buttons
combat:ButtonGroup({
	Buttons = {
		{
			Name = "Teleport",
			Icon = "send",
			Variant = "Primary",
			Callback = function()
				Window:Notify({
					Title = "Teleported",
					Subtitle = "You were moved to the target position.",
				})
			end,
		},
		{
			Name = "Reset",
			Icon = "rotate-cw",
			Variant = "Secondary",
			Callback = function()
				Window:Notify({
					Title = "Settings reset",
					Subtitle = "Combat settings were restored to defaults.",
				})
			end,
		},
	},
})

-- Control group 5: Custom Tag
combat:Input({
	Name = "Custom Tag",
	Placeholder = "Enter your custom tag...",
	Icon = "tag",
	Callback = function(text)
		print("[MyHub] Custom Tag:", text)
	end,
})

-- Reference toast (top-right of the viewport)
Window:Notify({
	Title = "Settings saved",
	Subtitle = "Your changes have been applied.",
})

-- Toggle window visibility with RightShift
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightShift then
		local gui = Window._screenGui
		gui.Enabled = not gui.Enabled
	end
end)
