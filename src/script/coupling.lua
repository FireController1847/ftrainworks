--[[
    Utility functions.
--]]

local function is_entity_rolling_stock(entity)
    if not entity or not entity.valid then return false end
    if not entity.train then return false end
    if entity.type == "locomotive" or entity.type:sub(-6) == "-wagon" then
        return true
    end
    return false
end

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

local function connect_disconnect_rolling_stock(player, position)
    local nearby = player.surface.find_entities_filtered{
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

    if front_connected and (front_connected == carriage2) then
        carriage1.disconnect_rolling_stock(defines.rail_direction.front)
        player.surface.play_sound{ path = "ftrainworks-decouple", position = position }
    elseif back_connected and (back_connected == carriage2) then
        carriage1.disconnect_rolling_stock(defines.rail_direction.back)
        player.surface.play_sound{ path = "ftrainworks-decouple", position = position }
    else
        if not carriage1.connect_rolling_stock(defines.rail_direction.front) then
            if not carriage1.connect_rolling_stock(defines.rail_direction.back) then
                player.print("Failed to connect carriages.")
                return
            end
        end
        player.surface.play_sound{ path = "ftrainworks-couple", position = position }
    end
end

--[[
    Coupler lifecycle functions.
--]]

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
    Train state functions.
--]]

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

local function add_train(train)
    update_train_state(train)
end

local function remove_train(id)
    if not id or not storage.train_state[id] then return end
    storage.train_state[id] = nil
    remove_train_all_couplers(id)
end

--[[
    Initialization and configuration.
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

script.on_init(function()
    storage.train_state = {}
    storage.couplers = {}
    storage.perform_train_cleanup = false
    reconcile_trains()
end)

script.on_configuration_changed(function()
    storage.train_state = storage.train_state or {}
    storage.couplers = storage.couplers or {}
    storage.perform_train_cleanup = storage.perform_train_cleanup or false
    reconcile_trains()
end)

--[[
    Left-click control event hook.
--]]

script.on_event("ftrainworks-left-click", function(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    local selected = player.selected
    if not (selected and selected.valid) then return end
    if selected.name == "ftrainworks-coupler" then
        connect_disconnect_rolling_stock(player, selected.position)
    end
end)

--[[
    Train state event hooks.
--]]

script.on_event(defines.events.on_train_changed_state, function(event)
    local train = event.train
    if not (train and train.valid) then return end
    update_train_state(train)
end)

script.on_event(defines.events.on_train_created, function(event)
    if event.old_train_id_1 and storage.train_state[event.old_train_id_1] then
        remove_train(event.old_train_id_1)
    end
    if event.old_train_id_2 and storage.train_state[event.old_train_id_2] then
        remove_train(event.old_train_id_2)
    end
    add_train(event.train)
end)

script.on_event({defines.events.on_entity_died, defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity}, function(event)
    local entity = event.entity
    if entity and is_entity_rolling_stock(entity) then
        storage.perform_train_cleanup = true
    end
end)

--[[
    Tick event hook for deferred train cleanup.
--]]

script.on_event(defines.events.on_tick, function(event)
    if not storage.perform_train_cleanup then return end

    for id,_ in pairs(storage.train_state) do
        local train = game.train_manager.get_train_by_id(id)
        if (not train or not train.valid) or (#train.carriages == 0) then
            remove_train(id)
        end
    end

    storage.perform_train_cleanup = false
end)
