data:extend({
    {
        type = "item-subgroup",
        name = "ftrainworks",
        group = "signals",
        order = "z"
    },
    {
        type = "virtual-signal",
        name = "ftrainworks-signal-couple",
        icon = "__base__/graphics/icons/battery.png",
        subgroup = "ftrainworks",
        order = "a[couple]"
    },
    {
        type = "virtual-signal",
        name = "ftrainworks-signal-uncouple",
        icon = "__base__/graphics/icons/battery.png",
        subgroup = "ftrainworks",
        order = "b[uncouple]"
    }
})