# VSCode Lua Language Server Setup

## Why You Need This

Without a Lua extension, VSCode treats `.lua` files as plain text:
- ❌ No "Go to Definition" (F12)
- ❌ No autocomplete
- ❌ No type checking
- ❌ No hover documentation
- ❌ No refactoring tools

## Install Lua Language Server

### Method 1: VSCode Extensions Panel

1. **Open Extensions** (`Ctrl+Shift+X`)
2. **Search** for `Lua`
3. **Install** "Lua" by **sumneko** (the one with 10M+ downloads)
4. **Reload** VSCode

### Method 2: Quick Open

1. Press `Ctrl+P`
2. Type: `ext install sumneko.lua`
3. Press Enter

## Features You'll Get

### 1. Go to Definition (F12)
```lua
local State = require("ui.guild_menu.state")
           -- F12 here jumps to state.lua!

State.selectedQuest = nil
   -- F12 here jumps to where selectedQuest is defined
```

### 2. Find All References (Shift+F12)
```lua
State.selectedQuest = quest  -- Find everywhere this is used
```

### 3. Autocomplete (Ctrl+Space)
```lua
State.  -- Shows: selectedQuest, currentTab, etc.
```

### 4. Hover Documentation
```lua
-- Hover over a function to see its signature
Components.drawPanel(...)  -- Shows parameters!
```

### 5. Error Checking
```lua
local x = "hello"
x = 5  -- Warning: type changed from string to number
```

## Configure for LÖVE (Love2D)

After installing the Lua extension, add this to your workspace settings:

**`.vscode/settings.json`:**
```json
{
  "Lua.runtime.version": "LuaJIT",
  "Lua.workspace.library": [
    "${3rd}/love2d/library"
  ],
  "Lua.diagnostics.globals": [
    "love"
  ]
}
```

This tells the Lua server:
- You're using **LuaJIT** (what LÖVE uses)
- **love** is a global (not undefined)
- Load LÖVE API definitions for autocomplete

## Keyboard Shortcuts

| Action | Windows/Linux | Mac |
|--------|---------------|-----|
| Go to Definition | `F12` | `F12` |
| Peek Definition | `Alt+F12` | `⌥F12` |
| Find References | `Shift+F12` | `⇧F12` |
| Rename Symbol | `F2` | `F2` |
| Format Document | `Shift+Alt+F` | `⇧⌥F` |

## Verify It Works

1. Open `ui/guild_menu/state.lua`
2. Put cursor on `State.selectedQuest`
3. Press **F12**
4. Should jump to line where it's defined!

## Troubleshooting

### "Go to Definition" not working?

1. **Wait for indexing** - Large projects take a minute to index
2. **Check bottom-right** - Should say "Lua" not "Plain Text"
3. **Reload window** - `Ctrl+Shift+P` → "Reload Window"

### Seeing lots of warnings?

Add to `.vscode/settings.json`:
```json
{
  "Lua.diagnostics.disable": [
    "lowercase-global",
    "undefined-global"
  ]
}
```

### Autocomplete not showing?

1. Press `Ctrl+Space` to manually trigger
2. Check if extension is enabled
3. Try opening a simpler file first

## Alternative Extensions

If sumneko's extension doesn't work, try:

- **Lua** by keyring
- **Lua Language Server** by actboy168

But sumneko's is the most popular and feature-rich.

## Next Level: Type Annotations

Add type hints for better autocomplete:

```lua
---@param hero table The hero object
---@param x number X position
---@param y number Y position
---@return boolean success Whether drawing succeeded
function drawHero(hero, x, y)
    -- ...
end
```

Now hovering shows parameter types! 🎉
