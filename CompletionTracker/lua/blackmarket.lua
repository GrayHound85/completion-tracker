---@diagnostic disable: undefined-global

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
    local categories = {"masks"}

    for _, category in ipairs(categories) do
        local crafted = managers.blackmarket:get_crafted_category(category)
        for _, mask in pairs(crafted) do
            if mask.mask_id == mask_id then
                return true
            end
        end
    end
    return false
end


local function add_owned_icon(slot, data)
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

        
local function add_owned_border(slot, owned)
    if not CompletionTracker.settings.show_borders or not slot._panel or slot._owned_border then
        return
    end

            local panel = slot._panel
            local t = 1 -- thickness
            local pad = 3

            slot._owned_border = {
                top = panel:rect({
                    layer = 3,
                    color = Color(0.3, 1, 0.3),
                    alpha = 0.6,
                    x = pad,
                    y = pad,
                    w = panel:w() - pad * 2,
                    h = t
                }),

                bottom = panel:rect({
                    layer = 3,
                    color = Color(0.3, 1, 0.3),
                    alpha = 0.6,
                    x = pad,
                    y = panel:h() - t - pad,
                    w = panel:w() - pad * 2,
                    h = t
                }),

                left = panel:rect({
                    layer = 3,
                    color = Color(0.3, 1, 0.3),
                    alpha = 0.6,
                    x = pad,
                    y = pad,
                    w = t,
                    h = panel:h() - pad * 2
                }),

                right = panel:rect({
                    layer = 3,
                    color = Color(0.3, 1, 0.3),
                    alpha = 0.6,
                    x = panel:w() - t - pad,
                    y = pad,
                    w = t,
                    h = panel:h() - pad * 2
                })
            }
            for _, rect in pairs(slot._owned_border) do
                rect:set_visible(owned)
            end
        end

-- Common function to handle owned items (weapons and masks)
local function handle_owned_items(self, main_panel, data, item_type, item_id_func)
    if not self._data or (item_type == "weapon" and self._data.on_create_func_name ~= "populate_buy_weapon")
       or (item_type == "mask" and self._data.on_create_func_name ~= "populate_buy_mask") then
        return
    end

    for _, slot in ipairs(self._slots or {}) do
        local item_id = slot._data and slot._data.name
        local owned = item_id and item_id_func(item_id)

        if item_id and owned then
            add_owned_icon(slot, slot._data)
            add_owned_border(slot, owned)
        end
    end
end

-- Hook for weapons
Hooks:PostHook(BlackMarketGuiTabItem, "init", "OwnedDataPostHook", function(self, main_panel, data, ...)
    handle_owned_items(self, main_panel, data, "weapon", player_owns_weapon)
end)

-- Hook for masks
Hooks:PostHook(BlackMarketGuiTabItem, "init", "OwnedDataPostHookMasks", function(self, main_panel, data, ...)
    handle_owned_items(self, main_panel, data, "mask", player_owns_mask)
end)

