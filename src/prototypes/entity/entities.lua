local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")

local sensor = generate_constant_combinator({
  type = "constant-combinator",
  name = "ftrainworks-sensor",

  -- EntityPrototype
  close_sound = sounds.combinator_close,
  collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
  -- TODO: Emissions per second? :)
  flags = {
      "placeable-neutral",
      "player-creation"
  },
  icon = "__ftrainworks__/graphics/icons/sensor.png",
  icon_draw_specification = {
      scale = 0.7
  },
  minable = {
      mining_time = 0.1,
      result = "ftrainworks-sensor"
  },
  open_sound = sounds.combinator_open,
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
  -- TODO: working sound?

  -- EntityWithHealthPrototype
  -- TODO: corpse
  dying_explosion = "constant-combinator-explosion",
  damaged_trigger_effect = hit_effects.entity(),
  max_health = 120,

  -- ConstantCombinatorPrototype
  activity_led_light_offsets = {
      {0.296875, -0.40625},
      {0.25, -0.03125},
      {-0.296875, -0.078125},
      {-0.21875, -0.46875}
  },
  circuit_wire_max_distance = combinator_circuit_wire_max_distance,
})
sensor.sprites = make_4way_animation_from_spritesheet({
  layers = {
    {
      scale = 0.5,
      filename = "__ftrainworks__/graphics/entity/sensor/sensor.png",
      width = 114,
      height = 102,
      shift = util.by_pixel(0, 5)
    },
    {
      scale = 0.5,
      filename = "__ftrainworks__/graphics/entity/sensor/sensor-shadow.png",
      width = 98,
      height = 66,
      shift = util.by_pixel(8.5, 5.5),
      draw_as_shadow = true
    }
  }
})

data:extend({
  {
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
    collision_mask = {
      layers = {}
    },
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
  },
  {
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
    circuit_connector = circuit_connector_definitions["inserter"],
    circuit_wire_max_distance = inserter_circuit_wire_max_distance,
    energy_per_movement = "5kJ",
    energy_per_rotation = "5kJ",
    filter_count = 2,
    hand_base_picture = {
        filename = "__ftrainworks__/graphics/entity/coupler-inserter/coupler-inserter-hand-base.png",
        priority = "extra-high",
        width = 32,
        height = 136,
        scale = 0.25
    },
    hand_base_shadow ={
      filename = "__base__/graphics/entity/burner-inserter/burner-inserter-hand-base-shadow.png",
      priority = "extra-high",
      width = 32,
      height = 132,
      scale = 0.25
    },
    hand_closed_picture = {
      filename = "__ftrainworks__/graphics/entity/coupler-inserter/coupler-inserter-hand-closed.png",
      priority = "extra-high",
      width = 72,
      height = 164,
      scale = 0.25
    },
    hand_closed_shadow = {
      filename = "__base__/graphics/entity/burner-inserter/burner-inserter-hand-closed-shadow.png",
      priority = "extra-high",
      width = 72,
      height = 164,
      scale = 0.25
    },
    hand_open_picture = {
      filename = "__ftrainworks__/graphics/entity/coupler-inserter/coupler-inserter-hand-open.png",
      priority = "extra-high",
      width = 72,
      height = 164,
      scale = 0.25
    },
    hand_open_shadow = {
      filename = "__base__/graphics/entity/burner-inserter/burner-inserter-hand-open-shadow.png",
      priority = "extra-high",
      width = 72,
      height = 164,
      scale = 0.25
    },
    platform_picture = {
      sheet = {
        filename = "__ftrainworks__/graphics/entity/coupler-inserter/coupler-inserter-platform.png",
        priority = "extra-high",
        width = 105,
        height = 79,
        shift = util.by_pixel(1.5, 7.5-1),
        scale = 0.5
      }
    },

    -- EntityWithHealthPrototype
    damaged_trigger_effect = hit_effects.entity(),
    max_health = 200,
    resistances = {
        { type = "fire", percent = 98 },
        { type = "impact", percent = 24 }
    },

    -- EntityPrototype
    close_sound = sounds.inserter_close,
    collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
    flags = {
        "placeable-neutral",
        "placeable-player",
        "player-creation"
    },
    icon = "__ftrainworks__/graphics/icons/coupler-inserter.png",
    impact_category = "metal",
    minable = {
        mining_time = 0.435,
        result = "ftrainworks-coupler-inserter"
    },
    open_sound = sounds.inserter_open,
    selection_box = {{-0.4, -0.35}, {0.4, 0.45}},
    working_sound = sounds.inserter_basic
  },
  {
    type = "container",
    name = "ftrainworks-coupler-container",
    hidden = true,

    -- EntityPrototype
    allow_copy_paste = false,
    collision_box = {{0.0, 0.0}, {0.0, 0.0}},
    flags = {
      "not-rotatable",
      "placeable-off-grid",
      "not-repairable",
      "not-on-map",
      "not-deconstructable",
      "not-blueprintable",
      "hide-alt-info",
      "not-flammable",
      "no-copy-paste",
      "not-selectable-in-game",
      "not-upgradable",
      "not-in-kill-statistics",
      "not-in-made-in"
    },
    remove_decorations = false,
    selectable_in_game = false,
    selection_box = {{0.0, 0.0}, {0.0, 0.0}},

    -- EntityWithHealthPrototype
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

    -- ContainerPrototype
    inventory_size = 1,
  },
  sensor
});