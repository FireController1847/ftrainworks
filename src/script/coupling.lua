local registry = require("script.registry")

--[[
    Utility methods.
--]]

-- Determine if an entity is rolling stock (locomotive or wagon)
local function is_entity_rolling_stock(entity)
    if not (entity and entity.valid) then return false end
    if not entity.train then return false end
    if entity.type == "locomotive" or entity.type:sub(-6) == "-wagon" then
        return true
    else
        return false
    end
end

-- Calculate the back center position of a carriage given its bounding box, coupler bounding box, and orientation
local function back_center(carriage_box, coupler_box, orientation)
    -- Calculate centers and sizes
    local car_x = (carriage_box.left_top.x + carriage_box.right_bottom.x) / 2
    local car_y = (carriage_box.left_top.y + carriage_box.right_bottom.y) / 2
    local width  = carriage_box.right_bottom.x - carriage_box.left_top.x
    local height = carriage_box.right_bottom.y - carriage_box.left_top.y
    local car_len = math.max(width, height) / 2
    local cup_len = math.max(coupler_box.right_bottom.x - coupler_box.left_top.x, coupler_box.right_bottom.y - coupler_box.left_top.y) / 2

    -- Base direction
    local fx, fy = 0, 1

    -- Apply orientation as a rotation
    local angle = orientation * 2 * math.pi
    local cos_a, sin_a = math.cos(angle), math.sin(angle)
    local rfx = fx * cos_a - fy * sin_a
    local rfy = fx * sin_a + fy * cos_a

    -- Return position
    return {
        x = car_x - rfx * (car_len + cup_len),
        y = car_y - rfy * (car_len + cup_len)
    }
end

