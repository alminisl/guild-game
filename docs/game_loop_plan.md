# Core Game Loop Enhancement Plan

## Philosophy (From User Input)

> "Idle games are not games that play themselves. They are decision games with delayed resolution."

**Core Loop**: Make decision → Wait → Observe outcome → Adjust strategy

**Golden Rule**: "The player should feel clever before the run, not busy during it."

---

## Current State Analysis

### What Works Well
- Real-time quest phases with visual feedback
- Hero roster management with clear status
- Faction reputation system
- Guild level progression
- Equipment system with stat bonuses
- Class/race variety

### Critical Gaps
1. **Decisions don't feel meaningful** - Just pick strongest heroes
2. **Risk is easily avoided** - Cleric prevents all death
3. **No tension when returning** - Nothing bad can happen while away
4. **Consequences don't stick** - Failed quest = just longer rest
5. **No "clever setup" feeling** - Party composition is obvious

---

## MVP Focus: Make One Loop Feel Good

Per user: No prestige, minimal automation, focus on the core loop.

### The Ideal Single Quest Loop

```
1. PLAYER SEES QUEST
   - Clear risk indicators (injury %, death %, bonus reward %)
   - Required stat highlighted
   - Time commitment shown

2. PLAYER BUILDS PARTY
   - Synergy bonuses visible (Cleric + Knight = +10% survival)
   - Risk changes as party forms
   - Trade-offs are clear (fast hero vs. strong hero)

3. PLAYER COMMITS
   - Confirmation shows full breakdown
   - "Are you sure?" for dangerous quests
   - Resources locked (heroes unavailable)

4. PLAYER WAITS (The Idle Part)
   - Progress visible but hands-off
   - Can do other things (manage inventory, check stats)
   - Tension builds as execute phase approaches

5. PLAYER RECEIVES RESULTS
   - Clear success/failure display
   - Rewards itemized (gold, XP, materials, bonus drops)
   - Consequences shown (hero injured for X time, hero gained trait)
   - "What went wrong" hints on failure
```

---

## Phase 1: Visible Risk & Meaningful Decisions

### 1.1 Risk Display Overhaul

**Current**: Success chance shown as single percentage
**Proposed**: Multi-factor risk breakdown

```
┌─────────────────────────────────────┐
│ QUEST: Vampire Nest [A-rank] [Night]│
├─────────────────────────────────────┤
│ Success Chance: 72%                 │
│ ─────────────────────────────────── │
│ On Success:                         │
│   Gold: 280g                        │
│   XP: 160 per hero                  │
│   Drops: Enchanted Gem (40%)        │
│          Phoenix Feather (5%)       │
│                                     │
│ On Failure:                         │
│   Gold: 56g (20%)                   │
│   XP: 48 per hero (30%)             │
│   DEATH RISK: 30% per hero          │
│   └─ Cleric in party: PROTECTED    │
│                                     │
│ Time: ~45 seconds                   │
└─────────────────────────────────────┘
```

**Files to modify**:
- `ui/guild_menu.lua` - Add expanded risk panel
- `data/quests.lua` - Ensure possibleRewards displayed

### 1.2 Party Synergy System

**New Mechanic**: Class combinations provide bonuses

| Combo | Bonus |
|-------|-------|
| Cleric + Any | Death protection on A/S quests |
| Knight + Knight | +10% survival chance |
| Mage + Mage | +15% success on INT quests |
| Rogue + Ranger | +25% material drops |
| Mixed (3+ classes) | +5% all bonuses |

**Files to modify**:
- `data/heroes.json` - Add synergy definitions
- `data/quests.lua` - Apply synergy in calculateSuccessChance
- `ui/guild_menu.lua` - Show active synergies in party panel

### 1.3 Quest Difficulty Tiers Within Ranks

**Current**: All D-rank quests feel the same
**Proposed**: Add difficulty modifiers

```json
{
  "name": "Rat Cellar",
  "difficulty": "easy",      // easy, normal, hard
  "difficultyBonus": {
    "reward": 0.8,           // 80% base reward
    "success": 0.1           // +10% success chance
  }
}
```

Hard quests = more reward, more risk, player chooses.

---

## Phase 2: Persistent Consequences

