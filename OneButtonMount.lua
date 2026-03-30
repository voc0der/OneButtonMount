-- OneButtonMount
-- Summon a random mount from your rotation with one button press.
-- Separate ground and flying pools with smart zone detection for TBC.

local addonName = "OneButtonMount"
local OneButtonMount = {}

-- ============================================================================
-- Constants
-- ============================================================================

-- Outland uiMapIDs where flying is allowed (TBC Anniversary)
-- Using map IDs instead of localized names for non-English client support
local OUTLAND_MAP_IDS = {
    [100] = true, -- Hellfire Peninsula
    [102] = true, -- Zangarmarsh
    [104] = true, -- Shadowmoon Valley
    [105] = true, -- Blade's Edge Mountains
    [107] = true, -- Nagrand
    [108] = true, -- Terokkar Forest
    [109] = true, -- Netherstorm
    [111] = true, -- Shattrath City
}
local OUTLAND_CONTINENT_MAP_ID = 101

-- Fallback zone names if localized map metadata is unavailable (enUS only).
local OUTLAND_ZONE_NAMES = {
    ["Hellfire Peninsula"] = true,
    ["Zangarmarsh"] = true,
    ["Terokkar Forest"] = true,
    ["Nagrand"] = true,
    ["Blade's Edge Mountains"] = true,
    ["Netherstorm"] = true,
    ["Shadowmoon Valley"] = true,
    ["Shattrath City"] = true,
}

-- Flying riding skill spell IDs
local EXPERT_RIDING = 34090
local ARTISAN_RIDING = 34091
local FLYING_MOUNT_MIN_LEVEL = 70
local CHARACTER_PROFILE_VERSION = 2

local SPELL_MOUNT_SPELLS = {
    { spellID = 13819, name = "Summon Warhorse", icon = "Interface\\Icons\\Spell_Nature_Swiftness", isFlying = false },
    { spellID = 23214, name = "Summon Charger", icon = "Interface\\Icons\\Ability_Mount_Charger", isFlying = false },
    { spellID = 5784, name = "Summon Felsteed", icon = "Interface\\Icons\\Spell_Nature_Swiftness", isFlying = false },
    { spellID = 23161, name = "Summon Dreadsteed", icon = "Interface\\Icons\\Ability_Mount_Dreadsteed", isFlying = false },
}

-- Mount type flags from GetCompanionInfo's 6th return value
-- Bitmask: 0x01 = ground, 0x02 = flying, 0x10 = underwater
-- Flying mounts have bit 0x02 set (mountType values like 0x0f, 0x1f include flying)
local MOUNT_TYPE_FLAG_FLYING = 0x02

-- Temple of Ahn'Qiraj (AQ40)
local AQ40_INSTANCE_ID = 531
local AQ40_ZONE_NAMES = {
    ["Temple of Ahn'Qiraj"] = true,
}
local AQ40_CRYSTAL_ITEM_IDS = {
    [21218] = true, -- Blue Qiraji Resonating Crystal
    [21321] = true, -- Red Qiraji Resonating Crystal
    [21323] = true, -- Green Qiraji Resonating Crystal
    [21324] = true, -- Yellow Qiraji Resonating Crystal
}

-- ============================================================================
-- State
-- ============================================================================

local configFrame = nil
local minimapButton = nil
local allMounts = {}        -- { spellID, name, icon, isFlying, canDetermineFlying, index, journalID }

-- ============================================================================
-- Utility
-- ============================================================================

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[OneButtonMount]|r " .. msg)
end

local GetCharacterDB
local SanitizeSavedMountPools

local function ShowTextualFeedback()
    local characterDB = GetCharacterDB()
    if characterDB.showTextualFeedback == nil then
        return true
    end

    return characterDB.showTextualFeedback
end

local function Feedback(msg)
    if ShowTextualFeedback() then
        Print(msg)
    end
end

local function TableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

