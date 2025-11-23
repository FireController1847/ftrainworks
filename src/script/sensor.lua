local registry = require("script.registry")
local coupling = require("script.coupling")

--[[
    Sensor event handlers.
--]]
local function train_sensor_check_perform_action(entity)
    -- START HIGH-PERFORMANT CODE --

    if not (entity and entity.valid) then return end
    local active_data = storage.sensor_active and storage.sensor_active[entity]
    if not active_data then return end
    local carriage = active_data.carriage
    if not (carriage and carriage.valid) then return end

    -- Fetch the control behavior
    local control_behavior = entity.get_or_create_control_behavior()
    if not (control_behavior and control_behavior.valid) then return end
    if not control_behavior.enabled then control_behavior.enabled = true end
    local section = control_behavior.get_section(1)
    if not (section and section.is_manual) then game.print("FATAL: Sensor control behavior section is not manual for sensor at position " .. serpent.block(entity.position)) return end
    if not section.active then section.active = true end

    -- If the description says to do nothing, then exit
    local read_type = string.find(entity.combinator_description, "read-type", 1, true) ~= nil
    local read_contents = string.find(entity.combinator_description, "read-contents", 1, true) ~= nil
    local read_fuel = string.find(entity.combinator_description, "read-fuel", 1, true) ~= nil
    if not (read_type or read_contents or read_fuel) then
        if #section.filters > 0 then
            section.filters = {}
            active_data.filters = {}
        end
        return
    end

    -- Depending on configuration, set filters and emit signals
    local filters = {}
    if carriage.name == "cargo-wagon" then
        if read_type then
            -- Emit carriage type signal
            table.insert(filters, {
                value = { type = "item", name = "cargo-wagon", quality = "normal" },
                min = 1,
                max = 1
            })
        end
        if read_contents then
            -- Read contents and emit signals
            local inventory = carriage.get_inventory(defines.inventory.cargo_wagon)
            if not (inventory and inventory.valid) then return end

            -- Loop through contents and set filters
            for _, item in pairs(inventory.get_contents()) do
                table.insert(filters, {
                    value = { type = "item", name = item.name, quality = item.quality },
                    min = item.count,
                    max = item.count
                })
            end
        end
    elseif carriage.name == "fluid-wagon" then
        if read_type then
            -- Emit carriage type signal
            table.insert(filters, {
                value = { type = "item", name = "fluid-wagon", quality = "normal" },
                min = 1,
                max = 1
            })
        end
        if read_contents then
            -- Read contents and emit signals
            for fluid, amount in pairs(carriage.get_fluid_contents()) do
                table.insert(filters, {
                    value = { type = "fluid", name = fluid, quality = "normal" },
                    min = amount,
                    max = amount
                })
            end
        end
    elseif carriage.name == "artillery-wagon" then
        if read_type then
            -- Emit carriage type signal
            table.insert(filters, {
                value = { type = "item", name = "artillery-wagon", quality = "normal" },
                min = 1,
                max = 1
            })
        end
        if read_contents then
            -- Read contents and emit signals
            local inventory = carriage.get_inventory(defines.inventory.artillery_wagon_ammo)
            if not (inventory and inventory.valid) then return end

            -- Loop through contents and set filters
            for _, item in pairs(inventory.get_contents()) do
                table.insert(filters, {
                    value = { type = "item", name = item.name, quality = item.quality },
                    min = item.count,
                    max = item.count
                })
            end
        end
    elseif carriage.name == "locomotive" then
        if read_type then
            -- Emit carriage type signal
            table.insert(filters, {
                value = { type = "item", name = "locomotive", quality = "normal" },
                min = 1,
                max = 1
            })
        end
        if read_fuel then
            -- Read fuel and emit signals
            local fuel_inventory = carriage.get_fuel_inventory()
            if not (fuel_inventory and fuel_inventory.valid) then return end

            -- Loop through fuel contents and set filters
            for _, item in pairs(fuel_inventory.get_contents()) do
                table.insert(filters, {
                    value = { type = "item", name = item.name, quality = item.quality },
                    min = item.count,
                    max = item.count
                })
            end
        end
    end

    -- If this filters didn't change, don't update
    -- TODO: Will this help or hurt performance?
    local previous_filters = active_data.filters or {}
    local filters_changed = false
    if #filters ~= #previous_filters then
        filters_changed = true
    else
        for i = 1, #filters do
            local new_filter = filters[i]
            local old_filter = previous_filters[i]
            if not old_filter or new_filter.value.type ~= old_filter.value.type or new_filter.value.name ~= old_filter.value.name or new_filter.min ~= old_filter.min then
                filters_changed = true
                break
            end
        end
    end

    -- Emit all the filters
    if filters_changed then
        section.filters = filters
        active_data.filters = filters
    end

    -- END HIGH-PERFORMANT CODE --
