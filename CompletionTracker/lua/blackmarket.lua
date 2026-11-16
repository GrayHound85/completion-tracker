---@diagnostic disable: undefined-global

-- Completion Tracker - marks items you already own in the shop screens,
-- where the game itself does not say:
--
--   buying a weapon      weapons you already own
--   buying a mask        masks you have already crafted
--   weapon attachments   attachments shown as out of stock that you do have,
--                        fitted to another weapon
--
-- Melee weapons, throwables and outfits are left alone on purpose, the game
-- already puts a padlock on the ones you do not have.

local OWNED_ICON_NAME = "owned_indicator"
local OWNED_ICON_TEXTURE = "guis/textures/pd2/blackmarket/inv_mod_new"

dofile(ModPath .. "lua/config.lua")
CompletionTracker:Load()

local function player_owns_weapon(weapon_id)
    local categories = {"primaries", "secondaries"}

    for _, category in ipairs(categories) do
        local crafted = managers.blackmarket:get_crafted_category(category)
        for _, weapon in pairs(crafted) do
            if weapon.weapon_id == weapon_id then
                return true
            end
        end
    end
    return false
end

local function player_owns_mask(mask_id)
    local crafted = managers.blackmarket:get_crafted_category("masks")
    for _, mask in pairs(crafted) do
        if mask.mask_id == mask_id then
            return true
        end
    end
    return false
end

-- Set of every attachment currently fitted to one of your weapons.
local function fitted_attachments()
    local fitted = {}

    for _, category in ipairs({"primaries", "secondaries"}) do
        for _, weapon in pairs(managers.blackmarket:get_crafted_category(category) or {}) do
            for _, part_id in ipairs(weapon.blueprint or {}) do
                fitted[part_id] = true
            end
        end
    end

    return fitted
end

local function add_owned_icon(slot)
    if not CompletionTracker.settings.show_icons then
        return
    end

    slot._data.mini_icons = slot._data.mini_icons or {}
    local already = false
    for _, icon in ipairs(slot._data.mini_icons) do
        if icon.name == OWNED_ICON_NAME then
            already = true
            break
        end
    end
    if not already then
        table.insert(slot._data.mini_icons, {
            name    = OWNED_ICON_NAME,
            texture = OWNED_ICON_TEXTURE,
            texture_type = "texture",
            right   = 5,
            bottom  = 5,
            w       = 16,
            h       = 16,
            layer   = 2
        })
    end

    if slot._mini_panel and not slot._mini_panel:child(OWNED_ICON_NAME) then
        local icon = slot._mini_panel:bitmap({
            name    = OWNED_ICON_NAME,
            texture = OWNED_ICON_TEXTURE,
            texture_type = "texture",
            w       = 16,
            h       = 16,
            layer   = 2
        })
        icon:set_right(slot._mini_panel:w() - 5)
        icon:set_bottom(slot._mini_panel:h() - 5)
    end
end

local function add_owned_border(slot)
    if not CompletionTracker.settings.show_borders or not slot._panel or slot._owned_border then
        return
    end

    local panel = slot._panel
    local t = 1 -- thickness
    local pad = 3
    local color = CompletionTracker.COMPLETED_COLOR

    slot._owned_border = {
        top = panel:rect({
            layer = 3,
            color = color,
            alpha = 0.6,
            x = pad,
            y = pad,
            w = panel:w() - pad * 2,
            h = t
        }),

        bottom = panel:rect({
            layer = 3,
            color = color,
            alpha = 0.6,
            x = pad,
            y = panel:h() - t - pad,
            w = panel:w() - pad * 2,
            h = t
        }),

        left = panel:rect({
            layer = 3,
            color = color,
            alpha = 0.6,
            x = pad,
            y = pad,
            w = t,
            h = panel:h() - pad * 2
        }),

        right = panel:rect({
            layer = 3,
            color = color,
            alpha = 0.6,
            x = panel:w() - t - pad,
            y = pad,
            w = t,
            h = panel:h() - pad * 2
        })
    }
end

-- One entry per shop screen that gets markers, keyed by the function the
-- game fills that screen with. Each returns a test for a single slot.
local SCREENS = {
    populate_buy_weapon = function()
        return function(slot_data)
            return player_owns_weapon(slot_data.name)
        end
    end,

    populate_buy_mask = function()
        return function(slot_data)
            return player_owns_mask(slot_data.name)
        end
    end,

    populate_mods = function()
        local fitted = fitted_attachments()

        return function(slot_data)
            -- Only where the game says there are none in stock. Anything in
            -- stock, or fitted to this very weapon, is already obvious.
            local in_stock = slot_data.unlocked and slot_data.unlocked ~= 0

            return not in_stock and not slot_data.equipped and fitted[slot_data.name] or false
        end
    end
}

Hooks:PostHook(BlackMarketGuiTabItem, "init", "OwnedDataPostHook", function(self)
    local screen = self._data and SCREENS[self._data.on_create_func_name]

    if not screen then
        return
    end

    local is_owned = screen()

    for _, slot in ipairs(self._slots or {}) do
        if slot._data and slot._data.name and is_owned(slot._data) then
            add_owned_icon(slot)
            add_owned_border(slot)
        end
    end
end)
