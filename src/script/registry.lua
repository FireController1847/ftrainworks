local event_registry = {}

--[[
    Event registry for managing mod lifecycle events.
--]]

-- Fired once when the mod is initialized for the first time
event_registry.on_init = {}

-- Fired once when the mod configuration is changed (e.g., mod added/removed/updated)
event_registry.on_configuration_changed = {}

-- Fired once on the first tick after initialization
event_registry.on_first_tick = {}

-- Fired on every game tick
event_registry.on_tick = {}

-- Fired when storage needs to be refreshed
event_registry.on_refresh_storage = {}


--[[
    Registration functions for event handlers.
--]]

local first_tick = true

function event_registry.register_init(handler)
    table.insert(event_registry.on_init, handler)
end

function event_registry.register_configuration_changed(handler)
    table.insert(event_registry.on_configuration_changed, handler)
end

function event_registry.register_first_tick(handler)
    table.insert(event_registry.on_first_tick, handler)
end

function event_registry.register_tick(handler)
    table.insert(event_registry.on_tick, handler)
end

function event_registry.register_refresh_storage(handler)
    table.insert(event_registry.on_refresh_storage, handler)
end


--[[
    Game event hooks to dispatch registered handlers.
--]]

script.on_init(function()
    for _, handler in pairs(event_registry.on_refresh_storage) do
        handler()
    end
    for _, handler in pairs(event_registry.on_init) do
        handler()
    end
end)

script.on_configuration_changed(function(data)
    for _, handler in pairs(event_registry.on_refresh_storage) do
        handler()
    end
    for _, handler in pairs(event_registry.on_configuration_changed) do
        handler(data)
    end
end)

script.on_event(defines.events.on_tick, function(event)
    if first_tick then
        first_tick = false
        for _, handler in pairs(event_registry.on_refresh_storage) do
            handler()
        end
        for _, handler in pairs(event_registry.on_first_tick) do
            handler(event)
        end
    end
    for _, handler in pairs(event_registry.on_tick) do
        handler(event)
    end
end)

return event_registry