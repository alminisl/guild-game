-- Design System Module
-- Centralized design tokens for consistent UI styling
-- Inspired by modern design systems (Dracula/Nord themes)

local DesignSystem = {}

-- ============================================================================
-- TYPOGRAPHY SCALE
-- ============================================================================
DesignSystem.fonts = {
    h1 = 32,      -- Page titles, major headers
    h2 = 24,      -- Section headers
    h3 = 18,      -- Subsection headers
    body = 14,    -- Normal text (current default)
    small = 12,   -- Hints, secondary info
    tiny = 10     -- Very small text, icon labels
}

-- ============================================================================
-- SPACING SCALE (4px base unit)
-- ============================================================================
DesignSystem.spacing = {
    xs = 4,       -- Tiny gaps
    sm = 8,       -- Small gaps between related elements
    md = 16,      -- Default spacing
    lg = 24,      -- Large spacing between sections
    xl = 32,      -- Extra large spacing
    xxl = 48      -- Massive spacing for major sections
}

-- ============================================================================
-- MODERN COLOR PALETTE
-- ============================================================================
DesignSystem.colors = {
    -- Background Layers (darkest to lightest)
    bg = {
        dark = {0.11, 0.12, 0.16, 1},      -- #1c1f29 - Darkest background
        medium = {0.15, 0.17, 0.22, 1},    -- #262a38 - Main background
        light = {0.20, 0.22, 0.28, 1}      -- #333847 - Elevated elements
    },
    
    -- Surface Colors (for panels, cards, buttons)
    surface = {
        default = {0.18, 0.20, 0.26, 0.95},   -- Default panel background
        hover = {0.22, 0.24, 0.30, 0.95},     -- Hover state
        active = {0.26, 0.28, 0.34, 0.95},    -- Active/pressed state
        disabled = {0.15, 0.16, 0.20, 0.8}    -- Disabled state
    },
    
    -- Primary Brand Color (Blue-Purple accent)
    primary = {
        default = {0.49, 0.55, 0.98, 1},      -- #7d8dfb - Main brand color
        hover = {0.59, 0.65, 1.00, 1},        -- Brighter on hover
        light = {0.70, 0.75, 1.00, 1},        -- Light variant
        dark = {0.39, 0.45, 0.88, 1}          -- Dark variant
    },
    
    -- Semantic Colors (for status, alerts, feedback)
    semantic = {
        success = {0.31, 0.78, 0.47, 1},      -- #4fc77a - Green
        warning = {0.95, 0.77, 0.31, 1},      -- #f2c44f - Yellow
        danger = {0.91, 0.38, 0.43, 1},       -- #e8616e - Red
        info = {0.52, 0.75, 0.96, 1}          -- #85c1f5 - Light blue
    },
    
    -- Text Hierarchy
    text = {
        primary = {0.94, 0.95, 0.97, 1},      -- #f0f2f8 - Main text (almost white)
        secondary = {0.70, 0.72, 0.76, 1},    -- #b3b7c2 - Secondary text (gray)
        disabled = {0.45, 0.47, 0.51, 1},     -- #737882 - Disabled text (dark gray)
        inverse = {0.11, 0.12, 0.16, 1}       -- #1c1f29 - For light backgrounds
    },
    
    -- Rank Colors (Enhanced for better visibility)
    rank = {
        D = {0.60, 0.62, 0.66, 1},            -- #999ea8 - Light gray (was too dark)
        C = {0.40, 0.83, 0.52, 1},            -- #66d485 - Bright green
        B = {0.45, 0.67, 0.98, 1},            -- #73abfa - Bright blue
        A = {0.98, 0.87, 0.35, 1},            -- #fad959 - Gold
        S = {0.96, 0.38, 0.38, 1}             -- #f56161 - Bright red
    },
    
    -- Status Colors (for hero/quest states)
    status = {
        idle = {0.31, 0.78, 0.47, 1},         -- Green (available)
        traveling = {0.52, 0.75, 0.96, 1},    -- Light blue (in transit)
        questing = {0.95, 0.77, 0.31, 1},     -- Yellow (active)
        returning = {0.70, 0.60, 0.90, 1},    -- Purple (coming back)
        resting = {0.60, 0.50, 0.70, 1},      -- Dark purple (recovering)
        injured = {0.91, 0.55, 0.32, 1},      -- Orange (wounded)
        dead = {0.50, 0.50, 0.50, 1}          -- Gray (deceased)
    },
    
    -- Resource Colors
    resources = {
        gold = {1.00, 0.85, 0.20, 1},         -- #ffd933 - Gold
        xp = {0.52, 0.75, 0.96, 1},           -- Light blue (matches info)
        material = {0.70, 0.55, 0.40, 1},     -- Brown
        health = {0.91, 0.38, 0.43, 1},       -- Red
        mana = {0.45, 0.67, 0.98, 1}          -- Blue
    },
    
    -- Special Effects
    synergy = {
        default = {0.60, 0.50, 0.80, 1},      -- Purple for synergies
        light = {0.70, 0.60, 0.90, 1}         -- Lighter purple
    },
    
    -- UI Chrome
    border = {
        default = {1, 1, 1, 0.1},             -- Subtle white border
        hover = {1, 1, 1, 0.2},               -- Brighter on hover
        focus = {0.49, 0.55, 0.98, 0.5}       -- Primary color for focus
    },
    
    -- Overlays
    overlay = {
        dark = {0, 0, 0, 0.7},                -- Modal backdrop
        light = {1, 1, 1, 0.1}                -- Subtle highlight overlay
    }
}

