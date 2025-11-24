local registry = require("script.registry")
local util = require("script.util")

local COUPLER_BOUNDING_BOX = prototypes.entity["ftrainworks-coupler"].selection_box

----------------------------
-- USED STORAGE VARIABLES --
----------------------------
-- storage.carriages: Table mapping carriage unit numbers to their data
----------------------------

--[[
    Data storage functions.
--]]

---Creates the data structure for a carriage in storage.
---Does not perform any validation.
---@param carriage_unit_number uint64 The unit number of the carriage.
local function create_carriage_data(carriage_unit_number)
    --game.print("trains.lua#create_carriage_data(): Creating carriage data for unit number " .. carriage_unit_number, { skip = defines.print_skip.never, game_state = false })
    storage.carriages = storage.carriages or {}
    storage.carriages[carriage_unit_number] = {
        couplers = {}
    }
end

---Removes the data structure for a carriage from storage.
---Does not perform any validation.
---@param carriage_unit_number uint64 The unit number of the carriage.
local function remove_carriage_data(carriage_unit_number)
    --game.print("trains.lua#remove_carriage_data(): Removing carriage data for unit number " .. carriage_unit_number, { skip = defines.print_skip.never, game_state = false })
    if not storage.carriages then return end
    storage.carriages[carriage_unit_number] = nil
end

--[[
    Carriage coupler validation functions.
--]]

---Validates a specific coupler for a given carriage.
---@param carriage LuaEntity The carriage entity.
---@param position MapPosition The expected position of the coupler.
---@param location string The location of the coupler ("front" or "back").
local function validate_carriage_coupler(carriage, position, location)
    --game.print("trains.lua#validate_carriage_coupler(): Validating " .. location .. " coupler for carriage unit number " .. carriage.unit_number, { skip = defines.print_skip.never, game_state = false })
    if not (carriage and carriage.valid) then return end
    local carriage_data = storage.carriages[carriage.unit_number]
    if not carriage_data then return end

    -- Check if coupler entity exists
    if carriage_data.couplers[location] then
        local coupler_unit_number = carriage_data.couplers[location]
        local coupler_entity = game.get_entity_by_unit_number(coupler_unit_number)
        if not (coupler_entity and coupler_entity.valid) then
            -- Coupler entity is missing, remove from storage and revalidate
            carriage_data.couplers[location] = nil
            validate_carriage_coupler(carriage, position, location)
            return
        end

        local distance = ((coupler_entity.position.x - position.x) ^ 2 + (coupler_entity.position.y - position.y) ^ 2) ^ 0.5
        if distance > 0.1 then
            game.print("trains.lua#validate_carriage_coupler(): " .. location .. " coupler for carriage unit number " .. carriage.unit_number .. " is out of position, moving.", { skip = defines.print_skip.never, game_state = false })
            coupler_entity.teleport(position)
        end
    else
        -- Create coupler entity
        local coupler_entity = carriage.surface.create_entity{
            name = "ftrainworks-coupler",
            position = position,
            force = carriage.force
        }
        if not (coupler_entity and coupler_entity.valid) then
            game.print("trains.lua#validate_carriage_coupler(): Failed to create " .. location .. " coupler for carriage unit number " .. carriage.unit_number, { skip = defines.print_skip.never, game_state = false })
            return
        end
        carriage_data.couplers[location] = coupler_entity.unit_number
    end

    -- Save updated carriage data
    storage.carriages[carriage.unit_number] = carriage_data
end

---Validates the couplers for a given carriage.
---@param carriage LuaEntity The carriage entity.
local function validate_carriage_couplers(carriage)
    --game.print("trains.lua#validate_carriage_couplers(): Validating couplers for carriage unit number " .. carriage.unit_number, { skip = defines.print_skip.never, game_state = false })
    if not (carriage and carriage.valid) then return end
    local train = carriage.train
    if not (train and train.valid) then return end

    -- Determine our position of the carriage in the train
    local carriages = train.carriages
    local i = nil
    for index, c in ipairs(carriages) do
        if c.unit_number == carriage.unit_number then
            i = index
            break
        end
    end
    if not i then return end

    -- Determine our orientation relative to our next connected rolling stock
    -- Then determine the back_center position of the carriage based on that orientation
    local orientation = carriage.orientation
    local next = carriages[i + 1]
    if next then
        if carriage.get_connected_rolling_stock(defines.rail_direction.back) == next then
            orientation = (orientation + 0.5) % 1
        end
    end
    local back_center = util.calculate_back_center(carriage.selection_box, COUPLER_BOUNDING_BOX, orientation)

    -- Validate front coupler (only on first carriage)
    if i == 1 then
        local front_center = util.flip_to_front_center(carriage.selection_box, back_center)
        validate_carriage_coupler(carriage, front_center, "front")
    end

    -- Validate back coupler
    validate_carriage_coupler(carriage, back_center, "back")
end

