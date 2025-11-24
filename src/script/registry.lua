local registry = {}
local handlers = {}
local nth_tick_handlers = {}

function registry.register(event_names, handler)
    if type(event_names) ~= "table" then
        event_names = { event_names }
    end
    for _, event_name in ipairs(event_names) do
        if not handlers[event_name] then
            handlers[event_name] = {}
        end
        table.insert(handlers[event_name], handler)
    end
end

function registry.register_nth_tick(tick_interval, handler)
    if not nth_tick_handlers[tick_interval] then
        nth_tick_handlers[tick_interval] = {}
    end
    table.insert(nth_tick_handlers[tick_interval], handler)
end

function registry.unregister(event_names, handler)
    if type(event_names) ~= "table" then
        event_names = { event_names }
    end
    for _, event_name in ipairs(event_names) do
        if handlers[event_name] then
            for i, registered_handler in ipairs(handlers[event_name]) do
                if registered_handler == handler then
                    table.remove(handlers[event_name], i)
                    break
                end
            end
        end
    end
end

function registry.unregister_nth_tick(tick_interval, handler)
    if nth_tick_handlers[tick_interval] then
        for i, registered_handler in ipairs(nth_tick_handlers[tick_interval]) do
            if registered_handler == handler then
                table.remove(nth_tick_handlers[tick_interval], i)
                break
            end
        end
    end
end

function registry.execute()
    -- Register normal event handlers
    for event_name, event_handlers in pairs(handlers) do
        if event_name == "on_init" or event_name == "on_configuration_changed" or event_name == "on_load" then
            -- These events are handled separately
        else
            script.on_event(event_name, function(event_data)
                for _, handler in ipairs(event_handlers) do
                    handler(event_data)
                end
            end)
        end
    end

    -- Register nth-tick handlers
    for tick_interval, tick_handlers in pairs(nth_tick_handlers) do
        script.on_nth_tick(tick_interval, function(event_data)
            for _, handler in ipairs(tick_handlers) do
                handler(event_data)
            end
        end)
    end
end

script.on_init(function()
    if handlers["on_init"] then
        for _, handler in ipairs(handlers["on_init"]) do
            handler()
        end
    end
end)

script.on_configuration_changed(function()
    if handlers["on_configuration_changed"] then
        for _, handler in ipairs(handlers["on_configuration_changed"]) do
            handler()
        end
    end
end)

script.on_load(function()
    if handlers["on_load"] then
        for _, handler in ipairs(handlers["on_load"]) do
            handler()
        end
    end
end)

return registry