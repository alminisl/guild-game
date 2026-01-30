# Implementation Plan: Rebalance Game Stats to 1-100 Scale

## Requirements Restatement

The user has identified that heroes are significantly overleveled compared to quest requirements:
- Current stat ranges are approximately 1-20 for both heroes and quests
- However, when factoring in equipment, class bonuses, and race bonuses, heroes far exceed quest expectations
- Goal: Normalize both quests and heroes to a 1-100 scale with smooth rank progression

## Analysis Summary

### Current Problem

**Quest Expected Stats (what the system thinks a hero should have):**
| Rank | Expected |
|------|----------|
| D | 5 |
| C | 7 |
| B | 10 |
| A | 13 |
| S | 16 |

**Actual Hero Stats (with typical equipment):**
- D-Rank hero: 5-12 (already meeting or exceeding expectations)
- B-Rank hero: 17-25 (nearly DOUBLE the expectation)
- S-Rank hero: 35-50+ (3x the expectation)

**Root Causes:**
1. Equipment provides massive stat bonuses not accounted for in expected stats
2. Class bonuses (+1 to +7) stack on top
3. Race bonuses (+1 to +3) stack further
4. Level-up gains add more

### Proposed Solution: 1-100 Scale

Scale everything by approximately 5x and rebalance so that a "properly geared" hero meets (not exceeds) the expected stats for their rank.

---

## Implementation Phases

### Phase 1: Update Hero Base Stats (`data/heroes.json`)

**Current → New Base Stats:**
| Rank | Current Min/Max/Cap | New Min/Max/Cap |
|------|---------------------|-----------------|
| D | 1 / 3 / 8 | 5 / 15 / 25 |
| C | 3 / 5 / 10 | 15 / 25 / 40 |
| B | 5 / 8 / 12 | 25 / 40 / 55 |
| A | 8 / 12 / 16 | 40 / 60 / 75 |
| S | 12 / 16 / 20 | 60 / 80 / 100 |

**Class Bonuses (scale by 3x to keep meaningful but not overwhelming):**
| Class | Current STR/DEX/INT/VIT/LUCK | New STR/DEX/INT/VIT/LUCK |
|-------|------------------------------|--------------------------|
| Knight | +1/0/0/+1/0 | +3/0/0/+3/0 |
| Archer | 0/+2/0/0/0 | 0/+5/0/0/0 |
| Mage | 0/0/+2/0/0 | 0/0/+5/0/0 |
| Rogue | 0/+1/0/0/+1 | 0/+3/0/0/+2 |
| Priest | 0/0/+1/+1/0 | 0/0/+3/+3/0 |
| Ranger | 0/+1/0/+1/0 | 0/+3/0/+3/0 |

**Awakened Class Bonuses (scale by 2x):**
| Class | Current | New |
|-------|---------|-----|
| Paladin | +5/+1/+2/+4/+2 | +10/+2/+4/+8/+4 |
| Hawkeye | +1/+6/+1/+1/+3 | +2/+12/+2/+2/+6 |
| Archmage | -1/+1/+7/0/+3 | -2/+2/+14/0/+6 |
| Shadow | +2/+5/+1/0/+4 | +4/+10/+2/0/+8 |
| Saint | +1/+1/+5/+3/+3 | +2/+2/+10/+6/+6 |
| Warden | +3/+4/+2/+2/+2 | +6/+8/+4/+4/+4 |

**Race Bonuses (scale by 2x):**
| Race | Current | New |
|------|---------|-----|
| Human | 0/0/0/0/+1 | 0/0/0/0/+2 |
| Dwarf | +1/0/0/+1/0 | +2/0/0/+2/0 |
| Elf | 0/+1/+1/0/0 | 0/+2/+2/0/0 |
| Halfling | 0/+1/0/0/+1 | 0/+2/0/0/+2 |
| Orc | +2/0/0/+1/0 | +4/0/0/+2/0 |
| Gnome | 0/0/+2/0/+1 | 0/0/+4/0/+2 |

---

### Phase 2: Update Quest Expected Stats (`data/quests.json`)

