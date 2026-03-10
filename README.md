# completion-tracker
A Payday 2 mod to help completionists track their progress and organise there inventory UI


# Devepment notes.
managers.blackmarket:weapon_unlocked(weapon_id) - Returns if weapon can be used
managers.blackmarket:get_crafted_category(category) - Get owned weapons
BlackMarketGuiSlotItem._mini_panel - The panel where mini_icons are rendered
BlackMarketGuiSlotItem:refresh() - Called when item state changes