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
        deprecation_fallbacks = opts.deprecation_fallbacks ~= false,
        locale = opts.locale or "enUS",
        run_macro_text_available = opts.run_macro_text_available or false,
        player_class = opts.player_class or nil,
        shapeshift_forms = opts.shapeshift_forms or {},
        player_moving = opts.player_moving or false,
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
        function font_string:SetPoint(...) self.point = { ... } end
        function font_string:ClearAllPoints() self.point = nil end
        function font_string:GetPoint()
            if self.point then
                return table.unpack(self.point)
            end
            return "CENTER", _G.UIParent, "CENTER", 0, 0
        end
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
        function frame:EnableMouseWheel(value) self.mouse_wheel_enabled = value end
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
        SetText = function(_, text)
            state.tooltip_lines = { text }
        end,
        AddLine = function(_, text)
            state.tooltip_lines = state.tooltip_lines or {}
            state.tooltip_lines[#state.tooltip_lines + 1] = text
        end,
        Show = function() end,
        Hide = function() end,
    }

    _G.UIDropDownMenu_CreateInfo = function()
        return {}
    end
    _G.UIDropDownMenu_SetWidth = function(frame, width)
        frame.dropdown_width = width
    end
    _G.UIDropDownMenu_SetText = function(frame, text)
        frame.text = text
    end
    _G.UIDropDownMenu_SetSelectedValue = function(frame, value)
        frame.selected_value = value
    end
    _G.UIDropDownMenu_AddButton = function(info)
        local dropdown = state.active_dropdown
        if dropdown then
            dropdown.menu_buttons = dropdown.menu_buttons or {}
            table.insert(dropdown.menu_buttons, copy_table(info))
        end
    end
    _G.UIDropDownMenu_Initialize = function(frame, init_function)
        frame.initialize = init_function
        frame.menu_buttons = {}
        state.active_dropdown = frame
        if init_function then
            init_function(frame, 1)
        end
        state.active_dropdown = nil
    end
    _G.CloseDropDownMenus = function() end

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
        SpellBookSpellBank = {
            Player = 0,
            Pet = 1,
        },
    }
    _G.OneButtonMountDB = copy_table(opts.db or {})
    _G.OneButtonMountCharDB = copy_table(opts.char_db)

    _G.InCombatLockdown = function() return state.in_combat end
    _G.IsMounted = function() return state.mounted end
    _G.IsPlayerMoving = function() return state.player_moving end
    _G.Dismount = function() state.dismounted = true end
    _G.IsIndoors = function() return state.indoors end
    _G.IsInInstance = function()
        local instance_type = "none"
        if state.instance_info and state.instance_info.instanceType then
            instance_type = state.instance_info.instanceType
        end
        return state.in_instance, instance_type
    end
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
    if state.run_macro_text_available then
        _G.RunMacroText = function(macro_text)
            state.last_run_macro_text = macro_text
        end
    else
        _G.RunMacroText = nil
    end
    _G.GetSpellInfo = function(spell_id)
        local spell_info = state.spell_infos[spell_id]
        if spell_info then
            return spell_info.name, spell_info.rank, spell_info.icon, spell_info.castTime
        end
        for _, mount in ipairs(state.mounts) do
            if mount.spellID == spell_id then
                return mount.name, nil, mount.icon or "icon", mount.castTime
            end
        end
        for _, mount in ipairs(state.mount_journal_mounts) do
            if mount.spellID == spell_id then
                return mount.name, nil, mount.icon or "icon", mount.castTime
            end
        end
        for item_id, spell in pairs(state.item_spells) do
            if spell.spellID == spell_id then
                local item_info = state.item_infos[item_id]
                return spell.name, nil, item_info and item_info.icon or "icon", spell.castTime
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
    _G.GetLocale = function()
        return state.locale
    end
    _G.UnitClass = function(unit)
        if unit == "player" and state.player_class then
            return state.player_class.local_name or state.player_class[1], state.player_class.file or state.player_class[2]
        end
        return nil, nil
    end
    _G.GetNumShapeshiftForms = function()
        return #state.shapeshift_forms
    end
    _G.GetShapeshiftFormInfo = function(index)
        local form = state.shapeshift_forms[index]
        if not form then return nil end
        return form.texture, form.isActive or false, form.isCastable ~= false, form.spellID
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
        local book_spell_id = entry.spellID
        if entry.omitSpellID then
            book_spell_id = nil
        elseif entry.bookSpellID ~= nil then
            book_spell_id = entry.bookSpellID
        end
        return entry.spellType or "SPELL", book_spell_id
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

    -- The TBC Anniversary client exposes these under C_Item and C_SpellBook, and
    -- only defines the bare globals while its loadDeprecationFallbacks CVar is
    -- on. deprecation_fallbacks = false simulates that CVar being off, so the
    -- namespaced path is the only way through.
    if state.deprecation_fallbacks then
        _G.C_Item = nil
        _G.C_SpellBook = nil
    else
        local spell_bank_player = _G.Enum.SpellBookSpellBank.Player
        _G.C_Item = {
            GetItemSpell = _G.GetItemSpell,
            GetItemInfo = _G.GetItemInfo,
            GetItemInfoInstant = _G.GetItemInfoInstant,
            GetItemSubClassInfo = _G.GetItemSubClassInfo,
            UseItemByName = _G.UseItemByName,
        }
        _G.C_SpellBook = {
            -- Blizzard's shim maps the old IsSpellKnown onto IsSpellInSpellBook.
            IsSpellInSpellBook = function(spell_id, spell_bank)
                if spell_bank ~= spell_bank_player then
                    return false
                end
                return state.known_spells[spell_id] or false
            end,
            -- ...and the old IsPlayerSpell onto the new IsSpellKnown.
            IsSpellKnown = function(spell_id, spell_bank)
                if spell_bank ~= spell_bank_player then
                    return false
                end
                return state.player_spells[spell_id] or false
            end,
        }
        _G.GetItemSpell = nil
        _G.GetItemInfo = nil
        _G.GetItemInfoInstant = nil
        _G.GetItemSubClassInfo = nil
        _G.UseItemByName = nil
        _G.IsSpellKnown = nil
        _G.IsPlayerSpell = nil
    end

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

local function resolve_spell_id_by_name(state, spell_name)
    if not spell_name then
        return nil
    end

    for spell_id, spell_info in pairs(state.spell_infos or {}) do
        if spell_info.name == spell_name then
            return spell_id
        end
    end

    for _, mount in ipairs(state.mounts or {}) do
        if mount.name == spell_name then
            return mount.spellID
        end
    end

    for _, mount in ipairs(state.mount_journal_mounts or {}) do
        if mount.name == spell_name then
            return mount.spellID
        end
    end

    for _, spell in pairs(state.item_spells or {}) do
        if spell.name == spell_name then
            return spell.spellID
        end
    end

    return nil
end