**New Expected Stats (accounting for base stats + class bonus + some equipment):**
| Rank | Current | New | Rationale |
|------|---------|-----|-----------|
| D | 5 | 20 | D-rank hero (10 base) + class (3) + basic gear (5) ≈ 18 |
| C | 7 | 35 | C-rank hero (20 base) + class (4) + gear (10) ≈ 34 |
| B | 10 | 55 | B-rank hero (33 base) + class (5) + gear (15) ≈ 53 |
| A | 13 | 75 | A-rank hero (50 base) + class (6) + gear (20) ≈ 76 |
| S | 16 | 95 | S-rank hero (70 base) + class (8) + gear (20) ≈ 98 |

---

### Phase 3: Update Equipment Stats (`data/equipment.lua`)

**Equipment Budget (total stat points per item):**
| Rank | Current Weapon/Armor/Accessory | New Weapon/Armor/Accessory |
|------|-------------------------------|----------------------------|
| D | 3 / 2.7 / 2.1 | 8 / 6 / 4 |
| C | 6 / 5.4 / 4.2 | 15 / 12 / 8 |
| B | 9 / 8.1 / 6.3 | 22 / 18 / 12 |
| A | 12 / 10.8 / 8.4 | 28 / 24 / 16 |
| S | 15 / 13.5 / 10.5 | 35 / 30 / 20 |

**Update all individual equipment items with scaled stats.**

---

### Phase 4: Adjust Success Calculation Coefficients (`data/quests.lua`)

Since stats are scaled up, the bonus per point should be scaled down:

**Current:**
- `primaryStatBonus = (avgPrimaryStat - expected) * 0.03` (+3% per point)
- `secondaryStatBonus = (avgSecStat - secExpected) * 0.015` (+1.5% per point)
- `luckBonus = (avgLuck - 5) * 0.01` (+1% per point)

**New (divide coefficients by ~5):**
- `primaryStatBonus = (avgPrimaryStat - expected) * 0.006` (+0.6% per point)
- `secondaryStatBonus = (avgSecStat - secExpected) * 0.003` (+0.3% per point)
- `luckBonus = (avgLuck - 25) * 0.002` (+0.2% per point, with scaled luck baseline)

---

## Files to Modify

1. **`data/heroes.json`** - Hero base stats, class bonuses, race bonuses
2. **`data/quests.json`** - Quest expected stats
3. **`data/equipment.lua`** - Equipment stat values and budget configuration
4. **`data/quests.lua`** - Success calculation coefficients (lines 537, 547, 558)

---

## Risks and Considerations

### MEDIUM: Save Compatibility
- Existing saves may have heroes with old stat values
- Need to either migrate saves or accept that existing heroes will be weaker

### LOW: Balance Fine-Tuning
- Initial numbers may need adjustment after playtesting
- The 5x multiplier is an approximation; some values may need tweaking

### LOW: Edge Cases
- Very early game (no equipment) heroes should still be viable
- Max-level S-rank heroes shouldn't trivialize all content

---

## Validation Checklist

After implementation, verify:
- [ ] D-rank hero with no equipment has ~20% chance on D-rank quest (challenging but doable)
- [ ] D-rank hero with D-rank equipment has ~50-60% chance on D-rank quest (fair)
- [ ] B-rank hero with B-rank equipment has ~50-60% chance on B-rank quest
- [ ] S-rank hero with S-rank equipment has ~50-60% chance on S-rank quest
- [ ] Lower rank heroes should struggle on higher rank quests
- [ ] Higher rank heroes should have high success on lower rank quests

---

## Summary

This plan normalizes the entire stat system to 1-100:
- **Heroes**: Base stats range from 5 (worst D-rank) to 100 (capped S-rank)
- **Quests**: Expected stats range from 20 (D-rank) to 95 (S-rank)
- **Equipment**: Provides meaningful but not overwhelming bonuses
- **Scaling**: Smooth progression where each rank tier feels appropriately challenging

**WAITING FOR CONFIRMATION**: Proceed with this plan? (yes/no/modify)
