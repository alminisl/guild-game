-- Party System Module
-- Manages hero parties, tracking, and party bonuses

local PartySystem = {}

-- Party name generation pools
local partyNameAdjectives = {
    "Brave", "Fierce", "Noble", "Shadow", "Iron", "Golden", "Silver", "Crimson",
    "Azure", "Emerald", "Phantom", "Thunder", "Storm", "Frost", "Flame", "Steel",
    "Wild", "Silent", "Swift", "Mighty", "Dread", "Valiant", "Reckless", "Fearless"
}

local partyNameNouns = {
    "Wolves", "Dragons", "Hawks", "Lions", "Bears", "Serpents", "Phoenixes",
    "Knights", "Sentinels", "Guardians", "Hunters", "Seekers", "Raiders", "Wardens",
    "Blades", "Shields", "Arrows", "Fangs", "Claws", "Wings", "Hearts", "Souls"
}

-- Party configuration
PartySystem.config = {
    requiredMembers = 4,           -- Heroes needed to form a party
    questsToForm = 3,              -- Successful quests together to become official
    luckBonus = 3,                 -- Flat luck bonus for party members
    rerollsPerQuest = 1,           -- Number of re-rolls on failed quests
}

-- Internal party ID counter
local nextPartyId = 1

-- Generate a random party name
function PartySystem.generateName()
    local adj = partyNameAdjectives[math.random(#partyNameAdjectives)]
    local noun = partyNameNouns[math.random(#partyNameNouns)]
    return "The " .. adj .. " " .. noun
end

-- Create a new party (proto-party, not yet formed)
function PartySystem.createParty(heroIds)
    local party = {
        id = nextPartyId,
        name = PartySystem.generateName(),
        memberIds = {},              -- Hero IDs in this party
        questsTogether = {},         -- Track quests per member: {heroId = questCount}
        isFormed = false,            -- True once all members have 3+ quests together
        formedDate = nil,            -- Day the party officially formed
        totalQuestsCompleted = 0,    -- Total quests completed as a formed party
    }

    -- Initialize member tracking
    for _, heroId in ipairs(heroIds) do
        table.insert(party.memberIds, heroId)
        party.questsTogether[heroId] = 0
    end

    nextPartyId = nextPartyId + 1
    return party
end

-- Check if a group of heroes can form a party (4 different classes)
function PartySystem.canFormParty(heroes)
    if #heroes ~= PartySystem.config.requiredMembers then
        return false, "Party requires exactly " .. PartySystem.config.requiredMembers .. " heroes"
    end

    -- Check for unique classes
    local classes = {}
    for _, hero in ipairs(heroes) do
        if classes[hero.class] then
            return false, "Party members must have different classes"
        end
        classes[hero.class] = true
    end

    -- Check if any hero is already in a formed party
    for _, hero in ipairs(heroes) do
        if hero.partyId then
            return false, hero.name .. " is already in a party"
        end
    end

    return true, "Can form party"
end

-- Find or create a proto-party for a group of heroes questing together
function PartySystem.getOrCreateProtoParty(heroes, gameData)
    if #heroes ~= PartySystem.config.requiredMembers then
        return nil
    end

    -- Check for unique classes
    local classes = {}
    for _, hero in ipairs(heroes) do
        if classes[hero.class] then
            return nil  -- Can't form party without unique classes
        end
        classes[hero.class] = true
    end

    -- Get hero IDs sorted for consistent comparison
    local heroIds = {}
    for _, hero in ipairs(heroes) do
        table.insert(heroIds, hero.id)
    end
    table.sort(heroIds)

    -- Check if this exact group already has a proto-party
    gameData.protoParties = gameData.protoParties or {}
    for _, party in ipairs(gameData.protoParties) do
        local partyIds = {}
        for _, id in ipairs(party.memberIds) do
            table.insert(partyIds, id)
        end
        table.sort(partyIds)

        -- Compare sorted ID lists
        local match = #partyIds == #heroIds
        if match then
            for i, id in ipairs(heroIds) do
                if partyIds[i] ~= id then
                    match = false
                    break
                end
            end
        end

        if match then
            return party
        end
    end

    -- Create new proto-party
    local party = PartySystem.createParty(heroIds)
    table.insert(gameData.protoParties, party)
    return party
end

-- Record a successful quest for a party
function PartySystem.recordQuestSuccess(heroes, gameData)
    if #heroes ~= PartySystem.config.requiredMembers then
        return nil
    end

    local party = PartySystem.getOrCreateProtoParty(heroes, gameData)
    if not party then
        return nil
    end

    -- Increment quest count for each hero
    local allFormed = true
    for _, hero in ipairs(heroes) do
        party.questsTogether[hero.id] = (party.questsTogether[hero.id] or 0) + 1
        if party.questsTogether[hero.id] < PartySystem.config.questsToForm then
            allFormed = false
        end
    end

    -- Check if party should now be officially formed
    if allFormed and not party.isFormed then
        party.isFormed = true
        party.formedDate = gameData.day or 1

        -- Assign party ID to all members
        for _, hero in ipairs(heroes) do
            hero.partyId = party.id
        end

        -- Move from proto-parties to official parties
        gameData.parties = gameData.parties or {}
        table.insert(gameData.parties, party)

        -- Remove from proto-parties
        for i, p in ipairs(gameData.protoParties) do
            if p.id == party.id then
                table.remove(gameData.protoParties, i)
                break
            end
        end

        return party, true  -- Return party and "just formed" flag
    end

    if party.isFormed then
        party.totalQuestsCompleted = party.totalQuestsCompleted + 1
    end

    return party, false
end

-- Get a party by ID
function PartySystem.getParty(partyId, gameData)
    gameData.parties = gameData.parties or {}
    for _, party in ipairs(gameData.parties) do
        if party.id == partyId then
            return party
        end
    end
    return nil
end

-- Get party members (hero objects)
function PartySystem.getPartyMembers(party, gameData)
    local members = {}
    for _, heroId in ipairs(party.memberIds) do
        for _, hero in ipairs(gameData.heroes) do
            if hero.id == heroId then
                table.insert(members, hero)
                break
            end
        end
    end
    return members
end

-- Check if heroes are a formed party
function PartySystem.isFormedParty(heroes, gameData)
    if #heroes ~= PartySystem.config.requiredMembers then
        return false, nil
    end

    -- Check if all heroes share the same party ID
    local partyId = heroes[1].partyId
    if not partyId then
        return false, nil
    end

    for _, hero in ipairs(heroes) do
        if hero.partyId ~= partyId then
            return false, nil
        end
    end

    local party = PartySystem.getParty(partyId, gameData)
    if party and party.isFormed then
        return true, party
    end

    return false, nil
end

-- Check if a hero's party has a cleric for guaranteed death protection
function PartySystem.hasClericProtection(heroes, gameData)
    local isParty, party = PartySystem.isFormedParty(heroes, gameData)
    if not isParty then
        return false
    end

    -- Check if any party member is a Priest or Saint
    for _, hero in ipairs(heroes) do
        if hero.class == "Priest" or hero.class == "Saint" then
            return true
        end
    end

    return false
end

-- Get luck bonus for party members
function PartySystem.getLuckBonus(heroes, gameData)
    local isParty, party = PartySystem.isFormedParty(heroes, gameData)
    if isParty then
        return PartySystem.config.luckBonus
    end
    return 0
end

-- Check if party can re-roll a failed quest
function PartySystem.canReroll(heroes, gameData)
    local isParty, party = PartySystem.isFormedParty(heroes, gameData)
    return isParty and party ~= nil
end

-- Handle party member death/removal
function PartySystem.removeMember(heroId, gameData)
    gameData.parties = gameData.parties or {}

    for _, party in ipairs(gameData.parties) do
        for i, memberId in ipairs(party.memberIds) do
            if memberId == heroId then
                -- Don't remove from memberIds, just mark quest count as needing rebuild
                -- The party continues but new member needs to quest to earn bonuses
                party.questsTogether[heroId] = 0

                -- Clear party ID from the removed hero (they might be dead)
                for _, hero in ipairs(gameData.heroes) do
                    if hero.id == heroId then
                        hero.partyId = nil
                        break
                    end
                end

                return party
            end
        end
    end

    return nil
end

-- Add a new member to a party (replacing a removed/dead member)
function PartySystem.addMember(party, newHero, gameData)
    -- Check if hero has different class from existing members
    local members = PartySystem.getPartyMembers(party, gameData)
    for _, member in ipairs(members) do
        if member.class == newHero.class then
            return false, "Party already has a " .. newHero.class
        end
    end

    -- Check if hero is already in a party
    if newHero.partyId then
        return false, newHero.name .. " is already in a party"
    end

    -- Find an empty slot (member with 0 quests who isn't in heroes anymore)
    local slotFound = false
    for i, memberId in ipairs(party.memberIds) do
        local memberExists = false
        for _, hero in ipairs(gameData.heroes) do
            if hero.id == memberId and hero.partyId == party.id then
                memberExists = true
                break
            end
        end

        if not memberExists or party.questsTogether[memberId] == 0 then
            -- Replace this slot
            party.memberIds[i] = newHero.id
            party.questsTogether[newHero.id] = 0
            newHero.partyId = party.id
            slotFound = true
            break
        end
    end

    if not slotFound then
        return false, "No open slots in party"
    end

    return true, newHero.name .. " joined the party (needs " .. PartySystem.config.questsToForm .. " quests for full bonuses)"
end

-- Check if all party members have full bonuses
function PartySystem.allMembersQualified(party)
    for _, count in pairs(party.questsTogether) do
        if count < PartySystem.config.questsToForm then
            return false
        end
    end
    return true
end

-- Get party status text
function PartySystem.getStatusText(party, gameData)
    if not party.isFormed then
        -- Count progress
        local minQuests = math.huge
        for _, count in pairs(party.questsTogether) do
            minQuests = math.min(minQuests, count)
        end
        return string.format("Forming... (%d/%d quests)", minQuests, PartySystem.config.questsToForm)
    end

    if not PartySystem.allMembersQualified(party) then
        return "Rebuilding bonds..."
    end

    return "Active"
end

-- Rename a party
function PartySystem.renameParty(party, newName)
    if newName and #newName > 0 and #newName <= 30 then
        party.name = newName
        return true
    end
    return false
end

-- Disband a party
function PartySystem.disbandParty(party, gameData)
    -- Clear party ID from all members
    for _, heroId in ipairs(party.memberIds) do
        for _, hero in ipairs(gameData.heroes) do
            if hero.id == heroId then
                hero.partyId = nil
                break
            end
        end
    end

    -- Remove from parties list
    for i, p in ipairs(gameData.parties) do
        if p.id == party.id then
            table.remove(gameData.parties, i)
            break
        end
    end

    return true
end

-- Initialize party data in game data
function PartySystem.initGameData(gameData)
    gameData.parties = gameData.parties or {}
    gameData.protoParties = gameData.protoParties or {}
end

-- Set next party ID (for save/load)
function PartySystem.setNextId(id)
    nextPartyId = id
end

-- Get next party ID (for save/load)
function PartySystem.getNextId()
    return nextPartyId
end

return PartySystem