---Invalidates (removes) all couplers for a given carriage.
---@param carriage LuaEntity The carriage entity.
local function invalidate_carriage_couplers(carriage)
    --game.print("trains.lua#invalidate_carriage_couplers(): Invalidating couplers for carriage unit number " .. carriage.unit_number, { skip = defines.print_skip.never, game_state = false })
    if not (carriage and carriage.valid) then return end
    local carriage_data = storage.carriages[carriage.unit_number]
    if not carriage_data then return end

    -- Destroy existing coupler entities
    for _, coupler_unit_number in pairs(carriage_data.couplers) do
        local coupler_entity = game.get_entity_by_unit_number(coupler_unit_number)
        if coupler_entity and coupler_entity.valid then
            coupler_entity.destroy()
        end
    end

    -- Save updated carriage data
    carriage_data.couplers = {}
    storage.carriages[carriage.unit_number] = carriage_data
end

--[[
    Carriage event handlers.
--]]

---Handler for when a rolling stock entity is built.
---@param carriage LuaEntity The carriage entity that was built.
local function on_carriage_built(carriage)
    --game.print("trains.lua#on_carriage_built(): Carriage unit number " .. carriage.unit_number .. " built.", { skip = defines.print_skip.never, game_state = false })
    create_carriage_data(carriage.unit_number)
    validate_carriage_couplers(carriage)
end

---Handler for when a rolling stock entity is removed.
---@param carriage LuaEntity The carriage entity that was removed.
local function on_carriage_removed(carriage)
    --game.print("trains.lua#on_carriage_removed(): Carriage unit number " .. carriage.unit_number .. " removed.", { skip = defines.print_skip.never, game_state = false })
    invalidate_carriage_couplers(carriage)
    remove_carriage_data(carriage.unit_number)
end

--[[
    Train state event handlers.
--]]

---Handler for when a train's state changes.
---@param train LuaTrain The train whose state has changed.
local function on_train_state_changed(train)
    if train.speed == 0 then
        for i = 1, #train.carriages do
            local carriage = train.carriages[i]
            validate_carriage_couplers(carriage)
        end
    else
        for i = 1, #train.carriages do
            local carriage = train.carriages[i]
            invalidate_carriage_couplers(carriage)
        end
    end
end

--[[
    Mouse-click event handlers.
--]]

---Handler for left-click custom input.
---@param event EventData.CustomInputEvent
local function on_left_click(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    local selected = player.selected
    if not (selected and selected.valid) then return end
    if selected.name == "ftrainworks-coupler" then
        local surface = selected.surface
        local position = selected.position
        local carriages = util.find_nearest_carriages(surface, position, 5)
        if not carriages then return end
        if #carriages < 2 then return end
        local carriage1 = carriages[1]
        local carriage2 = carriages[2]
        invalidate_carriage_couplers(carriage1)
        invalidate_carriage_couplers(carriage2)
        util.connect_disconnect_carriages(carriage1, carriage2, surface, position, "toggle")
        validate_carriage_couplers(carriage1)
        validate_carriage_couplers(carriage2)
    end
end

--[[
    Registry event handlers.
--]]

registry.register("on_init", function()
    -- Initialize all existing trains and their carriages
    for _, train in ipairs(game.train_manager.get_trains{}) do
        for _, carriage in ipairs(train.carriages) do
            if util.is_entity_carriage(carriage) then
                on_carriage_built(carriage)
            end
        end
    end
end)

---@param event EventData.on_built_entity
registry.register(defines.events.on_built_entity, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if util.is_entity_carriage(entity) then
        on_carriage_built(entity)
    end
end)

---@param event EventData.on_robot_built_entity
registry.register(defines.events.on_robot_built_entity, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if util.is_entity_carriage(entity) then
        on_carriage_built(entity)
    end
end)

---@param event EventData.script_raised_built
registry.register(defines.events.script_raised_built, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if util.is_entity_carriage(entity) then
        on_carriage_built(entity)
    end
end)

---@param event EventData.on_entity_died
registry.register(defines.events.on_entity_died, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if util.is_entity_carriage(entity) then
        on_carriage_removed(entity)
    end
end)

---@param event EventData.on_player_mined_entity
registry.register(defines.events.on_player_mined_entity, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if util.is_entity_carriage(entity) then
        on_carriage_removed(entity)
    end
end)

---@param event EventData.on_robot_mined_entity
registry.register(defines.events.on_robot_mined_entity, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if util.is_entity_carriage(entity) then
        on_carriage_removed(entity)
    end
end)

---@param event EventData.script_raised_destroy
registry.register(defines.events.script_raised_destroy, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if util.is_entity_carriage(entity) then
        on_carriage_removed(entity)
    end
end)

---@param event EventData.on_train_changed_state
registry.register(defines.events.on_train_changed_state, function(event)
    local train = event.train
    if not (train and train.valid) then return end
    on_train_state_changed(train)
end)

---@param event EventData.CustomInputEvent
registry.register("ftrainworks-left-click", function(event)
    on_left_click(event)
end)

return {
    invalidate_carriage_couplers = invalidate_carriage_couplers,
    validate_carriage_couplers = validate_carriage_couplers
}