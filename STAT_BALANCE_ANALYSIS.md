# Stat Balance Analysis - Quest vs Hero Stats

## The Math Problem

### Quest Success Formula
```
avgPartyStat = totalPartyStat / numHeroes
expectedStat = questExpectedStat (from quests.json)
statBonus = (avgPartyStat - expectedStat) * 0.02
```

### Current Settings

**D-Rank:**
- Quest expects: **18 per stat**
- Hero base range: 12-18 per stat (avg 15)
- With class bonus on primary: 17-23 (avg 20)
- With class bonus on secondary stats: 12-18 (avg 15)

**Party of 4 D-Rank Heroes:**
- If all 4 have avg 15 in STR: 15 × 4 = 60 total / 4 heroes = **15 avg**
- Quest expects: 18
- Penalty: (15 - 18) × 0.02 = -6%
- If one hero has STR primary with +3: 18 × 1 + 15 × 3 = 63 / 4 = **15.75 avg**
- Penalty: (15.75 - 18) × 0.02 = -4.5%

**This is too hard for starting heroes!**

---

**C-Rank:**
- Quest expects: **32 per stat**
- Hero base range: 22-32 per stat (avg 27)
- With class bonus on primary: 27-37 (avg 32)
- With class bonus on secondary: 22-32 (avg 27)

**Party of 4 C-Rank Heroes:**
- If all 4 have avg 27 in STR: 27 × 4 = 108 / 4 = **27 avg**
- Quest expects: 32
- Penalty: (27 - 32) × 0.02 = -10%

**Also too hard!**

## The Core Issue

Quest expected stats assume **END of rank** power level, but heroes start at **BEGINNING of rank** power level.

## Solution Options

### Option 1: Lower Quest Expectations (Recommended)
Make quests expect stats that match **mid-level heroes** of that rank:

```json
"expectedStats": {
    "D": 15,  // Was 18 - now matches avg D-hero stat
    "C": 27,  // Was 32 - now matches avg C-hero stat
    "B": 44,  // Was 50 - mid-range B hero
    "A": 68,  // Was 72
    "S": 88   // Was 92
}
```

### Option 2: Increase Hero Starting Stats
Make heroes stronger at start of each rank:

```json
"baseStats": {
    "D": { "min": 15, "max": 21, "cap": 35 },  // Was 12-18
    "C": { "min": 28, "max": 36, "cap": 55 },  // Was 22-32
    "B": { "min": 44, "max": 56, "cap": 75 },  // Was 38-50
    "A": { "min": 66, "max": 80, "cap": 95 },  // Was 60-76
    "S": { "min": 86, "max": 98, "cap": 100 }  // Was 82-95
}
```

### Option 3: Hybrid Approach (BEST)
Slightly lower quest expectations AND slightly raise hero stats:

**Quest Expected Stats:**
```json
"expectedStats": {
    "D": 16,  // Was 18
    "C": 29,  // Was 32
    "B": 47,  // Was 50
    "A": 70,  // Was 72
    "S": 90   // Was 92
}
```

**Hero Base Stats:**
```json
"baseStats": {
    "D": { "min": 13, "max": 19, "cap": 35 },  // Was 12-18, avg 16
    "C": { "min": 24, "max": 34, "cap": 55 },  // Was 22-32, avg 29
    "B": { "min": 40, "max": 54, "cap": 75 },  // Was 38-50, avg 47
    "A": { "min": 63, "max": 79, "cap": 95 },  // Was 60-76, avg 71
    "S": { "min": 84, "max": 96, "cap": 100 }  // Was 82-95, avg 90
}
```

## Verification - Option 3 (Hybrid)

### D-Rank Party (4 heroes, avg 16 per stat)
- Party avg stat: 16
- Quest expects: 16
- Penalty: 0%
- **Base success: ~60-70%** ✓

With class bonus on primary (+3-5):
- Hero with primary DEX: 16 + 4 = 20
- 3 other heroes: 16 each
- Party avg DEX: (20 + 16 + 16 + 16) / 4 = 17
- Bonus: (17 - 16) × 0.02 = +2%
- **Success: ~62-72%** ✓

### C-Rank Party (4 heroes, avg 29 per stat)
- Party avg stat: 29
- Quest expects: 29
- Penalty: 0%
- **Base success: ~60-70%** ✓

### Progression Feel
- Fresh heroes of each rank: ~60-70% success on same-rank quests
- With good class matching: ~65-75% success
- After leveling up: ~70-85% success
- **Feels rewarding but challenging!** ✓

## Recommendation

**Use Option 3 (Hybrid)** - It provides:
- Fair challenge for new heroes
- Meaningful progression through leveling
- Reward for good class/quest matching
- Consistent difficulty curve across all ranks
