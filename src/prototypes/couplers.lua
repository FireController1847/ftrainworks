data:extend({{
    type = "simple-entity-with-owner",
    name = "ftrainworks-coupler",
    hidden = true,

    -- SimpleEntityPrototype
    render_layer = "cargo-hatch",

    -- EntityWithHealthPrototype
    alert_when_damaged = false,
    create_ghost_on_death = false,
    max_health = 2147483648,
    resistances = {
        { type = "physical", percent = 100 },
        { type = "impact", percent = 100 },
        { type = "fire", percent = 100 },
        { type = "acid", percent = 100 },
        { type = "poison", percent = 100 },
        { type = "explosion", percent = 100 },
        { type = "laser", percent = 100 },
        { type = "electric", percent = 100 }
    },

    -- EntityPrototype
    allow_copy_paste = false,
    collision_box = {{0.0, 0.0}, {0.0, 0.0}},
    flags = {
        "placeable-neutral",
        "placeable-player",
        "placeable-off-grid",
        "not-rotatable",
        "not-repairable",
        "not-on-map",
        "not-deconstructable",
        "not-flammable",
        "no-copy-paste",
        "not-upgradable",
        "not-in-kill-statistics",
        "not-in-made-in"
    },
    icon = "__base__/graphics/icons/steel-chest.png", -- placeholder icon
    minable = {mining_time = math.huge},
    selection_box = {{-0.35, -0.35}, {0.35, 0.35}}
}});