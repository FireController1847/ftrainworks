local registry = require("script.registry")
local coupling = require("script.coupling")

--[[
    Coupler event handlers.
--]]
local function coupler_inserter_created(entity)
    -- Set default inserter state filters
    local filter_slots = entity.filter_slot_count
    if filter_slots < 2 then return end
    local filter_slot_1 = entity.get_filter(1)
    local filter_slot_2 = entity.get_filter(2)
    if not filter_slot_1 then entity.set_filter(1, "ftrainworks-coupler-priority-couple") end
    if not filter_slot_2 then entity.set_filter(2, "ftrainworks-coupler-priority-uncouple") end
end

local function coupler_inserter_perform(entity, action)
    if not (entity and entity.valid) then return end
    if not storage.coupler_inserter_moving then return end
    if storage.coupler_inserter_moving[entity] then return end -- Already moving
    local surface = entity.surface
    local pickup_position = entity.pickup_position
    local drop_position = entity.drop_position

    -- Fake item stack
    local dummy_stack = {
        name = "ftrainworks-coupler-stack",
        count = 1
    }
    local pickup_dummy = surface.create_entity{
        name = "item-on-ground",
        position = pickup_position,
        stack = dummy_stack
    }
    local drop_dummy = surface.create_entity{
        name = "ftrainworks-coupler-container",
        position = drop_position,
        force = entity.force
    }

    -- Assign the inserter targets
    entity.pickup_target = pickup_dummy
    entity.drop_target = drop_dummy
    entity.active = true

    -- Queue cleanup
    storage.coupler_inserter_moving[entity] = {
        pickup = pickup_dummy,
        drop = drop_dummy,
        position = drop_position,
        surface = surface,
        action = action,
        validated = false,
        state = 0,
        delay = 0
    }
end

local function coupler_inserter_check_perform_action(entity)
    -- START HIGH-PERFORMANT CODE --

    if not (entity and entity.valid) then return end

    -- If the entity is actively moving, do nothing
    if storage.coupler_inserter_moving and storage.coupler_inserter_moving[entity] then return end

    -- Fetch circuit signal
    local couple_signal = entity.get_signal({
        type = "virtual",
        name = "ftrainworks-signal-couple"
    }, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
    local uncouple_signal = entity.get_signal({
        type = "virtual",
        name = "ftrainworks-signal-uncouple"
    }, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    -- IF THE SIGNALS HAVE NOT CHANGED SINCE LAST ACTIVE, DO NOTHING
    local active_data = storage.coupler_inserter_active and storage.coupler_inserter_active[entity]
    if active_data then
        if active_data.couple_signal == couple_signal and active_data.uncouple_signal == uncouple_signal then
            return
        else
            -- Update stored signals
            storage.coupler_inserter_active[entity].couple_signal = couple_signal
            storage.coupler_inserter_active[entity].uncouple_signal = uncouple_signal
        end
    end

    -- END HIGH-PERFORMANT CODE --

    --game.print("Checking coupler inserter at " .. serpent.line(entity.position) .. " with signals: couple=" .. couple_signal .. ", uncouple=" .. uncouple_signal .. " on tick " .. game.tick)

    -- If no signals, do nothing
    -- If both signals, determine based on set priority
    -- If one signal, perform that action
    local determined_action = nil
    if couple_signal == 0 and uncouple_signal == 0 then
        return
    elseif couple_signal > 0 and uncouple_signal > 0 then
        local filter_slot_1 = entity.get_filter(1)
        if filter_slot_1 and filter_slot_1.name == "ftrainworks-coupler-priority-couple" then
            determined_action = "couple"
        else
            determined_action = "uncouple"
        end
    else
        if couple_signal > 0 then
            determined_action = "couple"
        else
            determined_action = "uncouple"
        end
    end

    -- Perform the action
    if determined_action then
        -- IF THE CURRENT CONNECTION MATCHES OUR ACTION, DO NOTHING
        local is_connected = coupling.are_nearest_carriages_connected(entity.surface, entity.position, 2)
        if (determined_action == "couple" and is_connected) or (determined_action == "uncouple" and not is_connected) then
            return
        end
        coupler_inserter_perform(entity, determined_action)
    end
end

local function coupler_inserter_check_trains(train)
    -- Loop through all couplers and find nearby coupler inserters
    if not storage.couplers or #storage.couplers == 0 then return end
    for i = 1, #storage.couplers do
        local coupler = storage.couplers[i]
        if coupler.train_id == train.id then
            local entity = coupler.entity
            if entity and entity.valid then
                local surface = entity.surface
                local position = entity.position
                local nearby_inserters = surface.find_entities_filtered{
                    name = "ftrainworks-coupler-inserter",
                    position = position,
                    radius = 2
                }

                -- Check if the inserters should perform their actions
                for _, inserter in ipairs(nearby_inserters) do
                    if inserter and inserter.valid then
                        -- Add to active list
                        storage.coupler_inserter_active[inserter] = {
                            train.id,
                            couple_signal = nil,
                            uncouple_signal = nil
                        }

                        -- Perform initial check
                        coupler_inserter_check_perform_action(inserter)
                    end
                end
            end
        end
    end
end

--[[
    Initialization and configuration events.
--]]
registry.register(defines.events.on_init, function(event)
    storage.coupler_inserter_active = {}
end)

registry.register(defines.events.on_configuration_changed, function(event)
    storage.coupler_inserter_active = storage.coupler_inserter_active or {}
end)

--[[
    Entity creation events.
--]]
registry.register({defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.on_space_platform_built_entity, defines.events.on_script_raised_built, defines.events.on_script_raised_revive}, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == "ftrainworks-coupler-inserter" then
        coupler_inserter_created(entity)
    end
end)

--[[
    Train state events.
--]]
registry.register(defines.events.on_train_changed_state, function(event)
    local train = event.train
    if not (train and train.valid) then return end
    local state = storage.train_state[train.id]
    if not state then return end -- If our mod hasn't registered the custom state, ignore
    if state.stopped then
        coupler_inserter_check_trains(train)
    else
        -- Remove from active inserter list
        for inserter, active_data in pairs(storage.coupler_inserter_active) do
            if active_data.train_id == train.id then
                storage.coupler_inserter_active[inserter] = nil
            end
        end
    end
end)

--[[
    Per-tick event.
--]]
local first_tick = true
registry.register(defines.events.on_tick, function(event)
    if first_tick then
        first_tick = false
        storage.coupler_inserter_active = storage.coupler_inserter_active or {}
    end

    -- If there are active inserters, process them
    for inserter, _ in pairs(storage.coupler_inserter_active) do
        -- I hate to perform this every tick but I don't know how else I'd respond to circuit changes
        coupler_inserter_check_perform_action(inserter)
    end
end)

-- Export various functions for internal API usage
return {
    coupler_inserter_created = coupler_inserter_created,
    coupler_inserter_perform = coupler_inserter_perform,
    coupler_inserter_check_perform_action = coupler_inserter_check_perform_action,
    coupler_inserter_check_trains = coupler_inserter_check_trains
}