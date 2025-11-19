--[[
    Dependencies.
--]]
local event_registry = require("script.registry")

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

local function connect_disconnect_rolling_stock(player, position, desired_state)
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
        player.surface.play_sound{ path = "ftrainworks-decouple", position = position }
    else
        if is_connected then return end
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
                -- if the coupler has settings, remove them too
                if storage.coupler_settings and storage.coupler_settings[coupler.entity] then
                    storage.coupler_settings[coupler.entity] = nil
                end
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
                    if storage.coupler_settings and storage.coupler_settings[coupler.entity] then
                        storage.coupler_settings[coupler.entity] = nil
                    end
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
            if storage.coupler_settings and storage.coupler_settings[coupler.entity] then
                storage.coupler_settings[coupler.entity] = nil
            end
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
    Coupler state functions.
--]]
local function coupler_perform_animation(coupler, player, position, action)
    if not (coupler and coupler.valid) then return end
    if storage.coupler_moving[coupler] then return end -- Already moving
    local surface = coupler.surface
    local pickup_position = coupler.pickup_position
    local drop_position = coupler.drop_position

    -- Fake item stack
    local dummy_stack = {
        name = "ftrainworks-coupler-target",
        count = 1
    }
    local pickup_dummy = surface.create_entity{
        name = "item-on-ground",
        position = pickup_position,
        stack = dummy_stack
    }
    local drop_dummy = surface.create_entity{
        name = "ftrainworks-coupler-target-container",
        position = drop_position,
        force = coupler.force
    }

    -- Assign the inserter targets
    coupler.pickup_target = pickup_dummy
    coupler.drop_target = drop_dummy
    coupler.active = true

    -- Queue cleanup
    storage.coupler_moving[coupler] = {
        pickup = pickup_dummy,
        drop = drop_dummy,
        player = player,
        position = position,
        action = action,
        state = 0,
        delay = 0
    }
end

local function coupler_perform_decouple(coupler, player, position)
    coupler_perform_animation(coupler, player, position, "decouple")
end

local function coupler_perform_couple(coupler, player, position)
    coupler_perform_animation(coupler, player, position, "couple")
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

local opened_coupler = nil

event_registry.register_init(function()
    storage.train_state = {}
    storage.couplers = {}
    storage.coupler_settings = {}
    storage.coupler_moving = storage.coupler_moving or {}
    storage.perform_train_cleanup = false
    reconcile_trains()
end)

event_registry.register_configuration_changed(function()
    storage.train_state = storage.train_state or {}
    storage.couplers = storage.couplers or {}
    storage.coupler_settings = storage.coupler_settings or {}
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
    elseif entity and entity.valid and entity.name == "ftrainworks-coupler-inserter" then
        -- Close GUI if open
        if opened_coupler == entity then
            for _, player in pairs(game.connected_players) do
                if player and player.valid then
                    if player.gui.screen["ftrainworks-coupler-inserter-gui"] then
                        player.gui.screen["ftrainworks-coupler-inserter-gui"].destroy()
                        opened_coupler = nil
                    end
                end
            end
        end

        -- Remove coupler settings
        if storage.coupler_settings and storage.coupler_settings[entity] then
            storage.coupler_settings[entity] = nil
        end

        -- Remove from coupler list
        for i = #storage.couplers, 1, -1 do
            local coupler = storage.couplers[i]
            if coupler.entity == entity then
                table.remove(storage.couplers, i)
            end
        end

        -- Remove from moving list
        if storage.coupler_moving and storage.coupler_moving[entity] then
            if storage.coupler_moving[entity].pickup and storage.coupler_moving[entity].pickup.valid then
                storage.coupler_moving[entity].pickup.destroy()
            end
            if storage.coupler_moving[entity].drop and storage.coupler_moving[entity].drop.valid then
                storage.coupler_moving[entity].drop.destroy()
            end
            storage.coupler_moving[entity] = nil
        end
    end
end)