local function TableRemove(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

local function CopyValue(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = CopyValue(value)
    end

    return copy
end

GetCharacterDB = function()
    if type(OneButtonMountCharDB) ~= "table" then
        OneButtonMountCharDB = {}
    end

    return OneButtonMountCharDB
end

local function GetMountPools()
    local characterDB = GetCharacterDB()

    if type(characterDB.groundMounts) ~= "table" then
        characterDB.groundMounts = {}
    end

    if type(characterDB.flyingMounts) ~= "table" then
        characterDB.flyingMounts = {}
    end

    return characterDB.groundMounts, characterDB.flyingMounts
end

local function GetMinimapSettings()
    local characterDB = GetCharacterDB()

    if type(characterDB.minimapButton) ~= "table" then
        characterDB.minimapButton = {}
    end
    if characterDB.minimapButton.show == nil then
        characterDB.minimapButton.show = true
    end
    if not characterDB.minimapButton.position then
        characterDB.minimapButton.position = 220
    end

    return characterDB.minimapButton
end

-- ============================================================================
-- ElvUI Integration
-- ============================================================================

local E, L, V, P, G
local S -- ElvUI Skins module

local function IsElvUILoaded()
    if not ElvUI then return false end
    E, L, V, P, G = unpack(ElvUI)
    S = E:GetModule('Skins', true)
    return S ~= nil
end

local function ApplyElvUISkin(frame, frameType)
    if not IsElvUILoaded() then return end

    if frameType == "frame" then
        S:HandleFrame(frame, true)
    elseif frameType == "button" then
        S:HandleButton(frame)
    elseif frameType == "checkbox" then
        S:HandleCheckBox(frame)
    elseif frameType == "scrollbar" then
        S:HandleScrollBar(frame)
    end
end

-- Compatibility: SetColorTexture may not exist in all TBC builds
local function SetSolidColor(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

-- Classic Lua compatibility: some clients throw when tonumber is called with nil.
local function SafeToNumber(value)
    if value == nil then
        return nil
    end

    local ok, number = pcall(tonumber, value)
    if ok then
        return number
    end

    return nil
end

local function HasBitFlag(value, flag)
    if type(value) ~= "number" or type(flag) ~= "number" then
        return false
    end

    if bit and bit.band then
        return bit.band(value, flag) ~= 0
    end

    if bit32 and bit32.band then
        return bit32.band(value, flag) ~= 0
    end

    -- Fallback when bit libs are unavailable.
    return (value % (flag + flag)) >= flag
end

local function IsEnglishClient()
    if not GetLocale then
        return true
    end

    local locale = GetLocale()
    return locale == "enUS" or locale == "enGB"
end

local function IsSpellInSpellbook(spellID, fallbackName)
    if not (GetNumSpellTabs and GetSpellTabInfo) then
        return false
    end

    local bookType = BOOKTYPE_SPELL or "spell"
    local targetSpellID = SafeToNumber(spellID)
    local targetSpellName = nil

    if GetSpellInfo and targetSpellID then
        local liveName = GetSpellInfo(targetSpellID)
        if type(liveName) == "string" and liveName ~= "" then
            targetSpellName = liveName
        end
    end

    if (not targetSpellName or targetSpellName == "") and IsEnglishClient() then
        targetSpellName = fallbackName
    end

    if type(targetSpellName) == "string" then
        targetSpellName = string.lower(targetSpellName)
    else
        targetSpellName = nil
    end

    local highestSlot = 0
    local numTabs = SafeToNumber(GetNumSpellTabs()) or 0
    for tabIndex = 1, numTabs do
        local _, _, offset, numSpells = GetSpellTabInfo(tabIndex)
        local tabEnd = (SafeToNumber(offset) or 0) + (SafeToNumber(numSpells) or 0)
        if tabEnd > highestSlot then
            highestSlot = tabEnd
        end
    end

    if highestSlot == 0 then
        return false
    end

    for slot = 1, highestSlot do
        if GetSpellBookItemInfo and targetSpellID then
            local spellType, bookSpellID = GetSpellBookItemInfo(slot, bookType)
            if spellType == "SPELL" and SafeToNumber(bookSpellID) == targetSpellID then
                return true
            end
        end

        if targetSpellName then
            local bookSpellName = nil
            if GetSpellBookItemName then
                bookSpellName = GetSpellBookItemName(slot, bookType)
            elseif GetSpellName then
                bookSpellName = GetSpellName(slot, bookType)
            end

            if type(bookSpellName) == "string" and string.lower(bookSpellName) == targetSpellName then
                return true
            end
        end
    end

    return false
end

local function IsPlayerSpellKnown(spellID, fallbackName)
    if IsSpellKnown and IsSpellKnown(spellID) then
        return true
    end

    if IsPlayerSpell and IsPlayerSpell(spellID) then
        return true
    end

    return IsSpellInSpellbook(spellID, fallbackName)
end

local function GetFlyingRidingSkillDetails()
    local playerLevel = nil
    if UnitLevel then
        playerLevel = SafeToNumber(UnitLevel("player"))
    end

    local hasSpellKnowledgeAPI = IsSpellKnown or IsPlayerSpell or GetNumSpellTabs
    local hasExpert = false
    local hasArtisan = false

    if hasSpellKnowledgeAPI then
        hasExpert = IsPlayerSpellKnown(EXPERT_RIDING)
        hasArtisan = IsPlayerSpellKnown(ARTISAN_RIDING)
    end

    local levelBlocksFlying = playerLevel and playerLevel > 0 and playerLevel < FLYING_MOUNT_MIN_LEVEL
    local canRideFlying = not levelBlocksFlying and (not hasSpellKnowledgeAPI or hasExpert or hasArtisan)
    local ridingLabel = "?"
    if hasArtisan then
        ridingLabel = (GetSpellInfo and GetSpellInfo(ARTISAN_RIDING)) or tostring(ARTISAN_RIDING)
    elseif hasExpert then
        ridingLabel = (GetSpellInfo and GetSpellInfo(EXPERT_RIDING)) or tostring(EXPERT_RIDING)
    elseif hasSpellKnowledgeAPI then
        ridingLabel = "none"
    end

    return {
        level = playerLevel,
        hasExpert = hasExpert,
        hasArtisan = hasArtisan,
        hasSpellKnowledgeAPI = not not hasSpellKnowledgeAPI,
        canRideFlying = canRideFlying,
        ridingLabel = ridingLabel,
    }
end

local function HasFlyingRidingSkill()
    local ridingDetails = GetFlyingRidingSkillDetails()
    return ridingDetails.canRideFlying
end

local function AddNameToSet(nameSet, name)
    if type(name) == "string" and name ~= "" then
        nameSet[name] = true
    end
end

local function BuildLocalizedMapNameSet(mapIDs)
    local nameSet = {}
    local addedLocalizedName = false

    if C_Map and C_Map.GetMapInfo then
        for mapID in pairs(mapIDs) do
            local info = C_Map.GetMapInfo(mapID)
            if info and type(info.name) == "string" and info.name ~= "" then
                nameSet[info.name] = true
                addedLocalizedName = true
            end
        end
    end

    if addedLocalizedName then
        return nameSet
    end

    if IsEnglishClient() then
        return OUTLAND_ZONE_NAMES
    end

    return {}
end

local function BuildAQ40ZoneNameSet()
    local nameSet = {}
    local addedLocalizedName = false

    if C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(AQ40_INSTANCE_ID)
        if info and type(info.name) == "string" and info.name ~= "" then
            nameSet[info.name] = true
            addedLocalizedName = true
        end
    end

    if addedLocalizedName then
        return nameSet
    end

    if IsEnglishClient() then
        return AQ40_ZONE_NAMES
    end

    return {}
end

local function BuildCurrentZoneNameSet()
    local nameSet = {}

    if GetRealZoneText then
        AddNameToSet(nameSet, GetRealZoneText())
    end

    if GetZoneText then
        AddNameToSet(nameSet, GetZoneText())
    end

    return nameSet
end

local function MapHierarchyContainsAnyName(mapID, nameSet)
    if not mapID or not nameSet or not next(nameSet) then
        return false
    end

    if not (C_Map and C_Map.GetMapInfo) then
        return false
    end

    local info = C_Map.GetMapInfo(mapID)
    while info do
        if type(info.name) == "string" and nameSet[info.name] then
            return true
        end

        local parentMapID = info.parentMapID
        if parentMapID and parentMapID ~= 0 then
            info = C_Map.GetMapInfo(parentMapID)
        else
            break
        end
    end

    return false
end

local function ZoneNameSetContainsAnyName(zoneNames, candidateNames)
    if not zoneNames or not candidateNames then
        return false
    end

    for zoneName in pairs(zoneNames) do
        if candidateNames[zoneName] then
            return true
        end
    end

    return false
end

local function IsOutlandMapContext(mapID)
    if not mapID then
        return false
    end

    if OUTLAND_MAP_IDS[mapID] then
        return true
    end

    if not (C_Map and C_Map.GetMapInfo) then
        return false
    end

    local info = C_Map.GetMapInfo(mapID)
    while info do
        if info.mapID == OUTLAND_CONTINENT_MAP_ID or OUTLAND_MAP_IDS[info.mapID] then
            return true
        end

        local parentMapID = info.parentMapID
        if parentMapID and parentMapID ~= 0 then
            if parentMapID == OUTLAND_CONTINENT_MAP_ID or OUTLAND_MAP_IDS[parentMapID] then
                return true
            end
            info = C_Map.GetMapInfo(parentMapID)
        else
            break
        end
    end

    return false
end

local function GetOutlandContextDetails()
    local zoneNames = BuildCurrentZoneNameSet()
    local localizedOutlandZoneNames = BuildLocalizedMapNameSet(OUTLAND_MAP_IDS)
    local bestMapID = nil
    local areaID = nil

    if C_Map and C_Map.GetBestMapForUnit then
        bestMapID = SafeToNumber(C_Map.GetBestMapForUnit("player"))
    end

    if GetCurrentMapAreaID then
        areaID = SafeToNumber(GetCurrentMapAreaID())
    end

    local mapIsOutland = IsOutlandMapContext(bestMapID)
    local mapMatchesZone = false
    if mapIsOutland then
        if not next(zoneNames) then
            mapMatchesZone = true
        else
            mapMatchesZone = MapHierarchyContainsAnyName(bestMapID, zoneNames)
        end
    end

    local zoneMatchesOutland = ZoneNameSetContainsAnyName(zoneNames, localizedOutlandZoneNames)
    local areaMatchesOutland = areaID and OUTLAND_MAP_IDS[areaID] and true or false

    local source = "none"
    local isOutland = false
    if mapIsOutland and mapMatchesZone then
        source = "map"
        isOutland = true
    elseif zoneMatchesOutland then
        source = "zone"
        isOutland = true
    elseif not next(zoneNames) and areaMatchesOutland then
        source = "area"
        isOutland = true
    end

    return {
        zoneNames = zoneNames,
        bestMapID = bestMapID,
        areaID = areaID,
        mapIsOutland = mapIsOutland,
        mapMatchesZone = mapMatchesZone,
        zoneMatchesOutland = zoneMatchesOutland,
        areaMatchesOutland = areaMatchesOutland,
        source = source,
        isOutland = isOutland,
    }
end

-- ============================================================================
-- Mount Detection
-- ============================================================================

local function ScanMounts()
    allMounts = {}
    local seenSpellIDs = {}

    local function AddMountEntry(spellID, name, icon, isFlying, canDetermineFlying, index, journalID, itemID)
        local normalizedSpellID = SafeToNumber(spellID)
        if not normalizedSpellID or seenSpellIDs[normalizedSpellID] then
            return
        end

        seenSpellIDs[normalizedSpellID] = true
        table.insert(allMounts, {
            spellID = normalizedSpellID,
            name = name or ("Mount " .. tostring(normalizedSpellID)),
            icon = icon,
            isFlying = not not isFlying,
            canDetermineFlying = not not canDetermineFlying,
            index = index,
            journalID = journalID,
            itemID = itemID,
        })
    end

    local function GetBagSlotCount(bag)
        if C_Container and C_Container.GetContainerNumSlots then
            local slotCount = C_Container.GetContainerNumSlots(bag)
            return SafeToNumber(slotCount) or 0
        elseif GetContainerNumSlots then
            local slotCount = GetContainerNumSlots(bag)
            return SafeToNumber(slotCount) or 0
        end
        return 0
    end

    local function GetBagItemID(bag, slot)
        if C_Container and C_Container.GetContainerItemID then
            return SafeToNumber(C_Container.GetContainerItemID(bag, slot))
        elseif GetContainerItemID then
            return SafeToNumber(GetContainerItemID(bag, slot))
        elseif GetContainerItemLink then
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemID = string.match(itemLink, "item:(%d+)")
                return SafeToNumber(itemID)
            end
        end
        return nil
    end

    local function IsMountItem(itemID)
        itemID = SafeToNumber(itemID)
        if not itemID then
            return false
        end

        local miscClassID = LE_ITEM_CLASS_MISCELLANEOUS or 15
        local mountSubClassID = LE_ITEM_MISCELLANEOUS_MOUNT or 5

        if C_MountJournal and C_MountJournal.GetMountFromItem then
            local mountID = C_MountJournal.GetMountFromItem(itemID)
            if mountID and mountID > 0 then
                return true
            end
        end

        local classID, subClassID
        if GetItemInfoInstant then
            local _, _, _, _, _, cID, sID = GetItemInfoInstant(itemID)
            classID, subClassID = SafeToNumber(cID), SafeToNumber(sID)
        end

        if classID and subClassID then
            if classID == miscClassID and subClassID == mountSubClassID then
                return true
            end
        end

        if GetItemInfo and GetItemSubClassInfo then
            local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemID)
            local mountSubType = GetItemSubClassInfo(miscClassID, mountSubClassID)
            if itemSubType and mountSubType and itemSubType == mountSubType then
                return true
            end
        end

        return false
    end

    -- Preferred on newer clients where companion APIs can be absent or empty.
    if C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID then
        local mountIDs = C_MountJournal.GetMountIDs()
        if mountIDs then
            for _, mountID in pairs(mountIDs) do
                local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
                if spellID and (isCollected == nil or isCollected) then
                    local isFlying = true
                    local canDetermineFlying = false

                    if C_MountJournal.GetMountInfoExtraByID and Enum and Enum.MountType and Enum.MountType.Flying then
                        local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
                        if mountTypeID ~= nil then
                            canDetermineFlying = true
                            isFlying = mountTypeID == Enum.MountType.Flying
                        end
                    end

                    AddMountEntry(spellID, name, icon, isFlying, canDetermineFlying, nil, mountID, nil)
                end
            end
        end
    end

    -- Legacy companion fallback for older clients.
    if GetNumCompanions and GetCompanionInfo then
        local rawCount = GetNumCompanions("MOUNT")
        local count = SafeToNumber(rawCount)

        local function AddCompanionMountByIndex(i)
            local creatureID, creatureName, creatureSpellID, icon, isSummoned, mountType = GetCompanionInfo("MOUNT", i)
            local normalizedSpellID = SafeToNumber(creatureSpellID)
            if not creatureID and not normalizedSpellID then
                return false
            end

            if normalizedSpellID then
                local mountTypeNumber = SafeToNumber(mountType)
                local canDetermineFlying = mountTypeNumber ~= nil and mountTypeNumber > 0
                local isFlying = true
                if canDetermineFlying then
                    isFlying = HasBitFlag(mountTypeNumber, MOUNT_TYPE_FLAG_FLYING)
                end

                AddMountEntry(normalizedSpellID, creatureName, icon, isFlying, canDetermineFlying, i, nil, nil)
            end

            return true
        end

        if count and count > 0 then
            for i = 1, count do
                AddCompanionMountByIndex(i)
            end
        else
            -- Some Classic clients return nil/empty counts but still expose companion entries by index.
            local maxProbe = 500
            local emptyStreak = 0
            for i = 1, maxProbe do
                local hasEntry = AddCompanionMountByIndex(i)
                if hasEntry then
                    emptyStreak = 0
                else
                    emptyStreak = emptyStreak + 1
                    if emptyStreak >= 3 then
                        break
                    end
                end
            end
        end
    end

    -- Secondary companion fallback for clients where GetNumCompanions is missing.
    if (not GetNumCompanions) and GetCompanionInfo and #allMounts == 0 then
        for i = 1, 500 do
            local creatureID, creatureName, creatureSpellID, icon, isSummoned, mountType = GetCompanionInfo("MOUNT", i)
            local normalizedSpellID = SafeToNumber(creatureSpellID)
            if not creatureID and not normalizedSpellID then
                break
            end

            if normalizedSpellID then
                local mountTypeNumber = SafeToNumber(mountType)
                local canDetermineFlying = mountTypeNumber ~= nil and mountTypeNumber > 0
                local isFlying = true
                if canDetermineFlying then
                    isFlying = HasBitFlag(mountTypeNumber, MOUNT_TYPE_FLAG_FLYING)
                end

                AddMountEntry(normalizedSpellID, creatureName, icon, isFlying, canDetermineFlying, i, nil, nil)
            end
        end
    end

    -- TBC-style fallback: scan bag items that are mount items.
    if GetItemSpell then
        local maxBag = SafeToNumber(NUM_BAG_SLOTS) or 4
        for bag = 0, maxBag do
            local slotCount = GetBagSlotCount(bag)
            for slot = 1, slotCount do
                local itemID = GetBagItemID(bag, slot)
                if itemID and IsMountItem(itemID) then
                    local spellName, spellID = GetItemSpell(itemID)
                    if spellID then
                        local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
                        AddMountEntry(spellID, itemName or spellName, itemIcon, true, false, nil, nil, itemID)
                    end
                end
            end
        end
    end

    -- Paladin and warlock class mounts are cast directly and do not always
    -- appear in companion, journal, or bag-based mount lists.
    if IsSpellKnown or IsPlayerSpell or GetNumSpellTabs then
        for _, spellMount in ipairs(SPELL_MOUNT_SPELLS) do
            if IsPlayerSpellKnown(spellMount.spellID) then
                local spellName = spellMount.name
                local spellIcon = spellMount.icon
                if GetSpellInfo then
                    local liveName, _, liveIcon = GetSpellInfo(spellMount.spellID)
                    if liveName then
                        spellName = liveName
                    end
                    if liveIcon then
                        spellIcon = liveIcon
                    end
                end

                AddMountEntry(spellMount.spellID, spellName, spellIcon, spellMount.isFlying, true, nil, nil, nil)
            end
        end
    end

    table.sort(allMounts, function(a, b) return (a.name or "") < (b.name or "") end)
end

local function GetFlyableAreaSignal()
    if not IsFlyableArea then
        return nil, false
    end

    local ok, flyable = pcall(IsFlyableArea)
    if not ok then
        return nil, true
    end

    return not not flyable, false
end

local function CanFlyHere()
    -- Must be outdoors and not in an instance
    if IsIndoors() then
        return false
    end

    local inInstance = IsInInstance()
    if inInstance then
        return false
    end

    local outlandContext = GetOutlandContextDetails()
    if not outlandContext.isOutland then
        return false
    end

    if not HasFlyingRidingSkill() then
        return false
    end

    local flyableSignal = GetFlyableAreaSignal()
    if flyableSignal then
        return true
    end

    return true
end

local function GetMountBySpellID(spellID)
    for _, mount in ipairs(allMounts) do
        if mount.spellID == spellID then
            return mount
        end
    end
    return nil
end

local function IsInAQ40()
    local localizedAQ40ZoneNames = BuildAQ40ZoneNameSet()

    if GetInstanceInfo then
        local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
        if SafeToNumber(instanceID) == AQ40_INSTANCE_ID then
            return true
        end

        if instanceType == "raid" and name and localizedAQ40ZoneNames[name] then
            return true
        end
    end

    -- Fallback when instance APIs are unavailable or incomplete.
    local zone = GetRealZoneText and GetRealZoneText()
    if zone and localizedAQ40ZoneNames[zone] then
        local inInstance = IsInInstance and select(1, IsInInstance())
        if inInstance then
            return true
        end
    end

    return false
end

local function IsAQ40CrystalMount(mount)
    if not mount then
        return false
    end

    if mount.itemID and AQ40_CRYSTAL_ITEM_IDS[mount.itemID] then
        return true
    end

    return false
end

local function FilterEligibleSpellIDs(sourcePool, includeAQ40Crystals, canFlyHere)
    local filtered = {}
    for _, spellID in ipairs(sourcePool) do
        local mount = GetMountBySpellID(spellID)
        if mount then
            local isAQ40Crystal = IsAQ40CrystalMount(mount)
            local isUsableFlyingMount = not mount.canDetermineFlying or not mount.isFlying or canFlyHere
            if includeAQ40Crystals == isAQ40Crystal and isUsableFlyingMount then
                table.insert(filtered, spellID)
            end
        end
    end
    return filtered
end

local function BuildEligibleMountPool()
    local groundMounts, flyingMounts = GetMountPools()
    local canFlyHere = CanFlyHere()

    if IsInAQ40() then
        local mergedPool = {}
        local seen = {}
        for _, spellID in ipairs(groundMounts) do
            if not seen[spellID] then
                seen[spellID] = true
                table.insert(mergedPool, spellID)
            end
        end
        for _, spellID in ipairs(flyingMounts) do
            if not seen[spellID] then
                seen[spellID] = true
                table.insert(mergedPool, spellID)
            end
        end

        local aq40Pool = FilterEligibleSpellIDs(mergedPool, true, canFlyHere)
        if #aq40Pool > 0 then
            return aq40Pool, nil
        end

        return nil, "AQ40: add at least one Qiraji Resonating Crystal to your rotation."
    end

    local function SelectPrimaryAndSecondaryPools()
        if canFlyHere and #flyingMounts > 0 then
            return flyingMounts, groundMounts
        end
        return groundMounts, nil
    end

    local primaryPool, secondaryPool = SelectPrimaryAndSecondaryPools()
    local primaryEligible = FilterEligibleSpellIDs(primaryPool, false, canFlyHere)
    if #primaryEligible > 0 then
        return primaryEligible, nil
    end

    if secondaryPool and #secondaryPool > 0 then
        local secondaryEligible = FilterEligibleSpellIDs(secondaryPool, false, canFlyHere)
        if #secondaryEligible > 0 then
            return secondaryEligible, nil
        end
    end

    if #groundMounts == 0 and #flyingMounts == 0 then
        return nil, "No mounts in your rotation! Open the config with /onebuttonmount"
    end

    return nil, "No eligible mounts here. Qiraji crystals are AQ40-only."
end

local function DebugLabel(text)
    return "|cff88ccff" .. text .. "|r"
end

local function DebugValue(value)
    if value == nil then
        return "|cff999999?|r"
    end

    local text = tostring(value)
    if text == "" then
        return "|cff999999-|r"
    end

    return text
end

local function DebugBool(value)
    if value == nil then
        return "|cff999999?|r"
    end

    if value then
        return "|cff66ff66Y|r"
    end

    return "|cffff6666N|r"
end

local function BuildMapHierarchyDebugString(mapID)
    if not mapID then
        return DebugValue(nil)
    end

    if not (C_Map and C_Map.GetMapInfo) then
        return tostring(mapID)
    end

    local parts = {}
    local visited = {}
    local currentMapID = mapID

    while currentMapID and not visited[currentMapID] do
        visited[currentMapID] = true
        local info = C_Map.GetMapInfo(currentMapID)
        if not info then
            table.insert(parts, tostring(currentMapID))
            break
        end

        local mapName = info.name
        if type(mapName) ~= "string" or mapName == "" then
            mapName = "?"
        end

        table.insert(parts, tostring(currentMapID) .. ":" .. mapName)

        local parentMapID = SafeToNumber(info.parentMapID)
        if parentMapID and parentMapID ~= 0 then
            currentMapID = parentMapID
        else
            break
        end
    end

    return table.concat(parts, ">")
end

local function SummarizeMountPool(pool, maxEntries)
    if not pool or #pool == 0 then
        return "-"
    end

    local names = {}
    local limit = math.min(#pool, maxEntries or 2)
    for i = 1, limit do
        local mount = GetMountBySpellID(pool[i])
        table.insert(names, mount and (mount.name or tostring(pool[i])) or tostring(pool[i]))
    end

    if #pool > limit then
        table.insert(names, "+" .. tostring(#pool - limit))
    end

    return table.concat(names, ",")
end

local function PrintDebugSummary()
    ScanMounts()
    SanitizeSavedMountPools()

    local outlandContext = GetOutlandContextDetails()
    local riding = GetFlyingRidingSkillDetails()
    local flyableSignal, flyableSignalErrored = GetFlyableAreaSignal()
    local canFlyHere = CanFlyHere()
    local inAQ40 = IsInAQ40()
    local indoors = IsIndoors()
    local inInstance = IsInInstance()
    local realZoneText = GetRealZoneText and GetRealZoneText() or nil
    local zoneText = GetZoneText and GetZoneText() or nil
    local groundMounts, flyingMounts = GetMountPools()
    local eligibleGround = FilterEligibleSpellIDs(groundMounts, false, canFlyHere)
    local eligibleFlying = FilterEligibleSpellIDs(flyingMounts, false, canFlyHere)
    local eligiblePool, poolError = BuildEligibleMountPool()

    local pickLabel = "none"
    if inAQ40 then
        local mergedPool = {}
        local seen = {}
        for _, spellID in ipairs(groundMounts) do
            if not seen[spellID] then
                seen[spellID] = true
                table.insert(mergedPool, spellID)
            end
        end
        for _, spellID in ipairs(flyingMounts) do
            if not seen[spellID] then
                seen[spellID] = true
                table.insert(mergedPool, spellID)
            end
        end

        local aq40Eligible = FilterEligibleSpellIDs(mergedPool, true, canFlyHere)
        if #aq40Eligible > 0 then
            pickLabel = "AQ40(" .. tostring(#aq40Eligible) .. ")[" .. SummarizeMountPool(aq40Eligible, 2) .. "]"
        else
            pickLabel = "AQ40(none)"
        end
    elseif canFlyHere and #flyingMounts > 0 then
        if #eligibleFlying > 0 then
            pickLabel = "F(" .. tostring(#eligibleFlying) .. ")[" .. SummarizeMountPool(eligibleFlying, 2) .. "]"
        elseif #eligibleGround > 0 then
            pickLabel = "Gfb(" .. tostring(#eligibleGround) .. ")[" .. SummarizeMountPool(eligibleGround, 2) .. "]"
        end
    elseif #eligibleGround > 0 then
        pickLabel = "G(" .. tostring(#eligibleGround) .. ")[" .. SummarizeMountPool(eligibleGround, 2) .. "]"
    end

    local flyableSummary = DebugBool(flyableSignal)
    if flyableSignalErrored then
        flyableSummary = "|cffffaa00ERR|r"
    end

    local segments = {
        DebugLabel("rz") .. "=" .. DebugValue(realZoneText),
        DebugLabel("z") .. "=" .. DebugValue(zoneText),
        DebugLabel("map") .. "=" .. BuildMapHierarchyDebugString(outlandContext.bestMapID),
        DebugLabel("area") .. "=" .. DebugValue(outlandContext.areaID),
        DebugLabel("outland") .. "=" .. DebugBool(outlandContext.isOutland) .. "(" .. outlandContext.source .. ")",
        DebugLabel("match") .. "=m" .. DebugBool(outlandContext.mapIsOutland) .. "/z" .. DebugBool(outlandContext.zoneMatchesOutland) .. "/a" .. DebugBool(outlandContext.areaMatchesOutland),
        DebugLabel("state") .. "=indoor:" .. DebugBool(indoors) .. ",inst:" .. DebugBool(inInstance) .. ",aq40:" .. DebugBool(inAQ40),
        DebugLabel("ride") .. "=" .. DebugValue(riding.ridingLabel) .. "@lvl" .. DebugValue(riding.level),
        DebugLabel("flyable") .. "=" .. flyableSummary,
        DebugLabel("canFly") .. "=" .. DebugBool(canFlyHere),
        DebugLabel("pools") .. "=G" .. tostring(#groundMounts) .. "/F" .. tostring(#flyingMounts) .. "/all" .. tostring(#allMounts),
        DebugLabel("eligible") .. "=G" .. tostring(#eligibleGround) .. "/F" .. tostring(#eligibleFlying),
        DebugLabel("pick") .. "=" .. DebugValue(pickLabel),
    }

    if eligiblePool and #eligiblePool > 0 then
        table.insert(segments, DebugLabel("pool") .. "=" .. SummarizeMountPool(eligiblePool, 3))
    elseif poolError then
        table.insert(segments, DebugLabel("err") .. "=" .. DebugValue(poolError))
    end

    Print(table.concat(segments, " | "))
end

local function BuildMountLookup()
    local lookup = {}
    for _, mount in ipairs(allMounts) do
        lookup[mount.spellID] = mount
    end
    return lookup
end

local function SanitizePool(pool, requireFlying, mountLookup)
    local cleaned = {}
    local seen = {}

    for _, spellID in ipairs(pool) do
        local mount = mountLookup[spellID]
        if mount and (not requireFlying or not mount.canDetermineFlying or mount.isFlying) and not seen[spellID] then
            table.insert(cleaned, spellID)
            seen[spellID] = true
        end
    end

    return cleaned
end

SanitizeSavedMountPools = function()
    local characterDB = GetCharacterDB()

    local mountLookup = BuildMountLookup()
    if not next(mountLookup) then
        return
    end

    characterDB.groundMounts = SanitizePool(characterDB.groundMounts, false, mountLookup)
    characterDB.flyingMounts = SanitizePool(characterDB.flyingMounts, true, mountLookup)
end

-- ============================================================================
-- Mount Summoning
-- ============================================================================

local function BuildMountMacroText(spellID, mount)
    if mount and mount.itemID then
        return "/use item:" .. mount.itemID
    end

    local spellName = GetSpellInfo and GetSpellInfo(spellID)
    if spellName then
        return "/cast " .. spellName
    end

    return nil
end

local function SummonRandomMount()
    if InCombatLockdown() then
        Feedback("Cannot mount in combat.")
        return
    end

    if IsMounted() then
        Dismount()
        return
    end

    local inAQ40 = IsInAQ40()
    if IsIndoors() and not inAQ40 then
        Feedback("Cannot mount indoors.")
        return
    end

    ScanMounts()
    SanitizeSavedMountPools()

    local pool, poolError = BuildEligibleMountPool()
    if not pool or #pool == 0 then
        Feedback(poolError or "No mounts in your rotation! Open the config with /onebuttonmount")
        return
    end

    -- Pick a random mount from the pool
    local spellID = pool[math.random(#pool)]
    local mount = GetMountBySpellID(spellID)
    local macroText = BuildMountMacroText(spellID, mount)

    -- Prefer the same macro-style action path used by the working keybind flow.
    if macroText and RunMacroText then
        RunMacroText(macroText)
        return
    end

    if mount then
        if mount.journalID and C_MountJournal and C_MountJournal.SummonByID then
            C_MountJournal.SummonByID(mount.journalID)
        elseif mount.index and CallCompanion then
            CallCompanion("MOUNT", mount.index)
        elseif mount.itemID and UseItemByName then
            UseItemByName(mount.itemID)
        else
            if CastSpellByID then
                CastSpellByID(spellID)
            elseif CastSpellByName then
                local spellName = GetSpellInfo(spellID)
                if spellName then
                    CastSpellByName(spellName)
                end
            end
        end
    else
        -- Mount may have been removed from companion list, try spell
        if CastSpellByID then
            CastSpellByID(spellID)
        end
    end
end

-- ============================================================================
-- Keybinding
-- ============================================================================

local bindingFrame = CreateFrame("Button", "OneButtonMountBindingButton", UIParent, "SecureActionButtonTemplate")
bindingFrame:SetSize(1, 1)
bindingFrame:SetPoint("CENTER")
bindingFrame:RegisterForClicks("AnyDown", "AnyUp")
bindingFrame:SetAttribute("type", "macro")

local function NormalizeMouseBindingToken(button)
    if button == "LeftButton" then
        return "BUTTON1"
    elseif button == "RightButton" then
        return "BUTTON2"
    elseif button == "MiddleButton" then
        return "BUTTON3"
    end

    local buttonNumber = string.match(button or "", "^Button(%d+)$")
    if buttonNumber then
        return "BUTTON" .. buttonNumber
    end

    return nil
end

local function SetMountKeybind(key)
    local characterDB = GetCharacterDB()

    if InCombatLockdown() then
        Feedback("Cannot change keybind in combat.")
        return
    end

    -- Clear old keybind
    if characterDB.keybind then
        SetOverrideBinding(bindingFrame, true, characterDB.keybind, nil)
    end

    if key then
        SetOverrideBindingClick(bindingFrame, true, key, "OneButtonMountBindingButton", "LeftButton")
        characterDB.keybind = key
        Feedback("Mount key bound to: " .. key)
    else
        characterDB.keybind = nil
        Feedback("Mount keybind cleared.")
    end
end

-- PreClick: build macro text dynamically before the secure action fires
bindingFrame:SetScript("PreClick", function(self, button)
    if InCombatLockdown() then return end

    ScanMounts()
    SanitizeSavedMountPools()

    if IsMounted() then
        self:SetAttribute("macrotext", "/dismount")
        return
    end

    local inAQ40 = IsInAQ40()
    if IsIndoors() and not inAQ40 then
        self:SetAttribute("macrotext", "")
        Feedback("Cannot mount indoors.")
        return
    end

    local pool, poolError = BuildEligibleMountPool()
    if not pool or #pool == 0 then
        self:SetAttribute("macrotext", "")
        Feedback(poolError or "No mounts in rotation!")
        return
    end

    local spellID = pool[math.random(#pool)]
    local mount = GetMountBySpellID(spellID)
    local macroText = BuildMountMacroText(spellID, mount)
    if macroText then
        self:SetAttribute("macrotext", macroText)
    else
        -- Fallback: clear macrotext to avoid firing a stale spell
        self:SetAttribute("macrotext", "")
    end
end)

local function RestoreKeybind()
    local characterDB = GetCharacterDB()

    if InCombatLockdown() then return end
    if characterDB.keybind then
        SetOverrideBindingClick(bindingFrame, true, characterDB.keybind, "OneButtonMountBindingButton", "LeftButton")
    end
end

-- ============================================================================
-- Minimap Button
-- ============================================================================

local function CreateMinimapButton()
    if minimapButton then return end

    minimapButton = CreateFrame("Button", "OneButtonMountMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Ability_Mount_Charger")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    minimapButton.icon = icon

    -- Use SetTexCoord to crop to a circle-ish shape (classic approach)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(56, 56)
    border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cff33ccffOneButtonMount|r")
        GameTooltip:AddLine("Left-click to open config", 1, 1, 1)
        GameTooltip:AddLine("Right-click to summon mount", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            OneButtonMount:ToggleConfigUI()
        else
            SummonRandomMount()
        end
    end)

    -- Dragging around minimap
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton.dragging = false

    minimapButton:SetScript("OnDragStart", function(self)
        self.dragging = true
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        local minimapSettings = GetMinimapSettings()
        self.dragging = false
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.deg(math.atan2(py - my, px - mx))
        minimapSettings.position = angle
        OneButtonMount:UpdateMinimapButtonPosition()
    end)

    minimapButton:SetScript("OnUpdate", function(self)
        if self.dragging then
            local minimapSettings = GetMinimapSettings()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            minimapSettings.position = angle
            OneButtonMount:UpdateMinimapButtonPosition()
        end
    end)
end

function OneButtonMount:UpdateMinimapButtonPosition()
    local minimapSettings = GetMinimapSettings()

    if not minimapButton then return end
    local angle = math.rad(minimapSettings.position or 220)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function OneButtonMount:ToggleMinimapButton()
    local minimapSettings = GetMinimapSettings()

    minimapSettings.show = not minimapSettings.show
    if minimapSettings.show then
        if not minimapButton then
            CreateMinimapButton()
        end
        minimapButton:Show()
        OneButtonMount:UpdateMinimapButtonPosition()
        Feedback("Minimap button shown.")
    else
        if minimapButton then
            minimapButton:Hide()
        end
        Feedback("Minimap button hidden. Use /onebuttonmount minimap to show it again.")
    end
    -- Update checkbox if config is open
    if configFrame and configFrame.minimapCheckbox then
        configFrame.minimapCheckbox:SetChecked(minimapSettings.show)
    end
end

-- ============================================================================
-- Config GUI
-- ============================================================================

local POOL_GROUND = "ground"
local POOL_FLYING = "flying"

local function CreateMountIcon(parent, mountData, pool, index)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(36, 36)

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(mountData.icon)
    -- Crop Blizzard icon edges to avoid the inner-square artifact on mount icons.
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.iconTexture = tex

    -- Use a simple frame outline so the icon body remains fully visible.
    local topEdge = btn:CreateTexture(nil, "OVERLAY")
    topEdge:SetSize(1, 1)
    topEdge:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
    topEdge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 1, 1)
    SetSolidColor(topEdge, 0.9, 0.9, 0.9, 0.9)

    local bottomEdge = btn:CreateTexture(nil, "OVERLAY")
    bottomEdge:SetSize(1, 1)
    bottomEdge:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", -1, -1)
    bottomEdge:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    SetSolidColor(bottomEdge, 0.9, 0.9, 0.9, 0.9)

    local leftEdge = btn:CreateTexture(nil, "OVERLAY")
    leftEdge:SetSize(1, 1)
    leftEdge:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
    leftEdge:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", -1, -1)
    SetSolidColor(leftEdge, 0.9, 0.9, 0.9, 0.9)

    local rightEdge = btn:CreateTexture(nil, "OVERLAY")
    rightEdge:SetSize(1, 1)
    rightEdge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 1, 1)
    rightEdge:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    SetSolidColor(rightEdge, 0.9, 0.9, 0.9, 0.9)

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    btn.mountData = mountData
    btn.pool = pool
    btn.poolIndex = index

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.mountData.name, 1, 1, 1)
        if self.pool then
            GameTooltip:AddLine("Click to remove", 0.8, 0.2, 0.2)
        else
            GameTooltip:AddLine("Left-click to add to Ground pool", 0.2, 0.8, 0.2)
            GameTooltip:AddLine("Right-click to add to Flying pool", 0.4, 0.6, 1.0)
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        local characterDB = GetCharacterDB()

        if self.pool then
            -- Remove from pool
            if self.pool == POOL_GROUND then
                TableRemove(characterDB.groundMounts, self.mountData.spellID)
            elseif self.pool == POOL_FLYING then
                TableRemove(characterDB.flyingMounts, self.mountData.spellID)
            end
            OneButtonMount:RefreshConfigUI()
        else
            -- Add to pool
            if button == "LeftButton" then
                if not TableContains(characterDB.groundMounts, self.mountData.spellID) then
                    table.insert(characterDB.groundMounts, self.mountData.spellID)
                end
            elseif button == "RightButton" then
                if self.mountData.canDetermineFlying and not self.mountData.isFlying then
                    Feedback((self.mountData.name or "This mount") .. " cannot be added to flying rotation.")
                    return
                end
                if not TableContains(characterDB.flyingMounts, self.mountData.spellID) then
                    table.insert(characterDB.flyingMounts, self.mountData.spellID)
                end
            end
            OneButtonMount:RefreshConfigUI()
        end
    end)

    return btn
end

local function CreatePoolSection(parent, title, pool, yOffset)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yOffset)
    label:SetText(title)

    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    container:SetSize(430, 44) -- explicit width avoids 0-width on first render

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    SetSolidColor(bg, 0, 0, 0, 0.3)

    local emptyText = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER")
    emptyText:SetText("No mounts added. Use the list below to add mounts.")
    container.emptyText = emptyText

    container.mountButtons = {}
    container.pool = pool

    return container, label
end

function OneButtonMount:CreateConfigUI()
    local characterDB = GetCharacterDB()

    if configFrame then return end

    ScanMounts()
    SanitizeSavedMountPools()

    configFrame = CreateFrame("Frame", "OneButtonMountConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(460, 560)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
        characterDB.configPosition = { point = point, relativePoint = relPoint, xOfs = xOfs, yOfs = yOfs }
    end)
    configFrame:SetFrameStrata("DIALOG")
    ApplyElvUISkin(configFrame, "frame")

    -- Restore position
    if characterDB.configPosition then
        local pos = characterDB.configPosition
        configFrame:ClearAllPoints()
        configFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    end

    -- Title
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", configFrame, "TOP", 0, -8)
    title:SetText("OneButtonMount")

    -- Close on Escape
    tinsert(UISpecialFrames, "OneButtonMountConfigFrame")

    local yOffset = -35

    -- ========================================================================
    -- Keybind Section
    -- ========================================================================
    local keybindLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keybindLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, yOffset)
    keybindLabel:SetText("Mount Keybind:")

    -- Use a plain frame for keybind capture instead of a button with EnableKeyboard
    -- This is more reliable across Classic API versions
    local keybindButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    keybindButton:SetSize(140, 25)
    keybindButton:SetPoint("LEFT", keybindLabel, "RIGHT", 10, 0)
    keybindButton:SetText(characterDB.keybind or "Click to Bind")
    configFrame.keybindButton = keybindButton
    ApplyElvUISkin(keybindButton, "button")

    local keybindClearBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    keybindClearBtn:SetSize(60, 25)
    keybindClearBtn:SetPoint("LEFT", keybindButton, "RIGHT", 5, 0)
    keybindClearBtn:SetText("Clear")
    ApplyElvUISkin(keybindClearBtn, "button")

    -- Invisible overlay button to capture keyboard and extended mouse buttons while binding
    local keyCaptureFrame = CreateFrame("Button", nil, configFrame)
    keyCaptureFrame:SetAllPoints(configFrame)
    keyCaptureFrame:SetFrameStrata("TOOLTIP")
    keyCaptureFrame:EnableKeyboard(true)
    keyCaptureFrame:EnableMouse(true)
    keyCaptureFrame:RegisterForClicks("AnyDown", "AnyUp")
    if keyCaptureFrame.SetPropagateKeyboardInput then
        keyCaptureFrame:SetPropagateKeyboardInput(false)
    end
    keyCaptureFrame:Hide()

    local function ApplyCapturedBinding(token)
        if not token or token == "" then
            keyCaptureFrame:Hide()
            keybindButton:SetText(characterDB.keybind or "Click to Bind")
            return
        end

        local bind = ""
        if IsShiftKeyDown() then bind = bind .. "SHIFT-" end
        if IsControlKeyDown() then bind = bind .. "CTRL-" end
        if IsAltKeyDown() then bind = bind .. "ALT-" end
        bind = bind .. token

        SetMountKeybind(bind)
        keybindButton:SetText(bind)
        keyCaptureFrame:Hide()
    end

    keyCaptureFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            keybindButton:SetText(characterDB.keybind or "Click to Bind")
            return
        end
        -- Ignore modifier-only keys
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
            return
        end

        ApplyCapturedBinding(key)
    end)

    keyCaptureFrame:SetScript("OnClick", function(self, button)
        -- Allow mouse buttons as keybinds too (including Button4/Button5).
        if button == "LeftButton" then
            -- Left click cancels binding mode
            self:Hide()
            keybindButton:SetText(characterDB.keybind or "Click to Bind")
            return
        end

        local mouseToken = NormalizeMouseBindingToken(button)
        ApplyCapturedBinding(mouseToken)
    end)

    keyCaptureFrame:SetScript("OnMouseDown", function(self, button)
        -- Side buttons can be unreliable through OnClick on some Classic clients.
        if button == "Button4" or button == "Button5" then
            local mouseToken = NormalizeMouseBindingToken(button)
            ApplyCapturedBinding(mouseToken)
        end
    end)

    keybindButton:SetScript("OnClick", function(self)
        if keyCaptureFrame:IsShown() then
            keyCaptureFrame:Hide()
            self:SetText(characterDB.keybind or "Click to Bind")
        else
            keyCaptureFrame:Show()
            self:SetText("|cffff0000Press a key...|r")
        end
    end)

    keybindClearBtn:SetScript("OnClick", function()
        keyCaptureFrame:Hide()
        SetMountKeybind(nil)
        keybindButton:SetText("Click to Bind")
    end)

    yOffset = yOffset - 35

    -- ========================================================================
    -- Settings Section
    -- ========================================================================
    local minimapCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 12, yOffset)
    minimapCheck:SetChecked(GetMinimapSettings().show)
    configFrame.minimapCheckbox = minimapCheck
    ApplyElvUISkin(minimapCheck, "checkbox")

    local minimapCheckLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minimapCheckLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 2, 0)
    minimapCheckLabel:SetText("Show Minimap Button")

    minimapCheck:SetScript("OnClick", function(self)
        OneButtonMount:ToggleMinimapButton()
    end)

    local textualFeedbackCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    textualFeedbackCheck:SetPoint("LEFT", minimapCheckLabel, "RIGHT", 24, 0)
    textualFeedbackCheck:SetChecked(ShowTextualFeedback())
    configFrame.textualFeedbackCheckbox = textualFeedbackCheck
    ApplyElvUISkin(textualFeedbackCheck, "checkbox")

    local textualFeedbackLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textualFeedbackLabel:SetPoint("LEFT", textualFeedbackCheck, "RIGHT", 2, 0)
    textualFeedbackLabel:SetText("Show Textual Feedback")

    textualFeedbackCheck:SetScript("OnClick", function(self)
        characterDB.showTextualFeedback = self:GetChecked() and true or false
    end)

    yOffset = yOffset - 35

    -- ========================================================================
    -- Ground Mount Pool
    -- ========================================================================
    local groundContainer, groundLabel = CreatePoolSection(configFrame, "Ground Mount Rotation", POOL_GROUND, yOffset)
    configFrame.groundContainer = groundContainer
    configFrame.groundLabel = groundLabel

    yOffset = yOffset - 80

    -- ========================================================================
    -- Flying Mount Pool
    -- ========================================================================
    local flyingContainer, flyingLabel = CreatePoolSection(configFrame, "Flying Mount Rotation", POOL_FLYING, yOffset)
    configFrame.flyingContainer = flyingContainer
    configFrame.flyingLabel = flyingLabel

    yOffset = yOffset - 80

    -- ========================================================================
    -- Available Mounts (All Mounts List)
    -- ========================================================================
    local availLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    availLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, yOffset)
    availLabel:SetText("Available Mounts")
    configFrame.availLabel = availLabel

    local availHint = configFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    availHint:SetPoint("LEFT", availLabel, "RIGHT", 10, 0)
    availHint:SetText("Left-click = Ground | Right-click = Flying")
    configFrame.availHint = availHint

    -- Scroll frame for available mounts
    local scrollFrame = CreateFrame("ScrollFrame", "OneButtonMountScrollFrame", configFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", availLabel, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -30, 12)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    configFrame.scrollChild = scrollChild
    configFrame.scrollFrame = scrollFrame
    ApplyElvUISkin(scrollFrame.ScrollBar or scrollFrame, "scrollbar")

    configFrame.mountButtons = {}

    configFrame:Hide()
    self:RefreshConfigUI()
end

function OneButtonMount:RefreshConfigUI()
    if not configFrame then return end

    ScanMounts()
    SanitizeSavedMountPools()

    if configFrame.minimapCheckbox then
        configFrame.minimapCheckbox:SetChecked(GetMinimapSettings().show)
    end
    if configFrame.textualFeedbackCheckbox then
        configFrame.textualFeedbackCheckbox:SetChecked(ShowTextualFeedback())
    end

    -- Refresh ground pool
    local gc = configFrame.groundContainer
    for _, btn in ipairs(gc.mountButtons or {}) do
        btn:Hide()
        btn:SetParent(nil)
    end
    gc.mountButtons = {}

    local groundMounts, flyingMounts = GetMountPools()

    if #groundMounts == 0 then
        gc.emptyText:Show()
    else
        gc.emptyText:Hide()
    end

    local xOff = 4
    local rowHeight = 40
    local rows = 1
    for i, spellID in ipairs(groundMounts) do
        local mount = GetMountBySpellID(spellID)
        if mount then
            local btn = CreateMountIcon(gc, mount, POOL_GROUND, i)
            btn:SetPoint("TOPLEFT", gc, "TOPLEFT", xOff, -4)
            xOff = xOff + 40
            if xOff > gc:GetWidth() - 40 then
                xOff = 4
                rows = rows + 1
            end
            table.insert(gc.mountButtons, btn)
        end
    end
    gc:SetHeight(math.max(44, rows * rowHeight + 8))

    -- Refresh flying pool
    local fc = configFrame.flyingContainer
    for _, btn in ipairs(fc.mountButtons or {}) do
        btn:Hide()
        btn:SetParent(nil)
    end
    fc.mountButtons = {}

    if #flyingMounts == 0 then
        fc.emptyText:Show()
    else
        fc.emptyText:Hide()
    end

    xOff = 4
    rows = 1
    for i, spellID in ipairs(flyingMounts) do
        local mount = GetMountBySpellID(spellID)
        if mount then
            local btn = CreateMountIcon(fc, mount, POOL_FLYING, i)
            btn:SetPoint("TOPLEFT", fc, "TOPLEFT", xOff, -4)
            xOff = xOff + 40
            if xOff > fc:GetWidth() - 40 then
                xOff = 4
                rows = rows + 1
            end
            table.insert(fc.mountButtons, btn)
        end
    end
    fc:SetHeight(math.max(44, rows * rowHeight + 8))

    -- Reposition sections based on dynamic heights
    local yOffset = -35 - 35 - 35 -- keybind + settings row

    configFrame.groundLabel:ClearAllPoints()
    configFrame.groundLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, yOffset)
    yOffset = yOffset - 20 - gc:GetHeight() - 10

    configFrame.flyingLabel:ClearAllPoints()
    configFrame.flyingLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, yOffset)
    yOffset = yOffset - 20 - fc:GetHeight() - 10

    configFrame.availLabel:ClearAllPoints()
    configFrame.availLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, yOffset)

    -- Refresh available mounts list
    local sc = configFrame.scrollChild
    for _, btn in ipairs(configFrame.mountButtons or {}) do
        btn:Hide()
        btn:SetParent(nil)
    end
    configFrame.mountButtons = {}

    xOff = 4
    local yPos = -4
    local cols = 0
    local frameWidth = configFrame:GetWidth()
    if frameWidth < 1 then frameWidth = 460 end -- fallback if frame not yet laid out
    local maxCols = math.floor((frameWidth - 50) / 40)

    for _, mount in ipairs(allMounts) do
        local inGround = TableContains(groundMounts, mount.spellID)
        local inFlying = TableContains(flyingMounts, mount.spellID)

        local btn = CreateMountIcon(sc, mount, nil, nil)
        btn:SetPoint("TOPLEFT", sc, "TOPLEFT", xOff, yPos)

        -- Dim if already in a pool
        if inGround or inFlying then
            btn.iconTexture:SetDesaturated(true)
            btn.iconTexture:SetAlpha(0.5)
        end

        -- Add a colored indicator if already assigned
        if inGround then
            local indicator = btn:CreateTexture(nil, "OVERLAY")
            indicator:SetSize(8, 8)
            indicator:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
            SetSolidColor(indicator, 0.2, 0.8, 0.2, 1)
        end
        if inFlying then
            local indicator = btn:CreateTexture(nil, "OVERLAY")
            indicator:SetSize(8, 8)
            indicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
            SetSolidColor(indicator, 0.4, 0.6, 1.0, 1)
        end

        table.insert(configFrame.mountButtons, btn)

        cols = cols + 1
        xOff = xOff + 40
        if cols >= maxCols then
            cols = 0
            xOff = 4
            yPos = yPos - 40
        end
    end

    -- Set scroll child height
    local totalRows = math.ceil(#allMounts / math.max(maxCols, 1))
    sc:SetSize(frameWidth - 50, math.max(totalRows * 40 + 10, 100))
end

function OneButtonMount:ToggleConfigUI()
    if not configFrame then
        self:CreateConfigUI()
    end

    if configFrame:IsShown() then
        configFrame:Hide()
    else
        self:RefreshConfigUI()
        configFrame:Show()
    end
end

function OneButtonMount:ShowConfigUI()
    if not configFrame then
        self:CreateConfigUI()
    end
    self:RefreshConfigUI()
    configFrame:Show()
end

-- ============================================================================
-- Saved Variables Init
-- ============================================================================

function OneButtonMount:InitDB()
    if type(OneButtonMountDB) ~= "table" then
        OneButtonMountDB = {}
    end

    local legacyDB = OneButtonMountDB
    local characterDB = GetCharacterDB()
    local hasLegacyProfile = type(legacyDB.groundMounts) == "table"
        or type(legacyDB.flyingMounts) == "table"
        or type(legacyDB.keybind) == "string"
        or type(legacyDB.minimapButton) == "table"
        or type(legacyDB.configPosition) == "table"
        or legacyDB.showTextualFeedback ~= nil

    if characterDB.profileVersion ~= CHARACTER_PROFILE_VERSION and hasLegacyProfile then
        if type(characterDB.groundMounts) ~= "table" and type(legacyDB.groundMounts) == "table" then
            characterDB.groundMounts = CopyValue(legacyDB.groundMounts)
        end
        if type(characterDB.flyingMounts) ~= "table" and type(legacyDB.flyingMounts) == "table" then
            characterDB.flyingMounts = CopyValue(legacyDB.flyingMounts)
        end
        if characterDB.keybind == nil and type(legacyDB.keybind) == "string" then
            characterDB.keybind = legacyDB.keybind
        end
        if characterDB.minimapButton == nil and type(legacyDB.minimapButton) == "table" then
            characterDB.minimapButton = CopyValue(legacyDB.minimapButton)
        end
        if characterDB.configPosition == nil and type(legacyDB.configPosition) == "table" then
            characterDB.configPosition = CopyValue(legacyDB.configPosition)
        end
        if characterDB.showTextualFeedback == nil and legacyDB.showTextualFeedback ~= nil then
            characterDB.showTextualFeedback = legacyDB.showTextualFeedback and true or false
        end
    end

    local groundMounts, flyingMounts = GetMountPools()
    characterDB.groundMounts = groundMounts
    characterDB.flyingMounts = flyingMounts

    if type(characterDB.keybind) ~= "string" and characterDB.keybind ~= nil then
        characterDB.keybind = nil
    end
    GetMinimapSettings()
    if characterDB.showTextualFeedback == nil then
        characterDB.showTextualFeedback = true
    end
    characterDB.profileVersion = CHARACTER_PROFILE_VERSION
end

-- ============================================================================
-- Slash Command
-- ============================================================================

SLASH_ONEBUTTONMOUNT1 = "/onebuttonmount"
SLASH_ONEBUTTONMOUNT2 = "/obm"
SlashCmdList["ONEBUTTONMOUNT"] = function(msg)
    local args = {}
    for word in string.gmatch(msg, "%S+") do
        table.insert(args, string.lower(word))
    end

    if #args == 0 then
        OneButtonMount:ToggleConfigUI()
        return
    end

    local cmd = args[1]

    if cmd == "help" or cmd == "?" then
        Print("Commands:")
        Print("  /onebuttonmount - Open config UI")
        Print("  /obm - Short alias")
        Print("  /obm minimap - Toggle minimap button")
        Print("  /obm mount - Summon a random mount")
        Print("  /obm debug - Print live mount-selection state")
        Print("  /obm help - Show this help")
    elseif cmd == "minimap" or cmd == "mm" then
        OneButtonMount:ToggleMinimapButton()
    elseif cmd == "mount" or cmd == "go" then
        SummonRandomMount()
    elseif cmd == "debug" or cmd == "diag" then
        PrintDebugSummary()
    elseif cmd == "config" or cmd == "ui" or cmd == "gui" then
        OneButtonMount:ShowConfigUI()
    else
        OneButtonMount:ToggleConfigUI()
    end
end

-- ============================================================================
-- Event Handling
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("COMPANION_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        OneButtonMount:InitDB()
        ScanMounts()
        SanitizeSavedMountPools()

        -- Create minimap button
        if GetMinimapSettings().show then
            CreateMinimapButton()
            OneButtonMount:UpdateMinimapButtonPosition()
        end

        Feedback("Loaded! Type /onebuttonmount or /obm to configure.")

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Restore keybind after loading screens
        RestoreKeybind()
        ScanMounts()
        SanitizeSavedMountPools()

    elseif event == "COMPANION_UPDATE" then
        ScanMounts()
        SanitizeSavedMountPools()
        if configFrame and configFrame:IsShown() then
            OneButtonMount:RefreshConfigUI()
        end
    end
end)
