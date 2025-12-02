local trains = require("script.trains")
local util = require("script.util")

commands.add_command("ftrainworks-reset", nil, function(event)
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

    game.print("FTrainWorks: Reset complete.")
end)