--[[
    GUI event hooks.
--]]
script.on_event(defines.events.on_gui_opened, function(event)
    if true then return end -- Disable GUI for now
    if event.gui_type == defines.gui_type.entity then
        local entity = event.entity
        if entity and entity.valid and entity.name == "ftrainworks-coupler-inserter" then
            local player = game.get_player(event.player_index)
            if player and player.valid then
                player.opened = nil
                if player.gui.screen["ftrainworks-coupler-inserter-gui"] then
                    player.gui.screen["ftrainworks-coupler-inserter-gui"].destroy()
                    opened_coupler = nil
                end
                opened_coupler = entity

                -- Ensure settings exists
                if not storage.coupler_settings[opened_coupler] then
                    storage.coupler_settings[opened_coupler] = {
                        state = "always_decouple"
                    }
                end

                -- Create frame
                local ui_frame = player.gui.screen.add{
                    type = "frame",
                    name = "ftrainworks-coupler-inserter-gui",
                    direction = "vertical",
                    style = "inset_frame_container_frame"
                }
                ui_frame.style.size = {325, 265}
                ui_frame.auto_center = true
                player.opened = ui_frame

                local ui_titlebar = ui_frame.add{
                    type = "flow",
                    name = "titlebar",
                    direction = "horizontal"
                }
                ui_titlebar.style.horizontal_spacing = 8
                local ui_titlebar_label = ui_titlebar.add{
                    type = "label",
                    caption = entity.localised_name,
                    style = "frame_title",
                }
                ui_titlebar_label.ignored_by_interaction = true
                local ui_titlebar_drag = ui_titlebar.add{
                    type = "empty-widget",
                    style = "draggable_space_header"
                }
                ui_titlebar_drag.style.height = 24
                ui_titlebar_drag.style.horizontally_stretchable = true
                ui_titlebar_drag.style.right_margin = 4
                local ui_titlebar_close = ui_titlebar.add{
                    type = "sprite-button",
                    name = "coupler_close",
                    sprite = "utility/close",
                    hovered_sprite = "utility/close_black",
                    clicked_sprite = "utility/close_black",
                    style = "close_button"
                }

                local ui_content = ui_frame.add{
                    type = "flow",
                    name = "content",
                    direction = "vertical"
                }
                ui_content.style.vertical_spacing = 12

                local always_decouple_checkbox = ui_content.add{
                    type = "checkbox",
                    name = "coupler_always_decouple",
                    caption = "Always Decouple",
                    state = true -- Default to always decouple
                }

                local always_couple_checkbox = ui_content.add{
                    type = "checkbox",
                    name = "coupler_always_couple",
                    caption = "Always Couple",
                    state = false
                }

                local circuit_decouple_checkbox = ui_content.add{
                    type = "checkbox",
                    name = "coupler_circuit_decouple",
                    caption = "Decouple on Circuit Signal",
                    state = false
                }

                local circuit_couple_checkbox = ui_content.add{
                    type = "checkbox",
                    name = "coupler_circuit_couple",
                    caption = "Couple on Circuit Signal",
                    state = false
                }

                local test_button = ui_content.add{
                    type = "button",
                    name = "coupler_test_button",
                    caption = "Test Coupler Action"
                }
            end
        end
    end
end)

-- script.on_event(defines.events.on_gui_closed, function(event)
--     local player = game.get_player(event.player_index)
--     if not player or not player.valid then return end

--     -- Was it our GUI that closed?
--     if event.element and event.element.name == "ftrainworks-coupler-inserter-gui" then
--         local gui = player.gui.screen["ftrainworks-coupler-inserter-gui"]
--         if gui and gui.valid then
--             gui.destroy()
--             opened_coupler = nil
--         end
--     end
-- end)

