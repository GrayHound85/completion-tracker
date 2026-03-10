---@diagnostic disable: undefined-global

local OWNED_ICON_NAME = "owned_indicator"
local OWNED_ICON_TEXTURE = "weaponownership/owned"

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


Hooks:PostHook(BlackMarketGuiTabItem, "init", "OwnedDataPostHook", function(self, main_panel, data, ...)
    if not self._data or self._data.on_create_func_name ~= "populate_buy_weapon" then
        return
    end

    for _, slot in ipairs(self._slots or {}) do
        local wid = slot._data and slot._data.name
        if wid and player_owns_weapon(wid) then
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
                    w       = 16,
                    h       = 16,
                    layer   = 2
                })
                icon:set_right(slot._mini_panel:w() - 5)
                icon:set_bottom(slot._mini_panel:h() - 5)
            end
        end
    end
end)

