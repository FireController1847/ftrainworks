local item_sounds = require("__base__.prototypes.item_sounds")

data:extend({
    {
        type = "item",
        name = "ftrainworks-coupler-inserter",

        -- ItemPrototype
        stack_size = 50,
        color_hint = { r = 0.0, g = 0.0, b = 0.0, a = 0.0 },
        drop_sound = item_sounds.inserter_inventory_move,
        icon = "__ftrainworks__/graphics/icons/coupler-inserter.png",
        inventory_move_sound = item_sounds.inserter_inventory_move,
        pick_sound = item_sounds.inserter_inventory_pickup,
        place_result = "ftrainworks-coupler-inserter",

        -- PrototypeBase
        order = "b[inserter]-c[fast-inserter]",
        subgroup = "inserter",
    },
    {
        type = "item",
        name = "ftrainworks-sensor",
        -- TODO: update
        icon = "__ftrainworks__/graphics/icons/coupler-inserter.png",
        subgroup = "circuit-network",
        place_result = "ftrainworks-sensor",
        order = "c[combinators]-e[ftrainworks-sensor]",
        -- TODO: custom sounds?
        inventory_move_sound = item_sounds.combinator_inventory_move,
        pick_sound = item_sounds.combinator_inventory_pickup,
        drop_sound = item_sounds.combinator_inventory_move,
        stack_size = 50,
        weight = 20 * kg
    }
});