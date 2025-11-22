-- Append technology effects to unlock the coupler inserter
local automatic_railway_technology = data.raw.technology["automated-rail-transportation"]
if automatic_railway_technology and automatic_railway_technology.effects then
    table.insert(automatic_railway_technology.effects, {
        type = "unlock-recipe",
        recipe = "ftrainworks-coupler-inserter"
    })
end