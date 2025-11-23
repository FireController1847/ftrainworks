local registry = {}
storage.handlers = storage.handlers or {}
local handlers = storage.handlers

function registry.register(event_names, handler)
    if type(event_names) ~= "table" then event_names = { event_names } end
    for _, event_name in ipairs(event_names) do
        if not handlers[event_name] then
            handlers[event_name] = {}
        end
        table.insert(handlers[event_name], handler)
    end
end

function registry.unregister(event_names, handler)
    if type(event_names) ~= "table" then event_names = { event_names } end
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

local function register_events()
    -- Loop through all registered handlers and assign them to their respective events
    for event_name, event_handlers in pairs(handlers) do
        if event_name == defines.on_init or event_name == defines.on_configuration_changed or event_name == defines.on_load then
            -- Skip these events as they are handled separately
        else
            script.on_event(event_name, function(event_data)
                for _, handler in ipairs(event_handlers) do
                    handler(event_data)
                end
            end)
        end
    end
end

script.on_init(function()
    register_events()
    for event_name, event_handlers in pairs(handlers) do
        if event_name == defines.on_init then
            for _, handler in ipairs(event_handlers) do
                handler()
            end
        end
    end
end)

script.on_configuration_changed(function()
    register_events()
    for event_name, event_handlers in pairs(handlers) do
        if event_name == defines.on_configuration_changed then
            for _, handler in ipairs(event_handlers) do
                handler()
            end
        end
    end
end)

script.on_load(function()
    register_events()
    for event_name, event_handlers in pairs(handlers) do
        if event_name == defines.on_load then
            for _, handler in ipairs(event_handlers) do
                handler()
            end
        end
    end
end)

return registry