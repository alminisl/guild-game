# UI Texture System Guide

## Quick Reference

### How Textures Work

```lua
-- 1. TEXTURED UI (uses PNG files)
UIAssets.drawPaper(x, y, w, h, {
    special = false,           -- false = regular paper, true = special paper
    color = {1, 1, 1, 1},     -- RGBA color tint
    alpha = 0.9                -- Transparency
})

-- 2. SIMPLE COLORED RECTANGLES (no textures)
Components.drawPanel(x, y, w, h, {
    color = {0.2, 0.22, 0.25}, -- RGB color
    cornerRadius = 5            -- Rounded corners
})
```

## Texture Connection Flow

```
Your Code (quest_tab.lua)
    ↓
UIAssets.drawPaper(...)
    ↓
loadAsset("assets/UI Elements/.../RegularPaper.png")
    ↓
love.graphics.newImage(path)  ← PNG loaded into GPU memory
    ↓
Cached in assets[path]        ← Reused next time
    ↓
love.graphics.draw(image, ...)
```

## Available Textured UI Elements

### Papers (Quest Boards)
```lua
-- Regular parchment
UIAssets.drawPaper(x, y, w, h, {special = false})

-- Special decorative paper
UIAssets.drawPaper(x, y, w, h, {special = true})
```

**Files:**
- `assets/UI Elements/UI Elements/Papers/RegularPaper.png`
- `assets/UI Elements/UI Elements/Papers/SpecialPaper.png`

### Buttons (Sprite-Based)
```lua
UIAssets.drawButton("bigBlue", x, y, w, h, {
    text = "Click Me",
    disabled = false
})
```

**Available buttons:**
- `bigBlue`, `bigRed` (320x320)
- `smallBlueRound`, `smallRedRound`
- `tinyRoundBlue`, `tinySquareRed`

### Progress Bars
```lua
UIAssets.drawProgressBar("blue", progress, x, y, w, h)
```

**Types:** `blue`, `green`, `red`, `yellow`

### Wood Table
```lua
UIAssets.drawWoodTable(x, y, w, h, {
    slots = false  -- false = solid, true = with slots
})
```

### Banners
```lua
UIAssets.drawBanner(x, y, w, h, {
    slots = false
})
```

## Current Guild Menu Usage

| Tab | Component | Texture? |
|-----|-----------|----------|
| Quests (available) | `UIAssets.drawPaper()` | ✅ Yes |
| Quests (hero cards) | `UIAssets.drawPaper()` | ✅ Yes |
| Active (quest cards) | `Components.drawPanel()` | ❌ No |
| Roster (hero cards) | `Components.drawPanel()` | ❌ No |
| Parties (cards) | `UIAssets.drawButton()` | ✅ Yes |

## How to Add Your Own Texture

1. **Add texture path to ui_assets.lua:**
```lua
UIAssets.myTexture = {
    default = "assets/UI Elements/MyTexture.png"
}
```

2. **Create draw function:**
```lua
function UIAssets.drawMyTexture(x, y, w, h, options)
    local image = loadAsset(UIAssets.myTexture.default)
    if not image then return end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, x, y, 0, w/imgW, h/imgH)
end
```

3. **Use it:**
```lua
UIAssets.drawMyTexture(x, y, 200, 100)
```

## Performance Notes

- Textures are **cached** after first load (in `assets` table)
- **Don't reload** textures every frame - they stay in memory
- The `loadAsset()` function handles caching automatically

## Preloading (Optional)

To load all textures at startup (faster first render):

```lua
-- In main.lua or init
UIAssets.preloadAll()
```

This loads all textures defined in `ui_assets.lua` at game start.
