--[[
	HuneUI — compact premium dark UI library for Roblox
	Implements the "MyHub v2.0" design specification.

	Place this ModuleScript in ReplicatedStorage as "HuneUI".
	See Example.client.lua for usage.

	Everything is self-contained: icons are drawn as vector primitives
	(capsules / rings / discs) inside CanvasGroups — no external image
	assets are required.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HuneUI = {}
HuneUI.Version = "2.0.0"

--=====================================================================================
-- Theme tokens (design spec §6) — centralized; do not duplicate these downstream
--=====================================================================================

local Theme = {
	Background    = Color3.fromHex("#0D0D0F"), -- viewport background
	Surface       = Color3.fromHex("#141418"), -- main window and toast
	SurfaceRaised = Color3.fromHex("#1E1E24"), -- inputs, dropdown, secondary surfaces
	Track         = Color3.fromHex("#23252D"), -- slider inactive track / toggle off

	TextPrimary   = Color3.fromHex("#F4F6FA"),
	TextSecondary = Color3.fromHex("#A5ADBD"),
	TextMuted     = Color3.fromHex("#7E8799"),

	Border        = Color3.fromRGB(180, 190, 210), -- used with BorderTransparency
	Divider       = Color3.fromRGB(180, 190, 210), -- used with DividerTransparency
	BorderTransparency      = 1 - 0.16,
	DividerTransparency     = 1 - 0.14,

	AccentBlue  = Color3.fromHex("#4B9EFF"),
	AccentCyan  = Color3.fromHex("#24B8F2"),
	AccentPurple = Color3.fromHex("#6557F5"),
	White       = Color3.fromHex("#FFFFFF"),
}

local FONT_FAMILY = "rbxasset://fonts/families/GothamSSm.json"
local Fonts = {
	SemiBold = Font.new(FONT_FAMILY, Enum.FontWeight.SemiBold),
	Medium   = Font.new(FONT_FAMILY, Enum.FontWeight.Medium),
	Regular  = Font.new(FONT_FAMILY, Enum.FontWeight.Regular),
}

--=====================================================================================
-- Small construction helpers
--=====================================================================================

local function New(class, props, parent)
	local inst = Instance.new(class)
	for key, value in pairs(props) do
		inst[key] = value
	end
	if parent ~= nil then
		inst.Parent = parent
	end
	return inst
end

local function Corner(parent, radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function Stroke(parent, color, thickness, transparency)
	return New("UIStroke", {
		Color = color or Theme.Border,
		Thickness = thickness or 1,
		Transparency = transparency or Theme.BorderTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function Pad(parent, left, top, right, bottom)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
	}, parent)
end

local function TextLabel(props, parent)
	local base = {
		BackgroundTransparency = 1,
		FontFace = Fonts.Medium,
		TextColor3 = Theme.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}
	for key, value in pairs(props) do
		base[key] = value
	end
	return New("TextLabel", base, parent)
end

-- Spaces out letters to fake letter-spacing ("COMBAT" -> "C O M B A T")
local function spaced(s)
	return (s:gsub(".", "%1 "):gsub("%s+$", ""))
end

local function tween(inst, time, props, style, direction)
	local info = TweenInfo.new(
		time,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

--=====================================================================================
-- Vector icons (Lucide-style, 24x24 design grid, drawn from primitives)
-- Primitives:
--   seg(x1,y1,x2,y2,w)   capsule line from (x1,y1) to (x2,y2), thickness w
--   ring(cx,cy,r,w)      circle outline, radius r, thickness w
--   disc(cx,cy,r)        filled circle
--   square(cx,cy,s,rot,radius,w) rounded-square outline, rotated
--=====================================================================================

local function seg(x1, y1, x2, y2, w)
	local dx, dy = x2 - x1, y2 - y1
	return {
		kind = "seg",
		cx = (x1 + x2) / 2,
		cy = (y1 + y2) / 2,
		len = math.sqrt(dx * dx + dy * dy),
		w = w,
		rot = math.deg(math.atan2(dy, dx)),
	}
end

local function ring(cx, cy, r, w)
	return { kind = "ring", cx = cx, cy = cy, r = r, w = w }
end

local function disc(cx, cy, r)
	return { kind = "disc", cx = cx, cy = cy, r = r }
end

local function square(cx, cy, s, rot, radius, w)
	return { kind = "square", cx = cx, cy = cy, s = s, rot = rot, radius = radius, w = w }
end

local ICON_DEFS = {}

ICON_DEFS["zap"] = function()
	return {
		seg(12.8, 3.5, 6.2, 12.8, 5.2),
		seg(12.2, 11.2, 10.2, 20.5, 5.2),
	}
end

ICON_DEFS["shield"] = function()
	return {
		seg(5.2, 6.2, 12, 3.6, 2),
		seg(12, 3.6, 18.8, 6.2, 2),
		seg(5.2, 6.2, 5.2, 13, 2),
		seg(18.8, 6.2, 18.8, 13, 2),
		seg(5.2, 13, 12, 20.6, 2),
		seg(18.8, 13, 12, 20.6, 2),
	}
end

ICON_DEFS["settings"] = function()
	local parts = { ring(12, 12, 6.2, 2.2), ring(12, 12, 2.3, 2) }
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local c, s = math.cos(a), math.sin(a)
		table.insert(parts, seg(12 + 6.2 * c, 12 + 6.2 * s, 12 + 9.0 * c, 12 + 9.0 * s, 2.2))
	end
	return parts
end

ICON_DEFS["user"] = function()
	return {
		ring(12, 7.6, 3.5, 2),
		ring(12, 23, 8, 2), -- shoulders; lower half clipped by the icon canvas
	}
end

ICON_DEFS["send"] = function()
	return {
		seg(21.5, 2.5, 14.8, 21.5, 2),
		seg(21.5, 2.5, 2.5, 9.2, 2),
		seg(14.8, 21.5, 11, 12.6, 2),
		seg(11, 12.6, 2.5, 9.2, 2),
		seg(21.5, 2.5, 11, 12.6, 2),
	}
end

ICON_DEFS["rotate-cw"] = function()
	return {
		ring(12, 12, 7.6, 2),
		seg(20.8, 3.2, 20.8, 8.4, 2),
		seg(20.8, 8.4, 15.8, 8.4, 2),
	}
end

ICON_DEFS["tag"] = function()
	return {
		square(11.2, 11.2, 11.5, 45, 3, 2),
		disc(9.2, 9.2, 1.35),
	}
end

ICON_DEFS["chevron-down"] = function()
	return {
		seg(6.2, 9.4, 12, 15.2, 2.2),
		seg(12, 15.2, 17.8, 9.4, 2.2),
	}
end

ICON_DEFS["check"] = function()
	return {
		seg(4.8, 12.6, 9.8, 17.4, 2.4),
		seg(9.8, 17.4, 19.2, 7.2, 2.4),
	}
end

ICON_DEFS["x"] = function()
	return {
		seg(6.4, 6.4, 17.6, 17.6, 2.2),
		seg(17.6, 6.4, 6.4, 17.6, 2.2),
	}
end

ICON_DEFS["minus"] = function()
	return {
		seg(5.6, 12, 18.4, 12, 2.2),
	}
end

ICON_DEFS["circle"] = function()
	return {
		ring(12, 12, 8, 2),
	}
end

-- Builds `name` at `px` pixels. Art is white; tint via CanvasGroup.GroupColor3.
local function buildIcon(name, px, parent)
	local def = ICON_DEFS[name]
	assert(def, "[HuneUI] unknown icon: " .. tostring(name))

	local canvas = New("CanvasGroup", {
		Name = "Icon_" .. name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(px, px),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ClipsDescendants = true,
		BorderSizePixel = 0,
		GroupColor3 = Color3.new(1, 1, 1),
	}, parent)

	local s = px / 24
	for _, p in ipairs(def()) do
		if p.kind == "seg" then
			local bar = New("Frame", {
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(p.cx * s, p.cy * s),
				Size = UDim2.fromOffset(math.max(p.len * s, 1), math.max(p.w * s, 1)),
				Rotation = p.rot,
			}, canvas)
			Corner(bar, math.max(p.w * s / 2, 0.5))
		elseif p.kind == "ring" then
			local d = p.r * 2 * s
			local c = New("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(p.cx * s, p.cy * s),
				Size = UDim2.fromOffset(d, d),
				BorderSizePixel = 0,
			}, canvas)
			Corner(c, d / 2) -- full round
			Stroke(c, Color3.new(1, 1, 1), math.max(p.w * s, 1), 0)
		elseif p.kind == "disc" then
			local d = p.r * 2 * s
			local c = New("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(p.cx * s, p.cy * s),
				Size = UDim2.fromOffset(d, d),
			}, canvas)
			Corner(c, d / 2)
		elseif p.kind == "square" then
			local c = New("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(p.cx * s, p.cy * s),
				Size = UDim2.fromOffset(p.s * s, p.s * s),
				Rotation = p.rot,
				BorderSizePixel = 0,
			}, canvas)
			Corner(c, p.radius * s)
			Stroke(c, Color3.new(1, 1, 1), math.max(p.w * s, 1), 0)
		end
	end

	return canvas
end

--=====================================================================================
-- Window
--=====================================================================================

local WindowMetatable = {}
WindowMetatable.__index = WindowMetatable

local TITLEBAR_HEIGHT = 68
local RAIL_WIDTH = 184
local SHADOW_MARGIN = 12 -- shadow layers live in this margin around the root

local TOAST_WIDTH = 400
local TOAST_HEIGHT = 64
local TOAST_GAP = 10

function HuneUI.Create(config)
	config = config or {}

	local player = Players.LocalPlayer
	assert(player, "[HuneUI] HuneUI.Create must be called from a LocalScript")

	local screenGui = New("ScreenGui", {
		Name = config.Name or "HuneUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, config.Parent or player:WaitForChild("PlayerGui"))

	-- Optional full-viewport backdrop (spec viewport color)
	if config.Backdrop then
		New("Frame", {
			Name = "Backdrop",
			BackgroundColor3 = Theme.Background,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, screenGui)
	end

	-- Container holds shadow layers + the root window, and is what gets dragged.
	local container = New("Frame", {
		Name = "WindowContainer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(940 + SHADOW_MARGIN * 2, 712 + SHADOW_MARGIN * 2),
	}, screenGui)

	local scale = New("UIScale", { Scale = 1 }, container)

	-- Soft layered shadow (restrained, no bloom)
	for i, info in ipairs({
		{ grow = 2, transparency = 0.88 },
		{ grow = 6, transparency = 0.93 },
		{ grow = 10, transparency = 0.965 },
	}) do
		New("Frame", {
			Name = "Shadow" .. i,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = info.transparency,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, info.grow * 2, 1, info.grow * 2),
			ZIndex = 0,
		}, container)
	end

	local root = New("Frame", {
		Name = "Window",
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -SHADOW_MARGIN * 2, 1, -SHADOW_MARGIN * 2),
		ClipsDescendants = true,
		ZIndex = 1,
	}, container)
	Corner(root, 12)
	Stroke(root, Theme.Border, 1, Theme.BorderTransparency)

	local size = config.Size or UDim2.fromOffset(940, 712)
	container.Size = UDim2.fromOffset(
		size.X.Offset + SHADOW_MARGIN * 2,
		size.Y.Offset + SHADOW_MARGIN * 2
	)

	---------------------------------------------------------------------------------
	-- Title bar
	---------------------------------------------------------------------------------

	local titleBar = New("Frame", {
		Name = "TitleBar",
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, TITLEBAR_HEIGHT),
		ZIndex = 2,
	}, root)

	-- Geometric app mark: two slanted gradient bars
	local mark = New("Frame", {
		Name = "AppMark",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 26, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(26, 26),
		ZIndex = 3,
	}, titleBar)
	local markA = New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 9, 0, 13),
		Size = UDim2.fromOffset(7, 20),
		Rotation = 22,
		ZIndex = 3,
	}, mark)
	Corner(markA, 2)
	New("UIGradient", {
		Color = ColorSequence.new(Theme.AccentCyan, Theme.AccentPurple),
		Rotation = 90,
	}, markA)
	local markB = New("Frame", {
		BackgroundColor3 = Theme.AccentBlue,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 17, 0, 15),
		Size = UDim2.fromOffset(7, 15),
		Rotation = 22,
		ZIndex = 3,
	}, mark)
	Corner(markB, 2)

	TextLabel({
		Name = "Title",
		Position = UDim2.new(0, 62, 0, 17),
		Size = UDim2.new(1, -160, 0, 20),
		FontFace = Fonts.SemiBold,
		TextSize = 18,
		Text = config.Title or "MyHub v2.0",
		ZIndex = 3,
	}, titleBar)

	TextLabel({
		Name = "Subtitle",
		Position = UDim2.new(0, 62, 0, 37),
		Size = UDim2.new(1, -160, 0, 14),
		FontFace = Fonts.Regular,
		TextSize = 12,
		TextColor3 = Theme.TextSecondary,
		Text = config.Subtitle or "",
		ZIndex = 3,
	}, titleBar)

	-- Window control buttons (minimize / close)
	local function windowButton(iconName, xOffset)
		local btn = New("TextButton", {
			Name = "Btn_" .. iconName,
			Text = "",
			BackgroundColor3 = Theme.SurfaceRaised,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			AutoButtonColor = false,
			ZIndex = 3,
		}, titleBar)
		Corner(btn, 8)
		local icon = buildIcon(iconName, 16, btn)
		icon.ZIndex = 3
		icon.GroupColor3 = Theme.TextSecondary
		btn.MouseEnter:Connect(function()
			tween(btn, 0.12, { BackgroundTransparency = 0.4 })
			tween(icon, 0.12, { GroupColor3 = Theme.TextPrimary })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, 0.15, { BackgroundTransparency = 1 })
			tween(icon, 0.15, { GroupColor3 = Theme.TextSecondary })
		end)
		return btn, icon
	end

	local minimizeBtn = windowButton("minus", 52)
	local closeBtn = windowButton("x", 14)

	-- Divider under the title bar
	New("Frame", {
		Name = "TitleDivider",
		BackgroundColor3 = Theme.Divider,
		BackgroundTransparency = Theme.DividerTransparency,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, TITLEBAR_HEIGHT),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 2,
	}, root)

	---------------------------------------------------------------------------------
	-- Body: navigation rail + content panel
	---------------------------------------------------------------------------------

	local rail = New("Frame", {
		Name = "NavRail",
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, TITLEBAR_HEIGHT),
		Size = UDim2.new(0, RAIL_WIDTH, 1, -TITLEBAR_HEIGHT),
		ZIndex = 2,
	}, root)

	New("Frame", { -- vertical divider between rail and content
		Name = "RailDivider",
		BackgroundColor3 = Theme.Divider,
		BackgroundTransparency = Theme.DividerTransparency,
		BorderSizePixel = 0,
		Position = UDim2.new(0, RAIL_WIDTH, 0, TITLEBAR_HEIGHT),
		Size = UDim2.new(0, 1, 1, -TITLEBAR_HEIGHT),
		ZIndex = 2,
	}, root)

	New("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, rail)
	Pad(rail, 0, 16, 14, 0) -- right padding leaves room beside the pill (rail 184 = 170 pill + 14)

	local content = New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, RAIL_WIDTH + 1, 0, TITLEBAR_HEIGHT),
		Size = UDim2.new(1, -(RAIL_WIDTH + 1), 1, -TITLEBAR_HEIGHT),
		ClipsDescendants = true,
		ZIndex = 2,
	}, root)

	local scroll = New("ScrollingFrame", {
		Name = "ContentScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.TextMuted,
		ScrollBarImageTransparency = 0.4,
		ZIndex = 2,
	}, content)
	Pad(scroll, 30, 24, 30, 24)

	---------------------------------------------------------------------------------
	-- Tabs
	---------------------------------------------------------------------------------

	local self = setmetatable({
		_screenGui = screenGui,
		_container = container,
		_root = root,
		_scale = scale,
		_tabs = {},
		_activeTab = nil,
		_collapsed = false,
		_closed = false,
		_restoredHeight = container.Size.Y.Offset,
		_toasts = {},
		_onClosed = nil,
	}, WindowMetatable)

	local function setTabActive(tab, active)
		tab._active = active
		-- Pill background
		tween(tab._pill, 0.2, { BackgroundTransparency = active and 0 or 1 })
		-- Blue left-edge indicator (+ subtle glow)
		tween(tab._indicator, 0.2, {
			BackgroundTransparency = active and 0 or 1,
		})
		tween(tab._indicatorGlow, 0.2, {
			BackgroundTransparency = active and 0.72 or 1,
		})
		-- Icon + label
		tween(tab._icon, 0.2, {
			GroupColor3 = active and Theme.AccentBlue or Theme.TextSecondary,
		})
		tween(tab._label, 0.2, {
			TextTransparency = active and 0 or 1,
			TextColor3 = active and Theme.TextPrimary or Theme.TextSecondary,
		})
		tab._page.Visible = active
	end

	function self:Tab(name, iconName)
		iconName = iconName or "circle"
		local order = #self._tabs + 1

		local page = New("Frame", {
			Name = "Page_" .. name,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = false,
			ZIndex = 2,
		}, scroll)
		local pageList = New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, page)

		-- Section heading (eyebrow + heading + divider)
		local heading = New("Frame", {
			Name = "Heading",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			ZIndex = 2,
		}, page)
		TextLabel({
			Name = "Eyebrow",
			FontFace = Fonts.Medium,
			TextSize = 12,
			TextColor3 = Theme.TextSecondary,
			Text = spaced(string.upper(name)),
			Position = UDim2.new(0, 0, 0, 4),
			Size = UDim2.new(1, 0, 0, 14),
			ZIndex = 2,
		}, heading)
		TextLabel({
			Name = "Heading",
			FontFace = Fonts.SemiBold,
			TextSize = 28,
			Text = name,
			Position = UDim2.new(0, 0, 0, 24),
			Size = UDim2.new(1, 0, 0, 34),
			ZIndex = 2,
		}, heading)
		New("Frame", { -- divider beneath the heading
			Name = "HeadingDivider",
			BackgroundColor3 = Theme.Divider,
			BackgroundTransparency = Theme.DividerTransparency,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 72),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 2,
		}, heading)
		Pad(heading, 0, 0, 0, 4)

		-- Navigation tab button
		local tabBtn = New("TextButton", {
			Name = "Tab_" .. name,
			Text = "",
			BackgroundColor3 = Theme.SurfaceRaised,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(170, 46),
			AutoButtonColor = false,
			LayoutOrder = order,
			ZIndex = 2,
		}, rail)
		Corner(tabBtn, 10)

		-- Blue indicator on the window's left edge, behind the pill
		-- The rail has no left padding, so tabBtn x=0 is the window's left edge
		local indicatorGlow = New("Frame", {
			Name = "IndicatorGlow",
			BackgroundColor3 = Theme.AccentBlue,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(7, 46),
			ZIndex = 2,
		}, tabBtn)
		Corner(indicatorGlow, 4)
		local indicator = New("Frame", {
			Name = "Indicator",
			BackgroundColor3 = Theme.AccentBlue,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 46),
			ZIndex = 2,
		}, tabBtn)
		Corner(indicator, 2)

		local icon = buildIcon(iconName, 20, tabBtn)
		icon.Position = UDim2.new(0, 32, 0.5, 0)
		icon.GroupColor3 = Theme.TextSecondary
		icon.ZIndex = 3

		local label = TextLabel({
			Name = "Label",
			FontFace = Fonts.Medium,
			TextSize = 15,
			Text = name,
			TextTransparency = 1,
			Position = UDim2.new(0, 52, 0, 0),
			Size = UDim2.new(1, -60, 1, 0),
			ZIndex = 3,
		}, tabBtn)

		local tab = setmetatable({
			Name = name,
			_page = page,
			_btn = tabBtn,
			_pill = tabBtn,
			_indicator = indicator,
			_indicatorGlow = indicatorGlow,
			_icon = icon,
			_label = label,
			_active = false,
			_order = 2, -- next LayoutOrder inside the page (1 = heading)
		}, WindowMetatable)

		tabBtn.MouseButton1Click:Connect(function()
			if self._activeTab ~= tab then
				local previous = self._activeTab
				self._activeTab = tab
				if previous then
					setTabActive(previous, false)
				end
				setTabActive(tab, true)
			end
		end)

		-- Rest-state hover for inactive tabs
		tabBtn.MouseEnter:Connect(function()
			if not tab._active then
				tween(tabBtn, 0.12, { BackgroundTransparency = 0.72 })
			end
		end)
		tabBtn.MouseLeave:Connect(function()
			if not tab._active then
				tween(tabBtn, 0.15, { BackgroundTransparency = 1 })
			end
		end)

		-- Internal: adds a divider above the next control group (groups after the first)
		function tab._nextOrder(withDivider)
			local orderInPage = tab._order
			if withDivider and orderInPage > 2 then
				local dividerRow = New("Frame", {
					Name = "DividerRow",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 29),
					LayoutOrder = orderInPage,
					ZIndex = 2,
				}, page)
				New("Frame", {
					BackgroundColor3 = Theme.Divider,
					BackgroundTransparency = Theme.DividerTransparency,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.new(1, 0, 0, 1),
					ZIndex = 2,
				}, dividerRow)
				orderInPage += 1
			end
			tab._order = orderInPage + 1
			return orderInPage
		end

		table.insert(self._tabs, tab)

		if order == 1 then
			self._activeTab = tab
			setTabActive(tab, true)
		end
		return tab
	end

	---------------------------------------------------------------------------------
	-- Components
	---------------------------------------------------------------------------------

	function WindowMetatable.Toggle(tab, opts) -- luau-ignore
		opts = opts or {}
		local order = tab._nextOrder(true)

		local row = New("Frame", {
			Name = "Toggle_" .. (opts.Name or ""),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = order,
			ZIndex = 2,
		}, tab._page)

		TextLabel({
			FontFace = Fonts.Medium,
			TextSize = 16,
			Text = opts.Name or "Toggle",
			Position = UDim2.new(0, 0, 0, 8),
			Size = UDim2.new(1, -80, 0, 20),
			ZIndex = 2,
		}, row)
		TextLabel({
			FontFace = Fonts.Regular,
			TextSize = 13,
			TextColor3 = Theme.TextSecondary,
			Text = opts.Description or "",
			Position = UDim2.new(0, 0, 0, 30),
			Size = UDim2.new(1, -80, 0, 16),
			ZIndex = 2,
		}, row)

		local state = opts.Default == true
		local track = New("TextButton", {
			Name = "Track",
			Text = "",
			BackgroundColor3 = state and Theme.AccentBlue or Theme.Track,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(46, 26),
			AutoButtonColor = false,
			ZIndex = 2,
		}, row)
		Corner(track, 13)
		local trackStroke = Stroke(track, Theme.AccentBlue, 1, state and 0.45 or 1)

		local thumb = New("Frame", {
			Name = "Thumb",
			BackgroundColor3 = Theme.White,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = state and UDim2.new(1, -13, 0.5, 0) or UDim2.new(0, 13, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			ZIndex = 3,
		}, track)
		Corner(thumb, 10)

		track.MouseButton1Click:Connect(function()
			state = not state
			tween(thumb, 0.16, {
				Position = state and UDim2.new(1, -13, 0.5, 0) or UDim2.new(0, 13, 0.5, 0),
			})
			tween(track, 0.16, {
				BackgroundColor3 = state and Theme.AccentBlue or Theme.Track,
			})
			tween(trackStroke, 0.16, { Transparency = state and 0.45 or 1 }) -- subtle glow while ON
			if opts.Callback then
				task.spawn(opts.Callback, state)
			end
		end)
	end

	function WindowMetatable.Slider(tab, opts) -- luau-ignore
		opts = opts or {}
		local order = tab._nextOrder(true)

		local min, max = opts.Min or 0, opts.Max or 100
		local value = math.clamp(opts.Default or min, min, max)
		local suffix = opts.Suffix and (" " .. opts.Suffix) or ""

		local row = New("Frame", {
			Name = "Slider_" .. (opts.Name or ""),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 74),
			LayoutOrder = order,
			ZIndex = 2,
		}, tab._page)

		TextLabel({
			FontFace = Fonts.Medium,
			TextSize = 16,
			Text = opts.Name or "Slider",
			Position = UDim2.new(0, 0, 0, 6),
			Size = UDim2.new(0.5, 0, 0, 20),
			ZIndex = 2,
		}, row)
		local valueLabel = TextLabel({
			FontFace = Fonts.Medium,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(math.floor(value + 0.5)) .. suffix,
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.new(0.5, 0, 0, 20),
			ZIndex = 2,
		}, row)

		-- Track + oversized hit area for comfortable dragging
		local hitArea = New("Frame", {
			Name = "HitArea",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 36),
			Size = UDim2.new(1, 0, 0, 24),
			ZIndex = 2,
		}, row)

		local track = New("Frame", {
			Name = "Track",
			BackgroundColor3 = Theme.Track,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 0, 8),
			ZIndex = 2,
		}, hitArea)
		Corner(track, 4)

		local alpha = (value - min) / math.max(max - min, 1e-6)

		local fill = New("Frame", {
			Name = "Fill",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(alpha, 1),
			ZIndex = 3,
		}, track)
		Corner(fill, 4)
		New("UIGradient", {
			Color = ColorSequence.new(Theme.AccentCyan, Theme.AccentPurple),
			Rotation = 0,
		}, fill)

		local thumb = New("Frame", {
			Name = "Thumb",
			BackgroundColor3 = Theme.White,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(alpha, 0.5),
			Size = UDim2.fromOffset(18, 18),
			ZIndex = 4,
		}, track)
		Corner(thumb, 9)
		Stroke(thumb, Theme.AccentBlue, 2, 0)

		local glow = New("Frame", { -- subtle glow behind the thumb
			BackgroundColor3 = Theme.AccentBlue,
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(alpha, 0.5),
			Size = UDim2.fromOffset(26, 26),
			ZIndex = 3,
		}, hitArea)
		Corner(glow, 13)

		local function setValueFromX(mouseX)
			local rel = math.clamp(
				(mouseX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1),
				0, 1
			)
			alpha = rel
			value = min + (max - min) * rel
			local display = math.floor(value + 0.5)
			valueLabel.Text = tostring(display) .. suffix
			fill.Size = UDim2.fromScale(rel, 1)
			thumb.Position = UDim2.fromScale(rel, 0.5)
			glow.Position = UDim2.fromScale(rel, 0.5)
			if opts.Callback then
				task.spawn(opts.Callback, display)
			end
		end

		local sliding = false
		hitArea.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				sliding = true
				setValueFromX(UserInputService:GetMouseLocation().X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				sliding = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				setValueFromX(UserInputService:GetMouseLocation().X)
			end
		end)
	end

	function WindowMetatable.Dropdown(tab, opts) -- luau-ignore
		opts = opts or {}
		local order = tab._nextOrder(true)
		local options = opts.Options or {}
		local selected = opts.Default or (options[1] or "Select...")

		local row = New("Frame", {
			Name = "Dropdown_" .. (opts.Name or ""),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 76),
			LayoutOrder = order,
			ZIndex = 2,
		}, tab._page)

		TextLabel({
			FontFace = Fonts.Medium,
			TextSize = 16,
			Text = opts.Name or "Dropdown",
			Position = UDim2.new(0, 0, 0, 6),
			Size = UDim2.new(1, 0, 0, 20),
			ZIndex = 2,
		}, row)

		local open = false
		local button = New("TextButton", {
			Name = "Button",
			Text = "",
			BackgroundColor3 = Theme.SurfaceRaised,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 32),
			Size = UDim2.new(1, 0, 0, 44),
			AutoButtonColor = false,
			ZIndex = 2,
		}, row)
		Corner(button, 8)
		Stroke(button, Theme.Border, 1, Theme.BorderTransparency)

		local selectedLabel = TextLabel({
			FontFace = Fonts.Medium,
			TextSize = 14,
			Text = selected,
			Position = UDim2.new(0, 14, 0, 0),
			Size = UDim2.new(1, -50, 1, 0),
			ZIndex = 3,
		}, button)

		local chevron = buildIcon("chevron-down", 16, button)
		chevron.AnchorPoint = Vector2.new(1, 0.5)
		chevron.Position = UDim2.new(1, -14, 0.5, 0)
		chevron.GroupColor3 = Theme.TextSecondary
		chevron.ZIndex = 3

		-- Expanding option list (in-flow; the scrolling canvas grows with it)
		local list = New("Frame", {
			Name = "Options",
			BackgroundColor3 = Theme.SurfaceRaised,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 80),
			Size = UDim2.new(1, 0, 0, 0),
			ClipsDescendants = true,
			Visible = false,
			ZIndex = 3,
		}, row)
		Corner(list, 8)
		Stroke(list, Theme.Border, 1, Theme.BorderTransparency)
		New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
		Pad(list, 4, 4, 4, 4)

		local optionRows = {}
		for i, optionName in ipairs(options) do
			local optionBtn = New("TextButton", {
				Name = "Option_" .. tostring(optionName),
				Text = "",
				BackgroundColor3 = Theme.SurfaceRaised,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 36),
				AutoButtonColor = false,
				LayoutOrder = i,
				ZIndex = 4,
			}, list)
			Corner(optionBtn, 6)
			local optionLabel = TextLabel({
				FontFace = Fonts.Medium,
				TextSize = 14,
				TextColor3 = optionName == selected and Theme.AccentBlue or Theme.TextPrimary,
				Text = tostring(optionName),
				Position = UDim2.new(0, 10, 0, 0),
				Size = UDim2.new(1, -46, 1, 0),
				ZIndex = 4,
			}, optionBtn)
			local checkIcon = buildIcon("check", 14, optionBtn)
			checkIcon.AnchorPoint = Vector2.new(1, 0.5)
			checkIcon.Position = UDim2.new(1, -10, 0.5, 0)
			checkIcon.GroupColor3 = Theme.AccentBlue
			checkIcon.ZIndex = 4
			checkIcon.Visible = optionName == selected

			table.insert(optionRows, {
				name = optionName,
				label = optionLabel,
				check = checkIcon,
			})

			optionBtn.MouseEnter:Connect(function()
				tween(optionBtn, 0.1, { BackgroundTransparency = 0.86 })
			end)
			optionBtn.MouseLeave:Connect(function()
				tween(optionBtn, 0.15, { BackgroundTransparency = 1 })
			end)
			optionBtn.MouseButton1Click:Connect(function()
				selected = optionName
				selectedLabel.Text = tostring(optionName)
				for _, r in ipairs(optionRows) do
					local isSelected = r.name == selected
					r.label.TextColor3 = isSelected and Theme.AccentBlue or Theme.TextPrimary
					r.check.Visible = isSelected
				end
				open = false
				row.Size = UDim2.new(1, 0, 0, 76)
				tween(list, 0.18, { Size = UDim2.new(1, 0, 0, 0) })
				tween(chevron, 0.18, { Rotation = 0 })
				task.delay(0.18, function()
					if not open then
						list.Visible = false
					end
				end)
				if opts.Callback then
					task.spawn(opts.Callback, optionName)
				end
			end)
		end

		button.MouseButton1Click:Connect(function()
			open = not open
			if open then
				local count = #options
				list.Visible = true
				list.Size = UDim2.new(1, 0, 0, 0)
				tween(list, 0.18, { Size = UDim2.new(1, 0, 0, count * 36 + 8) })
				tween(chevron, 0.18, { Rotation = 180 })
				row.Size = UDim2.new(1, 0, 0, 76 + count * 36 + 8)
			else
				tween(list, 0.18, { Size = UDim2.new(1, 0, 0, 0) })
				tween(chevron, 0.18, { Rotation = 0 })
				task.delay(0.18, function()
					if not open then
						list.Visible = false
					end
				end)
				row.Size = UDim2.new(1, 0, 0, 76)
			end
		end)
	end

	function WindowMetatable.ButtonGroup(tab, opts) -- luau-ignore
		opts = opts or {}
		local order = tab._nextOrder(true)
		local buttons = opts.Buttons or {}

		local row = New("Frame", {
			Name = "Buttons",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 78),
			LayoutOrder = order,
			ZIndex = 2,
		}, tab._page)

		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}, row)

		for i, def in ipairs(buttons) do
			local primary = (def.Variant or "Secondary") == "Primary"

			local btn = New("TextButton", {
				Name = "Btn_" .. (def.Name or i),
				Text = "",
				BackgroundColor3 = primary and Color3.new(1, 1, 1) or Theme.Surface,
				BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 46),
				AutoButtonColor = false,
				LayoutOrder = i,
				ZIndex = 2,
			}, row)
			Corner(btn, 8)
			if not primary then
				Stroke(btn, Theme.Border, 1, Theme.BorderTransparency)
			else
				New("UIGradient", {
					Color = ColorSequence.new(Theme.AccentCyan, Theme.AccentPurple),
					Rotation = 0,
				}, btn)
			end
			Pad(btn, 18, 0, 18, 0)

			New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}, btn)

			if def.Icon then
				local icon = buildIcon(def.Icon, 16, btn)
				icon.AnchorPoint = Vector2.new(0, 0.5)
				icon.Position = UDim2.new(0, 0, 0.5, 0)
				icon.GroupColor3 = Theme.White
				icon.ZIndex = 3
			end

			TextLabel({
				FontFace = Fonts.Medium,
				TextSize = 15,
				TextColor3 = primary and Theme.White or Theme.TextPrimary,
				Text = def.Name or "Button",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				ZIndex = 3,
			}, btn)

			-- Hover / pressed overlays (restrained brightness shifts)
			local hoverOverlay = New("Frame", {
				Name = "HoverOverlay",
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 4,
			}, btn)
			Corner(hoverOverlay, 8)
			local pressOverlay = New("Frame", {
				Name = "PressOverlay",
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
			}, btn)
			Corner(pressOverlay, 8)

			btn.MouseEnter:Connect(function()
				tween(hoverOverlay, 0.12, { BackgroundTransparency = primary and 0.86 or 0.93 })
				if not primary then
					tween(btn, 0.12, { BackgroundColor3 = Theme.SurfaceRaised })
				end
			end)
			btn.MouseLeave:Connect(function()
				tween(hoverOverlay, 0.15, { BackgroundTransparency = 1 })
				tween(pressOverlay, 0.15, { BackgroundTransparency = 1 })
				if not primary then
					tween(btn, 0.15, { BackgroundColor3 = Theme.Surface })
				end
			end)
			btn.MouseButton1Down:Connect(function()
				tween(pressOverlay, 0.08, { BackgroundTransparency = 0.82 })
			end)
			btn.MouseButton1Up:Connect(function()
				tween(pressOverlay, 0.12, { BackgroundTransparency = 1 })
			end)
			btn.MouseButton1Click:Connect(function()
				if def.Callback then
					task.spawn(def.Callback)
				end
			end)
		end
	end

	function WindowMetatable.Input(tab, opts) -- luau-ignore
		opts = opts or {}
		local order = tab._nextOrder(true)

		local row = New("Frame", {
			Name = "Input_" .. (opts.Name or ""),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 78),
			LayoutOrder = order,
			ZIndex = 2,
		}, tab._page)

		TextLabel({
			FontFace = Fonts.Medium,
			TextSize = 16,
			Text = opts.Name or "Input",
			Position = UDim2.new(0, 0, 0, 6),
			Size = UDim2.new(1, 0, 0, 20),
			ZIndex = 2,
		}, row)

		local container = New("Frame", {
			Name = "Container",
			BackgroundColor3 = Theme.SurfaceRaised,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 32),
			Size = UDim2.new(1, 0, 0, 44),
			ZIndex = 2,
		}, row)
		Corner(container, 8)
		local containerStroke = Stroke(container, Theme.Border, 1, Theme.BorderTransparency)

		if opts.Icon then
			local icon = buildIcon(opts.Icon, 15, container)
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 22, 0.5, 0)
			icon.GroupColor3 = Theme.TextSecondary
			icon.ZIndex = 3
		end

		local box = New("TextBox", {
			Name = "TextBox",
			BackgroundTransparency = 1,
			FontFace = Fonts.Regular,
			TextSize = 14,
			TextColor3 = Theme.TextPrimary,
			PlaceholderText = opts.Placeholder or "",
			PlaceholderColor3 = Theme.TextMuted,
			Text = "",
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, opts.Icon and 44 or 14, 0, 0),
			Size = UDim2.new(1, opts.Icon and -58 or -28, 1, 0),
			ZIndex = 3,
		}, container)

		container.MouseEnter:Connect(function()
			if not box:IsFocused() then
				tween(container, 0.12, { BackgroundColor3 = Theme.Track })
			end
		end)
		container.MouseLeave:Connect(function()
			if not box:IsFocused() then
				tween(container, 0.15, { BackgroundColor3 = Theme.SurfaceRaised })
			end
		end)
		box.Focused:Connect(function()
			tween(containerStroke, 0.12, { Color = Theme.AccentBlue, Transparency = 0.2 })
		end)
		box.FocusLost:Connect(function(enterPressed)
			tween(containerStroke, 0.15, { Color = Theme.Border, Transparency = Theme.BorderTransparency })
			tween(container, 0.15, { BackgroundColor3 = Theme.SurfaceRaised })
			if opts.Callback then
				task.spawn(opts.Callback, box.Text, enterPressed)
			end
		end)
	end

	---------------------------------------------------------------------------------
	-- Notification toasts (viewport top-right, stacked)
	---------------------------------------------------------------------------------

	function WindowMetatable.Notify(win, opts) -- luau-ignore
		opts = opts or {}
		local title = opts.Title or "Notification"
		local subtitle = opts.Subtitle or ""
		local duration = opts.Duration or 4.5

		local toast = New("Frame", {
			Name = "Toast",
			BackgroundColor3 = Theme.Surface,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(TOAST_WIDTH, TOAST_HEIGHT),
			ClipsDescendants = true,
			ZIndex = 50,
		}, win._screenGui)
		Corner(toast, 12)
		Stroke(toast, Theme.Border, 1, Theme.BorderTransparency)

		-- Narrow accent line along the left edge
		New("Frame", {
			BackgroundColor3 = Theme.AccentBlue,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 3, 1, 0),
			ZIndex = 51,
		}, toast)

		-- Blue circular icon with white check
		local disc = New("Frame", {
			BackgroundColor3 = Theme.AccentBlue,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			ZIndex = 51,
		}, toast)
		Corner(disc, 17)
		local checkIcon = buildIcon("check", 16, disc)
		checkIcon.GroupColor3 = Theme.White
		checkIcon.ZIndex = 52

		TextLabel({
			FontFace = Fonts.SemiBold,
			TextSize = 15,
			Text = title,
			Position = UDim2.new(0, 62, 0, 12),
			Size = UDim2.new(1, -120, 0, 18),
			ZIndex = 51,
		}, toast)
		TextLabel({
			FontFace = Fonts.Regular,
			TextSize = 12,
			TextColor3 = Theme.TextSecondary,
			Text = subtitle,
			Position = UDim2.new(0, 62, 0, 32),
			Size = UDim2.new(1, -120, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 51,
		}, toast)

		local closeBtn = New("TextButton", {
			Name = "Close",
			Text = "",
			BackgroundColor3 = Theme.SurfaceRaised,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			AutoButtonColor = false,
			ZIndex = 51,
		}, toast)
		Corner(closeBtn, 8)
		local closeIcon = buildIcon("x", 14, closeBtn)
		closeIcon.GroupColor3 = Theme.TextMuted
		closeIcon.ZIndex = 52
		closeBtn.MouseEnter:Connect(function()
			tween(closeBtn, 0.12, { BackgroundTransparency = 0.4 })
			tween(closeIcon, 0.12, { GroupColor3 = Theme.TextPrimary })
		end)
		closeBtn.MouseLeave:Connect(function()
			tween(closeBtn, 0.15, { BackgroundTransparency = 1 })
			tween(closeIcon, 0.15, { GroupColor3 = Theme.TextMuted })
		end)

		-- Stack management: index-based vertical slots at the viewport top-right
		local dismissed = false
		local entry = { toast = toast }
		table.insert(win._toasts, entry)

		local function slotPosition(index)
			return UDim2.new(1, -20, 0, 20 + (index - 1) * (TOAST_HEIGHT + TOAST_GAP))
		end

		local function relayout()
			for i, e in ipairs(win._toasts) do
				if e.toast.Parent then
					tween(e.toast, 0.25, { Position = slotPosition(i) })
				end
			end
		end

		local function dismiss()
			if dismissed then
				return
			end
			dismissed = true
			local index = table.find(win._toasts, entry)
			if index then
				table.remove(win._toasts, index)
			end
			tween(toast, 0.22, {
				Position = UDim2.new(1, -20, 0, -TOAST_HEIGHT - 10),
				BackgroundTransparency = 1,
			})
			task.delay(0.24, function()
				toast:Destroy()
			end)
			relayout()
		end

		closeBtn.MouseButton1Click:Connect(dismiss)
		entry.dismiss = dismiss

		-- Slide in from above the viewport edge
		toast.Position = UDim2.new(1, -20, 0, -TOAST_HEIGHT - 10)
		relayout()
		tween(toast, 0.35, { Position = slotPosition(#win._toasts) }, Enum.EasingStyle.Back)

		task.delay(duration, dismiss)
	end

	---------------------------------------------------------------------------------
	-- Window controls: drag, minimize (collapse), close
	---------------------------------------------------------------------------------

	local dragging = false
	local dragStart, startPos

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = container.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			local s = scale.Scale
			container.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X / s,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y / s
			)
		end
	end)

	minimizeBtn.MouseButton1Click:Connect(function()
		self._collapsed = not self._collapsed
		local targetHeight = self._collapsed
			and (TITLEBAR_HEIGHT + SHADOW_MARGIN * 2)
			or self._restoredHeight
		tween(container, 0.3, { Size = UDim2.fromOffset(container.Size.X.Offset, targetHeight) },
			Enum.EasingStyle.Quint)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		self._closed = true
		if self._onClosed then
			task.spawn(self._onClosed)
		end
		screenGui:Destroy()
	end)

	---------------------------------------------------------------------------------
	-- Responsive scaling (spec §10): scale down before shrinking text
	---------------------------------------------------------------------------------

	local function updateScale()
		if self._closed then
			return
		end
		local view = screenGui.AbsoluteSize
		local s = math.clamp(math.min(view.X / 1100, view.Y / 880), 0.7, 1)
		scale.Scale = s
	end
	updateScale()
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)

	return self
end

-- WindowMetatable methods declared above are bound per-window via the metatable
-- trick (they take the tab as first arg). Re-expose them on the window object too
-- so tooling sees a clean API: Window:Tab/Notify/Destroy.

function WindowMetatable.Destroy(win) -- luau-ignore
	win._closed = true
	win._screenGui:Destroy()
end

function WindowMetatable.OnClose(win, callback) -- luau-ignore
	win._onClosed = callback
end

return HuneUI
