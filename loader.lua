--[[
	MyHub v2.0 loader — single-file entry point for loadstring usage:

	    loadstring(game:HttpGet("https://raw.githubusercontent.com/Konmeo22132-alt/Ui-lib/main/loader.lua"))()

	Fetches the HuneUI library from this repo, then builds the MyHub v2.0
	window (same content as Example.client.lua).
]]

local REPO = "https://raw.githubusercontent.com/Konmeo22132-alt/Ui-lib/main/"

local source = game:HttpGet(REPO .. "HuneUI.lua")
local HuneUI = loadstring(source)()
assert(type(HuneUI) == "table" and HuneUI.Create, "[MyHub] failed to load HuneUI library")

---------------------------------------------------------------------
-- Window
---------------------------------------------------------------------

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

---------------------------------------------------------------------
-- Combat controls
---------------------------------------------------------------------

combat:Toggle({
	Name = "Speed Hack",
	Description = "Increase your movement speed.",
	Default = true,
	Callback = function(enabled)
		print("[MyHub] Speed Hack:", enabled)
	end,
})

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

combat:Dropdown({
	Name = "Aura Type",
	Options = { "Ring", "Nova", "Pulse", "Orbit" },
	Default = "Ring",
	Callback = function(option)
		print("[MyHub] Aura Type:", option)
	end,
})

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

combat:Input({
	Name = "Custom Tag",
	Placeholder = "Enter your custom tag...",
	Icon = "tag",
	Callback = function(text)
		print("[MyHub] Custom Tag:", text)
	end,
})

---------------------------------------------------------------------
-- Reference toast + toggle keybind
---------------------------------------------------------------------

Window:Notify({
	Title = "Settings saved",
	Subtitle = "Your changes have been applied.",
})

local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightShift then
		local gui = Window._screenGui
		gui.Enabled = not gui.Enabled
	end
end)