### 2.1 Hero Injury System (Replace Failure Count)

**Current**: failureCount tracks toward death (unclear)
**Proposed**: Injury states with gameplay impact

```
HERO STATUS:
├─ Healthy (full stats)
├─ Fatigued (after successful quest, -10% stats until rested)
├─ Injured (failed D/C/B quest, -25% stats, 2x rest time)
├─ Wounded (failed A/S quest, -50% stats, 3x rest time)
└─ Dead (A/S quest without Cleric protection)
```

**How Injuries Occur**:
- Successful quest → Hero becomes Fatigued (normal rest)
- Failed D/C/B quest → Hero becomes Injured (2x rest time)
- Failed A/S quest (with Cleric) → Hero becomes Wounded (3x rest time)
- Failed A/S quest (no Cleric) → Hero may die (30-50% chance)

**Rest Time Multipliers**:
| Status | Rest Multiplier | Stat Penalty | Can Quest? |
|--------|-----------------|--------------|------------|
| Healthy | 1x | None | Yes |
| Fatigued | 1x | -10% all stats | Yes (risky) |
| Injured | **2x** | -25% all stats | Yes (very risky) |
| Wounded | **3x** | -50% all stats | No (must rest) |

**Recovery Path**:
- Fatigued → Healthy: Normal rest time
- Injured → Healthy: **2x normal rest time** (Potion reduces to 1.5x)
- Wounded → Injured → Healthy: **3x rest** then **2x rest** (Greater Potion skips to Fatigued)

**Key Design Point**: Injured heroes CAN still go on quests but at reduced effectiveness. This creates a risk/reward decision: "Do I send my injured hero now, or wait for them to heal?"

**Files to modify**:
- `data/heroes.lua` - Add injury states and rest multiplier logic
- `data/heroes.json` - Add injury config (multipliers, stat penalties)
- `systems/quest_system.lua` - Apply injuries on failure
- `ui/guild_menu.lua` - Show injury status with colored icons

### 2.2 Hero Progression System

Heroes grow stronger the longer you keep them alive. Each level up offers meaningful choices.

**Level Up Rewards**:
| Level | Reward |
|-------|--------|
| 1-4 | +1 random stat |
| 5 | **Choose 1 of 3 passive traits** |
| 6-9 | +1 random stat |
| 10 | **Choose 1 of 3 passive traits** (powerful) |

**Passive Trait Categories** (player picks 1 of 3 offered):

*Combat Traits*:
| Trait | Effect |
|-------|--------|
| Iron Will | +15% survival on failed quests |
| Battle Hardened | +10% success on combat quests |
| First Strike | +5% success, +10% on quick quests |
| Berserker | +20% STR quests, -10% survival |

*Utility Traits*:
| Trait | Effect |
|-------|--------|
| Quick Learner | +25% XP gained |
| Treasure Nose | +20% gold from quests |
| Swift Recovery | -30% rest time |
| Lucky Charm | +15% rare drop chance |

*Support Traits*:
| Trait | Effect |
|-------|--------|
| Team Player | +5% success per party member |
| Mentor | Party members gain +10% XP |
| Guardian | Protects 1 ally from injury on failure |
| Salvager | Always recovers items from dead allies |

**Trait Selection UI**:
```
╔═══════════════════════════════════════╗
║   LEVEL UP! Marcus reached Lv.5!      ║
╠═══════════════════════════════════════╣
║   Choose a passive trait:             ║
║                                       ║
║   [1] Iron Will                       ║
║       +15% survival on failed quests  ║
║                                       ║
║   [2] Quick Learner                   ║
║       +25% XP gained                  ║
║                                       ║
║   [3] Lucky Charm                     ║
║       +15% rare drop chance           ║
╚═══════════════════════════════════════╝
```

**Design Goal**: A level 10 hero with 2 chosen traits is VALUABLE. Losing them hurts.

### 2.3 Earned Traits (Through Play)

In addition to chosen traits, heroes can EARN traits from experiences:

