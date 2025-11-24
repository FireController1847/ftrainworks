local registry = require("script.registry")
local trains = require("script.trains")
local util = require("script.util")

----------------------------
-- USED STORAGE VARIABLES --
----------------------------
-- storage.coupler_inserters: Table of all coupler inserter entities indexed by unit number.
----------------------------

---@alias ActiveInserterData {train:LuaTrain, carriage1:LuaEntity, carriage2:LuaEntity, coupler:LuaEntity, inserter:LuaEntity}
local active_inserters = {} ---@type table<uint64, ActiveInserterData> -- All active inserters with detected carriages indexed by inserters unit number.

---@alias AnimatingInserterData {state: number, delay: number, action: string, pickup: LuaEntity, drop: LuaEntity, train: LuaTrain, inserter:LuaEntity}
local animating_inserters = {} ---@type table<uint64, AnimatingInserterData> -- All inserters currently animating indexed by inserters unit number.

--[[
    Data storage functions.
--]]

---Creates the data structure for an inserter in storage.
---Does not perform any validation.
---@param inserter_unit_number uint64 The inserter entity unit number.
local function create_inserter_data(inserter_unit_number)
    storage.inserters = storage.inserters or {}
    table.insert(storage.inserters, inserter_unit_number)
end

---Validates that the data structure for an inserter exists in storage.
---If it does not exist, it is created.
---@param inserter_unit_number uint64 The inserter entity unit number.
local function validate_inserter_data(inserter_unit_number)
    storage.inserters = storage.inserters or {}
    for _, unit_number in ipairs(storage.inserters) do
        if unit_number == inserter_unit_number then
            return
        end
    end
    table.insert(storage.inserters, inserter_unit_number)
end

---Removes the data structure for an inserter from storage.
---Does not perform any validation.
---@param inserter_unit_number uint64 The inserter entity unit number.
local function remove_inserter_data(inserter_unit_number)
    if not storage.inserters then return end
    for index, unit_number in ipairs(storage.inserters) do
        if unit_number == inserter_unit_number then
            table.remove(storage.inserters, index)
            return
        end
    end
end

--[[
    Inserter functions.
--]]

---Activates inserters for a train by checking which inserters are near its carriages.
---@param train LuaTrain The train to check for nearby inserters.
local function activate_inserters(train)
    if not (train and train.valid) then return end
    for _, carriage in pairs(train.carriages) do
        local nearby_inserters = util.find_nearest_inserters(carriage.surface, carriage.position, 6)
        for _, inserter in pairs(nearby_inserters) do
            -- Validate inserter data
            validate_inserter_data(inserter.unit_number)

            -- It seems like extra work, but now we're going to find nearby carriages
            -- and the coupler for this inserter to validate it can work.
            local nearby_carriages = util.find_nearest_carriages(inserter.surface, inserter.drop_position, 6)
            if not nearby_carriages then return end
            if #nearby_carriages < 2 then return end
            local nearby_couplers = util.find_nearest_couplers(inserter.surface, inserter.drop_position, 2)
            if nearby_couplers and #nearby_couplers > 0 then
                active_inserters[inserter.unit_number] = {
                    train = train,
                    carriage1 = nearby_carriages[1],
                    carriage2 = nearby_carriages[2],
                    coupler = nearby_couplers[1],
                    inserter = inserter
                }
            end
        end
    end
end

---Deactivates an inserter.
---@param inserter_unit_number uint64 The inserter entity unit number.
---@param inserter LuaEntity The inserter entity.
local function deactivate_inserter(inserter_unit_number, inserter)
    active_inserters[inserter_unit_number] = nil
end

