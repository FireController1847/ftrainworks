local event_registry = require("script.registry")

--[[
    GUI creation for the FTrainworks Coupler Inserter.
--]]
local function create_coupler_gui(player, entity)
    -- Close default gui and destroy existing gui if present
    player.opened = nil
    local screen = player.gui.screen
    if screen["ftrainworks-coupler-inserter-gui"] then
        screen["ftrainworks-coupler-inserter-gui"].destroy()
    end

    -- Create the frame
    local ui_frame = screen.add{
        type = "frame",
        name = "ftrainworks-coupler-inserter-gui",
        direction = "vertical",
        style = "inset_frame_container_frame"
    }
    ui_frame.style.minimal_width = 300
    ui_frame.auto_center = true
    player.opened = ui_frame

    -- Create the title bar
    local ui_titlebar = ui_frame.add{
        type = "flow",
        direction = "horizontal",
        style = "frame_header_flow"
    }
    ui_titlebar.style.vertically_stretchable = false
    ui_titlebar.style.bottom_margin = -12
    local ui_titlebar_label = ui_titlebar.add{
        type = "label",
        caption = entity.localised_name,
        style = "frame_title"
    }
    ui_titlebar_label.style.vertically_stretchable = true
    ui_titlebar_label.style.horizontally_squashable = true
    ui_titlebar_label.style.bottom_padding = 3
    ui_titlebar_label.style.top_margin = -2.5
    local ui_titlebar_drag = ui_titlebar.add{
        type = "empty-widget",
        style = "draggable_space_header"
    }
    ui_titlebar_drag.style.height = 24
    ui_titlebar_drag.style.natural_height = 24
    ui_titlebar_drag.style.horizontally_stretchable = true
    ui_titlebar_drag.style.vertically_stretchable = true
    ui_titlebar_drag.style.right_margin = 4
    ui_titlebar_drag.drag_target = ui_frame
    local ui_titlebar_circuit = ui_titlebar.add{
        type = "sprite-button",
        sprite = "utility/circuit_network_panel",
        style = "frame_action_button"
    }
    local connectors = entity.get_wire_connectors(false)
    local total_connections = 0
    for _, connector in pairs(connectors) do
        total_connections = total_connections + connector.connection_count
    end
    if total_connections > 0 then
        ui_titlebar_circuit.enabled = true
    else
        ui_titlebar_circuit.enabled = false
    end
    local ui_titlebar_close = ui_titlebar.add{
        type = "sprite-button",
        name = "ftrainworks-coupler-inserter-gui-close-button",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        style = "close_button"
    }

    -- Create the content flow
    local ui_content_frame = ui_frame.add{
        type = "frame",
        style = "inside_shallow_frame_with_padding"
    }
    ui_content_frame.style.top_padding = 8
    local ui_content_flow = ui_content_frame.add{
        type = "flow",
        direction = "vertical"
    }
    ui_content_flow.style.vertical_spacing = 8

    -- Create the status widget
    local ui_status_flow = ui_content_flow.add{
        type = "flow",
        direction = "horizontal"
    }
    ui_status_flow.style.vertical_align = "center"
    local ui_status_image = ui_status_flow.add{
        type = "sprite",
        sprite = "utility/status_not_working",
        resize_to_sprite = false
    }
    ui_status_image.style.width = 16
    ui_status_image.style.height = 16
    ui_status_image.style.natural_width = 16
    ui_status_image.style.natural_height = 16
    local ui_status_label = ui_status_flow.add{
        type = "label",
        caption = {"other.ftrainworks-coupler-inserter-not-working"}
    }

    -- Create the entity preview
    local ui_preview_frame = ui_content_flow.add{
        type = "frame",
        style = "deep_frame_in_shallow_frame"
    }
    local ui_preview = ui_preview_frame.add{
        type = "entity-preview",
        style = "wide_entity_button"
    }
    ui_preview.entity = entity

    -- Line separator
    local ui_content_line = ui_content_flow.add{
        type = "line",
        direction = "horizontal"
    }
    ui_content_line.style.top_margin = 6
    ui_content_line.style.bottom_margin = 2

    -- Create controls flow
    local ui_controls_flow = ui_content_flow.add{
        type = "flow",
        direction = "horizontal"
    }
    ui_controls_flow.style.horizontal_spacing = 8

    -- Create enabled switch
    local ui_controls_enabled_flow = ui_controls_flow.add{
        type = "flow",
        direction = "vertical"
    }
    ui_controls_enabled_flow.style.vertical_spacing = 8
    local ui_enabled_label = ui_controls_enabled_flow.add{
        type = "label",
        caption = {"gui.ftrainworks-automatic-coupling"},
        style = "semibold_label"
    }
    local ui_enabled_switch = ui_controls_enabled_flow.add{
        type = "switch",
        name = "coupler_enabled_switch",
        left_label_caption = {"gui.off"},
        right_label_caption = {"gui.on"},
        switch_state = "right"
    }

    -- Line separator
    local ui_controls_line = ui_controls_flow.add{
        type = "line",
        direction = "vertical"
    }

    -- Create configuration radio buttons
    local ui_controls_radio_flow = ui_controls_flow.add{
        type = "flow",
        direction = "vertical"
    }
    ui_controls_radio_flow.style.vertical_spacing = 2
    local ui_config_label = ui_controls_radio_flow.add{
        type = "label",
        caption = {"gui.set-constant"},
        style = "semibold_label"
    }
    ui_config_label.style.top_margin = 1
    ui_config_label.style.bottom_margin = 4
    local ui_config_always_couple = ui_controls_radio_flow.add{
        type = "radiobutton",
        caption = {"other.ftrainworks-coupler-inserter-always-couple"},
        state = true
    }
    local ui_config_always_decouple = ui_controls_radio_flow.add{
        type = "radiobutton",
        caption = {"other.ftrainworks-coupler-inserter-always-decouple"},
        state = false
    }
end

local function close_coupler_gui(player)
    local screen = player.gui.screen
    if screen["ftrainworks-coupler-inserter-gui"] then
        screen["ftrainworks-coupler-inserter-gui"].destroy()
    end
end



--[[
    GUI event hooks.
--]]
script.on_event(defines.events.on_gui_opened, function(event)
    if event.gui_type == defines.gui_type.entity then
        local entity = event.entity
        if entity and entity.valid and entity.name == "ftrainworks-coupler-inserter" then
            local player = game.get_player(event.player_index)
            if not (player and player.valid) then return end
            create_coupler_gui(player, entity)
        end
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    if element.name == "ftrainworks-coupler-inserter-gui-close-button" then
        local player = game.get_player(event.player_index)
        if not (player and player.valid) then return end
        close_coupler_gui(player)
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    if event.gui_type == defines.gui_type.custom then
        local player = game.get_player(event.player_index)
        if not (player and player.valid) then return end
        close_coupler_gui(player)
    end
end)


--[[
    Registry hooks.
--]]
event_registry.register_refresh_storage(function()
    storage.players = storage.players or {}
end)