| Trait | Trigger | Effect |
|-------|---------|--------|
| Veteran | Complete 20 quests | +5% success |
| Scarred | Survive near-death 3x | -2 VIT, +2 STR |
| Lucky | Get 3 rare drops | +1 LUCK permanent |
| Cursed | Fail 3 night quests | -10% on night quests |
| Dragonslayer | Complete S-rank quest | +20% vs S-rank quests |
| Lone Survivor | Only survivor of party wipe | +10% survival, -5% team synergy |

**Files to create**:
- `data/traits.json` - Trait definitions (passive + earned)
- `systems/trait_system.lua` - Trait selection and earning logic

**Files to modify**:
- `data/heroes.lua` - Add traits array, pending trait selection
- `ui/guild_menu.lua` - Trait selection popup, display on hero card

### 2.4 Death Has Weight

**Current**: Heroes die, you hire new ones
**Proposed**: Death has real consequences

**Equipment Loss on Death**:
- Dead heroes **lose all equipped items** (weapon, armor, accessory)
- Items are DESTROYED unless a party member survives
- **Survivor Recovery**: If at least 1 hero survives, they salvage dead heroes' items
- Heroes with **Salvager** trait always recover items, even if they die too

```
╔═══════════════════════════════════════╗
║         QUEST FAILED - DEATHS         ║
╠═══════════════════════════════════════╣
║   Sir Marcus has fallen!              ║
║                                       ║
║   LOST EQUIPMENT:                     ║
║     Steel Longsword (A-rank)          ║
║     Knight's Plate (B-rank)           ║
║                                       ║
║   Elena SURVIVED and recovered:       ║
║     ✓ Steel Longsword                 ║
║     ✓ Knight's Plate                  ║
║                                       ║
║   Items returned to inventory.        ║
╚═══════════════════════════════════════╝
```

**Total Party Wipe** (no survivors):
```
╔═══════════════════════════════════════╗
║       TOTAL PARTY WIPE                ║
╠═══════════════════════════════════════╣
║   All heroes have fallen...           ║
║                                       ║
║   PERMANENTLY LOST:                   ║
║     ✗ Steel Longsword (A-rank)        ║
║     ✗ Knight's Plate (B-rank)         ║
║     ✗ Mage's Staff (B-rank)           ║
║                                       ║
║   The equipment was not recovered.    ║
╚═══════════════════════════════════════╝
```

**Other Death Consequences**:
- **Memorial**: Dead heroes shown in Graveyard with stats and cause of death
- **Guild Mourning**: -10% success for 60 seconds after death
- **Reputation Hit**: Lose 5 faction rep when hero dies on their faction's quest

