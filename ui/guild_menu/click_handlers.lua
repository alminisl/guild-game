-- ui/guild_menu/click_handlers.lua
-- Complete click event routing for all guild menu interactions

local Components = require("ui.components")
local PartySystem = require("systems.party_system")

local ClickHandlers = {}

-- Main click handler - routes to appropriate tab/modal handlers
function ClickHandlers.handle(x, y, gameData, QuestSystem, Quests, Heroes, GuildSystem, State, Helpers, Equipment, EquipmentSystem)
    -- Get module references from roster tab
    local RosterTab = require("ui.guild_menu.roster_tab")
    
    -- Transform screen coordinates to design coordinates
    Helpers.updateMenuRect(State)
    local scale = State.MENU.scale or 1
    local designX = (x - State.MENU.x) / scale
    local designY = (y - State.MENU.y) / scale
    
    local MENU_DESIGN_WIDTH = Helpers.MENU_DESIGN_WIDTH
    local MENU_DESIGN_HEIGHT = Helpers.MENU_DESIGN_HEIGHT
    
    -- ============================================================================
    -- HERO DETAIL POPUP (overlay on any tab)
    -- ============================================================================
    if State.selectedHeroDetail and State.currentTab ~= "roster" then
        local windowW, windowH = love.graphics.getDimensions()
        local popupW, popupH = 580, 560
        local popupX = (windowW - popupW) / 2
        local popupY = (windowH - popupH) / 2
        
        -- Close button on popup
        if Components.isPointInRect(x, y, popupX + popupW - 40, popupY + 10, 30, 30) then
            State.selectedHeroDetail = nil
            State.equipDropdownSlot = nil
            State.equipDropdownItems = {}
            return nil
        end
        
        -- Bars/Graph toggle button
        local toggleBtnPos = RosterTab.getToggleButtonPos()
        if toggleBtnPos and Components.isPointInRect(x, y, toggleBtnPos.x, toggleBtnPos.y, toggleBtnPos.w, toggleBtnPos.h) then
            State.statDisplayMode = (State.statDisplayMode == "bars") and "graph" or "bars"
            return nil
        end
        
        -- Equipment slot buttons
        local equipSlotPositions = RosterTab.getEquipSlotPositions()
        if equipSlotPositions and EquipmentSystem then
            for _, slotInfo in ipairs(equipSlotPositions) do
                local btnX = popupX + popupW - 55
                local btnY = slotInfo.y + 2
                local btnW, btnH = 24, 24
                
                if Components.isPointInRect(x, y, btnX, btnY, btnW, btnH) then
                    if slotInfo.equipped then
                        local success, msg = EquipmentSystem.unequip(State.selectedHeroDetail, slotInfo.key, gameData)
                        if success then
                            return "equip_changed", State.selectedHeroDetail.name .. " unequipped item"
                        end
                    else
                        local available = EquipmentSystem.getAvailableForSlot(gameData, slotInfo.key, State.selectedHeroDetail.rank)
                        if #available > 0 then
                            local success, msg = EquipmentSystem.equip(State.selectedHeroDetail, available[1].item.id, gameData)
                            if success then
                                return "equip_changed", State.selectedHeroDetail.name .. " equipped " .. available[1].item.name
                            end
                        end
                    end
                    return nil
                end
            end
        end
        
        -- Click outside popup closes it
        if not Components.isPointInRect(x, y, popupX, popupY, popupW, popupH) then
            State.selectedHeroDetail = nil
            State.equipDropdownSlot = nil
            State.equipDropdownItems = {}
            return nil
        end
        
        return nil
    end
    
    -- ============================================================================
    -- PARTY CREATION MODAL
    -- ============================================================================
    if State.partyCreationActive then
        local modalW = 800
        local modalH = 500
        local modalX = (MENU_DESIGN_WIDTH - modalW) / 2
        local modalY = (MENU_DESIGN_HEIGHT - modalH) / 2
        
        -- Check if clicking outside modal (close it)
        if not Components.isPointInRect(designX, designY, modalX, modalY, modalW, modalH) then
            State.partyCreationActive = false
            State.selectedHeroesForParty = {}
            State.partyCreationName = ""
            return nil
        end
        
        -- Cancel button
        if Components.isPointInRect(designX, designY, modalX + 20, modalY + modalH - 35, 150, 30) then
            State.partyCreationActive = false
            State.selectedHeroesForParty = {}
            State.partyCreationName = ""
            return nil
        end
        
        -- Random Name button
        if Components.isPointInRect(designX, designY, modalX + 325, modalY + modalH - 35, 150, 30) then
            State.partyCreationName = PartySystem.generateName()
            return nil
        end
        
        -- Create Party button
        if Components.isPointInRect(designX, designY, modalX + modalW - 170, modalY + modalH - 35, 150, 30) and #State.selectedHeroesForParty == 4 then
            -- Create the party
            local finalName = State.partyCreationName ~= "" and State.partyCreationName or nil
            local newParty = PartySystem.createParty(State.selectedHeroesForParty, finalName)
            newParty.createdDay = gameData.day or 1
            
            -- Assign party IDs to heroes
            for _, heroId in ipairs(State.selectedHeroesForParty) do
                for _, hero in ipairs(gameData.heroes) do
                    if hero.id == heroId then
                        hero.partyId = newParty.id
                        break
                    end
                end
            end
            
            -- Add to parties list
            gameData.parties = gameData.parties or {}
            table.insert(gameData.parties, newParty)
            
            -- Close modal
            State.partyCreationActive = false
            State.selectedHeroesForParty = {}
            State.partyCreationName = ""
            
            return "party_created", "Created party: " .. newParty.name
        end
        
        -- Hero selection in grid
        local contentY = modalY + 70
        local gridY = contentY + 60
        local gridCols = 4
        local gridSpacing = 10
        local cardW = (modalW - 40 - (gridCols - 1) * gridSpacing) / gridCols
        local cardH = 120
        
        -- Get available heroes
        local availableHeroes = {}
        for _, hero in ipairs(gameData.heroes) do
            if (hero.status == "idle" or not hero.status) and not hero.partyId then
                table.insert(availableHeroes, hero)
            end
        end
        
        -- Check hero card clicks
        local row = 0
        local col = 0
        for i, hero in ipairs(availableHeroes) do
            if i > 12 then break end
            
            local cardX = modalX + 20 + col * (cardW + gridSpacing)
            local cardY = gridY + row * (cardH + gridSpacing)
            
            -- Check if this class is already selected
            local classDisabled = false
            for _, selectedId in ipairs(State.selectedHeroesForParty) do
                for _, h in ipairs(gameData.heroes) do
                    if h.id == selectedId and h.class == hero.class then
                        classDisabled = true
                        break
                    end
                end
            end
            
            if Components.isPointInRect(designX, designY, cardX, cardY, cardW, cardH) and not classDisabled then
                -- Toggle selection
                local isSelected = false
                local selectedIndex = nil
                for idx, selectedId in ipairs(State.selectedHeroesForParty) do
                    if selectedId == hero.id then
                        isSelected = true
                        selectedIndex = idx
                        break
                    end
                end
                
                if isSelected then
                    -- Deselect
                    table.remove(State.selectedHeroesForParty, selectedIndex)
                else
                    -- Select (if not at limit)
                    if #State.selectedHeroesForParty < 4 then
                        table.insert(State.selectedHeroesForParty, hero.id)
                    end
                end
                return nil
            end
            
            col = col + 1
            if col >= gridCols then
                col = 0
                row = row + 1
            end
        end
        
        return nil
    end
    
    -- ============================================================================
    -- CLOSE BUTTON
    -- ============================================================================
    if Components.isPointInRect(designX, designY, MENU_DESIGN_WIDTH - 40, 10, 30, 30) then
        State.reset()
        return "close"
    end
    
    -- ============================================================================
    -- TAB SWITCHING
    -- ============================================================================
    local tabY = 50
    local clickedTab = Components.getClickedTab(Helpers.TABS, designX, designY, 20, tabY, 100, 30)
    if clickedTab then
        State.currentTab = clickedTab
        if clickedTab ~= "quests" then
            State.selectedQuest = nil
            State.selectedHeroes = {}
        end
        return nil
    end
    
    local contentY = tabY + 35
    
    -- ============================================================================
    -- ROSTER TAB - Hero details, fire, expand/collapse parties
    -- ============================================================================
    if State.currentTab == "roster" then
        local cardHeight = 70
        local partyHeaderHeight = 40
        local listStartY = contentY + 25
        local listHeight = MENU_DESIGN_HEIGHT - 20 - listStartY
        local listX = 20
        
        -- Calculate actual list width based on whether detail panel is open (60-40 split)
        local actualListWidth = State.selectedHeroDetail and math.floor(MENU_DESIGN_WIDTH * 0.6) - 30 or (MENU_DESIGN_WIDTH - 40)
        local cardWidth = actualListWidth - 30
        
        -- Check for clicks in the detail panel area (right side, 40% width)
        if State.selectedHeroDetail then
            local panelW = math.floor(MENU_DESIGN_WIDTH * 0.4) - 10
            local panelX = MENU_DESIGN_WIDTH - panelW - 10
            local panelY = listStartY
            local panelH = listHeight
            
            -- Check if click is in panel area
            if Components.isPointInRect(designX, designY, panelX, panelY, panelW, panelH) then
                -- Handle toggle button clicks
                local toggleBtnPos = RosterTab.getToggleButtonPos()
                if toggleBtnPos and Components.isPointInRect(designX, designY, toggleBtnPos.x, toggleBtnPos.y, toggleBtnPos.w, toggleBtnPos.h) then
                    State.statDisplayMode = (State.statDisplayMode == "bars") and "graph" or "bars"
                    return nil
                end
                
                -- Handle equipment slot clicks
                local equipSlotPositions = RosterTab.getEquipSlotPositions()
                if equipSlotPositions and EquipmentSystem then
                    for _, slotInfo in ipairs(equipSlotPositions) do
                        local btnX = slotInfo.x + slotInfo.width - 22
                        local btnY = slotInfo.y + 2
                        local btnW, btnH = 20, 20
                        
                        if Components.isPointInRect(designX, designY, btnX, btnY, btnW, btnH) then
                            if slotInfo.equipped then
                                local success, msg = EquipmentSystem.unequip(State.selectedHeroDetail, slotInfo.key, gameData)
                                if success then
                                    return "equip_changed", State.selectedHeroDetail.name .. " unequipped item"
                                end
                            else
                                local available = EquipmentSystem.getAvailableForSlot(gameData, slotInfo.key, State.selectedHeroDetail.rank)
                                if #available > 0 then
                                    local success, msg = EquipmentSystem.equip(State.selectedHeroDetail, available[1].item.id, gameData)
                                    if success then
                                        return "equip_changed", State.selectedHeroDetail.name .. " equipped " .. available[1].item.name
                                    end
                                end
                            end
                            return nil
                        end
                    end
                end
                
                return nil  -- Click in panel, don't propagate
            end
        end
        
        -- Only process clicks within the scroll area
        if not Components.isPointInRect(designX, designY, listX, listStartY, actualListWidth, listHeight) then
            State.heroToFire = nil
            return nil
        end
        
        -- Build the same content layout as drawing (matches drawRosterTab)
        PartySystem.initGameData(gameData)
        local contentItems = {}
        
        if gameData.parties and #gameData.parties > 0 then
            for _, party in ipairs(gameData.parties) do
                local members = PartySystem.getPartyMembers(party, gameData)
                local isExpanded = State.expandedParties[party.id]
                table.insert(contentItems, {type = "party_header", party = party, members = members, height = partyHeaderHeight, cardWidth = cardWidth})
                if isExpanded then
                    for _, member in ipairs(members) do
                        table.insert(contentItems, {type = "party_member", hero = member, height = cardHeight + 5, cardWidth = cardWidth})
                    end
                end
            end
        end
        
        local unassignedHeroes = {}
        for _, hero in ipairs(gameData.heroes) do
            if not hero.partyId then
                table.insert(unassignedHeroes, hero)
            end
        end
        
        if #unassignedHeroes > 0 or #contentItems == 0 then
            table.insert(contentItems, {type = "section_header", text = "Unassigned Heroes", height = 25})
            for _, hero in ipairs(unassignedHeroes) do
                table.insert(contentItems, {type = "hero", hero = hero, height = cardHeight + 5, cardWidth = cardWidth})
            end
        end
        
        -- Find which item was clicked
        local itemY = listStartY - State.rosterScrollOffset
        for _, item in ipairs(contentItems) do
            local itemBottom = itemY + item.height
            
            -- Check if click is on this item (and item is visible)
            if designY >= itemY and designY < itemBottom and itemBottom >= listStartY and itemY < listStartY + listHeight then
                if item.type == "party_header" then
                    -- Toggle party expansion
                    State.expandedParties[item.party.id] = not State.expandedParties[item.party.id]
                    State.heroToFire = nil
                    return nil
                    
                elseif item.type == "party_member" or item.type == "hero" then
                    local hero = item.hero
                    
                    -- Check Fire button click (only for unassigned idle heroes)
                    if hero.status == "idle" and item.type == "hero" and cardWidth > 400 then
                        local fireBtnX = listX + cardWidth - 55
                        local fireBtnY = itemY + 10
                        local fireBtnW = 45
                        local fireBtnH = 22
                        
                        if Components.isPointInRect(designX, designY, fireBtnX, fireBtnY, fireBtnW, fireBtnH) then
                            if State.heroToFire == hero.id then
                                -- Confirm fire
                                for j, h in ipairs(gameData.heroes) do
                                    if h.id == hero.id then
                                        -- Return equipment to inventory
                                        if hero.equipment and gameData.inventory and gameData.inventory.equipment then
                                            for slot, itemId in pairs(hero.equipment) do
                                                if itemId then
                                                    gameData.inventory.equipment[itemId] = (gameData.inventory.equipment[itemId] or 0) + 1
                                                end
                                            end
                                        end
                                        table.remove(gameData.heroes, j)
                                        break
                                    end
                                end
                                State.heroToFire = nil
                                return "fired", hero.name .. " has been dismissed from the guild."
                            else
                                State.heroToFire = hero.id
                            end
                            return nil
                        end
                    end
                    
                    -- Click elsewhere on card opens details
                    State.heroToFire = nil
                    if hero.status == "idle" or hero.status == "resting" then
                        State.selectedHeroDetail = hero
                    end
                    return nil
                end
            end
            
            itemY = itemY + item.height
        end
        
        -- Clicking anywhere else resets fire confirmation
        State.heroToFire = nil
    end
    
    -- ============================================================================
    -- QUESTS TAB - Quest selection and hero assignment
    -- ============================================================================
    if State.currentTab == "quests" then
        -- Quest list clicks
        local questListWidth = 350
        local questY = contentY + 25
        for i, quest in ipairs(gameData.availableQuests) do
            if Components.isPointInRect(designX, designY, 20, questY, questListWidth - 10, 65) then
                State.selectedQuest = quest
                State.selectedHeroes = {}
                return nil
            end
            questY = questY + 70
        end
        
        -- Party selection clicks
        if State.selectedQuest then
            local partyX = questListWidth + 20
            local partyWidth = MENU_DESIGN_WIDTH - questListWidth - 50
            
            -- Mode toggle buttons
            local toggleY = contentY - 5
            local toggleBtnWidth = 80
            
            -- Individual (heroes) toggle button
            if Components.isPointInRect(designX, designY, partyX + partyWidth - 165, toggleY, toggleBtnWidth, 22) then
                State.questSelectionMode = "heroes"
                State.selectedPartyId = nil
                State.questHeroScrollOffset = 0
                return nil
            end
            
            -- Party toggle button
            if Components.isPointInRect(designX, designY, partyX + partyWidth - 80, toggleY, 70, 22) then
                State.questSelectionMode = "parties"
                State.selectedHeroes = {}
                State.questHeroScrollOffset = 0
                return nil
            end
            
            -- Clear button
            if Components.isPointInRect(designX, designY, partyX + partyWidth - 230, contentY - 5, 50, 22) then
                State.selectedHeroes = {}
                State.selectedPartyId = nil
                return nil
            end
            
            -- Hero/Party selection - with scroll offset support
            local heroListStartY = contentY + 210
            local listHeight = MENU_DESIGN_HEIGHT - 65 - heroListStartY
            
            -- Only process clicks within the list bounds
            if Components.isPointInRect(designX, designY, partyX, heroListStartY, partyWidth, listHeight) then
                if State.questSelectionMode == "heroes" then
                    -- HEROES MODE: Individual hero selection
                    local heroCardHeight = 70
                    local heroCardSpacing = 75
                    
                    -- Count currently selected heroes
                    local currentCount = 0
                    for _, isSelected in pairs(State.selectedHeroes) do
                        if isSelected then currentCount = currentCount + 1 end
                    end
                    local maxHeroes = State.selectedQuest.maxHeroes or 6
                    
                    -- Apply scroll offset to click position
                    local heroY = heroListStartY - State.questHeroScrollOffset
                    for i, hero in ipairs(gameData.heroes) do
                        if hero.status == "idle" then
                            -- Check if this hero card is at the clicked position
                            local cardScreenY = heroY
                            if designY >= cardScreenY and designY < cardScreenY + heroCardHeight
                               and cardScreenY + heroCardHeight >= heroListStartY
                               and cardScreenY < heroListStartY + listHeight then
                                -- Check for double-click to show hero detail popup
                                local currentTime = love.timer.getTime()
                                if State.lastHeroClickId == hero.id and (currentTime - State.lastHeroClickTime) < 0.4 then
                                    -- Double-click: show hero detail popup
                                    State.selectedHeroDetail = hero
                                    State.lastHeroClickId = nil
                                    State.lastHeroClickTime = 0
                                    return nil
                                end
                                State.lastHeroClickId = hero.id
                                State.lastHeroClickTime = currentTime
                                
                                -- Single click: toggle selection
                                if State.selectedHeroes[hero.id] then
                                    -- Always allow deselection
                                    State.selectedHeroes[hero.id] = nil
                                elseif currentCount < maxHeroes then
                                    -- Only allow selection if under limit
                                    State.selectedHeroes[hero.id] = true
                                end
                                return nil
                            end
                            heroY = heroY + heroCardSpacing
                        end
                    end
                else
                    -- PARTIES MODE: Select entire party
                    local partyCardHeight = 90
                    local partyCardSpacing = 95
                    
                    -- Get available parties
                    gameData.parties = gameData.parties or {}
                    local availableParties = {}
                    for _, party in ipairs(gameData.parties) do
                        if party.isFormed then
                            local allIdle = true
                            local members = PartySystem.getPartyMembers(party, gameData)
                            if #members == PartySystem.config.requiredMembers then
                                for _, member in ipairs(members) do
                                    if member.status ~= "idle" then
                                        allIdle = false
                                        break
                                    end
                                end
                                if allIdle then
                                    table.insert(availableParties, {party = party, members = members})
                                end
                            end
                        end
                    end
                    
                    -- Apply scroll offset to click position
                    local partyY = heroListStartY - State.questHeroScrollOffset
                    for i, partyData in ipairs(availableParties) do
                        local cardScreenY = partyY
                        if designY >= cardScreenY and designY < cardScreenY + partyCardHeight
                           and cardScreenY + partyCardHeight >= heroListStartY
                           and cardScreenY < heroListStartY + listHeight then
                            -- Toggle party selection
                            if State.selectedPartyId == partyData.party.id then
                                -- Deselect party
                                State.selectedPartyId = nil
                                State.selectedHeroes = {}
                            else
                                -- Select party - populate selectedHeroes with all members
                                State.selectedPartyId = partyData.party.id
                                State.selectedHeroes = {}
                                for _, member in ipairs(partyData.members) do
                                    State.selectedHeroes[member.id] = true
                                end
                            end
                            return nil
                        end
                        partyY = partyY + partyCardSpacing
                    end
                end
            end
            
            -- Send Party button
            local btnY = MENU_DESIGN_HEIGHT - 55
            if Components.isPointInRect(designX, designY, partyX, btnY, partyWidth, 35) then
                local partyHeroes = {}
                -- Only include heroes that are truly selected AND idle
                for heroId, isSelected in pairs(State.selectedHeroes) do
                    if isSelected == true then
                        for _, hero in ipairs(gameData.heroes) do
                            if hero.id == heroId and hero.status == "idle" then
                                table.insert(partyHeroes, hero)
                                break
                            end
                        end
                    end
                end
                
                if #partyHeroes > 0 then
                    -- Check quest slot availability
                    if GuildSystem and not GuildSystem.canStartQuest(gameData) then
                        return "error", "Quest slots full! Level up your guild."
                    end
                    
                    -- Assign quest to party
                    local success, message = QuestSystem.assignParty(State.selectedQuest, partyHeroes, gameData)
                    if success then
                        State.selectedQuest = nil
                        State.selectedHeroes = {}
                        State.selectedPartyId = nil
                        return "assigned", message
                    else
                        return "error", message
                    end
                end
                
                return "error", "Select heroes first!"
            end
        end
    end
    
    -- ============================================================================
    -- ACTIVE TAB - Quest execution buttons
    -- ============================================================================
    if State.currentTab == "active" then
        local y = contentY + 30
        
        for i, quest in ipairs(gameData.activeQuests) do
            if y + 85 > MENU_DESIGN_HEIGHT - 20 then break end
            
            -- Execute button
            if quest.currentPhase == "awaiting_execute" and quest._execBtnPos then
                local btn = quest._execBtnPos
                if Components.isPointInRect(designX, designY, btn.x, btn.y, btn.w, btn.h) then
                    return "execute_quest", quest
                end
            end
            
            -- Return button
            if quest.currentPhase == "awaiting_return" and quest._returnBtnPos then
                local btn = quest._returnBtnPos
                if Components.isPointInRect(designX, designY, btn.x, btn.y, btn.w, btn.h) then
                    return "start_return", quest
                end
            end
            
            -- Claim button
            if quest.currentPhase == "awaiting_claim" and quest._claimBtnPos then
                local btn = quest._claimBtnPos
                if Components.isPointInRect(designX, designY, btn.x, btn.y, btn.w, btn.h) then
                    return "claim_quest", quest
                end
            end
            
            -- Retreat button (for dungeons)
            if quest.isDungeon and quest._retreatBtnPos then
                local btn = quest._retreatBtnPos
                if Components.isPointInRect(designX, designY, btn.x, btn.y, btn.w, btn.h) then
                    if QuestSystem and QuestSystem.retreatFromDungeon then
                        local success, message = QuestSystem.retreatFromDungeon(quest, gameData)
                        if success then
                            return "retreat", message
                        else
                            return "error", message or "Cannot retreat from dungeon"
                        end
                    end
                end
            end
            
            y = y + 85
        end
    end
    
    -- ============================================================================
    -- PARTIES TAB - Party creation and management
    -- ============================================================================
    if State.currentTab == "parties" then
        -- Create Party button (main screen)
        local createBtnX = MENU_DESIGN_WIDTH - 180
        local createBtnY = contentY - 5
        local createBtnW = 160
        local createBtnH = 32
        
        gameData.parties = gameData.parties or {}
        local canCreateParty = #gameData.parties < 4
        
        if canCreateParty and Components.isPointInRect(designX, designY, createBtnX, createBtnY, createBtnW, createBtnH) then
            State.partyCreationActive = true
            State.selectedHeroesForParty = {}
            State.partyCreationName = ""
            return nil
        end
        
        -- Party card buttons
        local scrollY = contentY + 40
        local cardHeight = 180
        local cardSpacing = 12
        local y = scrollY - State.partyScrollOffset
        
        for i, party in ipairs(gameData.parties) do
            if y + cardHeight > scrollY and y < scrollY + (MENU_DESIGN_HEIGHT - 120 - 50) then
                local cardY = y
                local cardW = MENU_DESIGN_WIDTH - 40
                local btnY = cardY + cardHeight - 35
                
                -- Details button
                if Components.isPointInRect(designX, designY, 20 + cardW - 250, btnY, 75, 28) then
                    State.selectedPartyDetail = party.id
                    return nil
                end
                
                -- Manage button
                if Components.isPointInRect(designX, designY, 20 + cardW - 170, btnY, 75, 28) then
                    return "info", "Party management coming soon!"
                end
                
                -- Disband button
                if Components.isPointInRect(designX, designY, 20 + cardW - 90, btnY, 75, 28) then
                    State.partyToDisband = party.id
                    return nil
                end
            end
            
            y = y + cardHeight + cardSpacing
        end
    end
    
    return nil
end

return ClickHandlers
