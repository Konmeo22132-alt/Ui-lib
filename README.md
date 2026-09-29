# HuneUI — MyHub v2.0 UI Library

A compact, premium dark UI library for Roblox implementing the **MyHub v2.0**
design specification: narrow icon navigation rail, settings content area, and a
floating notification toast, with restrained electric-blue accents and a
cyan-to-purple gradient on primary actions.

Fully self-contained — no external image assets. All icons are drawn as vector
primitives (capsules, rings, discs) inside `CanvasGroup`s, so they stay crisp at
any size and tint cleanly.

## Quick start (one line)

Run the ready-made **MyHub v2.0** window from any executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Konmeo22132-alt/Ui-lib/main/loader.lua"))()
```

> The URL must be the **raw** file (`raw.githubusercontent.com`), not the
> github.com page — `game:HttpGet` on a page URL returns HTML, not code.

`loader.lua` fetches `HuneUI.lua` from this repo, compiles it with `loadstring`,
and builds the demo window (toggle keybind: **RightShift**).

## Install (Studio)

1. In Roblox Studio, create a **ModuleScript** in `ReplicatedStorage`, name it
   `HuneUI`, and paste the contents of `HuneUI.lua`.
2. Create a **LocalScript** in `StarterPlayer/StarterPlayerScripts`, name it
   `Example`, and paste the contents of `Example.client.lua`.
3. Play. Press **RightShift** to show/hide the window.

## Quick start (code)

```lua
local HuneUI = require(game.ReplicatedStorage.HuneUI)

local Window = HuneUI.Create({
    Title    = "MyHub v2.0",
    Subtitle = "by KONMEO",
    Size     = UDim2.fromOffset(940, 712), -- ~1.32:1 reference aspect
    Backdrop = true,                        -- #0D0D0F viewport background
})

local combat = Window:Tab("Combat", "zap")   -- first tab starts active
Window:Tab("Defense", "shield")
Window:Tab("Settings", "settings")
Window:Tab("Profile", "user")

combat:Toggle({
    Name = "Speed Hack",
    Description = "Increase your movement speed.",
    Default = true,
    Callback = function(enabled) end,
})

combat:Slider({
    Name = "Walk Speed",
    Min = 0, Max = 350, Default = 250,
    Suffix = "stud/s",                       -- shows "250 stud/s", thumb ~70%
    Callback = function(value) end,
})

combat:Dropdown({
    Name = "Aura Type",
    Options = { "Ring", "Nova", "Pulse", "Orbit" },
    Default = "Ring",
    Callback = function(option) end,
})

combat:ButtonGroup({
    Buttons = {
        { Name = "Teleport", Icon = "send",      Variant = "Primary",   Callback = function() end },
        { Name = "Reset",    Icon = "rotate-cw", Variant = "Secondary", Callback = function() end },
    },
})

combat:Input({
    Name = "Custom Tag",
    Placeholder = "Enter your custom tag...",
    Icon = "tag",
    Callback = function(text) end,
})

Window:Notify({
    Title = "Settings saved",
    Subtitle = "Your changes have been applied.",
    Duration = 4.5,
})
```

## API

### `HuneUI.Create(config) -> Window`

| Option    | Type    | Default              | Notes                              |
| --------- | ------- | -------------------- | ---------------------------------- |
| `Title`   | string  | `"MyHub v2.0"`       | Title bar title                    |
| `Subtitle`| string  | `""`                 | Title bar subtitle                 |
| `Size`    | UDim2   | `940 × 712`          | Window body size                   |
| `Backdrop`| boolean | `false`              | Full-viewport `#0D0D0F` background |
| `Parent`  | Instance| `PlayerGui`          | ScreenGui parent                   |

### Window methods

- `Window:Tab(name, icon)` — adds a navigation tab and returns it. Available
  icons: `zap`, `shield`, `settings`, `user`, `send`, `rotate-cw`, `tag`,
  `chevron-down`, `check`, `x`, `minus`, `circle`. The first tab is active by
  default; only the active tab expands to show its label.
- `Window:Notify({ Title, Subtitle, Duration })` — shows a toast at the
  viewport's top-right. Toasts stack; the close icon dismisses.
- `Window:OnClose(callback)` — runs before the window is destroyed.
- `Window:Destroy()` — removes the UI.

Window controls: drag via the title bar, **minimize** collapses to the title
bar, **close** destroys the window.

### Tab methods

- `Tab:Toggle({ Name, Description, Default, Callback })`
- `Tab:Slider({ Name, Min, Max, Default, Suffix, Callback })`
- `Tab:Dropdown({ Name, Options, Default, Callback })`
- `Tab:ButtonGroup({ Buttons = { { Name, Icon, Variant, Callback }, ... } })`
  — `Variant` is `"Primary"` (cyan→purple gradient) or `"Secondary"`
  (outlined).
- `Tab:Input({ Name, Placeholder, Icon, Callback })`

Thin dividers are inserted between control groups automatically, matching the
reference layout.

## Design token map (spec §6)

Centralized in the `Theme` table at the top of `HuneUI.lua`:
`background #0D0D0F`, `surface #141418`, `surfaceRaised #1E1E24`,
`textPrimary #F4F6FA`, `textSecondary #A5ADBD`, `textMuted #7E8799`,
`border rgba(180,190,210,0.16)`, `divider rgba(180,190,210,0.14)`,
`accentBlue #4B9EFF`, `accentCyan #24B8F2`, `accentPurple #6557F5`.

The cyan→purple gradient is used only where the spec allows it: the primary
button and the slider fill. The active-tab indicator, toggle, and toast accent
line stay electric blue.

## Spec acceptance checklist (§12)

- Window centered, 12 px radius, 1 px low-opacity border, clipped children, soft
  layered shadow.
- Title bar (68 px): app mark, `MyHub v2.0`, `by KONMEO`, minimize + close with
  hover states; divider beneath.
- Rail (184 px): four icon tabs; only the active tab shows a label; active tab
  has the blue left-edge indicator (with subtle glow) and a subdued pill.
- Combat page: eyebrow `COMBAT`, heading `Combat`, divider, then the five
  groups in order — Speed Hack (ON, blue toggle, right thumb), Walk Speed
  (`250 stud/s`, thumb ~70 %, cyan→purple fill), Aura Type (`Ring`, chevron),
  Teleport (gradient) + Reset (outlined), Custom Tag (tag icon, placeholder).
- Toast top-right: `Settings saved` / `Your changes have been applied.`, blue
  check disc, close icon, 12 px radius, left accent line, stacked + animated.
- Dividers, 30 px content padding, 8/12 px radii, and text hierarchy per spec.
- Responsive: window re-centers, scales down via `UIScale` on small viewports,
  and the content area scrolls while the title bar stays fixed.

## Notes

- Icons are stylized vector approximations of the Lucide set, drawn on a 24×24
  grid with consistent stroke weight. To use image-based icons instead, replace
  `buildIcon` in `HuneUI.lua` — every call site takes a name and pixel size.
- Fonts use Gotham SSm (`rbxasset://fonts/families/GothamSSm.json`) at the
  weights/sizes from spec §7.