**Why This Matters**:
- High-rank equipment becomes precious (don't send your best gear on risky quests!)
- Party composition matters (always have a potential survivor)
- Clerics are even more valuable (prevent death = keep items)
- Creates tension: "Do I risk my A-rank sword on this S-rank quest?"

**Files to modify**:
- `systems/quest_system.lua` - Handle equipment loss/recovery on death
- `ui/guild_menu.lua` - Death result modal with item fate
- `data/heroes.lua` - Graveyard tracking

---

## Phase 3: Time as Resource

### 3.1 Quest Duration Trade-offs

**Current**: Longer quests = more reward (linear)
**Proposed**: Non-linear risk/reward

| Duration | Gold/sec | Risk | Notes |
|----------|----------|------|-------|
| Quick (15s) | Low | Low | Safe grinding |
| Normal (45s) | Medium | Medium | Balanced |
| Extended (90s) | High | High | High stakes |
| Expedition (5min) | Very High | Very High | Rare drops |

**Player Decision**: "Do I want safe progress or risky jackpot?"

### 3.2 Day/Night Pressure

**Current**: Night quests exist but no pressure
**Proposed**: Time-limited opportunities

- Night quests pay 1.5x but only available for 90 seconds of night
- Day quests are safer but lower reward
- Some quests have "Urgent" tag - disappear in 60 seconds

**UI Change**: Show countdown timer on urgent quests

### 3.3 Parallel Quest Management

**Current**: Can run multiple quests, no strategy
**Proposed**: Quest slot system with trade-offs

```
Guild Level 1: 2 quest slots
Guild Level 5: 4 quest slots
Guild Level 10: 6 quest slots

BUT: Running 2+ quests simultaneously:
- Each quest gets -5% success (heroes spread thin)
- Synergies don't apply across quests
```

Player decides: Serial (safer) vs Parallel (faster but riskier)

---

## Phase 4: Readable Results

### 4.1 Quest Completion Summary

**Current**: Toast notification, easy to miss
**Proposed**: Modal popup for important results

```
╔═══════════════════════════════════════╗
║        QUEST COMPLETE: SUCCESS        ║
╠═══════════════════════════════════════╣
║ Vampire Nest [A-rank]                 ║
║                                       ║
║ REWARDS EARNED:                       ║
║   Gold: 280 (+45 bonus)               ║
║   XP: 160 per hero                    ║
║   Enchanted Gem x2                    ║
║   Phoenix Feather x1 (RARE!)          ║
║                                       ║
║ HERO STATUS:                          ║
║   Sir Marcus: Fatigued (rest 20s)     ║
║   Elena: Fatigued (rest 18s)          ║
║   Brother Thomas: Healthy (Cleric)    ║
║                                       ║
║ REPUTATION:                           ║
║   Humans: +12 (now Friendly)          ║
║                                       ║
║              [Continue]               ║
╚═══════════════════════════════════════╝
```

**Files to modify**:
- `ui/guild_menu.lua` - Add result modal
- `main.lua` - Pause for important results

### 4.2 Failure Breakdown

On failure, show WHY:

```
╔═══════════════════════════════════════╗
║         QUEST FAILED                  ║
╠═══════════════════════════════════════╣
║ What went wrong:                      ║
║   - Party STR (24) below ideal (30)   ║
║   - No Cleric for healing             ║
║   - Night quest penalty applied       ║
║                                       ║
║ Suggestion:                           ║
║   Bring a Knight or Cleric next time  ║
╚═══════════════════════════════════════╝
```

### 4.3 Quest History Log

Add "History" tab to Guild Menu:

```
RECENT QUESTS (last 20):
───────────────────────────────────
[OK] Rat Cellar (D) - 35g, 20 XP
[OK] Goblin Camp (C) - 92g, 55 XP
[X]  Werewolf Hunt (C) - FAILED
     Marcus injured, Elena fatigued
[OK] Forest Spirits (C) - 88g, 52 XP
───────────────────────────────────
Session Stats:
  Quests: 4 (75% success)
  Gold: 215g earned
  XP: 127 total
```

---

## Implementation Order (MVP First)

### Sprint 1: Core Risk Visibility
1. [DONE] Death warnings already added
2. Add expanded quest info panel (rewards, risks)
3. Add synergy display in party panel

### Sprint 2: Consequence System
4. Implement injury states (Fatigued/Injured/Wounded)
5. Update rest system for injury recovery
6. Add injury icons to hero cards

### Sprint 3: Result Feedback
7. Create quest completion modal
8. Add failure breakdown hints
9. Add quest history tab

### Sprint 4: Time Pressure
10. Add urgent quest timers
11. Add parallel quest penalty
12. Balance duration vs reward

---

## Files Summary

### New Files
- `data/traits.json` - Hero trait definitions
- `data/synergies.json` - Party combo bonuses
- `systems/trait_system.lua` - Trait logic

### Modified Files
- `data/heroes.lua` / `heroes.json` - Injury states, traits
- `data/quests.lua` / `quests.json` - Difficulty tiers, urgency
- `systems/quest_system.lua` - Injury application, synergies
- `ui/guild_menu.lua` - Risk panel, result modal, history tab
- `main.lua` - Modal system for results

---

## Success Metric

**The 2-Hour Test**:
> "If the player leaves for 2 hours, will they be excited to come back?"

With these changes:
- Heroes might be injured (need attention)
- Quest results waiting to be seen
- Urgent quests might have expired
- New night/day cycle quests available
- Gold/materials accumulated

**Player returns thinking**: "What happened? Did my heroes survive? What did I earn?"

---

## Questions to Consider

1. **Injury Severity**: Should injuries be punishing (forces player to manage) or mild (just flavor)?

2. **Trait Permanence**: Should traits be permanent, or fade over time?

3. **Failure Hints**: How explicit should failure reasons be? (Hand-holding vs discovery)

4. **Modal Popups**: Should all quest completions pause for modal, or just important ones (failures, deaths, rare drops)?
