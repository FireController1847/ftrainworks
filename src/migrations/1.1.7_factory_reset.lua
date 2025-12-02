local trains = require("script.trains")
local sensor_script = require("script.sensor")
local inserter_script = require("script.inserter")
local util = require("script.util")

-- Wipe storage
storage.carriages = {}
storage.coupler_inserters = {}
storage.sensors = {}

-- Clear ALL couplers
for _, surface in pairs(game.surfaces) do
    local couplers = surface.find_entities_filtered{ name = "ftrainworks-coupler" }
    if couplers and #couplers > 0 then
        for _, coupler in ipairs(couplers) do
            coupler.destroy()
        end
    end
end

-- Re-validate all carriages
for _, train in ipairs(game.train_manager.get_trains{}) do
    for _, carriage in ipairs(train.carriages) do
        if util.is_entity_carriage(carriage) then
            trains.on_carriage_built(carriage)
        end
    end
end

-- Fix all sensors
for _, surface in pairs(game.surfaces) do
    local sensors = surface.find_entities_filtered{ name = "ftrainworks-sensor" }
    if sensors and #sensors > 0 then
        for _, sensor in ipairs(sensors) do
            sensor_script.on_sensor_built(sensor)
            if not string.find(sensor.combinator_description, " read-contents", 1, true) then
                if string.find(sensor.combinator_description, "read-contents", 1, true) then
                    sensor.combinator_description = sensor.combinator_description:gsub("read%-contents", " read-contents")
                end
            end
        end
    end
end

-- Fix all inserters
for _, surface in pairs(game.surfaces) do
    local inserters = surface.find_entities_filtered{ name = "ftrainworks-coupler-inserter" }
    if inserters and #inserters > 0 then
        for _, inserter in ipairs(inserters) do
            inserter_script.on_inserter_built(inserter)
        end
    end
end