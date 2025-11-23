local automatic_railway_technology = data.raw.technology["automated-rail-transportation"]
local circuit_network = data.raw.technology["circuit-network"]

-- Append technology effects to unlock the coupler inserter
if automatic_railway_technology and automatic_railway_technology.effects then
    table.insert(automatic_railway_technology.effects, {
        type = "unlock-recipe",
        recipe = "ftrainworks-coupler-inserter"
    })
end

-- Append technology effects to unlock the sensor
if circuit_network and circuit_network.effects then
    local i
    for j, effect in ipairs(circuit_network.effects) do
        if effect.recipe == "constant-combinator" then
            i = j
            break
        end
    end
    table.insert(circuit_network.effects, i + 1, {
        type = "unlock-recipe",
        recipe = "ftrainworks-sensor"
    })
end