local function trigger_secure_mount(state, button)
    local binding_button = _G.OneButtonMountBindingButton
    assert_true(binding_button ~= nil, "binding button not created")
    assert_true(type(binding_button.scripts["PreClick"]) == "function", "binding button PreClick missing")

    state.last_binding_macrotext = nil
    state.last_cast_spell_id = nil
    state.last_cast_spell_name = nil
    state.last_used_item_id = nil
    state.macro_cast_lines = {}

    binding_button.scripts["PreClick"](binding_button, button or "LeftButton")

    local macro_text = binding_button:GetAttribute("macrotext")
    state.last_binding_macrotext = macro_text

    if not macro_text or macro_text == "" then
        return macro_text
    end

    -- Parse each line of potentially multi-line macrotext
    for line in (macro_text .. "\n"):gmatch("([^\n]*)\n") do
        if line == "/dismount" then
            state.dismounted = true
        else
            local item_id = string.match(line, "^/use item:(%d+)$")
            if item_id then
                state.last_used_item_id = tonumber(item_id)
            else
                local spell_name = string.match(line, "^/cast !?(.+)$")
                if spell_name then
                    state.macro_cast_lines[#state.macro_cast_lines + 1] = spell_name
                    state.last_cast_spell_name = spell_name
                    state.last_cast_spell_id = resolve_spell_id_by_name(state, spell_name)
                end
            end
        end
    end

    return macro_text
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

    trigger_secure_mount(state)

    assert_equal(#OneButtonMountCharDB.groundMounts, 1, "ground pool should be sanitized")
    assert_equal(OneButtonMountCharDB.groundMounts[1], 1001, "valid ground mount should remain")
    assert_equal(#OneButtonMountCharDB.flyingMounts, 0, "invalid flying mount should be removed")
    assert_equal(state.last_cast_spell_id, 1001, "valid mount should be selected by the secure button")
end)

run_test("loading screen does not wipe saved pools when the mount scan briefly omits them", function()
    local state = setup_env({
        mounts = {
            { spellID = 1001, name = "Brown Horse", mountType = 0x01 },
            { spellID = 2001, name = "Gryphon", mountType = 0x02 },
            { spellID = 3001, name = "Camel", mountType = 0x01 },
        },
        db = {
            groundMounts = { 1001 },
            flyingMounts = { 2001 },
        },
        c_map_enabled = false,
    })

    local event_frame
    for _, frame in ipairs(state.frames) do
        if frame.events["PLAYER_ENTERING_WORLD"] and frame.scripts["OnEvent"] then
            event_frame = frame
            break
        end
    end
    assert_true(event_frame ~= nil, "event frame should be registered for PLAYER_ENTERING_WORLD")

    -- Simulate a loading screen where the mount collection API has not finished
    -- repopulating yet: the companion list briefly reports an unrelated mount
    -- but omits the two the player already has saved.
    state.mounts = {
        { spellID = 3001, name = "Camel", mountType = 0x01 },
    }
    event_frame.scripts["OnEvent"](event_frame, "PLAYER_ENTERING_WORLD")

    assert_equal(#OneButtonMountCharDB.groundMounts, 1, "ground pool should survive a transient partial mount scan")
    assert_equal(OneButtonMountCharDB.groundMounts[1], 1001, "saved ground mount should not be pruned by a loading screen")
    assert_equal(#OneButtonMountCharDB.flyingMounts, 1, "flying pool should survive a transient partial mount scan")
    assert_equal(OneButtonMountCharDB.flyingMounts[1], 2001, "saved flying mount should not be pruned by a loading screen")
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 3001, "flying pool should be selected in Outland")
end)

run_test("flying rotation defaults to enabled", function()
    setup_env({
        mounts = {
            { spellID = 2011, name = "Ground Mount", mountType = 0x01 },
        },
        char_db = {
            groundMounts = { 2011 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    assert_equal(OneButtonMountCharDB.useFlyingMounts, true, "flying rotation should default to enabled")
end)

run_test("flying rotation switched off keeps ground mounts in outland", function()
    local state = setup_env({
        mounts = {
            { spellID = 2012, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3012, name = "Flying Mount", mountType = 0x02 },
        },
        char_db = {
            groundMounts = { 2012 },
            flyingMounts = { 3012 },
            useFlyingMounts = false,
        },
        known_spells = {
            [34090] = true,
        },
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 2012, "flying rotation off should force the ground pool in Outland")
end)

run_test("flying rotation switched on still flies in outland", function()
    local state = setup_env({
        mounts = {
            { spellID = 2013, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3013, name = "Flying Mount", mountType = 0x02 },
        },
        char_db = {
            groundMounts = { 2013 },
            flyingMounts = { 3013 },
            useFlyingMounts = true,
        },
        known_spells = {
            [34090] = true,
        },
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 3013, "flying rotation on should still pick the flying pool")
end)

run_test("flying rotation switched off with an empty ground pool explains why", function()
    local state = setup_env({
        mounts = {
            { spellID = 3014, name = "Flying Mount", mountType = 0x02 },
        },
        char_db = {
            groundMounts = {},
            flyingMounts = { 3014 },
            useFlyingMounts = false,
        },
        known_spells = {
            [34090] = true,
        },
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, nil, "no mount should be summoned")
    local found_message = false
    for _, line in ipairs(state.chat) do
        if string.find(line, "Flying Mount Rotation is off", 1, true) then
            found_message = true
            break
        end
    end
    assert_true(found_message, "expected the message to name the flying rotation toggle as the cause")
end)

run_test("flying rotation switched off with only flying mounts in the ground pool explains why", function()
    local state = setup_env({
        mounts = {
            { spellID = 2017, name = "Flying Mount In Ground Pool", mountType = 0x02 },
            { spellID = 3017, name = "Flying Mount", mountType = 0x02 },
        },
        char_db = {
            groundMounts = { 2017 },
            flyingMounts = { 3017 },
            useFlyingMounts = false,
        },
        known_spells = {
            [34090] = true,
        },
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, nil, "no mount should be summoned")
    local blamed_crystals = false
    local found_message = false
    for _, line in ipairs(state.chat) do
        if string.find(line, "Qiraji crystals are AQ40-only", 1, true) then
            blamed_crystals = true
        end
        if string.find(line, "Flying Mount Rotation is off", 1, true) then
            found_message = true
        end
    end
    assert_true(not blamed_crystals, "an unrelated Qiraji crystal message should not be blamed")
    assert_true(found_message, "expected the message to name the flying rotation toggle as the cause")
end)

run_test("flying rotation checkbox toggles the saved setting", function()
    local state = setup_env({
        mounts = {
            { spellID = 2015, name = "Ground Mount", mountType = 0x01 },
            { spellID = 3015, name = "Flying Mount", mountType = 0x02 },
        },
        char_db = {
            groundMounts = { 2015 },
            flyingMounts = { 3015 },
        },
        known_spells = {
            [34090] = true,
        },
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")
    assert_true(config_frame.flyingToggle ~= nil, "flying rotation checkbox missing")
    assert_equal(config_frame.flyingToggle:GetChecked(), true, "flying rotation checkbox should default checked")

    config_frame.flyingToggle:SetChecked(false)
    config_frame.flyingToggle.scripts["OnClick"](config_frame.flyingToggle)

    assert_equal(OneButtonMountCharDB.useFlyingMounts, false, "unchecking should save the setting")

    trigger_secure_mount(state)
    assert_equal(state.last_cast_spell_id, 2015, "unchecking should take effect on the next summon")

    config_frame.flyingToggle:SetChecked(true)
    config_frame.flyingToggle.scripts["OnClick"](config_frame.flyingToggle)

    assert_equal(OneButtonMountCharDB.useFlyingMounts, true, "rechecking should save the setting")

    trigger_secure_mount(state)
    assert_equal(state.last_cast_spell_id, 3015, "rechecking should restore flying selection")
end)

run_test("flying rotation header keeps its gutter aligned with the ground header", function()
    setup_env({
        mounts = {
            { spellID = 2016, name = "Ground Mount", mountType = 0x01 },
        },
        char_db = {
            groundMounts = { 2016 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")

    local _, _, _, ground_x = config_frame.groundLabel:GetPoint()
    local _, _, _, flying_x = config_frame.flyingLabel:GetPoint()
    assert_equal(flying_x, ground_x, "both rotation headers should share the same indent")
    assert_true(ground_x > 15, "rotation headers should be indented to leave a checkbox gutter")

    -- The icon box is pulled back by the gutter so it keeps its full width.
    local _, anchor, _, container_offset = config_frame.groundContainer:GetPoint()
    assert_equal(anchor, config_frame.groundLabel, "icon box should anchor to its header")
    assert_equal(ground_x + container_offset, 15, "icon box should still start at the content edge")
end)

local function setup_pool_layout(count, options)
    options = options or {}
    local mounts, ground, flying = {}, {}, {}
    for i = 1, count do
        local spell_id = 7000 + i
        mounts[i] = {
            spellID = spell_id,
            name = string.format("Mount %02d", i),
            mountType = options.flying and 0x02 or 0x01,
        }
        if options.flying then
            flying[#flying + 1] = spell_id
        else
            ground[#ground + 1] = spell_id
        end
    end

    setup_env({
        mounts = mounts,
        char_db = {
            groundMounts = ground,
            flyingMounts = flying,
            useFlyingMounts = options.useFlyingMounts,
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")
    return config_frame
end

local function count_overlapping_icons(container)
    local seen, overlaps = {}, 0
    for _, btn in ipairs(container.mountButtons or {}) do
        local key = tostring(btn.point[4]) .. "," .. tostring(btn.point[5])
        if seen[key] then
            overlaps = overlaps + 1
        end
        seen[key] = true
    end
    return overlaps
end

run_test("rotation icons wrap onto a second row instead of stacking", function()
    local config_frame = setup_pool_layout(11)
    local gc = config_frame.groundContainer

    assert_equal(#gc.mountButtons, 11, "every ground icon should be created")
    assert_equal(count_overlapping_icons(gc), 0, "no two icons should share a position")

    assert_equal(gc.mountButtons[1].point[4], 4, "first icon should start at the box origin")
    assert_equal(gc.mountButtons[1].point[5], -4, "first icon should sit on the first row")
    assert_equal(gc.mountButtons[10].point[4], 364, "tenth icon should finish the first row")
    assert_equal(gc.mountButtons[10].point[5], -4, "tenth icon should still be on the first row")
    assert_equal(gc.mountButtons[11].point[4], 4, "eleventh icon should start a new row")
    assert_equal(gc.mountButtons[11].point[5], -44, "eleventh icon should drop one row height")
end)

run_test("a rotation row that is exactly full does not reserve an empty row", function()
    local config_frame = setup_pool_layout(10)

    assert_equal(count_overlapping_icons(config_frame.groundContainer), 0, "ten icons should fit one row")
    assert_equal(config_frame.groundContainer:GetHeight(), 48, "ten icons should size the box to a single row")
end)

run_test("large rotations stay free of overlapping icons", function()
    local config_frame = setup_pool_layout(30)
    local gc = config_frame.groundContainer

    assert_equal(#gc.mountButtons, 30, "every ground icon should be created")
    assert_equal(count_overlapping_icons(gc), 0, "no two icons should share a position")
    assert_equal(gc:GetHeight(), 128, "thirty icons should size the box to three rows")
end)

run_test("flying rotation icons wrap and keep their dimmed state", function()
    local config_frame = setup_pool_layout(11, { flying = true, useFlyingMounts = false })
    local fc = config_frame.flyingContainer

    assert_equal(#fc.mountButtons, 11, "every flying icon should be created")
    assert_equal(count_overlapping_icons(fc), 0, "no two icons should share a position")
    assert_equal(fc.mountButtons[11].point[5], -44, "eleventh icon should drop one row height")

    for _, btn in ipairs(fc.mountButtons) do
        assert_equal(btn.iconTexture.desaturated, true, "flying icons should stay dimmed while the section is off")
    end
end)

run_test("rotation icons are not dimmed while the section is enabled", function()
    local config_frame = setup_pool_layout(11, { flying = true, useFlyingMounts = true })

    for _, btn in ipairs(config_frame.flyingContainer.mountButtons) do
        assert_equal(btn.iconTexture.desaturated, false, "flying icons should not be dimmed while the section is on")
    end
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 3002, "area-id fallback should still select the flying pool when zone text is unavailable")
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 2011, "ground pool should be selected until the character can actually use flying mounts")
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 2021, "ground pool should be selected outside Outland even when IsFlyableArea returns true")
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 2031, "ground pool should be selected when zone text says Stormwind even if area ID is stale")
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 3041, "localized zone text should still match Outland map names and select the flying pool")
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 2051, "localized live zone text should override a stale Outland C_Map result")
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

    trigger_secure_mount(state)

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

    trigger_secure_mount(state)

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

    trigger_secure_mount(state)

    assert_equal(state.last_binding_macrotext, "", "outside AQ40 should not prepare a summon macro for qiraji crystals")
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

run_test("black qiraji crystal is detected and usable outside aq40", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        in_instance = false,
        bag_items = { 21176 },
        item_spells = {
            [21176] = { name = "Summon Black Qiraji Battle Tank", spellID = 9331 },
        },
        item_infos = {
            -- No item class data: TBC-era clients do not tag crystals as mounts.
            [21176] = { name = "Black Qiraji Resonating Crystal", icon = "icon" },
        },
        db = {
            groundMounts = { 9331 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    trigger_secure_mount(state)

    assert_equal(state.last_used_item_id, 21176, "black qiraji crystal should be detected and usable outside AQ40")
end)

run_test("black qiraji crystal is eligible inside aq40", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        indoors = true,
        in_instance = true,
        instance_info = {
            name = "Temple of Ahn'Qiraj",
            instanceType = "raid",
            instanceID = 531,
        },
        bag_items = { 21176, 37012 },
        item_spells = {
            [21176] = { name = "Summon Black Qiraji Battle Tank", spellID = 9341 },
            [37012] = { name = "Summon Ground Mount", spellID = 9342 },
        },
        item_infos = {
            [21176] = { name = "Black Qiraji Resonating Crystal", icon = "icon" },
            [37012] = { name = "Ground Mount Item", icon = "icon", classID = 15, subClassID = 5, itemType = "Miscellaneous", itemSubType = "Mount" },
        },
        db = {
            groundMounts = { 9341, 9342 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    trigger_secure_mount(state)

    assert_equal(state.last_used_item_id, 21176, "inside AQ40 the black crystal should be the only eligible mount")
end)

run_test("black qiraji crystal can be added to the flying rotation like any other mount", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        bag_items = { 21176 },
        item_spells = {
            [21176] = { name = "Summon Black Qiraji Battle Tank", spellID = 9351 },
        },
        item_infos = {
            [21176] = { name = "Black Qiraji Resonating Crystal", icon = "icon" },
        },
        db = {
            groundMounts = {},
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")

    local crystal_button
    for _, button in ipairs(config_frame.mountButtons or {}) do
        if button.mountData and button.mountData.spellID == 9351 and not button.pool then
            crystal_button = button
            break
        end
    end
    assert_true(crystal_button ~= nil, "black qiraji crystal button not found in available list")

    crystal_button.scripts["OnClick"](crystal_button, "RightButton")

    -- The client reports no mount type for anything else, so classifying the
    -- black crystal would make it the only mount that cannot go here.
    assert_equal(#OneButtonMountCharDB.flyingMounts, 1, "black crystal should be allowed into the flying pool")
    assert_equal(OneButtonMountCharDB.flyingMounts[1], 9351, "expected the black crystal spellID in the flying pool")

    for _, line in ipairs(state.chat) do
        assert_true(not string.find(line, "ground-only mount", 1, true),
            "the black crystal should not be refused")
    end
end)

run_test("aq40-only crystals stay out of the flying rotation", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        bag_items = { 21218 },
        item_spells = {
            [21218] = { name = "Summon Blue Qiraji Battle Tank", spellID = 9381 },
        },
        item_infos = {
            [21218] = { name = "Blue Qiraji Resonating Crystal", icon = "icon" },
        },
        db = {
            groundMounts = {},
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")

    local crystal_button
    for _, button in ipairs(config_frame.mountButtons or {}) do
        if button.mountData and button.mountData.spellID == 9381 and not button.pool then
            crystal_button = button
            break
        end
    end
    assert_true(crystal_button ~= nil, "blue qiraji crystal button not found in available list")

    crystal_button.scripts["OnClick"](crystal_button, "RightButton")

    -- AQ40 is indoors, so a colored crystal can never be used for flying anyway.
    assert_equal(#OneButtonMountCharDB.flyingMounts, 0, "AQ40-only crystal should not enter flying pool")

    local found_message = false
    for _, line in ipairs(state.chat) do
        if string.find(line, "ground-only mount, so it can only be added to the ground rotation", 1, true) then
            found_message = true
            break
        end
    end
    assert_true(found_message, "expected flying rotation rejection message")
end)

run_test("bag mounts are detected and summoned through C_Item when deprecation fallbacks are off", function()
    local state = setup_env({
        deprecation_fallbacks = false,
        num_companions_mode = "no_values",
        in_instance = false,
        bag_items = { 21176 },
        item_spells = {
            [21176] = { name = "Summon Black Qiraji Battle Tank", spellID = 9361 },
        },
        item_infos = {
            [21176] = { name = "Black Qiraji Resonating Crystal", icon = "icon" },
        },
        db = {
            groundMounts = { 9361 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    assert_equal(_G.GetItemSpell, nil, "test setup should remove the deprecated GetItemSpell global")
    assert_equal(_G.UseItemByName, nil, "test setup should remove the deprecated UseItemByName global")

    trigger_secure_mount(state)
    assert_equal(state.last_used_item_id, 21176, "bag scan should resolve items through C_Item")

    -- Minimap right-click takes the non-secure summon path, which is the only
    -- caller of UseItemByName.
    local minimap_button = _G.OneButtonMountMinimapButton
    assert_true(minimap_button ~= nil, "minimap button not created")
    state.last_used_item_id = nil
    minimap_button.scripts["OnClick"](minimap_button, "RightButton")
    assert_equal(state.last_used_item_id, 21176, "summon should use C_Item.UseItemByName")
end)

run_test("class mount spells resolve through C_SpellBook when deprecation fallbacks are off", function()
    local state = setup_env({
        deprecation_fallbacks = false,
        mounts = {},
        known_spells = {
            [13819] = true, -- Summon Warhorse
        },
        spell_infos = {
            [13819] = { name = "Summon Warhorse", icon = "warhorse" },
        },
        db = {
            groundMounts = { 13819 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    assert_equal(_G.IsSpellKnown, nil, "test setup should remove the deprecated IsSpellKnown global")
    assert_equal(_G.IsPlayerSpell, nil, "test setup should remove the deprecated IsPlayerSpell global")

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 13819, "class mount should resolve through C_SpellBook.IsSpellInSpellBook")
end)

run_test("player spell knowledge resolves through C_SpellBook.IsSpellKnown when deprecation fallbacks are off", function()
    local state = setup_env({
        deprecation_fallbacks = false,
        is_spell_known_available = false,
        mounts = {},
        known_spells = {},
        player_spells = {
            [23214] = true, -- Summon Charger
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 23214, "class mount should resolve through C_SpellBook.IsSpellKnown")
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

    trigger_secure_mount(state)
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

run_test("debug command prints live state even when textual feedback is disabled", function()
    local state = setup_env({
        mounts = {
            { spellID = 4401, name = "Ground Mount", mountType = 0x01 },
            { spellID = 4402, name = "Flying Mount", mountType = 0x02 },
        },
        char_db = {
            groundMounts = { 4401 },
            flyingMounts = { 4402 },
            showTextualFeedback = false,
        },
        known_spells = {
            [34090] = true,
        },
        map_id = 111,
        map_infos = {
            [111] = { name = "Shattrath City", parentMapID = 101 },
            [101] = { name = "Outland" },
        },
        current_map_area_id = 111,
        real_zone_text = "Shattrath City",
        zone_text = "Terrace of Light",
        is_flyable_area = true,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("debug")

    local last_line = state.chat[#state.chat]
    assert_true(type(last_line) == "string", "debug command should print a chat line")
    assert_true(string.find(last_line, "rz|r=", 1, true) ~= nil, "debug output should include real zone text")
    assert_true(string.find(last_line, "map|r=", 1, true) ~= nil, "debug output should include map data")
    assert_true(string.find(last_line, "pools|r=", 1, true) ~= nil, "debug output should include pool counts")
    assert_true(string.find(last_line, "pick|r=", 1, true) ~= nil, "debug output should include selected pool summary")
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

run_test("shift plus mouse wheel up keybind is captured as SHIFT-MOUSEWHEELUP", function()
    local state = setup_env({
        mounts = {
            { spellID = 4104, name = "Test Mount", mountType = 0x01 },
        },
        db = {},
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local key_capture_frame
    for _, frame in ipairs(state.frames) do
        if frame.scripts["OnMouseWheel"] and frame.scripts["OnKeyDown"] then
            key_capture_frame = frame
            break
        end
    end
    assert_true(key_capture_frame ~= nil, "key capture frame with mouse wheel handler not found")
    assert_equal(key_capture_frame.mouse_wheel_enabled, true, "key capture frame should enable mouse wheel input")

    state.shift_down = true
    key_capture_frame.scripts["OnMouseWheel"](key_capture_frame, 1)

    local last_binding = state.binding_clicks[#state.binding_clicks]
    assert_true(last_binding ~= nil, "no binding call recorded")
    assert_equal(last_binding.key, "SHIFT-MOUSEWHEELUP", "shift+wheel up should be stored as SHIFT-MOUSEWHEELUP")
end)

run_test("shift plus mouse wheel down keybind is captured as SHIFT-MOUSEWHEELDOWN", function()
    local state = setup_env({
        mounts = {
            { spellID = 4105, name = "Test Mount", mountType = 0x01 },
        },
        db = {},
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local key_capture_frame
    for _, frame in ipairs(state.frames) do
        if frame.scripts["OnMouseWheel"] and frame.scripts["OnKeyDown"] then
            key_capture_frame = frame
            break
        end
    end
    assert_true(key_capture_frame ~= nil, "key capture frame with mouse wheel handler not found")

    state.shift_down = true
    key_capture_frame.scripts["OnMouseWheel"](key_capture_frame, -1)

    local last_binding = state.binding_clicks[#state.binding_clicks]
    assert_true(last_binding ~= nil, "no binding call recorded")
    assert_equal(last_binding.key, "SHIFT-MOUSEWHEELDOWN", "shift+wheel down should be stored as SHIFT-MOUSEWHEELDOWN")
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

    trigger_secure_mount(state)
    assert_equal(state.last_cast_spell_id, 8101, "journal mount should still be selected through the secure button")
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

    trigger_secure_mount(state)
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

    trigger_secure_mount(state)
    assert_equal(state.last_cast_spell_id, 9201, "companion probe fallback should still select the probed mount")
end)

run_test("class mount spells populate available mounts and summon by spell", function()
    local state = setup_env({
        known_spells = {
            [13819] = true,
            [23214] = true,
            [34769] = true,
            [34767] = true,
            [5784] = true,
            [23161] = true,
        },
        spell_infos = {
            [13819] = { name = "Summon Warhorse", icon = "warhorse" },
            [23214] = { name = "Summon Charger", icon = "charger" },
            [34769] = { name = "Summon Thalassian Warhorse", icon = "thalassianwarhorse" },
            [34767] = { name = "Summon Thalassian Charger", icon = "thalassiancharger" },
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
    assert_true(found_spells[34769], "thalassian warhorse should appear in the available mount list")
    assert_true(found_spells[34767], "thalassian charger should appear in the available mount list")
    assert_true(found_spells[5784], "felsteed should appear in the available mount list")
    assert_true(found_spells[23161], "dreadsteed should appear in the available mount list")

    trigger_secure_mount(state)
    assert_equal(state.last_cast_spell_id, 13819, "class mount should summon through spell casting")
end)

run_test("blood elf paladin class mounts resolve to learned spell IDs and remap saved pools", function()
    local state = setup_env({
        is_spell_known_available = false,
        spellbook_entries = {
            { spellID = 34769, name = "Summon Warhorse" },
        },
        spell_infos = {
            [13819] = { name = "Summon Warhorse", icon = "warhorse" },
            [34769] = { name = "Summon Warhorse", icon = "thalassianwarhorse" },
        },
        char_db = {
            groundMounts = { 13819 },
            flyingMounts = {},
        },
        c_map_enabled = false,
    })

    assert_equal(_G.OneButtonMountCharDB.groundMounts[1], 34769, "saved paladin class mount should remap to the learned spell ID")
    assert_equal(#_G.OneButtonMountCharDB.groundMounts, 1, "remapped ground pool should keep a single entry")

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")

    local found_warhorse = false
    for _, button in ipairs(config_frame.mountButtons) do
        if button.mountData and button.mountData.spellID == 34769 then
            found_warhorse = true
            break
        end
    end

    assert_true(found_warhorse, "blood elf paladin mount should appear with its learned spell ID")

    local minimap_button = _G.OneButtonMountMinimapButton
    assert_true(minimap_button ~= nil, "minimap button not created")

    state.last_cast_spell_id = nil
    minimap_button.scripts["OnClick"](minimap_button, "RightButton")
    assert_equal(state.last_cast_spell_id, 34769, "direct summon path should cast the learned blood elf paladin spell ID")
end)

run_test("mount slash command is no longer supported", function()
    local state = setup_env({
        known_spells = {
            [23214] = true,
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

    if _G.OneButtonMountConfigFrame then
        _G.OneButtonMountConfigFrame:Hide()
    end

    SlashCmdList["ONEBUTTONMOUNT"]("mount")

    assert_equal(state.last_cast_spell_id, nil, "mount slash command should not attempt a protected summon")
    assert_true(_G.OneButtonMountConfigFrame == nil or not _G.OneButtonMountConfigFrame:IsShown(), "mount slash command should not fall back to opening the config")
    local last_line = state.chat[#state.chat]
    assert_true(type(last_line) == "string", "mount slash command should print an unknown-command message")
    assert_true(string.find(last_line, "Unknown command.", 1, true) ~= nil, "mount slash command should be treated as an unknown command")
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

    trigger_secure_mount(state)
    assert_equal(state.last_cast_spell_id, 23214, "spellbook fallback mount should summon through spell casting")
end)

run_test("localized spellbook names still match class mounts without spell IDs", function()
    local state = setup_env({
        locale = "deDE",
        is_spell_known_available = false,
        spellbook_entries = {
            { spellID = 23214, omitSpellID = true, name = "Beschworenes Streitross" },
        },
        spell_infos = {
            [23214] = { name = "Beschworenes Streitross", icon = "charger" },
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

    assert_true(found_charger, "localized spellbook name should still expose the class mount")

    trigger_secure_mount(state)
    assert_equal(state.last_cast_spell_id, 23214, "localized spellbook fallback should still summon through spell casting")
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 2111, "known flying mounts in the ground pool should be skipped until the character can ride them")
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 2121, "without a known riding spell in the spellbook fallback, the addon should stay on ground mounts")
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

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 3131, "riding found via spellbook fallback should allow the flying pool")
end)

run_test("moving prefers eligible instant flight form over cast-time flying mounts", function()
    local state = setup_env({
        mounts = {
            { spellID = 3141, name = "Cast-Time Flying Mount", mountType = 0x02, castTime = 1500 },
        },
        known_spells = {
            [33943] = true,
            [34090] = true,
        },
        spell_infos = {
            [33943] = { name = "Flight Form", icon = "flight" },
        },
        db = {
            groundMounts = {},
            flyingMounts = { 3141, 33943 },
        },
        player_moving = true,
        player_level = 70,
        is_flyable_area = true,
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    trigger_secure_mount(state)

    assert_equal(state.last_binding_macrotext, "/cast !Flight Form", "moving should choose the hardcoded instant flight form")
    assert_equal(state.last_cast_spell_id, 33943, "moving should cast flight form from the eligible instant pool")
end)

run_test("standing still prefers cast-time flying mounts when instant options are also eligible", function()
    local state = setup_env({
        mounts = {
            { spellID = 3151, name = "Cast-Time Flying Mount", mountType = 0x02, castTime = 1500 },
        },
        known_spells = {
            [33943] = true,
            [34090] = true,
        },
        spell_infos = {
            [33943] = { name = "Flight Form", icon = "flight" },
        },
        db = {
            groundMounts = {},
            flyingMounts = { 3151, 33943 },
        },
        player_moving = false,
        player_level = 70,
        is_flyable_area = true,
        c_map_enabled = false,
        real_zone_text = "Nagrand",
    })

    trigger_secure_mount(state)

    assert_equal(state.last_cast_spell_id, 3151, "standing still should keep normal cast-time mounts preferred")
end)

run_test("moving prefers hardcoded instant broom item from the eligible pool", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        bag_items = { 33184, 37013 },
        item_spells = {
            [33184] = { name = "Swift Magic Broom", spellID = 42668 },
            [37013] = { name = "Summon Cast-Time Ground Mount", spellID = 9162, castTime = 1500 },
        },
        item_infos = {
            [33184] = { name = "Swift Magic Broom", icon = "broom", classID = 15, subClassID = 5, itemType = "Miscellaneous", itemSubType = "Mount" },
            [37013] = { name = "Cast-Time Ground Mount Item", icon = "icon", classID = 15, subClassID = 5, itemType = "Miscellaneous", itemSubType = "Mount" },
        },
        db = {
            groundMounts = { 42668, 9162 },
            flyingMounts = {},
        },
        player_moving = true,
        c_map_enabled = false,
    })

    trigger_secure_mount(state)

    assert_equal(state.last_used_item_id, 33184, "moving should use the hardcoded instant broom item")
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
        if string.find(line, "ground-only mount, so it can only be added to the ground rotation", 1, true) then
            found_message = true
            break
        end
    end
    assert_true(found_message, "expected rejection message was not printed")
end)

local function tooltip_for_available_mount(state, spell_id)
    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")

    local button
    for _, candidate in ipairs(config_frame.mountButtons or {}) do
        if candidate.mountData and candidate.mountData.spellID == spell_id and not candidate.pool then
            button = candidate
            break
        end
    end
    assert_true(button ~= nil, "available mount button not found for spellID " .. tostring(spell_id))

    state.tooltip_lines = nil
    button.scripts["OnEnter"](button)
    return state.tooltip_lines or {}
end

local function tooltip_contains(lines, needle)
    for _, line in ipairs(lines) do
        if type(line) == "string" and string.find(line, needle, 1, true) then
            return true
        end
    end
    return false
end

run_test("ground-only mounts do not advertise the flying pool in their tooltip", function()
    local state = setup_env({
        mounts = {
            { spellID = 5101, name = "Ground Only", mountType = 0x01 },
        },
        db = {},
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")
    local lines = tooltip_for_available_mount(state, 5101)

    assert_true(tooltip_contains(lines, "Ground-only mount"), "expected the ground-only note")
    assert_true(not tooltip_contains(lines, "Right-click to add to Flying pool"),
        "tooltip should not offer a click that gets refused")
    assert_true(tooltip_contains(lines, "Left-click to add to Ground pool"), "ground pool hint should remain")
end)

run_test("mounts of unknown type still advertise the flying pool in their tooltip", function()
    local state = setup_env({
        mounts = {
            { spellID = 5102, name = "Unknown Type Mount", mountType = 0 },
        },
        db = {},
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")
    local lines = tooltip_for_available_mount(state, 5102)

    assert_true(tooltip_contains(lines, "Right-click to add to Flying pool"),
        "unclassified mounts should still offer the flying pool")
    assert_true(not tooltip_contains(lines, "Ground-only mount"), "unclassified mounts are not ground-only")
end)

run_test("the black qiraji crystal advertises both pools like any other mount", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        bag_items = { 21176 },
        item_spells = {
            [21176] = { name = "Summon Black Qiraji Battle Tank", spellID = 9371 },
        },
        item_infos = {
            [21176] = { name = "Black Qiraji Resonating Crystal", icon = "icon" },
        },
        db = {},
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")
    local lines = tooltip_for_available_mount(state, 9371)

    assert_true(tooltip_contains(lines, "Right-click to add to Flying pool"),
        "the black crystal should offer the flying pool")
    assert_true(not tooltip_contains(lines, "Ground-only mount"),
        "the black crystal should not be flagged ground-only")
end)

run_test("aq40-only crystals are flagged ground-only in their tooltip", function()
    local state = setup_env({
        num_companions_mode = "no_values",
        bag_items = { 21321 },
        item_spells = {
            [21321] = { name = "Summon Red Qiraji Battle Tank", spellID = 9391 },
        },
        item_infos = {
            [21321] = { name = "Red Qiraji Resonating Crystal", icon = "icon" },
        },
        db = {},
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")
    local lines = tooltip_for_available_mount(state, 9391)

    assert_true(tooltip_contains(lines, "Ground-only mount"), "the crystal should be flagged ground-only")
    assert_true(not tooltip_contains(lines, "Right-click to add to Flying pool"),
        "the crystal should not offer the flying pool")
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

local function setup_paladin_crusader_mount(opts)
    opts = opts or {}
    local instance_info = nil
    local in_instance = false
    if opts.instance_type then
        instance_info = { name = opts.instance_name or opts.instance_type, instanceType = opts.instance_type, maxPlayers = opts.max_players }
        in_instance = true
    end

    return setup_env({
        mounts = {
            { spellID = 5209, name = "Brown Horse", mountType = 0x01 },
        },
        known_spells = {
            [32223] = true,
        },
        spell_infos = {
            [5209] = { name = "Brown Horse", icon = "icon" },
            [32223] = { name = "Crusader Aura", icon = "crusader" },
            [465] = { name = "Devotion Aura", icon = "devotion" },
        },
        player_class = { "Paladin", "PALADIN" },
        shapeshift_forms = {
            { spellID = 465, isActive = true },
        },
        char_db = {
            groundMounts = { 5209 },
            flyingMounts = {},
            crusaderAura = true,
            crusaderAuraDisableMode = opts.disable_mode,
        },
        instance_info = instance_info,
        in_instance = in_instance,
        c_map_enabled = false,
    })
end

local function assert_macro_skips_crusader_aura(state, message)
    trigger_secure_mount(state)

    assert_true(state.last_binding_macrotext ~= nil, message .. " should set macrotext")
    assert_true(string.find(state.last_binding_macrotext, "Crusader Aura", 1, true) == nil, message .. " should not cast Crusader Aura")
    assert_equal(#state.macro_cast_lines, 1, message .. " should only cast the mount")
    assert_equal(state.macro_cast_lines[1], "Brown Horse", message .. " mount cast should remain")
end

local function assert_macro_uses_crusader_aura(state, message)
    trigger_secure_mount(state)

    assert_equal(state.last_binding_macrotext, "/cast Crusader Aura\n/cast Brown Horse", message .. " should cast Crusader Aura before the mount")
    assert_equal(state.macro_cast_lines[1], "Crusader Aura", message .. " first cast should be Crusader Aura")
    assert_equal(state.macro_cast_lines[2], "Brown Horse", message .. " second cast should be the mount")
end

run_test("crusader aura disable dropdown appears when paladin enables aura behavior", function()
    setup_env({
        mounts = {
            { spellID = 5208, name = "Brown Horse", mountType = 0x01 },
        },
        known_spells = {
            [32223] = true,
        },
        spell_infos = {
            [5208] = { name = "Brown Horse", icon = "icon" },
            [32223] = { name = "Crusader Aura", icon = "crusader" },
        },
        player_class = { "Paladin", "PALADIN" },
        char_db = {
            groundMounts = { 5208 },
            flyingMounts = {},
            crusaderAura = false,
        },
        c_map_enabled = false,
    })

    SlashCmdList["ONEBUTTONMOUNT"]("")

    local config_frame = _G.OneButtonMountConfigFrame
    assert_true(config_frame ~= nil, "config frame not created")
    assert_true(config_frame.crusaderAuraCheckbox ~= nil, "crusader aura checkbox missing")
    assert_true(config_frame.crusaderAuraDisableDropdown ~= nil, "crusader aura disable dropdown missing")
    assert_true(not config_frame.crusaderAuraDisableDropdown:IsShown(), "dropdown should hide until the aura behavior is enabled")

    config_frame.crusaderAuraCheckbox:SetChecked(true)
    config_frame.crusaderAuraCheckbox.scripts["OnClick"](config_frame.crusaderAuraCheckbox)

    local dropdown = config_frame.crusaderAuraDisableDropdown
    assert_true(dropdown:IsShown(), "dropdown should show when the aura behavior is enabled")
    assert_equal(dropdown.text, "Neither", "dropdown should default to neither")
    assert_equal(#dropdown.menu_buttons, 4, "dropdown should expose four disable choices")

    local pvp_option = nil
    local dungeon_option = nil
    local both_option = nil
    local raid_option = nil
    for _, option in ipairs(dropdown.menu_buttons) do
        if option.value == "pvp" then
            pvp_option = option
        elseif option.value == "dungeon" then
            dungeon_option = option
        elseif option.value == "both" then
            both_option = option
        elseif option.value == "raid" then
            raid_option = option
        end
    end
    assert_true(pvp_option ~= nil, "PvP dropdown option missing")
    assert_true(dungeon_option ~= nil, "Dungeons dropdown option missing")
    assert_true(both_option ~= nil, "PvP and Dungeons dropdown option missing")
    assert_true(raid_option == nil, "Raids dropdown option should be replaced")
    assert_equal(dungeon_option.text, "Dungeons", "dungeon option should use player-facing dungeon copy")
    assert_equal(both_option.text, "PvP and Dungeons", "both option should use dungeon copy")

    pvp_option.func()

    assert_equal(OneButtonMountCharDB.crusaderAuraDisableMode, "pvp", "dropdown should save the selected character option")
    assert_equal(dropdown.text, "PvP", "dropdown text should update after selection")
    assert_equal(OneButtonMountDB.crusaderAuraDisableMode, nil, "legacy account-wide settings should remain unused")
end)

run_test("crusader aura neither mode still applies in PvP", function()
    local state = setup_paladin_crusader_mount({
        instance_type = "pvp",
        disable_mode = "never",
    })

    trigger_secure_mount(state)

    assert_equal(state.last_binding_macrotext, "/cast Crusader Aura\n/cast Brown Horse", "neither mode should keep Crusader Aura enabled in PvP")
    assert_equal(state.macro_cast_lines[1], "Crusader Aura", "first cast should remain Crusader Aura")
    assert_equal(state.macro_cast_lines[2], "Brown Horse", "second cast should remain the mount")
end)

run_test("crusader aura PvP disable mode suppresses battlegrounds and arenas", function()
    local battleground_state = setup_paladin_crusader_mount({
        instance_type = "pvp",
        disable_mode = "pvp",
    })
    assert_macro_skips_crusader_aura(battleground_state, "PvP disable mode in battlegrounds")

    local arena_state = setup_paladin_crusader_mount({
        instance_type = "arena",
        disable_mode = "pvp",
    })
    assert_macro_skips_crusader_aura(arena_state, "PvP disable mode in arenas")
end)

run_test("crusader aura dungeon and both disable modes suppress dungeons", function()
    local black_morass_state = setup_paladin_crusader_mount({
        instance_type = "party",
        instance_name = "The Black Morass",
        max_players = 5,
        disable_mode = "dungeon",
    })
    assert_macro_skips_crusader_aura(black_morass_state, "dungeon disable mode in Black Morass")

    local both_state = setup_paladin_crusader_mount({
        instance_type = "party",
        disable_mode = "both",
    })
    assert_macro_skips_crusader_aura(both_state, "both disable mode")
end)

run_test("crusader aura dungeon modes do not suppress raids", function()
    local dungeon_mode_raid_state = setup_paladin_crusader_mount({
        instance_type = "raid",
        disable_mode = "dungeon",
    })
    assert_macro_uses_crusader_aura(dungeon_mode_raid_state, "dungeon disable mode in raids")

    local both_mode_raid_state = setup_paladin_crusader_mount({
        instance_type = "raid",
        disable_mode = "both",
    })
    assert_macro_uses_crusader_aura(both_mode_raid_state, "PvP and Dungeons disable mode in raids")
end)

run_test("legacy crusader aura raid disable mode migrates to dungeon mode", function()
    local state = setup_paladin_crusader_mount({
        instance_type = "party",
        instance_name = "The Black Morass",
        disable_mode = "raid",
    })

    assert_equal(OneButtonMountCharDB.crusaderAuraDisableMode, "dungeon", "legacy raid mode should normalize to dungeon mode")
    assert_macro_skips_crusader_aura(state, "legacy raid disable mode after migration")
end)

run_test("crusader aura is cast alone on first press for class spell mounts; mount fires on second press", function()
    -- Class spell mounts (Paladin Warhorse etc.) share the combat GCD with aura spells.
    -- They are added via SPELL_MOUNT_SPELLS with no companion index, so isSpellOnlyMount = true.
    local state = setup_env({
        mounts = {},  -- no companion mounts; class mount added via known_spells path
        known_spells = {
            [13819] = true,  -- Summon Warhorse
            [32223] = true,  -- Crusader Aura
        },
        spell_infos = {
            [13819] = { name = "Summon Warhorse", icon = "icon" },
            [32223] = { name = "Crusader Aura", icon = "crusader" },
        },
        player_class = { "Paladin", "PALADIN" },
        shapeshift_forms = {
            { spellID = 465, isActive = true },
        },
        char_db = {
            groundMounts = { 13819 },
            flyingMounts = {},
            crusaderAura = true,
        },
        c_map_enabled = false,
    })

    -- First press: CA not active → only switch aura, no mount
    trigger_secure_mount(state)
    assert_equal(state.last_binding_macrotext, "/cast Crusader Aura", "first press should only cast Crusader Aura")
    assert_equal(#state.macro_cast_lines, 1, "first press should have exactly one cast line")
    assert_equal(state.macro_cast_lines[1], "Crusader Aura", "first press cast should be Crusader Aura")

    -- Simulate CA becoming active
    state.shapeshift_forms = { { spellID = 32223, isActive = true } }

    -- Second press: CA active → mount fires without GCD issue
    trigger_secure_mount(state)
    assert_equal(state.last_cast_spell_id, 13819, "second press should cast the mount")
end)

run_test("companion mount with crusader aura active mounts in a single press", function()
    -- Companion mounts bypass the combat GCD, so CA + mount can fire in one macro.
    local state = setup_env({
        mounts = {
            { spellID = 5201, name = "Brown Horse", mountType = 0x01 },
        },
        known_spells = {
            [32223] = true,
        },
        spell_infos = {
            [5201] = { name = "Brown Horse", icon = "icon" },
            [32223] = { name = "Crusader Aura", icon = "crusader" },
        },
        player_class = { "Paladin", "PALADIN" },
        shapeshift_forms = {
            { spellID = 465, isActive = true },
        },
        char_db = {
            groundMounts = { 5201 },
            flyingMounts = {},
            crusaderAura = true,
        },
        c_map_enabled = false,
    })

    -- Single press: companion mount → CA + mount in one macro line
    trigger_secure_mount(state)
    assert_true(string.find(state.last_binding_macrotext, "Crusader Aura", 1, true) ~= nil,
        "macrotext should include Crusader Aura")
    assert_true(string.find(state.last_binding_macrotext, "Brown Horse", 1, true) ~= nil,
        "macrotext should include the mount in the same press")
    assert_equal(#state.macro_cast_lines, 2, "both CA and mount should appear as cast lines")
    assert_equal(state.macro_cast_lines[1], "Crusader Aura", "first cast line should be Crusader Aura")
    assert_equal(state.macro_cast_lines[2], "Brown Horse", "second cast line should be the mount")
end)

run_test("crusader aura is not applied when feature is disabled", function()
    local state = setup_env({
        mounts = {
            { spellID = 5202, name = "Warhorse", mountType = 0x01 },
        },
        known_spells = {
            [32223] = true,
        },
        spell_infos = {
            [5202] = { name = "Warhorse", icon = "icon" },
            [32223] = { name = "Crusader Aura", icon = "crusader" },
        },
        player_class = { "Paladin", "PALADIN" },
        char_db = {
            groundMounts = { 5202 },
            flyingMounts = {},
            crusaderAura = false,
        },
        c_map_enabled = false,
    })

    trigger_secure_mount(state)

    assert_true(state.last_binding_macrotext ~= nil, "macrotext should be set")
    assert_true(string.find(state.last_binding_macrotext, "Crusader Aura", 1, true) == nil, "macrotext should not contain Crusader Aura when disabled")
    assert_equal(#state.macro_cast_lines, 1, "only one cast line when disabled")
    assert_equal(state.macro_cast_lines[1], "Warhorse", "cast line should be the mount only")
end)

run_test("crusader aura is not applied for non-paladin classes", function()
    local state = setup_env({
        mounts = {
            { spellID = 5203, name = "Brown Horse", mountType = 0x01 },
        },
        known_spells = {},
        spell_infos = {
            [5203] = { name = "Brown Horse", icon = "icon" },
        },
        player_class = { "Warrior", "WARRIOR" },
        char_db = {
            groundMounts = { 5203 },
            flyingMounts = {},
            crusaderAura = true,
        },
        c_map_enabled = false,
    })

    trigger_secure_mount(state)

    assert_true(state.last_binding_macrotext ~= nil, "macrotext should be set")
    assert_true(string.find(state.last_binding_macrotext, "Crusader Aura", 1, true) == nil, "macrotext should not contain Crusader Aura for non-paladins")
end)

run_test("saved aura is restored in macrotext on dismount", function()
    local state = setup_env({
        mounts = {},  -- no companion mounts; class mount added via known_spells path
        known_spells = {
            [13819] = true,  -- Summon Warhorse
            [32223] = true,  -- Crusader Aura
        },
        spell_infos = {
            [13819] = { name = "Summon Warhorse", icon = "icon" },
            [32223] = { name = "Crusader Aura", icon = "crusader" },
            [465] = { name = "Devotion Aura", icon = "devotion" },
        },
        player_class = { "Paladin", "PALADIN" },
        shapeshift_forms = {
            { spellID = 465, isActive = true },
        },
        char_db = {
            groundMounts = { 13819 },
            flyingMounts = {},
            crusaderAura = true,
        },
        c_map_enabled = false,
    })

    -- Press 1: Devotion Aura active → switch to Crusader Aura, save Devotion Aura
    trigger_secure_mount(state)
    assert_equal(state.last_binding_macrotext, "/cast Crusader Aura", "first press should switch to Crusader Aura")

    -- Simulate CA becoming active
    state.shapeshift_forms = { { spellID = 32223, isActive = true } }

    -- Press 2: CA active → mount
    trigger_secure_mount(state)
    assert_equal(state.last_cast_spell_name, "Summon Warhorse", "second press should cast the mount")

    -- Simulate being mounted
    state.mounted = true

    -- Press 3: dismount → restore Devotion Aura
    trigger_secure_mount(state)
    assert_true(state.dismounted, "third press should dismount")
    assert_true(string.find(state.last_binding_macrotext, "Devotion Aura", 1, true) ~= nil, "dismount macrotext should include the saved aura")
end)

run_test("no aura restoration when crusader aura feature is disabled on dismount", function()
    local state = setup_env({
        mounts = {
            { spellID = 5205, name = "Warhorse", mountType = 0x01 },
        },
        player_class = { "Paladin", "PALADIN" },
        char_db = {
            groundMounts = { 5205 },
            flyingMounts = {},
            crusaderAura = false,
        },
        c_map_enabled = false,
        mounted = true,
    })

    trigger_secure_mount(state)

    assert_equal(state.last_binding_macrotext, "/dismount", "disabled feature should produce plain dismount")
end)

run_test("unit aura event restores saved aura when dismounted outside combat", function()
    local state = setup_env({
        mounts = {},  -- no companion mounts; class mount added via known_spells path
        known_spells = {
            [13819] = true,  -- Summon Warhorse
            [32223] = true,  -- Crusader Aura
        },
        spell_infos = {
            [13819] = { name = "Summon Warhorse", icon = "icon" },
            [32223] = { name = "Crusader Aura", icon = "crusader" },
            [465] = { name = "Devotion Aura", icon = "devotion" },
        },
        player_class = { "Paladin", "PALADIN" },
        shapeshift_forms = {
            { spellID = 465, isActive = true },
        },
        char_db = {
            groundMounts = { 13819 },
            flyingMounts = {},
            crusaderAura = true,
        },
        c_map_enabled = false,
    })

    -- Mount via keybind so savedAura is set
    trigger_secure_mount(state)

    -- Simulate mount happening (player is now mounted)
    state.mounted = true

    -- Simulate wasMountedState update by firing UNIT_AURA while mounted
    local event_frame
    for _, frame in ipairs(state.frames) do
        if frame.events["UNIT_AURA"] and frame.scripts["OnEvent"] then
            event_frame = frame
            break
        end
    end
    assert_true(event_frame ~= nil, "event frame should be registered for UNIT_AURA")
    event_frame.scripts["OnEvent"](event_frame, "UNIT_AURA", "player")

    -- Simulate dismount (player is no longer mounted)
    state.mounted = false
    state.last_cast_spell_name = nil

    -- Fire UNIT_AURA again to detect the dismount
    event_frame.scripts["OnEvent"](event_frame, "UNIT_AURA", "player")

    assert_equal(state.last_cast_spell_name, "Devotion Aura", "UNIT_AURA handler should restore the saved aura on dismount")
end)

run_test("minimap dismount restores saved aura", function()
    local state = setup_env({
        mounts = {},  -- no companion mounts; class mount added via known_spells path
        known_spells = {
            [13819] = true,  -- Summon Warhorse
            [32223] = true,  -- Crusader Aura
        },
        spell_infos = {
            [13819] = { name = "Summon Warhorse", icon = "icon" },
            [32223] = { name = "Crusader Aura", icon = "crusader" },
            [465] = { name = "Devotion Aura", icon = "devotion" },
        },
        player_class = { "Paladin", "PALADIN" },
        shapeshift_forms = {
            { spellID = 465, isActive = true },
        },
        char_db = {
            groundMounts = { 13819 },
            flyingMounts = {},
            crusaderAura = true,
        },
        c_map_enabled = false,
    })

    -- Mount via keybind to save the aura
    trigger_secure_mount(state)

    -- Now simulate being mounted and dismounting via minimap
    state.mounted = true
    state.last_cast_spell_name = nil

    local minimap_button = _G.OneButtonMountMinimapButton
    assert_true(minimap_button ~= nil, "minimap button should exist")
    minimap_button.scripts["OnClick"](minimap_button, "RightButton")

    assert_true(state.dismounted, "minimap right-click should dismount")
    assert_equal(state.last_cast_spell_name, "Devotion Aura", "minimap dismount should restore the saved aura")
end)

run_test("cancelling mount cast restores previous aura via UNIT_SPELLCAST_INTERRUPTED", function()
    local state = setup_env({
        mounts = {},  -- no companion mounts; class mount added via known_spells path
        known_spells = {
            [13819] = true,  -- Summon Warhorse
            [32223] = true,  -- Crusader Aura
        },
        spell_infos = {
            [13819] = { name = "Summon Warhorse", icon = "icon" },
            [32223] = { name = "Crusader Aura", icon = "crusader" },
            [465] = { name = "Devotion Aura", icon = "devotion" },
        },
        player_class = { "Paladin", "PALADIN" },
        shapeshift_forms = {
            { spellID = 465, isActive = true },
        },
        char_db = {
            groundMounts = { 13819 },
            flyingMounts = {},
            crusaderAura = true,
        },
        c_map_enabled = false,
    })

    local event_frame
    for _, frame in ipairs(state.frames) do
        if frame.events["UNIT_SPELLCAST_INTERRUPTED"] and frame.scripts["OnEvent"] then
            event_frame = frame
            break
        end
    end
    assert_true(event_frame ~= nil, "event frame should be registered for UNIT_SPELLCAST_INTERRUPTED")

    -- Press 1: save Devotion Aura, switch to Crusader Aura
    trigger_secure_mount(state)
    state.shapeshift_forms = { { spellID = 32223, isActive = true } }

    -- Press 2: mount cast begins (mountingInProgress = true)
    trigger_secure_mount(state)

    -- Player cancels mount cast (moves, Escape, etc.)
    state.last_cast_spell_name = nil
    event_frame.scripts["OnEvent"](event_frame, "UNIT_SPELLCAST_INTERRUPTED", "player")

    assert_equal(state.last_cast_spell_name, "Devotion Aura", "cancelled mount should restore the previous aura")
end)

print(string.format("Ran %d tests, %d failures", total, failures))
if failures > 0 then
    os.exit(1)
end
