local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_equal failed") .. string.format(" (expected=%s, actual=%s)", tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, message)
    if not value then
        error(message or "assert_true failed")
    end
end

local native_tonumber = tonumber

local function copy_table(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for k, v in pairs(value) do
        out[k] = copy_table(v)
    end
    return out
end

local function setup_env(opts)
    opts = opts or {}
    local state = {
        frames = {},
        chat = {},
        binding_clicks = {},
        binding_clears = {},
        mounts = opts.mounts or {},
        known_spells = opts.known_spells or {},
        indoors = opts.indoors or false,
        in_instance = opts.in_instance or false,
        mounted = opts.mounted or false,
        in_combat = opts.in_combat or false,
        instance_info = opts.instance_info,
        map_id = opts.map_id,
        map_infos = opts.map_infos or {},
        current_map_area_id = opts.current_map_area_id,
        real_zone_text = opts.real_zone_text,
        zone_text = opts.zone_text,
        mount_journal_mounts = opts.mount_journal_mounts or {},
        bag_items = opts.bag_items or {},
        item_spells = opts.item_spells or {},
        item_infos = opts.item_infos or {},
        c_map_enabled = opts.c_map_enabled ~= false,
        num_companions_mode = opts.num_companions_mode,
        num_companions_value = opts.num_companions_value,
        shift_down = opts.shift_down or false,
        control_down = opts.control_down or false,
        alt_down = opts.alt_down or false,
        num_slots_mode = opts.num_slots_mode,
        strict_tonumber = opts.strict_tonumber or false,
        is_flyable_area = opts.is_flyable_area,
        player_level = opts.player_level or 70,
        player_name = opts.player_name or "TestPlayer",
        realm_name = opts.realm_name or "TestRealm",
        spell_infos = opts.spell_infos or {},
        spellbook_entries = opts.spellbook_entries or {},
        player_spells = opts.player_spells or {},
        is_spell_known_available = opts.is_spell_known_available ~= false,
    }

    _G.unpack = table.unpack
    _G.tinsert = table.insert
    if state.strict_tonumber then
        _G.tonumber = function(value, base)
            if value == nil then
                error("bad argument #1 to 'tonumber' (value expected)")
            end
            return native_tonumber(value, base)
        end
    else
        _G.tonumber = native_tonumber
    end

    if not math.atan2 then
        math.atan2 = function(y, x)
            return math.atan(y, x)
        end
    end

    _G.bit = {
        band = function(a, b)
            return a & b
        end,
    }

    local function new_texture()
        local texture = {}
        function texture:SetAllPoints() end
        function texture:SetTexture(...) self.texture = { ... } end
        function texture:SetColorTexture(...) self.color = { ... } end
        function texture:SetSize() end
        function texture:SetPoint() end
        function texture:SetTexCoord() end
        function texture:SetBlendMode() end
        function texture:SetAlpha() end
        function texture:SetDesaturated(value) self.desaturated = value end
        return texture
    end

    local function new_font_string()
        local font_string = { shown = true }
        function font_string:SetPoint() end
        function font_string:ClearAllPoints() end
        function font_string:SetText(text) self.text = text end
        function font_string:Show() self.shown = true end
        function font_string:Hide() self.shown = false end
        return font_string
    end

    local function new_frame(frame_type, name, parent, template)
        local frame = {
            frame_type = frame_type,
            name = name,
            parent = parent,
            template = template,
            shown = true,
            width = 0,
            height = 0,
            scripts = {},
            events = {},
        }

        function frame:SetSize(width, height)
            self.width = width
            self.height = height
        end
        function frame:SetWidth(width) self.width = width end
        function frame:SetHeight(height) self.height = height end
        function frame:GetWidth() return self.width or 0 end
        function frame:GetHeight() return self.height or 0 end
        function frame:SetPoint(...) self.point = { ... } end
        function frame:GetPoint()
            if self.point then
                return table.unpack(self.point)
            end
            return "CENTER", _G.UIParent, "CENTER", 0, 0
        end
        function frame:ClearAllPoints() self.point = nil end
        function frame:SetMovable() end
        function frame:EnableMouse() end
        function frame:EnableKeyboard() end
        function frame:RegisterForDrag() end
        function frame:RegisterForClicks(...) self.clicks = { ... } end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(script_name, fn) self.scripts[script_name] = fn end
        function frame:SetFrameStrata() end
        function frame:SetFrameLevel() end
        function frame:SetPropagateKeyboardInput() end
        function frame:SetHighlightTexture() end
        function frame:SetAttribute(key, value)
            self.attributes = self.attributes or {}
            self.attributes[key] = value
        end
        function frame:GetAttribute(key)
            return self.attributes and self.attributes[key]
        end
        function frame:CreateTexture()
            return new_texture()
        end
        function frame:CreateFontString()
            return new_font_string()
        end
        function frame:SetAllPoints() end
        function frame:SetScrollChild(child) self.scroll_child = child end
        function frame:SetText(text) self.text = text end
        function frame:SetChecked(value) self.checked = value end
        function frame:GetChecked() return self.checked end
        function frame:Hide() self.shown = false end
        function frame:Show() self.shown = true end
        function frame:IsShown() return self.shown end
        function frame:SetParent(parent_frame) self.parent = parent_frame end
        function frame:StartMoving() end
        function frame:StopMovingOrSizing() end
        function frame:GetCenter() return 0, 0 end
        function frame:GetEffectiveScale() return 1 end

        state.frames[#state.frames + 1] = frame
        if name then
            _G[name] = frame
        end
        return frame
    end

    _G.CreateFrame = function(frame_type, name, parent, template)
        return new_frame(frame_type, name, parent, template)
    end

    _G.UIParent = new_frame("Frame", "UIParent", nil, nil)
    _G.Minimap = new_frame("Frame", "Minimap", _G.UIParent, nil)

    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, message)
            state.chat[#state.chat + 1] = message
        end,
    }

    _G.GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
    }

    _G.SlashCmdList = {}
    _G.UISpecialFrames = {}
    _G.ElvUI = nil
    _G.LE_ITEM_CLASS_MISCELLANEOUS = 15
    _G.LE_ITEM_MISCELLANEOUS_MOUNT = 5
    _G.BOOKTYPE_SPELL = "spell"
    _G.Enum = {
        MountType = {
            Flying = 1,
        },
    }
    _G.OneButtonMountDB = copy_table(opts.db or {})
    _G.OneButtonMountCharDB = copy_table(opts.char_db)

    _G.InCombatLockdown = function() return state.in_combat end
    _G.IsMounted = function() return state.mounted end
    _G.Dismount = function() state.dismounted = true end
    _G.IsIndoors = function() return state.indoors end
    _G.IsInInstance = function() return state.in_instance, "none" end
    _G.GetInstanceInfo = function()
        if not state.instance_info then
            return nil
        end

        return state.instance_info.name,
            state.instance_info.instanceType or "none",
            state.instance_info.difficultyID,
            state.instance_info.difficultyName,
            state.instance_info.maxPlayers,
            state.instance_info.dynamicDifficulty,
            state.instance_info.isDynamic,
            state.instance_info.instanceID,
            state.instance_info.instanceGroupSize,
            state.instance_info.lfgDungeonID
    end
    _G.GetNumCompanions = function()
        if state.num_companions_mode == "nil" then
            return nil
        end
        if state.num_companions_mode == "no_values" then
            return
        end
        if state.num_companions_value ~= nil then
            return state.num_companions_value
        end
        return #state.mounts
    end
    _G.GetCompanionInfo = function(_, index)
        local mount = state.mounts[index]
        if not mount then
            return nil
        end
        return index, mount.name, mount.spellID, mount.icon or "icon", false, mount.mountType or 0
    end
    _G.CallCompanion = function(_, index)
        state.last_call_companion_index = index
    end
    _G.CastSpellByID = function(spell_id)
        state.last_cast_spell_id = spell_id
    end
    _G.CastSpellByName = function(spell_name)
        state.last_cast_spell_name = spell_name
    end
    _G.UseItemByName = function(item_id)
        state.last_used_item_id = item_id
    end
    _G.GetSpellInfo = function(spell_id)
        local spell_info = state.spell_infos[spell_id]
        if spell_info then
            return spell_info.name, spell_info.rank, spell_info.icon
        end
        for _, mount in ipairs(state.mounts) do
            if mount.spellID == spell_id then
                return mount.name, nil, mount.icon or "icon"
            end
        end
        for _, mount in ipairs(state.mount_journal_mounts) do
            if mount.spellID == spell_id then
                return mount.name, nil, mount.icon or "icon"
            end
        end
        for item_id, spell in pairs(state.item_spells) do
            if spell.spellID == spell_id then
                local item_info = state.item_infos[item_id]
                return spell.name, nil, item_info and item_info.icon or "icon"
            end
        end
        return nil
    end
    if state.is_spell_known_available then
        _G.IsSpellKnown = function(spell_id)
            return state.known_spells[spell_id] or false
        end
    else
        _G.IsSpellKnown = nil
    end
    _G.IsPlayerSpell = function(spell_id)
        return state.player_spells[spell_id] or false
    end
    _G.SetOverrideBindingClick = function(_, is_priority, key, button_name, mouse_button)
        state.binding_clicks[#state.binding_clicks + 1] = {
            key = key,
            button_name = button_name,
            is_priority = is_priority,
            mouse_button = mouse_button,
        }
    end
    _G.SetOverrideBinding = function(_, _, key, command)
        state.binding_clears[#state.binding_clears + 1] = { key = key, command = command }
    end
    _G.GetRealZoneText = function() return state.real_zone_text end
    _G.GetZoneText = function() return state.zone_text end
    _G.GetCurrentMapAreaID = function() return state.current_map_area_id end
    _G.GetCursorPosition = function() return 0, 0 end
    _G.IsShiftKeyDown = function() return state.shift_down end
    _G.IsControlKeyDown = function() return state.control_down end
    _G.IsAltKeyDown = function() return state.alt_down end
    _G.IsFlyableArea = function() return state.is_flyable_area end
    _G.UnitLevel = function(unit)
        if unit == "player" then
            return state.player_level
        end
        return nil
    end
    _G.UnitFullName = function(unit)
        if unit == "player" then
            return state.player_name, state.realm_name
        end
        return nil
    end
    _G.UnitName = function(unit)
        if unit == "player" then
            return state.player_name
        end
        return nil
    end
    _G.GetRealmName = function()
        return state.realm_name
    end
    _G.GetItemSpell = function(item_id)
        local spell = state.item_spells[item_id]
        if spell then
            return spell.name, spell.spellID
        end
        return nil
    end
    _G.GetItemInfoInstant = function(item_id)
        local info = state.item_infos[item_id]
        if not info then
            return item_id, nil, nil, nil, nil, nil, nil
        end
        return item_id, info.itemType, info.itemSubType, nil, info.icon, info.classID, info.subClassID
    end
    _G.GetNumSpellTabs = function()
        if #state.spellbook_entries > 0 then
            return 1
        end
        return 0
    end
    _G.GetSpellTabInfo = function(index)
        if index == 1 and #state.spellbook_entries > 0 then
            return "General", nil, 0, #state.spellbook_entries
        end
        return nil
    end
    _G.GetSpellBookItemInfo = function(slot, book_type)
        if book_type ~= _G.BOOKTYPE_SPELL then
            return nil
        end
        local entry = state.spellbook_entries[slot]
        if not entry then
            return nil
        end
        return "SPELL", entry.spellID
    end
    _G.GetSpellBookItemName = function(slot, book_type)
        if book_type ~= _G.BOOKTYPE_SPELL then
            return nil
        end
        local entry = state.spellbook_entries[slot]
        if not entry then
            return nil
        end
        return entry.name
    end
    _G.GetItemInfo = function(item_id)
        local info = state.item_infos[item_id]
        if not info then
            return nil
        end
        return info.name, nil, nil, nil, nil, info.itemType, info.itemSubType, nil, nil, info.icon
    end
    _G.GetItemSubClassInfo = function(class_id, sub_class_id)
        if class_id == _G.LE_ITEM_CLASS_MISCELLANEOUS and sub_class_id == _G.LE_ITEM_MISCELLANEOUS_MOUNT then
            return "Mount"
        end
        return nil
    end
    _G.NUM_BAG_SLOTS = 4
    _G.GetContainerNumSlots = function(bag)
        if state.num_slots_mode == "nil" then
            return nil
        end
        if state.num_slots_mode == "no_values" then
            return
        end
        if bag == 0 then
            return #state.bag_items
        end
        return 0
    end
    _G.GetContainerItemID = function(bag, slot)
        if bag == 0 then
            return state.bag_items[slot]
        end
        return nil
    end
    _G.C_Container = {
        GetContainerNumSlots = _G.GetContainerNumSlots,
        GetContainerItemID = _G.GetContainerItemID,
    }

    if #state.mount_journal_mounts > 0 then
        local mount_by_id = {}
        local mount_ids = {}
        for _, mount in ipairs(state.mount_journal_mounts) do
            mount_by_id[mount.mountID] = mount
            mount_ids[#mount_ids + 1] = mount.mountID
        end

        _G.C_MountJournal = {
            GetMountIDs = function()
                return mount_ids
            end,
            GetMountInfoByID = function(mount_id)
                local mount = mount_by_id[mount_id]
                if not mount then
                    return nil
                end

                local is_collected = mount.isCollected
                if is_collected == nil then
                    is_collected = true
                end

                return mount.name, mount.spellID, mount.icon or "icon", false, true, nil, false, false, nil, false, is_collected
            end,
            GetMountInfoExtraByID = function(mount_id)
                local mount = mount_by_id[mount_id]
                if not mount then
                    return nil
                end
                return nil, nil, nil, nil, mount.mountTypeID
            end,
            SummonByID = function(mount_id)
                state.last_journal_summon_id = mount_id
            end,
        }
    else
        _G.C_MountJournal = nil
    end

    if state.c_map_enabled then
        _G.C_Map = {
            GetBestMapForUnit = function()
                return state.map_id
            end,
            GetMapInfo = function(map_id)
                local info = state.map_infos[map_id]
                if not info then
                    return nil
                end
                return {
                    mapID = map_id,
                    parentMapID = info.parentMapID or 0,
                    name = info.name,
                }
            end,
        }
    else
        _G.C_Map = nil
    end

    dofile("OneButtonMount.lua")

    local event_frame
    for _, frame in ipairs(state.frames) do
        if frame.events["ADDON_LOADED"] and frame.scripts["OnEvent"] then
            event_frame = frame
            break
        end
    end
    assert_true(event_frame ~= nil, "event frame was not created")
    event_frame.scripts["OnEvent"](event_frame, "ADDON_LOADED", "OneButtonMount")

    return state
end

local failures = 0
local total = 0

local function run_test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        print("PASS " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

run_test("stale mount IDs are pruned before summoning", function()
    local state = setup_env({
        mounts = {
            { spellID = 1001, name = "Brown Horse", mountType = 0x01 },
        },
        db = {
            groundMounts = { 9999, 1001, 9999 },
            flyingMounts = { 8888 },
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(#OneButtonMountCharDB.groundMounts, 1, "ground pool should be sanitized")
    assert_equal(OneButtonMountCharDB.groundMounts[1], 1001, "valid ground mount should remain")
    assert_equal(#OneButtonMountCharDB.flyingMounts, 0, "invalid flying mount should be removed")
    assert_equal(state.last_call_companion_index, 1, "valid mount should be summoned")
end)

run_test("zone-text fallback still allows flying without C_Map", function()
    local state = setup_env({
        mounts = {
            { spellID = 2001, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3001, name = "Flying Mount", mountType = 0x02 },
        },
        db = {
            groundMounts = { 2001 },
            flyingMounts = { 3001 },
        },
        known_spells = {
            [34090] = true,
        },
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_call_companion_index, 2, "flying pool should be selected in Outland")
end)

run_test("area-id fallback still allows flying when zone text is unavailable", function()
    local state = setup_env({
        mounts = {
            { spellID = 2002, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3002, name = "Flying Mount", mountType = 0x02 },
        },
        db = {
            groundMounts = { 2002 },
            flyingMounts = { 3002 },
        },
        known_spells = {
            [34090] = true,
        },
        c_map_enabled = false,
        current_map_area_id = 111,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_call_companion_index, 2, "area-id fallback should still select the flying pool when zone text is unavailable")
end)

run_test("is flyable area signal does not bypass missing riding skill", function()
    local state = setup_env({
        mounts = {
            { spellID = 2011, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3011, name = "Flying Mount", mountType = 0x02 },
        },
        db = {
            groundMounts = { 2011 },
            flyingMounts = { 3011 },
        },
        known_spells = {},
        is_flyable_area = true,
        c_map_enabled = false,
        real_zone_text = "Shattrath City",
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_call_companion_index, 1, "ground pool should be selected until the character can actually use flying mounts")
end)

run_test("non-outland flyable-area signal does not force flying pool", function()
    local state = setup_env({
        mounts = {
            { spellID = 2021, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3021, name = "Flying Mount", mountType = 0x02 },
        },
        db = {
            groundMounts = { 2021 },
            flyingMounts = { 3021 },
        },
        known_spells = {
            [34090] = true,
        },
        is_flyable_area = true,
        c_map_enabled = false,
        real_zone_text = "Orgrimmar",
        zone_text = "Orgrimmar",
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_call_companion_index, 1, "ground pool should be selected outside Outland even when IsFlyableArea returns true")
end)

run_test("zone text beats stale outland area IDs outside outland", function()
    local state = setup_env({
        mounts = {
            { spellID = 2031, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3031, name = "Flying Mount", mountType = 0x02 },
        },
        db = {
            groundMounts = { 2031 },
            flyingMounts = { 3031 },
        },
        known_spells = {
            [34090] = true,
        },
        c_map_enabled = false,
        current_map_area_id = 111,
        real_zone_text = "Stormwind City",
        zone_text = "Stormwind City",
        is_flyable_area = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_call_companion_index, 1, "ground pool should be selected when zone text says Stormwind even if area ID is stale")
end)

run_test("localized map names still allow flying without english zone fallback", function()
    local state = setup_env({
        mounts = {
            { spellID = 2041, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3041, name = "Flying Mount", mountType = 0x02 },
        },
        db = {
            groundMounts = { 2041 },
            flyingMounts = { 3041 },
        },
        known_spells = {
            [34090] = true,
        },
        map_id = nil,
        map_infos = {
            [111] = { name = "Schatrath", parentMapID = 101 },
            [101] = { name = "Scherbenwelt" },
        },
        real_zone_text = "Schatrath",
        zone_text = "Schatrath",
        is_flyable_area = true,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_call_companion_index, 2, "localized zone text should still match Outland map names and select the flying pool")
end)

run_test("localized zone text beats stale outland c_map results outside outland", function()
    local state = setup_env({
        mounts = {
            { spellID = 2051, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3051, name = "Flying Mount", mountType = 0x02 },
        },
        db = {
            groundMounts = { 2051 },
            flyingMounts = { 3051 },
        },
        known_spells = {
            [34090] = true,
        },
        map_id = 111,
        map_infos = {
            [111] = { name = "Schatrath", parentMapID = 101 },
            [101] = { name = "Scherbenwelt" },
        },
        real_zone_text = "Sturmwind",
        zone_text = "Sturmwind",
        is_flyable_area = true,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_call_companion_index, 1, "localized live zone text should override a stale Outland C_Map result")
end)

run_test("aq40 only uses configured qiraji crystals", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        indoors = true,
        in_instance = true,
        instance_info = {
            name = "Temple of Ahn'Qiraj",
            instanceType = "raid",
            instanceID = 531,
        },
        bag_items = { 21218, 37012 },
        item_spells = {
            [21218] = { name = "Summon Blue Qiraji Battle Tank", spellID = 9301 },
            [37012] = { name = "Summon Ground Mount", spellID = 9302 },
        },
        item_infos = {
            [21218] = { name = "Blue Qiraji Resonating Crystal", icon = "icon", classID = 15, subClassID = 5, itemType = "Miscellaneous", itemSubType = "Mount" },
            [37012] = { name = "Ground Mount Item", icon = "icon", classID = 15, subClassID = 5, itemType = "Miscellaneous", itemSubType = "Mount" },
        },
        db = {
            groundMounts = { 9301, 9302 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_used_item_id, 21218, "AQ40 should only allow configured qiraji crystals")
end)

run_test("outside aq40 excludes qiraji crystals from selection", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        in_instance = false,
        bag_items = { 21218, 37012 },
        item_spells = {
            [21218] = { name = "Summon Blue Qiraji Battle Tank", spellID = 9311 },
            [37012] = { name = "Summon Ground Mount", spellID = 9312 },
        },
        item_infos = {
            [21218] = { name = "Blue Qiraji Resonating Crystal", icon = "icon", classID = 15, subClassID = 5, itemType = "Miscellaneous", itemSubType = "Mount" },
            [37012] = { name = "Ground Mount Item", icon = "icon", classID = 15, subClassID = 5, itemType = "Miscellaneous", itemSubType = "Mount" },
        },
        db = {
            groundMounts = { 9311, 9312 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_used_item_id, 37012, "outside AQ40 should skip qiraji crystal mounts")
end)

run_test("outside aq40 with only qiraji mounts reports no eligible mounts", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        in_instance = false,
        bag_items = { 21218 },
        item_spells = {
            [21218] = { name = "Summon Blue Qiraji Battle Tank", spellID = 9321 },
        },
        item_infos = {
            [21218] = { name = "Blue Qiraji Resonating Crystal", icon = "icon", classID = 15, subClassID = 5, itemType = "Miscellaneous", itemSubType = "Mount" },
        },
        db = {
            groundMounts = { 9321 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_used_item_id, nil, "outside AQ40 should not summon qiraji crystals")
    local found_message = false
    for _, line in ipairs(state.chat) do
        if string.find(line, "Qiraji crystals are AQ40-only", 1, true) then
            found_message = true
            break
        end
    end
    assert_true(found_message, "expected AQ40-only eligibility message")
end)

run_test("right mouse keybind maps to BUTTON2 token", function()
    local state = setup_env({
        mounts = {
            { spellID = 4001, name = "Test Mount", mountType = 0x01 },
        },
        db = {},
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local key_capture_frame
    for _, frame in ipairs(state.frames) do
        if frame.scripts["OnClick"] and frame.scripts["OnKeyDown"] then
            key_capture_frame = frame
            break
        end
    end
    assert_true(key_capture_frame ~= nil, "key capture frame not found")

    key_capture_frame.scripts["OnClick"](key_capture_frame, "RightButton")

    local last_binding = state.binding_clicks[#state.binding_clicks]
    assert_true(last_binding ~= nil, "no binding call recorded")
    assert_equal(last_binding.key, "BUTTON2", "right-click bind token should be BUTTON2")
    assert_equal(last_binding.is_priority, true, "binding override should use priority")
    assert_equal(last_binding.mouse_button, "LeftButton", "binding click should target left button explicitly")
    assert_equal(OneButtonMountCharDB.keybind, "BUTTON2", "keybind should be saved per character")
    assert_equal(OneButtonMountDB.keybind, nil, "legacy account-wide keybind should remain unused")
end)

run_test("textual feedback defaults to enabled and can be toggled from config", function()
    setup_env({
        mounts = {
            { spellID = 4201, name = "Test Mount", mountType = 0x01 },
        },
        db = {},
    })

    assert_equal(OneButtonMountCharDB.showTextualFeedback, true, "textual feedback should default to enabled")

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")
    assert_true(config_frame.textualFeedbackCheckbox ~= nil, "textual feedback checkbox missing")
    assert_equal(config_frame.textualFeedbackCheckbox:GetChecked(), true, "textual feedback checkbox should default checked")

    config_frame.textualFeedbackCheckbox:SetChecked(false)
    config_frame.textualFeedbackCheckbox.scripts["OnClick"](config_frame.textualFeedbackCheckbox)

    assert_equal(OneButtonMountCharDB.showTextualFeedback, false, "textual feedback checkbox should update saved state")
end)

run_test("disabled textual feedback suppresses addon feedback but not explicit help", function()
    local state = setup_env({
        mounts = {
            { spellID = 4301, name = "Muted Mount", mountType = 0x01 },
        },
        indoors = true,
        char_db = {
            groundMounts = { 4301 },
            showTextualFeedback = false,
        },
        c_map_enabled = false,
    })

    assert_equal(#state.chat, 0, "load feedback should be muted when disabled")

    SlashCmdList["ONEBUTTONMOUNT"]("mount")
    SlashCmdList["ONEBUTTONMOUNT"]("minimap")

    assert_equal(#state.chat, 0, "mount and status feedback should be muted when disabled")

    SlashCmdList["ONEBUTTONMOUNT"]("help")

    local found_help = false
    for _, line in ipairs(state.chat) do
        if string.find(line, "Commands:", 1, true) then
            found_help = true
            break
        end
    end
    assert_true(found_help, "explicit help output should still be shown")
end)

run_test("shift plus button5 keybind is captured as SHIFT-BUTTON5", function()
    local state = setup_env({
        mounts = {
            { spellID = 4101, name = "Test Mount", mountType = 0x01 },
        },
        db = {},
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local key_capture_frame
    for _, frame in ipairs(state.frames) do
        if frame.scripts["OnClick"] and frame.scripts["OnKeyDown"] then
            key_capture_frame = frame
            break
        end
    end
    assert_true(key_capture_frame ~= nil, "key capture frame not found")

    state.shift_down = true
    key_capture_frame.scripts["OnClick"](key_capture_frame, "Button5")

    local last_binding = state.binding_clicks[#state.binding_clicks]
    assert_true(last_binding ~= nil, "no binding call recorded")
    assert_equal(last_binding.key, "SHIFT-BUTTON5", "shift+button5 should be stored as SHIFT-BUTTON5")
    assert_equal(last_binding.is_priority, true, "binding override should use priority")
    assert_equal(last_binding.mouse_button, "LeftButton", "binding click should target left button explicitly")
    assert_equal(OneButtonMountCharDB.keybind, "SHIFT-BUTTON5", "shift+button5 should be saved per character")
end)

run_test("binding button accepts key down and key up clicks", function()
    setup_env({
        mounts = {
            { spellID = 4103, name = "Test Mount", mountType = 0x01 },
        },
        db = {},
    })

    local binding_button = _G.OneButtonMountBindingButton
    assert_true(binding_button ~= nil, "binding button not created")
    assert_true(type(binding_button.clicks) == "table", "binding button click registration missing")

    local has_any_down = false
    local has_any_up = false
    for _, token in ipairs(binding_button.clicks) do
        if token == "AnyDown" then
            has_any_down = true
        elseif token == "AnyUp" then
            has_any_up = true
        end
    end

    assert_true(has_any_down, "binding button should register AnyDown")
    assert_true(has_any_up, "binding button should register AnyUp")
end)

run_test("shift plus button5 keybind is captured via mouse down fallback", function()
    local state = setup_env({
        mounts = {
            { spellID = 4102, name = "Test Mount", mountType = 0x01 },
        },
        db = {},
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local key_capture_frame
    for _, frame in ipairs(state.frames) do
        if frame.scripts["OnMouseDown"] and frame.scripts["OnKeyDown"] then
            key_capture_frame = frame
            break
        end
    end
    assert_true(key_capture_frame ~= nil, "key capture frame with mouse down handler not found")

    state.shift_down = true
    key_capture_frame.scripts["OnMouseDown"](key_capture_frame, "Button5")

    local last_binding = state.binding_clicks[#state.binding_clicks]
    assert_true(last_binding ~= nil, "no binding call recorded")
    assert_equal(last_binding.key, "SHIFT-BUTTON5", "shift+button5 should be stored as SHIFT-BUTTON5 from mouse down")
end)

run_test("mount journal fallback populates mounts and can summon", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        mount_journal_mounts = {
            { mountID = 9001, spellID = 8101, name = "Journal Ground", mountTypeID = 0 },
            { mountID = 9002, spellID = 8102, name = "Journal Flying", mountTypeID = 1 },
        },
        db = {
            groundMounts = { 8101 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")
    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")
    assert_true(type(config_frame.mountButtons) == "table" and #config_frame.mountButtons >= 2, "mount journal entries should populate available list")

    SlashCmdList["ONEBUTTONMOUNT"]("mount")
    assert_equal(state.last_journal_summon_id, 9001, "journal mount should summon via C_MountJournal")
end)

run_test("bag mount fallback populates mounts and summons via item use", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        bag_items = { 37012, 37013 },
        item_spells = {
            [37012] = { name = "Summon Ground Mount", spellID = 9101 },
            [37013] = { name = "Summon Flying Mount", spellID = 9102 },
        },
        item_infos = {
            [37012] = { name = "Ground Mount Item", icon = "icon", classID = 15, subClassID = 5, itemType = "Miscellaneous", itemSubType = "Mount" },
            [37013] = { name = "Flying Mount Item", icon = "icon", classID = 15, subClassID = 5, itemType = "Miscellaneous", itemSubType = "Mount" },
        },
        db = {
            groundMounts = { 9101 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")
    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")
    assert_true(type(config_frame.mountButtons) == "table" and #config_frame.mountButtons >= 2, "bag mount entries should populate available list")

    SlashCmdList["ONEBUTTONMOUNT"]("mount")
    assert_equal(state.last_used_item_id, 37012, "bag mount should summon via UseItemByName")
end)

run_test("companion index probe fallback works when companion count is unavailable", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        mounts = {
            { spellID = 9201, name = "Probe Mount", mountType = 0x01 },
        },
        db = {
            groundMounts = { 9201 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")
    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")
    assert_true(type(config_frame.mountButtons) == "table" and #config_frame.mountButtons >= 1, "companion probe should populate available mounts")

    SlashCmdList["ONEBUTTONMOUNT"]("mount")
    assert_equal(state.last_call_companion_index, 1, "companion probe fallback should summon via CallCompanion")
end)

run_test("class mount spells populate available mounts and summon by spell", function()
    local state = setup_env({
        known_spells = {
            [13819] = true,
            [23214] = true,
            [5784] = true,
            [23161] = true,
        },
        spell_infos = {
            [13819] = { name = "Summon Warhorse", icon = "warhorse" },
            [23214] = { name = "Summon Charger", icon = "charger" },
            [5784] = { name = "Summon Felsteed", icon = "felsteed" },
            [23161] = { name = "Summon Dreadsteed", icon = "dreadsteed" },
        },
        db = {
            groundMounts = { 13819 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")

    local found_spells = {}
    for _, button in ipairs(config_frame.mountButtons) do
        if button.mountData and button.mountData.spellID then
            found_spells[button.mountData.spellID] = true
        end
    end

    assert_true(found_spells[13819], "warhorse should appear in the available mount list")
    assert_true(found_spells[23214], "charger should appear in the available mount list")
    assert_true(found_spells[5784], "felsteed should appear in the available mount list")
    assert_true(found_spells[23161], "dreadsteed should appear in the available mount list")

    SlashCmdList["ONEBUTTONMOUNT"]("mount")
    assert_equal(state.last_cast_spell_id, 13819, "class mount should summon through spell casting")
end)

run_test("class mount spells populate from spellbook when IsSpellKnown is unavailable", function()
    local state = setup_env({
        is_spell_known_available = false,
        spellbook_entries = {
            { spellID = 23214, name = "Summon Charger" },
        },
        spell_infos = {
            [23214] = { name = "Summon Charger", icon = "charger" },
        },
        db = {
            groundMounts = { 23214 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")

    local found_charger = false
    for _, button in ipairs(config_frame.mountButtons) do
        if button.mountData and button.mountData.spellID == 23214 then
            found_charger = true
            break
        end
    end

    assert_true(found_charger, "charger should appear in the available mount list from spellbook fallback")

    SlashCmdList["ONEBUTTONMOUNT"]("mount")
    assert_equal(state.last_cast_spell_id, 23214, "spellbook fallback mount should summon through spell casting")
end)

run_test("ground pool skips known flying mounts until the character can fly", function()
    local state = setup_env({
        mounts = {
            { spellID = 2111, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3111, name = "Flying Mount", mountType = 0x02 },
        },
        db = {
            groundMounts = { 3111, 2111 },
            flyingMounts = {},
        },
        known_spells = {},
        player_level = 69,
        is_flyable_area = true,
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_call_companion_index, 1, "known flying mounts in the ground pool should be skipped until the character can ride them")
end)

run_test("spellbook fallback keeps ground mounts selected until riding is learned", function()
    local state = setup_env({
        is_spell_known_available = false,
        mounts = {
            { spellID = 2121, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3121, name = "Flying Mount", mountType = 0x02 },
        },
        db = {
            groundMounts = { 2121 },
            flyingMounts = { 3121 },
        },
        player_level = 70,
        is_flyable_area = true,
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_call_companion_index, 1, "without a known riding spell in the spellbook fallback, the addon should stay on ground mounts")
end)

run_test("spellbook fallback allows flying once riding is present", function()
    local state = setup_env({
        is_spell_known_available = false,
        mounts = {
            { spellID = 2131, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3131, name = "Flying Mount", mountType = 0x02 },
        },
        db = {
            groundMounts = { 2131 },
            flyingMounts = { 3131 },
        },
        player_level = 70,
        spellbook_entries = {
            { spellID = 34090, name = "Expert Riding" },
        },
        is_flyable_area = true,
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_call_companion_index, 2, "riding found via spellbook fallback should allow the flying pool")
end)

run_test("non-flying mounts cannot be added to flying rotation", function()
    local state = setup_env({
        mounts = {
            { spellID = 5001, name = "Ground Only", mountType = 0x01 },
        },
        db = {
            groundMounts = {},
            flyingMounts = {},
        },
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")
    assert_true(type(config_frame.mountButtons) == "table", "available mount buttons missing")

    local ground_button
    for _, button in ipairs(config_frame.mountButtons) do
        if button.mountData and button.mountData.spellID == 5001 and not button.pool then
            ground_button = button
            break
        end
    end
    assert_true(ground_button ~= nil, "ground mount button not found")

    ground_button.scripts["OnClick"](ground_button, "RightButton")

    assert_equal(#OneButtonMountCharDB.flyingMounts, 0, "ground-only mount should not enter flying pool")

    local found_message = false
    for _, line in ipairs(state.chat) do
        if string.find(line, "cannot be added to flying rotation", 1, true) then
            found_message = true
            break
        end
    end
    assert_true(found_message, "expected rejection message was not printed")
end)

run_test("unknown companion mount type can still be added to flying rotation", function()
    local state = setup_env({
        mounts = {
            { spellID = 5002, name = "Unknown Type Mount", mountType = 0 },
        },
        db = {
            groundMounts = {},
            flyingMounts = {},
        },
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")
    assert_true(type(config_frame.mountButtons) == "table", "available mount buttons missing")

    local unknown_type_button
    for _, button in ipairs(config_frame.mountButtons) do
        if button.mountData and button.mountData.spellID == 5002 and not button.pool then
            unknown_type_button = button
            break
        end
    end
    assert_true(unknown_type_button ~= nil, "unknown type mount button not found")

    unknown_type_button.scripts["OnClick"](unknown_type_button, "RightButton")
    assert_equal(#OneButtonMountCharDB.flyingMounts, 1, "unknown type mount should be allowed into flying pool")
    assert_equal(OneButtonMountCharDB.flyingMounts[1], 5002, "expected unknown type mount spellID in flying pool")
end)

run_test("nil companion count on addon load does not crash", function()
    local state = setup_env({
        mounts = {
            { spellID = 6001, name = "Backup Mount", mountType = 0x01 },
        },
        num_companions_mode = "nil",
        db = {
            groundMounts = { 6001 },
            flyingMounts = {},
        },
    })

    assert_true(type(state.chat) == "table", "addon should finish loading without runtime error")
    assert_equal(#OneButtonMountCharDB.groundMounts, 1, "existing pool should remain intact when count is nil")
end)

run_test("empty-return companion count on addon load does not crash", function()
    local state = setup_env({
        mounts = {
            { spellID = 7001, name = "Backup Mount", mountType = 0x01 },
        },
        num_companions_mode = "no_values",
        db = {
            groundMounts = { 7001 },
            flyingMounts = {},
        },
    })

    assert_true(type(state.chat) == "table", "addon should finish loading without runtime error")
    assert_equal(#OneButtonMountCharDB.groundMounts, 1, "existing pool should remain intact when count has no return values")
end)

run_test("strict tonumber mode does not crash on nil companion and bag slot values", function()
    local state = setup_env({
        strict_tonumber = true,
        num_companions_mode = "no_values",
        num_slots_mode = "no_values",
        db = {
            groundMounts = {},
            flyingMounts = {},
        },
    })

    assert_true(type(state.chat) == "table", "addon should finish loading under strict tonumber behavior")
end)

run_test("legacy global mount pools migrate into the per-character profile", function()
    setup_env({
        mounts = {
            { spellID = 8101, name = "Legacy Ground", mountType = 0x01 },
            { spellID = 8102, name = "Legacy Flying", mountType = 0x02 },
        },
        db = {
            groundMounts = { 8101 },
            flyingMounts = { 8102 },
            keybind = "CTRL-F",
            minimapButton = {
                show = false,
                position = 135,
            },
            configPosition = {
                point = "TOP",
                relativePoint = "TOP",
                xOfs = 12,
                yOfs = -34,
            },
            showTextualFeedback = false,
        },
    })

    assert_equal(#OneButtonMountCharDB.groundMounts, 1, "legacy ground pool should migrate to character storage")
    assert_equal(OneButtonMountCharDB.groundMounts[1], 8101, "legacy ground mount should be copied into character storage")
    assert_equal(#OneButtonMountCharDB.flyingMounts, 1, "legacy flying pool should migrate to character storage")
    assert_equal(OneButtonMountCharDB.flyingMounts[1], 8102, "legacy flying mount should be copied into character storage")
    assert_equal(OneButtonMountCharDB.keybind, "CTRL-F", "legacy keybind should migrate to character storage")
    assert_equal(OneButtonMountCharDB.minimapButton.show, false, "legacy minimap visibility should migrate to character storage")
    assert_equal(OneButtonMountCharDB.minimapButton.position, 135, "legacy minimap position should migrate to character storage")
    assert_equal(OneButtonMountCharDB.configPosition.xOfs, 12, "legacy config position should migrate to character storage")
    assert_equal(OneButtonMountCharDB.showTextualFeedback, false, "legacy textual feedback setting should migrate to character storage")
    assert_equal(OneButtonMountCharDB.profileVersion, 2, "character profile version should be updated after migration")
end)

run_test("current character profile does not get overwritten by legacy account settings", function()
    setup_env({
        db = {
            groundMounts = { 8201 },
            flyingMounts = { 8202 },
            keybind = "CTRL-G",
            minimapButton = {
                show = true,
                position = 180,
            },
            configPosition = {
                point = "BOTTOM",
                relativePoint = "BOTTOM",
                xOfs = 50,
                yOfs = 25,
            },
            showTextualFeedback = true,
        },
        char_db = {
            groundMounts = {},
            flyingMounts = {},
            keybind = "ALT-F",
            minimapButton = {
                show = false,
                position = 45,
            },
            configPosition = {
                point = "LEFT",
                relativePoint = "LEFT",
                xOfs = -15,
                yOfs = 5,
            },
            showTextualFeedback = false,
            profileVersion = 2,
        },
    })

    assert_equal(#OneButtonMountCharDB.groundMounts, 0, "empty character ground pool should stay empty after migration")
    assert_equal(#OneButtonMountCharDB.flyingMounts, 0, "empty character flying pool should stay empty after migration")
    assert_equal(OneButtonMountCharDB.keybind, "ALT-F", "character keybind should win over legacy account data")
    assert_equal(OneButtonMountCharDB.minimapButton.show, false, "character minimap visibility should win over legacy account data")
    assert_equal(OneButtonMountCharDB.minimapButton.position, 45, "character minimap position should win over legacy account data")
    assert_equal(OneButtonMountCharDB.configPosition.xOfs, -15, "character config position should win over legacy account data")
    assert_equal(OneButtonMountCharDB.showTextualFeedback, false, "character textual feedback should win over legacy account data")
end)

run_test("config updates character rotations without overwriting account settings", function()
    setup_env({
        mounts = {
            { spellID = 8301, name = "Fresh Mount", mountType = 0x01 },
        },
        db = {
            groundMounts = { 9999 },
            showTextualFeedback = false,
        },
        char_db = {
            groundMounts = {},
            flyingMounts = {},
        },
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")

    local available_button
    for _, button in ipairs(config_frame.mountButtons) do
        if button.mountData and button.mountData.spellID == 8301 and not button.pool then
            available_button = button
            break
        end
    end
    assert_true(available_button ~= nil, "available mount button not found")

    available_button.scripts["OnClick"](available_button, "LeftButton")

    assert_equal(#OneButtonMountCharDB.groundMounts, 1, "new mount should be stored in the character profile")
    assert_equal(OneButtonMountCharDB.groundMounts[1], 8301, "character profile should receive the selected mount")
    assert_equal(OneButtonMountDB.groundMounts[1], 9999, "legacy account-wide pool should not be overwritten by character edits")
    assert_equal(OneButtonMountDB.showTextualFeedback, false, "shared account setting should remain untouched")
end)

run_test("minimap visibility is stored per character", function()
    setup_env({
        char_db = {
            minimapButton = {
                show = true,
                position = 220,
            },
            profileVersion = 2,
        },
    })

    SlashCmdList["ONEBUTTONMOUNT"]("minimap")

    assert_equal(OneButtonMountCharDB.minimapButton.show, false, "minimap visibility should be stored per character")
    assert_equal(OneButtonMountDB.minimapButton, nil, "legacy account-wide minimap state should remain unused")
end)

run_test("config window position is stored per character", function()
    setup_env({
        mounts = {
            { spellID = 8401, name = "Position Test Mount", mountType = 0x01 },
        },
        char_db = {
            profileVersion = 2,
        },
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")

    config_frame.scripts["OnDragStop"](config_frame)

    assert_true(type(OneButtonMountCharDB.configPosition) == "table", "config position should be stored per character")
    assert_equal(OneButtonMountCharDB.configPosition.point, "CENTER", "config position point should be saved")
    assert_equal(OneButtonMountDB.configPosition, nil, "legacy account-wide config position should remain unused")
end)

print(string.format("Ran %d tests, %d failures", total, failures))
if failures > 0 then
    os.exit(1)
end