script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    if element.name == "coupler_close" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            if player.gui.screen["ftrainworks-coupler-inserter-gui"] then
                player.gui.screen["ftrainworks-coupler-inserter-gui"].destroy()
                opened_coupler = nil
            end
        end
    elseif element.name == "coupler_test_button" then
        -- local player = game.get_player(event.player_index)
        -- if not (player and player.valid) then return end
        -- if opened_coupler == nil then return end
        -- local settings = storage.coupler_settings[opened_coupler]
        -- if not settings then return end
        -- if settings.state == "always_couple" then
        --     coupler_perform_couple(opened_coupler, player, opened_coupler.position)
        -- elseif settings.state == "always_decouple" then
        --     coupler_perform_decouple(opened_coupler, player, opened_coupler.position)
        -- end
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local element = event.element
    if not (element and element.valid) then return end

    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    if opened_coupler == nil then return end

    -- Ensure settings exists
    if not storage.coupler_settings[opened_coupler] then
        storage.coupler_settings[opened_coupler] = {
            state = "always_decouple"
        }
    end

    -- Mutual exclusivity of checkboxes
    local name = element.name
    local state = element.state
    local parent = element.parent
    local settings = storage.coupler_settings[opened_coupler]
    if name == "coupler_always_decouple" then
        if state == true then
            settings.state = "always_decouple"

            -- Remove all other checkbox states
            parent["coupler_always_couple"].state = false
            parent["coupler_circuit_decouple"].state = false
            parent["coupler_circuit_couple"].state = false
        end
    end
    if name == "coupler_always_couple" then
        if state == true then
            settings.state = "always_couple"

            -- Remove all other checkbox states
            parent["coupler_always_decouple"].state = false
            parent["coupler_circuit_decouple"].state = false
            parent["coupler_circuit_couple"].state = false
        end
    end
    if name == "coupler_circuit_decouple" then
        if state == true then
            if settings.state == "circuit_couple" then
                settings.state = "circuit_decouple_couple"
            else
                settings.state = "circuit_decouple"
            end

            -- Remove 'always' checkbox states
            parent["coupler_always_decouple"].state = false
            parent["coupler_always_couple"].state = false
        else
            -- If unchecked but we are also circuit_coupling, revert to that state
            if settings.state == "circuit_decouple_couple" then
                settings.state = "circuit_couple"
                parent["coupler_circuit_couple"].state = true
            end
        end
    end
    if name == "coupler_circuit_couple" then
        if state == true then
            if settings.state == "circuit_decouple" then
                settings.state = "circuit_decouple_couple"
            else
                settings.state = "circuit_couple"
            end

            -- Remove 'always' checkbox states
            parent["coupler_always_decouple"].state = false
            parent["coupler_always_couple"].state = false
        else
            -- If unchecked but we are also circuit_decoupling, revert to that state
            if settings.state == "circuit_decouple_couple" then
                settings.state = "circuit_decouple"
                parent["coupler_circuit_decouple"].state = true
            end
        end
    end

    -- Check for invalid state (neither always checked, nor one of the circuit options)
    if not (parent["coupler_always_decouple"].state or parent["coupler_always_couple"].state or parent["coupler_circuit_decouple"].state or parent["coupler_circuit_couple"].state) then
        -- Default to always decouple
        settings.state = "always_decouple"
        parent["coupler_always_decouple"].state = true
    end
end)

--[[
    Tick event hook for deferred train cleanup.
--]]

local first_tick = true

event_registry.register_tick(function(event)
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
        storage.coupler_settings = storage.coupler_settings or {}
        storage.coupler_moving = storage.coupler_moving or {}
        storage.perform_train_cleanup = storage.perform_train_cleanup or false
        return
    end

    for coupler, entry in pairs(storage.coupler_moving) do
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
                    connect_disconnect_rolling_stock(entry.player, entry.position, true)
                elseif entry.action == "decouple" then
                    connect_disconnect_rolling_stock(entry.player, entry.position, false)
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
                    storage.coupler_moving[coupler] = nil
                end
            end
        else
            if entry.pickup and entry.pickup.valid then entry.pickup.destroy() end
            if entry.drop and entry.drop.valid then entry.drop.destroy() end
            storage.coupler_moving[coupler] = nil
        end
    end
end)