-- Checks if the two nearest carriages to a position are connected (returns nil if not enough carriages found)
local function are_nearest_carriages_connected(surface, position, radius)
    -- Find nearby entities
    local nearby = surface.find_entities_filtered{
        area = {
            { position.x - radius, position.y - radius },
            { position.x + radius, position.y + radius }
        }
    }

    -- Collect rolling stock only
    local carriages = {}
    for _, entity in pairs(nearby) do
        if entity and entity.valid and entity.train and is_entity_rolling_stock(entity) then
            carriages[#carriages + 1] = entity
        end
    end

    -- Need at least two carriages to check connection
    if #carriages < 2 then return nil end

    -- Sort by squared distance to avoid math.sqrt
    table.sort(carriages, function(a, b)
        local ax = a.position.x - position.x
        local ay = a.position.y - position.y
        local bx = b.position.x - position.x
        local by = b.position.y - position.y
        return (ax*ax + ay*ay) < (bx*bx + by*by)
    end)

    local carriage1 = carriages[1]
    local carriage2 = carriages[2]

    if not (carriage1.valid and carriage2.valid) then
        return nil
    end

    -- Check connections
    local front_connected = carriage1.get_connected_rolling_stock(defines.rail_direction.front)
    local back_connected  = carriage1.get_connected_rolling_stock(defines.rail_direction.back)

    local is_connected =
        (front_connected and front_connected == carriage2) or
        (back_connected and back_connected == carriage2)

    return is_connected
end

-- Connects or disconnects a rolling stock near a position based on desired state
local function connect_disconnect_rolling_stock(surface, position, desired_state)
    local nearby = surface.find_entities_filtered{
        area = {
            {position.x - 2.5, position.y - 2.5},
            {position.x + 2.5, position.y + 2.5}
        }
    }

    -- Find all carriages in the area
    local carriages = {}
    for _, entity in pairs(nearby) do
        if entity and entity.valid and entity.train and is_entity_rolling_stock(entity) then
            table.insert(carriages, entity)
        end
    end
    if #carriages < 2 then return end

    -- Sort by distance to the coupler
    table.sort(carriages, function(a, b)
        local da = (a.position.x - position.x)^2 + (a.position.y - position.y)^2
        local db = (b.position.x - position.x)^2 + (b.position.y - position.y)^2
        return da < db
    end)

    -- Determine relative direction
    local carriage1, carriage2 = carriages[1], carriages[2]
    if not carriage1.valid or not carriage2.valid then return end
    local front_connected = carriage1.get_connected_rolling_stock(defines.rail_direction.front)
    local back_connected  = carriage1.get_connected_rolling_stock(defines.rail_direction.back)

    local is_connected =
        (front_connected and front_connected == carriage2) or
        (back_connected and back_connected == carriage2)

    -- Decide action based on desired_state
    local should_disconnect
    if desired_state == nil then
        -- toggle
        should_disconnect = is_connected
    else
        -- explicit couple / uncouple
        should_disconnect = (desired_state == false)
    end

    if should_disconnect then
        if front_connected and (front_connected == carriage2) then
            carriage1.disconnect_rolling_stock(defines.rail_direction.front)
        elseif back_connected and (back_connected == carriage2) then
            carriage1.disconnect_rolling_stock(defines.rail_direction.back)
        else
            return
        end
        surface.play_sound{ path = "ftrainworks-decouple", position = position }
    else
        if is_connected then return end
        if not carriage1.connect_rolling_stock(defines.rail_direction.front) then
            if not carriage1.connect_rolling_stock(defines.rail_direction.back) then
                player.print("Failed to connect carriages.")
                return
            end
        end
        surface.play_sound{ path = "ftrainworks-couple", position = position }
    end
end

--[[
    Coupler lifecycle methods.
--]]

-- Creates a new coupler for a train carriage at a specified position
local function create_train_coupler(train, carriage, position, front)
    -- Check for existing couplers
    for j, coupler in ipairs(storage.couplers) do
        if coupler.train_id == train.id and coupler.carriage_unit_number == carriage.unit_number and coupler.front == front then
            if coupler.entity and coupler.entity.valid then
                return -- Coupler already exists
            else
                table.remove(storage.couplers, j) -- Remove invalid coupler record
                break
            end
        end
    end

    -- Create new coupler
    local coupler_entity = carriage.surface.create_entity{
        name = "ftrainworks-coupler",
        position = position,
        force = carriage.force
    }
    table.insert(storage.couplers, {
        train_id = train.id,
        carriage_unit_number = carriage.unit_number,
        front = front,
        entity = coupler_entity
    })
end

-- Creates couplers for all carriages in a train
local function create_train_couplers(train)
    local carriages = train.carriages
    for i = 1, #carriages do
        local carriage = carriages[i]
        if carriage and carriage.valid then
            -- Adjust orientation if this carriage is flipped relative to the next one
            local orientation = carriage.orientation
            local next = carriages[i+1]
            if next then
                if carriage.get_connected_rolling_stock(defines.rail_direction.back) == next then
                    orientation = (orientation + 0.5) % 1
                end
            end

            local carriage_box = carriage.selection_box
            local coupler_box  = prototypes.entity["ftrainworks-coupler"].selection_box
            local pos_back = back_center(carriage_box, coupler_box, orientation)

            -- Back coupler always
            create_train_coupler(train, carriage, pos_back, "back")

            -- Extra front coupler for *first* carriage
            if i == 1 then
                -- Mirror the back position across the carriage center to get the front
                local car_x = (carriage_box.left_top.x + carriage_box.right_bottom.x) / 2
                local car_y = (carriage_box.left_top.y + carriage_box.right_bottom.y) / 2
                local pos_front = { x = 2 * car_x - pos_back.x, y = 2 * car_y - pos_back.y }
                create_train_coupler(train, carriage, pos_front, "front")
            end
        end
    end
end

-- Removes couplers associated with a train
local function remove_train_couplers(train)
    if not train or not train.valid then return end
    local carriages = train.carriages
    for _, carriage in pairs(carriages) do
        if carriage and carriage.valid then
            for i = #storage.couplers, 1, -1 do
                local coupler = storage.couplers[i]
                if coupler.train_id == train.id and coupler.carriage_unit_number == carriage.unit_number then
                    if coupler.entity and coupler.entity.valid then
                        coupler.entity.destroy()
                    end
                    table.remove(storage.couplers, i)
                end
            end
        end
    end
end

-- Removes all couplers associated with a train by train ID
local function remove_train_all_couplers(train_id)
    if not train_id then return end
    for i = #storage.couplers, 1, -1 do
        local coupler = storage.couplers[i]
        if coupler.train_id == train_id then
            if coupler.entity and coupler.entity.valid then
                coupler.entity.destroy()
            end
            table.remove(storage.couplers, i)
        end
    end
end

--[[
    Train state methods.
--]]

-- Updates the stored state of a train and manages couplers accordingly
local function update_train_state(train)
    if not train or not train.valid then return end
    local state = {
        stopped = train.speed == 0,
        tick = game.tick
    };
    storage.train_state[train.id] = state;

    -- Update couplers if needed
    if state.stopped then
        create_train_couplers(train)
    else
        remove_train_couplers(train)
    end
end

-- Adds a train to the tracking system and updates its state
local function add_train(train)
    update_train_state(train)
end

-- Removes a train from the tracking system and deletes its couplers
local function remove_train(id)
    if not id or not storage.train_state[id] then return end
    storage.train_state[id] = nil
    remove_train_all_couplers(id)
end

--[[
    Initialization and configuration events.
--]]
local function reconcile_trains()
    for _, train in pairs(game.train_manager.get_trains({})) do
        if train and train.valid then
            if not storage.train_state[train.id] then
                add_train(train)
            end
        end
    end
end

registry.register(defines.events.on_init, function(event)
    storage.train_state = {}
    storage.couplers = {}
    storage.coupler_inserter_moving = storage.coupler_inserter_moving or {}
    storage.perform_train_cleanup = false
    reconcile_trains()
end)

registry.register(defines.events.on_configuration_changed, function(event)
    storage.train_state = storage.train_state or {}
    storage.couplers = storage.couplers or {}
    storage.coupler_inserter_moving = storage.coupler_inserter_moving or {}
    storage.perform_train_cleanup = storage.perform_train_cleanup or false
    reconcile_trains()
end)

--[[
    Left-click control event.
--]]
registry.register("ftrainworks-left-click", function(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    local selected = player.selected
    if not (selected and selected.valid) then return end
    if selected.name == "ftrainworks-coupler" then
        connect_disconnect_rolling_stock(player.surface, selected.position)
    end
end)

--[[
    Train state events.
--]]
registry.register(defines.events.on_train_changed_state, function(event)
    local train = event.train
    if not (train and train.valid) then return end
    update_train_state(train)
end)

registry.register(defines.events.on_train_created, function(event)
    if event.old_train_id_1 and storage.train_state[event.old_train_id_1] then
        remove_train(event.old_train_id_1)
    end
    if event.old_train_id_2 and storage.train_state[event.old_train_id_2] then
        remove_train(event.old_train_id_2)
    end
    add_train(event.train)
end)

registry.register({defines.events.on_entity_died, defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.on_script_raised_destroy}, function(event)
    local entity = event.entity
    if entity and is_entity_rolling_stock(entity) then
        storage.perform_train_cleanup = true
    end
end)

--[[
    Per-tick event.
--]]
local first_tick = true
registry.register(defines.events.on_tick, function(event)
    if storage.perform_train_cleanup then
        storage.perform_train_cleanup = false
        for id,_ in pairs(storage.train_state) do
            local train = game.train_manager.get_train_by_id(id)
            if (not train or not train.valid) or (#train.carriages == 0) then
                remove_train(id)
            end
        end
    end

    if first_tick then
        first_tick = false
        storage.train_state = storage.train_state or {}
        storage.couplers = storage.couplers or {}
        storage.coupler_inserter_moving = storage.coupler_inserter_moving or {}
        storage.perform_train_cleanup = storage.perform_train_cleanup or false
        reconcile_trains()
    end

    -- Perform animations for moving coupler inserters
    for coupler, entry in pairs(storage.coupler_inserter_moving) do
        if coupler and coupler.valid then
            -- Use state to determine action
            if entry.state == 0 then
                local target_position = coupler.drop_position
                local stack_position = coupler.held_stack_position
                local dist_sq = (stack_position.x - target_position.x) ^ 2 + (stack_position.y - target_position.y) ^ 2
                if dist_sq == 0 then
                    coupler.active = false
                    entry.state = 1 -- pasued at pickup

                    -- Determine energy state
                    local energy = coupler.energy
                    local stored = coupler.electric_buffer_size
                    local ratio = energy / stored
                    local wait
                    if (ratio == 1) then
                        wait = 0 -- fully charged, no wait
                    else
                        wait = 15 * (1 - ratio) -- wait longer if energy is low
                    end
                    entry.delay = game.tick + wait -- wait based on energy level
                end
            elseif entry.state == 1 and game.tick >= entry.delay then
                -- Perform the action
                if entry.action == "couple" then
                    connect_disconnect_rolling_stock(entry.surface, entry.position, true)
                elseif entry.action == "uncouple" then
                    connect_disconnect_rolling_stock(entry.surface, entry.position, false)
                end

                -- Delay again
                entry.state = 2 -- paused at drop
                entry.delay = game.tick + 5 -- delay for sound effect
            elseif entry.state == 2 and game.tick >= entry.delay then
                -- Resume movement
                coupler.active = true
                entry.state = 3 -- moving back to drop
            elseif entry.state == 3 then
                local target_position = coupler.pickup_position
                local stack_position = coupler.held_stack_position
                local dist_sq = (stack_position.x - target_position.x) ^ 2 + (stack_position.y - target_position.y) ^ 2
                if dist_sq == 0 then
                    -- Cleanup
                    if entry.pickup and entry.pickup.valid then entry.pickup.destroy() end
                    if entry.drop and entry.drop.valid then entry.drop.destroy() end
                    coupler.pickup_target = nil
                    coupler.drop_target = nil
                    coupler.active = false
                    storage.coupler_inserter_moving[coupler] = nil
                end
            end
        else
            if entry.pickup and entry.pickup.valid then entry.pickup.destroy() end
            if entry.drop and entry.drop.valid then entry.drop.destroy() end
            storage.coupler_inserter_moving[coupler] = nil
        end
    end
end)

-- Export various functions for internal API usage
return {
    is_entity_rolling_stock = is_entity_rolling_stock,
    back_center = back_center,
    are_nearest_carriages_connected = are_nearest_carriages_connected,
    connect_disconnect_rolling_stock = connect_disconnect_rolling_stock,
    create_train_coupler = create_train_coupler,
    create_train_couplers = create_train_couplers,
    remove_train_couplers = remove_train_couplers,
    remove_train_all_couplers = remove_train_all_couplers,
    update_train_state = update_train_state,
    add_train = add_train,
    remove_train = remove_train
}