-- ============================================================================
-- BORDER RADIUS
-- ============================================================================
DesignSystem.radius = {
    sm = 4,       -- Small radius (subtle rounding)
    md = 8,       -- Medium radius (buttons, cards)
    lg = 12,      -- Large radius (panels)
    xl = 16,      -- Extra large radius
    full = 9999   -- Pill shape (circular)
}

-- ============================================================================
-- SHADOWS (Alpha values for depth)
-- ============================================================================
DesignSystem.shadows = {
    sm = 0.15,    -- Subtle shadow for cards
    md = 0.25,    -- Medium shadow for modals
    lg = 0.35,    -- Strong shadow for tooltips
    xl = 0.50     -- Very strong shadow for important overlays
}

-- ============================================================================
-- TRANSITIONS (Animation durations in seconds)
-- ============================================================================
DesignSystem.transitions = {
    fast = 0.1,     -- Quick feedback (button hover)
    normal = 0.2,   -- Standard transitions
    slow = 0.3      -- Smooth, deliberate transitions
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Get rank color by rank string
function DesignSystem.getRankColor(rank)
    return DesignSystem.colors.rank[rank] or DesignSystem.colors.text.secondary
end

-- Get status color by status string
function DesignSystem.getStatusColor(status)
    return DesignSystem.colors.status[status] or DesignSystem.colors.text.secondary
end

-- Linear interpolation for smooth animations
function DesignSystem.lerp(a, b, t)
    return a + (b - a) * t
end

-- Ease-out cubic function (natural feeling animations)
function DesignSystem.easeOut(t)
    return 1 - math.pow(1 - t, 3)
end

-- Ease-in cubic function
function DesignSystem.easeIn(t)
    return math.pow(t, 3)
end

-- Ease-in-out cubic function (smooth start and end)
function DesignSystem.easeInOut(t)
    if t < 0.5 then
        return 4 * t * t * t
    else
        return 1 - math.pow(-2 * t + 2, 3) / 2
    end
end

-- Clamp value between min and max
function DesignSystem.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Convert hex color to RGB (utility for future use)
function DesignSystem.hexToRgb(hex)
    hex = hex:gsub("#", "")
    return {
        tonumber("0x" .. hex:sub(1, 2)) / 255,
        tonumber("0x" .. hex:sub(3, 4)) / 255,
        tonumber("0x" .. hex:sub(5, 6)) / 255,
        1
    }
end

-- Create a darker version of a color
function DesignSystem.darken(color, amount)
    amount = amount or 0.2
    return {
        color[1] * (1 - amount),
        color[2] * (1 - amount),
        color[3] * (1 - amount),
        color[4] or 1
    }
end

-- Create a lighter version of a color
function DesignSystem.lighten(color, amount)
    amount = amount or 0.2
    return {
        color[1] + (1 - color[1]) * amount,
        color[2] + (1 - color[2]) * amount,
        color[3] + (1 - color[3]) * amount,
        color[4] or 1
    }
end

-- Create color with adjusted alpha
function DesignSystem.alpha(color, alpha)
    return {color[1], color[2], color[3], alpha}
end

return DesignSystem