---@param inserter_unit_number uint64 The inserter entity unit number.
---@param active_inserter_data ActiveInserterData The active inserter data.
local function inserter_check_tick(inserter_unit_number, active_inserter_data)
    -- Validate inserter
    local inserter = active_inserter_data.inserter
    if not (inserter and inserter.valid) then
        remove_inserter_data(inserter_unit_number)
        deactivate_inserter(inserter_unit_number, inserter)
        return
    end

    -- Validate carriage
    local carriage1 = active_inserter_data.carriage1
    local carriage2 = active_inserter_data.carriage2
    if not (carriage1 and carriage1.valid) then
        deactivate_inserter(inserter_unit_number, inserter)
        return
    end
    if not (carriage2 and carriage2.valid) then
        deactivate_inserter(inserter_unit_number, inserter)
        return
    end

    -- Validate train 1
    local train1 = carriage1.train
    if not (train1 and train1.valid) then
        -- Invalid state? Can a carriage exist without a train?
        deactivate_inserter(inserter_unit_number, inserter)
        return
    end
    if train1.speed ~= 0 then
        -- Train is moving; deactivate inserter.
        deactivate_inserter(inserter_unit_number, inserter)
        return
    end
    if train1.id ~= train1.id then
        -- Carriage is no longer part of the same train; update inserter data.
        active_inserter_data.train = train1
        active_inserters[inserter_unit_number] = active_inserter_data
    end

    -- Validate train 2
    local train2 = carriage2.train
    if not (train2 and train2.valid) then
        -- Invalid state? Can a carriage exist without a train?
        deactivate_inserter(inserter_unit_number, inserter)
        return
    end
    if train2.speed ~= 0 then
        -- Train is moving; deactivate inserter.
        deactivate_inserter(inserter_unit_number, inserter)
        return
    end
    if train2.id ~= train2.id then
        -- Carriage is no longer part of the same train; update inserter data.
        active_inserter_data.train = train2
        active_inserters[inserter_unit_number] = active_inserter_data
    end

    -- Validate coupler
    local coupler = active_inserter_data.coupler
    if not (coupler and coupler.valid) then
        deactivate_inserter(inserter_unit_number, inserter)
        return
    end

    -- Fetch circuit signal
    local couple_signal = inserter.get_signal({
        type = "virtual",
        name = "ftrainworks-signal-couple"
    }, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
    local uncouple_signal = inserter.get_signal({
        type = "virtual",
        name = "ftrainworks-signal-uncouple"
    }, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    -- If no signals, do nothing
    -- If both signals, determine based on set priority
    -- If one signal, perform that action
    local determined_action = nil
    if couple_signal == 0 and uncouple_signal == 0 then
        return
    elseif couple_signal > 0 and uncouple_signal > 0 then
        local filter_slot_1 = inserter.get_filter(1)
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
        local is_connected = util.are_carriages_connected(carriage1, carriage2)
        if (determined_action == "couple" and is_connected) or (determined_action == "uncouple" and not is_connected) then
            return
        end

        -- Start animating inserter
        deactivate_inserter(inserter_unit_number, inserter)
        local animating_data = {
            state = 0, -- moving to drop
            delay = 0,
            action = determined_action,
            pickup = nil,
            drop = nil,
            train = nil,
            inserter = inserter
        }
        local surface = inserter.surface
        local pickup_position = inserter.pickup_position
        local drop_position = inserter.drop_position

        -- If the inserter already has a pickup target and drop target,
        -- destroy them first.
        local item_on_ground = inserter.pickup_target
        if item_on_ground and item_on_ground.valid and item_on_ground.name == "item-on-ground" then
            if item_on_ground.stack and item_on_ground.stack.valid and item_on_ground.stack.name == "ftrainworks-coupler-stack" then
                item_on_ground.destroy()
            end
        end
        if inserter.drop_target and inserter.drop_target.valid and inserter.drop_target.name == "ftrainworks-coupler-container" then
            inserter.drop_target.destroy()
        end

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
        animating_data.pickup = pickup_dummy
        local drop_dummy = surface.create_entity{
            name = "ftrainworks-coupler-container",
            position = drop_position,
            force = inserter.force
        }
        animating_data.drop = drop_dummy

        inserter.pickup_target = pickup_dummy
        inserter.drop_target = drop_dummy
        inserter.active = true
        animating_inserters[inserter_unit_number] = animating_data
    end
end

---Animates an inserter on each tick.
---@param inserter_unit_number uint64 The inserter entity unit number.
---@param animating_inserter_data AnimatingInserterData The animating inserter data.
local function inserter_animate_tick(inserter_unit_number, animating_inserter_data)
    local inserter = animating_inserter_data.inserter
    if not (inserter and inserter.valid) then return end

    local updated_data = false
    if animating_inserter_data.state == 0 then
        local target_position = inserter.drop_position
        local stack_position = inserter.held_stack_position
        local dist_sq = (stack_position.x - target_position.x) ^ 2 + (stack_position.y - target_position.y) ^ 2
        if dist_sq == 0 then
            inserter.active = false
            animating_inserter_data.state = 1 -- pasued at pickup

            -- Determine energy state
            local energy = inserter.energy
            local stored = inserter.electric_buffer_size
            local ratio = energy / stored
            local wait
            if (ratio == 1) then
                wait = 0 -- fully charged, no wait
            else
                wait = 15 * (1 - ratio) -- wait longer if energy is low
            end
            animating_inserter_data.delay = game.tick + wait -- wait based on energy level
        end
    elseif animating_inserter_data.state == 1 and game.tick >= animating_inserter_data.delay then
        -- Perform the action
        if animating_inserter_data.action == "couple" then
            local carriages = util.find_nearest_carriages(inserter.surface, inserter.drop_position, 6)
            local carriage1 = carriages and carriages[1]
            local carriage2 = carriages and carriages[2]
            if carriages and #carriages >= 2 then
                trains.invalidate_carriage_couplers(carriage1)
                trains.invalidate_carriage_couplers(carriage2)
                util.connect_disconnect_carriages(carriage1, carriage2, inserter.surface, inserter.position, "connect")
                trains.validate_carriage_couplers(carriage1)
                trains.validate_carriage_couplers(carriage2)

                -- choose one to assign the train
                animating_inserter_data.train = carriage1.train
            end
        elseif animating_inserter_data.action == "uncouple" then
            local carriages = util.find_nearest_carriages(inserter.surface, inserter.drop_position, 6)
            local carriage1 = carriages and carriages[1]
            local carriage2 = carriages and carriages[2]
            if carriages and #carriages >= 2 then
                trains.invalidate_carriage_couplers(carriage1)
                trains.invalidate_carriage_couplers(carriage2)
                util.connect_disconnect_carriages(carriage1, carriage2, inserter.surface, inserter.position, "disconnect")
                trains.validate_carriage_couplers(carriage1)
                trains.validate_carriage_couplers(carriage2)

                -- choose one to assign the train
                animating_inserter_data.train = carriage1.train
            end
        end

        -- Delay again
        animating_inserter_data.state = 2 -- paused at drop
        animating_inserter_data.delay = game.tick + 5 -- delay for sound effect
    elseif animating_inserter_data.state == 2 and game.tick >= animating_inserter_data.delay then
        -- Resume movement
        inserter.active = true
        animating_inserter_data.state = 3 -- moving back to drop
    elseif animating_inserter_data.state == 3 then
        local target_position = inserter.pickup_position
        local stack_position = inserter.held_stack_position
        local dist_sq = (stack_position.x - target_position.x) ^ 2 + (stack_position.y - target_position.y) ^ 2
        if dist_sq == 0 then
            -- Cleanup
            if animating_inserter_data.pickup and animating_inserter_data.pickup.valid then animating_inserter_data.pickup.destroy() end
            if animating_inserter_data.drop and animating_inserter_data.drop.valid then animating_inserter_data.drop.destroy() end
            inserter.pickup_target = nil
            inserter.drop_target = nil
            inserter.active = false
            animating_inserters[inserter_unit_number] = nil

            -- Check if it should be re-activated
            activate_inserters(animating_inserter_data.train)
        end
    end
    if updated_data then
        animating_inserters[inserter_unit_number] = animating_inserter_data
    end
end

--[[
    Inserter event handlers.
--]]

---Handler for when a inserter is built.
---@param inserter LuaEntity The inserter entity.
local function on_inserter_built(inserter)
    create_inserter_data(inserter.unit_number)

    -- Check if a train is nearby
    local nearby_carriages = util.find_nearest_carriages(inserter.surface, inserter.position, 5)
    if not nearby_carriages then return end
    if #nearby_carriages == 0 then return end
    local closest_carriage = nearby_carriages[1]
    activate_inserters(closest_carriage.train)
end

---Handler for when a inserter is removed.
---@param inserter LuaEntity The inserter entity.
local function on_inserter_removed(inserter)
    active_inserters[inserter.unit_number] = nil
    remove_inserter_data(inserter.unit_number)
end

--[[
    Train state event handlers.
--]]

---Handler for when a train is created.
---@param train LuaTrain The train that was created.
local function on_train_created(train)
    -- When a train is created, check for nearby inserters to activate.
    activate_inserters(train)
end

---Handler for when a train's state changes.
---@param train LuaTrain The train whose state has changed.
local function on_train_state_changed(train)
    if train.speed == 0 then
        -- Train is stopped, find inserters which should be activated.
        activate_inserters(train)
    else
        -- Inserters deactivate themselves when the train starts moving.
    end
end

--[[
    Registry event handlers.
--]]

---@param event EventData.on_built_entity
registry.register(defines.events.on_built_entity, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == "ftrainworks-coupler-inserter" then
        on_inserter_built(entity)
    end
end)

---@param event EventData.on_robot_built_entity
registry.register(defines.events.on_robot_built_entity, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == "ftrainworks-coupler-inserter" then
        on_inserter_built(entity)
    end
end)

---@param event EventData.script_raised_built
registry.register(defines.events.script_raised_built, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == "ftrainworks-coupler-inserter" then
        on_inserter_built(entity)
    end
end)

---@param event EventData.on_entity_died
registry.register(defines.events.on_entity_died, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == "ftrainworks-coupler-inserter" then
        on_inserter_removed(entity)
    end
end)

---@param event EventData.on_player_mined_entity
registry.register(defines.events.on_player_mined_entity, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == "ftrainworks-coupler-inserter" then
        on_inserter_removed(entity)
    end
end)

---@param event EventData.on_robot_mined_entity
registry.register(defines.events.on_robot_mined_entity, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == "ftrainworks-coupler-inserter" then
        on_inserter_removed(entity)
    end
end)

---@param event EventData.script_raised_destroy
registry.register(defines.events.script_raised_destroy, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == "ftrainworks-coupler-inserter" then
        on_inserter_removed(entity)
    end
end)

---@param event EventData.on_train_created
registry.register(defines.events.on_train_created, function(event)
    local train = event.train
    if not (train and train.valid) then return end
    on_train_created(train)
end)

---@param event EventData.on_train_changed_state
registry.register(defines.events.on_train_changed_state, function(event)
    local train = event.train
    if not (train and train.valid) then return end
    on_train_state_changed(train)
end)

local first_tick = true
---@param event EventData.on_tick
registry.register(defines.events.on_tick, function(event)
    if first_tick then
        first_tick = false

        -- Activate inserters for all existing trains.
        for _, train in ipairs(game.train_manager.get_trains{}) do
            if train.speed == 0 then
                activate_inserters(train)
            end
        end
    end

    for inserter_unit_number, animating_inserter_data in pairs(animating_inserters) do
        inserter_animate_tick(inserter_unit_number, animating_inserter_data)
    end
end)

registry.register_nth_tick(35, function()
    for inserter_unit_number, active_inserter_data in pairs(active_inserters) do
        inserter_check_tick(inserter_unit_number, active_inserter_data)
    end
end)