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
        icon = "__ftrainworks__/graphics/icons/signal/signal-couple.png",
        subgroup = "ftrainworks",
        order = "a[couple]"
    },
    {
        type = "virtual-signal",
        name = "ftrainworks-signal-uncouple",
        icon = "__ftrainworks__/graphics/icons/signal/signal-uncouple.png",
        subgroup = "ftrainworks",
        order = "b[uncouple]"
    }
})