end

local function train_sensor_check_trains(train)
    for _, carriage in pairs(train.carriages) do
        local surface = carriage.surface
        local position = carriage.position
        local nearby_sensors = surface.find_entities_filtered{
            name = "ftrainworks-sensor",
            position = position,
            radius = 3 -- Carriages are 6 tiles long, so this ensures we catch any sensors near the ends
        }

        -- Check if the sensors should perform their actions
        for _, sensor in ipairs(nearby_sensors) do
            if sensor and sensor.valid then
                -- Add to active list
                if not storage.sensor_active[sensor] then
                    storage.sensor_active[sensor] = {
                        train_id = train.id,
                        carriage = carriage,
                        filters = {}
                    }

                    -- Perform initial check
                    train_sensor_check_perform_action(sensor)
                end
            end
        end
    end
end

local function train_sensor_created(entity)
    -- Set default params
    entity.combinator_description = "read-contents"

    -- If there is a train in front of us, make sure to add to active sensor list
    local surface = entity.surface
    local position = entity.position
    local nearest_carriage = coupling.get_nearest_rolling_stock(surface, position, 6)
    if nearest_carriage then
        local train = nearest_carriage.train
        if train and train.valid then
            local train_state = storage.train_state[train.id]
            if train_state and train_state.stopped then
                -- Add to active inserter list
                storage.sensor_active[entity] = {
                    train_id = train.id,
                    carriage = nearest_carriage,
                    filters = {}
                }

                -- Perform initial check
                train_sensor_check_perform_action(entity)
            end
        end
    end
end

--[[
    Initialization and configuration events.
--]]
registry.register(defines.events.on_init, function(event)
    storage.sensor_active = {}
end)

registry.register(defines.events.on_configuration_changed, function(event)
    storage.sensor_active = storage.sensor_active or {}
end)

--[[
    Entity creation events.
--]]
registry.register({defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.on_space_platform_built_entity, defines.events.on_script_raised_built, defines.events.on_script_raised_revive}, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == "ftrainworks-sensor" then
        train_sensor_created(entity)
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
        train_sensor_check_trains(train)
    else
        -- Remove from active sensor list
        for sensor, active_data in pairs(storage.sensor_active) do
            if active_data.train_id == train.id then
                storage.sensor_active[sensor] = nil

                -- Reset control behavior
                if sensor and sensor.valid then
                    local control_behavior = sensor.get_or_create_control_behavior()
                    if control_behavior and control_behavior.valid then
                        local section = control_behavior.get_section(1)
                        if section and section.is_manual then
                            section.filters = {}
                        end
                    end
                end
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

        -- On first tick, re-check all stopped trains to register sensors
        storage.sensor_active = {}
        local train_manager = game.train_manager
        local trains = train_manager.get_trains{}
        for _, train in pairs(trains) do
            local state = storage.train_state[train.id]
            if state and state.stopped then
                train_sensor_check_trains(train)
            end
        end
    end

    -- If there are active sensors, process them
    -- NOTE: The circuit network runs per-tick, so we need to do this every tick
    --       I wish I could do this less frequently, but Factorio doesn't provide a way to hook into circuit network updates
    for sensor, _ in pairs(storage.sensor_active) do
        train_sensor_check_perform_action(sensor)
    end
end)