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
        map_id = opts.map_id,
        map_infos = opts.map_infos or {},
        current_map_area_id = opts.current_map_area_id,
        real_zone_text = opts.real_zone_text,
        zone_text = opts.zone_text,
        c_map_enabled = opts.c_map_enabled ~= false,
        num_companions_mode = opts.num_companions_mode,
        num_companions_value = opts.num_companions_value,
    }

    _G.unpack = table.unpack
    _G.tinsert = table.insert

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
        function frame:RegisterForClicks() end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(script_name, fn) self.scripts[script_name] = fn end
        function frame:SetFrameStrata() end
        function frame:SetFrameLevel() end
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
    _G.OneButtonMountDB = copy_table(opts.db or {})

    _G.InCombatLockdown = function() return state.in_combat end
    _G.IsMounted = function() return state.mounted end
    _G.Dismount = function() state.dismounted = true end
    _G.IsIndoors = function() return state.indoors end
    _G.IsInInstance = function() return state.in_instance, "none" end
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
    _G.GetSpellInfo = function(spell_id)
        for _, mount in ipairs(state.mounts) do
            if mount.spellID == spell_id then
                return mount.name
            end
        end
        return nil
    end
    _G.IsSpellKnown = function(spell_id)
        return state.known_spells[spell_id] or false
    end
    _G.SetOverrideBindingClick = function(_, _, key, button_name)
        state.binding_clicks[#state.binding_clicks + 1] = { key = key, button_name = button_name }
    end
    _G.SetOverrideBinding = function(_, _, key, command)
        state.binding_clears[#state.binding_clears + 1] = { key = key, command = command }
    end
    _G.GetRealZoneText = function() return state.real_zone_text end
    _G.GetZoneText = function() return state.zone_text end
    _G.GetCurrentMapAreaID = function() return state.current_map_area_id end
    _G.GetCursorPosition = function() return 0, 0 end
    _G.IsShiftKeyDown = function() return false end
    _G.IsControlKeyDown = function() return false end
    _G.IsAltKeyDown = function() return false end

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

    assert_equal(#OneButtonMountDB.groundMounts, 1, "ground pool should be sanitized")
    assert_equal(OneButtonMountDB.groundMounts[1], 1001, "valid ground mount should remain")
    assert_equal(#OneButtonMountDB.flyingMounts, 0, "invalid flying mount should be removed")
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
        if frame.scripts["OnMouseDown"] then
            key_capture_frame = frame
            break
        end
    end
    assert_true(key_capture_frame ~= nil, "key capture frame not found")

    key_capture_frame.scripts["OnMouseDown"](key_capture_frame, "RightButton")

    local last_binding = state.binding_clicks[#state.binding_clicks]
    assert_true(last_binding ~= nil, "no binding call recorded")
    assert_equal(last_binding.key, "BUTTON2", "right-click bind token should be BUTTON2")
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

    assert_equal(#OneButtonMountDB.flyingMounts, 0, "ground-only mount should not enter flying pool")

    local found_message = false
    for _, line in ipairs(state.chat) do
        if string.find(line, "cannot be added to flying rotation", 1, true) then
            found_message = true
            break
        end
    end
    assert_true(found_message, "expected rejection message was not printed")
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
    assert_equal(#OneButtonMountDB.groundMounts, 1, "existing pool should remain intact when count is nil")
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
    assert_equal(#OneButtonMountDB.groundMounts, 1, "existing pool should remain intact when count has no return values")
end)

print(string.format("Ran %d tests, %d failures", total, failures))
if failures > 0 then
    os.exit(1)
end
