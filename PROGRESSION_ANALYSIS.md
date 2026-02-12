# Hero Progression System Analysis

## Current Issues Found

### 1. Starting Stats Too High
- **D-rank Lv.2 Ranger** had stats: STR:17, DEX:25, INT:23, VIT:18, LCK:23
- **Total**: ~106 stat points at level 2
- **Problem**: This is way too powerful for a starting hero

### 2. Quest Expected Stats
From `quests.json`:
- D-rank quest: 18 per stat (avg across party)
- C-rank quest: 32 per stat
- B-rank quest: 50 per stat
- A-rank quest: 72 per stat
- S-rank quest: 92 per stat

## Proposed Balanced Progression

### Starting Stats by Rank (NEW)
| Rank | Min/Stat | Max/Stat | Cap/Stat | Total Min | Total Max | Quest Target |
|------|----------|----------|----------|-----------|-----------|--------------|
| D    | 8        | 12       | 30       | 40        | 60        | 18/stat = 90 total |
| C    | 18       | 24       | 50       | 90        | 120       | 32/stat = 160 total |
| B    | 32       | 42       | 70       | 160       | 210       | 50/stat = 250 total |
| A    | 52       | 66       | 90       | 260       | 330       | 72/stat = 360 total |
| S    | 75       | 88       | 100      | 375       | 440       | 92/stat = 460 total |

### Level Progression System

**Max Levels by Rank:**
- D: 4 levels (total +4 stats gained)
- C: 7 levels (total +7 stats gained)
- B: 11 levels (total +11 stats gained)
- A: 16 levels (total +16 stats gained)
- S: 20 levels (total +20 stats gained)

**XP Requirements:**
- Level 2: 100 XP
- Level 3: 200 XP
- Level 4: 300 XP
- Level N: 100 * N XP

**Stat Gains:**
- +1 random stat per level up
- Capped by rank's stat cap

### Example Progression: D-Rank Ranger

**Starting (Lv.1):**
- Base: STR:8-12, DEX:8-12, INT:8-12, VIT:8-12, LCK:8-12
- Class bonus (Ranger): DEX+2, LCK+1
- Example: STR:10, DEX:14, INT:9, VIT:11, LCK:11
- **Total: 55 stats**

**At Max Level (Lv.4):**
- Gains +3 random stats (levels 2-4)
- Example: STR:11, DEX:17, INT:9, VIT:11, LCK:12
- **Total: 60 stats**

**D-Rank Party of 4 at Lv.2-3:**
- Average per hero: ~57 stats
- Average per stat: ~11.4
- **For D-rank quest needing 18/stat**: Needs 4 heroes working together
- Party total per stat: 11.4 × 4 = 45.6 (vs 72 needed = 90/5 stats × 4 heroes)

Wait, let me recalculate...

### Quest Success Calculation

The success formula uses **average party stat** vs **expected stat**:
- D-rank quest expects: 18 in primary stat
- 4 heroes at ~11 STR each = 44 total / 4 heroes = 11 avg
- Gap: -7 from expected
- Success chance penalty: -7 × 0.02 = -14%

This means D-rank heroes need:
- About 15-20 in their primary stat to comfortably do D-rank quests
- Total stats around 70-80 per hero

## REVISED Starting Stats

### Better Balanced Stats (FINAL)

| Rank | Min/Stat | Max/Stat | Cap/Stat | Example Starting Total |
|------|----------|----------|----------|------------------------|
| D    | 12       | 18       | 35       | 75 (15×5 stats)        |
| C    | 22       | 32       | 55       | 135 (27×5 stats)       |
| B    | 38       | 50       | 75       | 220 (44×5 stats)       |
| A    | 60       | 76       | 95       | 340 (68×5 stats)       |
| S    | 82       | 95       | 100      | 435 (87×5 stats)       |

### Class Bonuses (Applied to Base)
- Knight: STR+3, VIT+3
- Archer: DEX+5
- Mage: INT+5
- Rogue: DEX+3, LCK+2
- Priest: INT+3, VIT+2
- Ranger: DEX+2, LCK+1

### Example: D-Rank Ranger Lv.1
- Base roll: STR:14, DEX:15, INT:13, VIT:16, LCK:14 (Total: 72)
- Class bonus: DEX+2, LCK+1
- **Final: STR:14, DEX:17, INT:13, VIT:16, LCK:15 (Total: 75)**
- Primary stat (DEX): 17 ✓ (close to D-quest target of 18)

### Party Example: 4 D-Rank Heroes vs D-Quest
- 4 heroes with ~16-18 in primary stat
- Average: 17 × 4 = 68 total / 4 = 17 avg
- Quest expects: 18
- Penalty: -1 × 0.02 = -2% (minor penalty, reasonable challenge)
- **Base success chance: ~60-70%** ✓

## Implementation Changes Needed

1. ✅ **heroes.json** - Update baseStats ranges
2. **UI Cramping** - Fix quest selection UI spacing
3. **New Save Required** - Old saves will have overpowered heroes

## UI Fixes Needed

### Quest Selection Screen (Image 2)
- Quest list is cramped
- Success percentage needs more space
- Synergy display is too condensed
- Combined stats pentagon is good but text overlaps
