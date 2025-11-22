data:extend({
    {
        -- Prototype
        type = "recipe",
        name = "ftrainworks-coupler-inserter",

        -- RecipePrototype
        allow_quality = false,
        enabled = false,
        energy_required = 0.5,
        ingredients = {
            {
                type = "item",
                name = "iron-plate",
                amount = 2
            },
            {
                type = "item",
                name = "iron-gear-wheel",
                amount = 2
            },
            {
                type = "item",
                name = "electronic-circuit",
                amount = 2
            },
            {
                type = "item",
                name = "inserter",
                amount = 1
            }
        },
        results = {
            {
                type = "item",
                name = "ftrainworks-coupler-inserter",
                amount = 1
            }
        }
    }
})