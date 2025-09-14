local hit_effects = require("__base__.prototypes.entity.hit-effects")

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
    minable = {mining_time = math.huge},
    selection_box = {{-0.35, -0.35}, {0.35, 0.35}}
}, {
    type = "inserter",
    name = "ftrainworks-coupler-inserter",

    -- InserterPrototype
    energy_source = {
        type = "electric",
        usage_priority = "secondary-input",
        drain = "0.4kW"
    },
    extension_speed = 0.035,
    pickup_position = {0, -1},
    insert_position = {0, 1.2},
    rotation_speed = 0.014,
    energy_per_movement = "5kJ",
    energy_per_rotation = "5kJ",
    circuit_wire_max_distance = inserter_circuit_wire_max_distance,

    -- EntityWithHealthPrototype
    damaged_trigger_effect = hit_effects.entity(),
    max_health = 200,
    resistances = {
        { type = "fire", percent = 98 },
        { type = "impact", percent = 24 }
    },

    -- EntityPrototype
    collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
    flags = {
        "placeable-neutral",
        "placeable-player",
        "player-creation"
    },
    icon = "__ftrainworks__/graphics/icons/coupler-inserter.png",
    minable = {
        mining_time = 0.435,
        result = "ftrainworks-coupler-inserter"
    },
    selection_box = {{-0.4, -0.35}, {0.4, 0.45}},
}});