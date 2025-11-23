local registry = require("script.registry")
local inserters = require("script.inserters")
local coupling = require("script.coupling")

--[[
    GUI management for the train coupler inserter.
--]]
local function close_coupler_gui(player)
    local screen = player.gui.screen
    local gui = screen["ftrainworks-coupler-inserter-gui-window"]
    if gui then
        gui.destroy()
        player.play_sound{ path = "entity-close/inserter" }
    end
end

local function update_coupler_gui(player, entity)
    if not (player and player.valid) then return end
    if not (entity and entity.valid) then return end

    -- Fetch UI components
    -- TODO: The amount of string comparisons here makes me want to cry
    local screen = player.gui.screen
    local ui_window_frame = screen["ftrainworks-coupler-inserter-gui-window"]
    if not ui_window_frame then return end
    local ui_frame = ui_window_frame["ftrainworks-coupler-inserter-gui"]
    local ui_content_frame = ui_frame["ftrainworks-coupler-inserter-gui-content-frame"]
    local ui_content_flow = ui_content_frame["ftrainworks-coupler-inserter-gui-content-flow"]
    local ui_controls_flow = ui_content_flow["ftrainworks-coupler-inserter-gui-controls-flow"]
    local ui_status_flow = ui_content_flow["ftrainworks-coupler-inserter-gui-status-flow"]
    local ui_status_image = ui_status_flow["ftrainworks-coupler-inserter-gui-status-image"]
    local ui_status_label = ui_status_flow["ftrainworks-coupler-inserter-gui-status-label"]
    local ui_controls_radio_flow = ui_controls_flow["ftrainworks-coupler-inserter-gui-controls-radio-flow"]
    local ui_config_prioritize_coupling = ui_controls_radio_flow["ftrainworks-coupler-inserter-gui-controls-radio-prioritize-coupling"]
    local ui_config_prioritize_uncoupling = ui_controls_radio_flow["ftrainworks-coupler-inserter-gui-controls-radio-prioritize-uncoupling"]

    local filter_count = entity.filter_slot_count
    if filter_count < 2 then return end
    local filter_slot_1 = entity.get_filter(1)
    --local filter_slot_2 = entity.get_filter(2) -- TODO: Can be used for more complex logic later

    -- Update status
    local is_connected = false
    local connectors = entity.get_wire_connectors(false)
    for _, connector in ipairs(connectors) do
        if connector.real_connection_count > 0 then
            is_connected = true
            break
        end
    end
    if is_connected then
        local nearest_coupler = coupling.get_nearest_coupler(entity.surface, entity.position, 3)
        if nearest_coupler then
            ui_status_image.sprite = "utility/status_working"
            ui_status_label.caption = {"other.ftrainworks-working"}
        else
            ui_status_image.sprite = "utility/status_yellow"
            ui_status_label.caption = {"other.ftrainworks-waiting"}
        end
    else
        ui_status_image.sprite = "utility/status_not_working"
        ui_status_label.caption = {"other.ftrainworks-not-working"}
    end

    -- Determine constant couple/decouple state
    if is_connected then
        ui_config_prioritize_coupling.enabled = true
        ui_config_prioritize_uncoupling.enabled = true
        local couple_state
        if filter_slot_1 and filter_slot_1.name == "ftrainworks-coupler-priority-couple" then
            couple_state = "couple"
        else
            couple_state = "decouple"
        end
        if couple_state == "couple" then
            ui_config_prioritize_coupling.state = true
            ui_config_prioritize_uncoupling.state = false
        else
            ui_config_prioritize_coupling.state = false
            ui_config_prioritize_uncoupling.state = true
        end
    else
        ui_config_prioritize_coupling.enabled = false
        ui_config_prioritize_uncoupling.enabled = false
    end

    -- Perform movement check
    inserters.coupler_inserter_check_perform_action(entity)
end

local function open_coupler_gui(player, entity)
    -- Close the default gui, destroy existing gui if present
    player.opened = nil
    close_coupler_gui(player)

    -- Create the window frame
    local screen = player.gui.screen
    local ui_window_frame = screen.add{
        type = "frame",
        name = "ftrainworks-coupler-inserter-gui-window",
        direction = "horizontal",
        style = "invisible_frame"
    }
    ui_window_frame.auto_center = true
    player.opened = ui_window_frame -- Set currently opened GUI to our frame

    -- Create the frame
    local ui_frame = ui_window_frame.add{
        type = "frame",
        name = "ftrainworks-coupler-inserter-gui",
        direction = "vertical",
        style = "inset_frame_container_frame"
    }
    ui_frame.style.minimal_width = 300

    -- Create the title bar
    local ui_titlebar = ui_frame.add{
        type = "flow",
        name = "ftrainworks-coupler-inserter-gui-titlebar",
        direction = "horizontal",
        style = "frame_header_flow"
    }
    ui_titlebar.style.vertically_stretchable = false
    ui_titlebar.style.bottom_margin = -12
    local ui_titlebar_label = ui_titlebar.add{
        type = "label",
        name = "ftrainworks-coupler-inserter-gui-titlebar-label",
        caption = entity.localised_name,
        style = "frame_title"
    }
    ui_titlebar_label.style.vertically_stretchable = true
    ui_titlebar_label.style.horizontally_squashable = true
    ui_titlebar_label.style.bottom_padding = 3
    ui_titlebar_label.style.top_margin = -2.5
    local ui_titlebar_drag = ui_titlebar.add{
        type = "empty-widget",
        name = "ftrainworks-coupler-inserter-gui-titlebar-drag",
        style = "draggable_space_header"
    }
    ui_titlebar_drag.style.height = 24
    ui_titlebar_drag.style.natural_height = 24
    ui_titlebar_drag.style.horizontally_stretchable = true
    ui_titlebar_drag.style.vertically_stretchable = true
    ui_titlebar_drag.style.right_margin = 4
    ui_titlebar_drag.drag_target = ui_window_frame
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
        name = "ftrainworks-coupler-inserter-gui-content-frame",
        style = "inside_shallow_frame_with_padding"
    }
    ui_content_frame.style.top_padding = 8
    local ui_content_flow = ui_content_frame.add{
        type = "flow",
        name = "ftrainworks-coupler-inserter-gui-content-flow",
        direction = "vertical"
    }
    ui_content_flow.style.vertical_spacing = 8

    -- Create the status widget
    local ui_status_flow = ui_content_flow.add{
        type = "flow",
        name = "ftrainworks-coupler-inserter-gui-status-flow",
        direction = "horizontal"
    }
    ui_status_flow.style.vertical_align = "center"
    local ui_status_image = ui_status_flow.add{
        type = "sprite",
        name = "ftrainworks-coupler-inserter-gui-status-image",
        sprite = "utility/status_not_working",
        resize_to_sprite = false
    }
    ui_status_image.style.width = 16
    ui_status_image.style.height = 16
    ui_status_image.style.natural_width = 16
    ui_status_image.style.natural_height = 16
    local ui_status_label = ui_status_flow.add{
        type = "label",
        name = "ftrainworks-coupler-inserter-gui-status-label",
        caption = {"other.ftrainworks-coupler-inserter-not-working"}
    }

    -- Create the entity preview
    local ui_preview_frame = ui_content_flow.add{
        type = "frame",
        name = "ftrainworks-coupler-inserter-gui-preview-frame",
        style = "deep_frame_in_shallow_frame"
    }
    local ui_preview = ui_preview_frame.add{
        type = "entity-preview",
        name = "ftrainworks-coupler-inserter-gui-preview",
        style = "wide_entity_button"
    }
    ui_preview.entity = entity

    -- Line separator
    local ui_content_line = ui_content_flow.add{
        type = "line",
        name = "ftrainworks-coupler-inserter-gui-content-line",
        direction = "horizontal"
    }
    ui_content_line.style.top_margin = 6
    ui_content_line.style.bottom_margin = 2

    -- Create controls flow
    local ui_controls_flow = ui_content_flow.add{
        type = "flow",
        name = "ftrainworks-coupler-inserter-gui-controls-flow",
        direction = "vertical"
    }
    ui_controls_flow.style.vertical_spacing = 2

    -- Create configuration radio buttons
    local ui_controls_radio_flow = ui_controls_flow.add{
        type = "flow",
        name = "ftrainworks-coupler-inserter-gui-controls-radio-flow",
        direction = "vertical"
    }
    ui_controls_radio_flow.style.vertical_spacing = 2
    local ui_config_label = ui_controls_radio_flow.add{
        type = "label",
        name = "ftrainworks-coupler-inserter-gui-controls-radio-label",
        caption = {"gui.ftrainworks-automatic-coupling"},
        style = "semibold_label"
    }
    ui_config_label.style.top_margin = 1
    ui_config_label.style.bottom_margin = 4
    local ui_config_prioritize_coupling = ui_controls_radio_flow.add{
        type = "radiobutton",
        name = "ftrainworks-coupler-inserter-gui-controls-radio-prioritize-coupling",
        caption = {"other.ftrainworks-coupler-inserter-prioritize-coupling"},
        state = true
    }
    local ui_config_prioritize_uncoupling = ui_controls_radio_flow.add{
        type = "radiobutton",
        name = "ftrainworks-coupler-inserter-gui-controls-radio-prioritize-uncoupling",
        caption = {"other.ftrainworks-coupler-inserter-prioritize-uncoupling"},
        state = false
    }

    -- Initial GUI update
    update_coupler_gui(player, entity)
end

--[[
    GUI management for the train sensor.
--]]
local function close_train_sensor_gui(player)
    local screen = player.gui.screen
    local gui = screen["ftrainworks-sensor-gui-window"]
    if gui then
        gui.destroy()
        player.play_sound{ path = "entity-close/constant-combinator" }
    end
end

local function update_train_sensor_gui(player, entity)
    if not (player and player.valid) then return end
    if not (entity and entity.valid) then return end

    -- Fetch UI components
    local screen = player.gui.screen
    local ui_window_frame = screen["ftrainworks-sensor-gui-window"]
    if not ui_window_frame then return end
    local ui_frame = ui_window_frame["ftrainworks-sensor-gui"]
    local ui_content_frame = ui_frame["ftrainworks-sensor-gui-content-frame"]
    local ui_content_flow = ui_content_frame["ftrainworks-sensor-gui-content-flow"]
    local ui_status_flow = ui_content_flow["ftrainworks-sensor-gui-status-flow"]
    local ui_status_image = ui_status_flow["ftrainworks-sensor-gui-status-image"]
    local ui_status_label = ui_status_flow["ftrainworks-sensor-gui-status-label"]
    local ui_controls_flow = ui_content_flow["ftrainworks-sensor-gui-controls-flow"]
    local ui_controls_checkbox_flow = ui_controls_flow["ftrainworks-sensor-gui-controls-checkbox-flow"]
    local ui_config_read_type = ui_controls_checkbox_flow["ftrainworks-sensor-gui-controls-checkbox-read-type"]
    local ui_config_read_contents = ui_controls_checkbox_flow["ftrainworks-sensor-gui-controls-checkbox-read-contents"]
    local ui_config_read_fuel = ui_controls_checkbox_flow["ftrainworks-sensor-gui-controls-checkbox-read-fuel"]

    -- Update status
    local is_connected = false
    local connectors = entity.get_wire_connectors(false)
    for _, connector in ipairs(connectors) do
        if connector.real_connection_count > 0 then
            is_connected = true
            break
        end
    end
    if is_connected then
        local nearest_rolling_stock = coupling.get_nearest_rolling_stock(entity.surface, entity.position, 3)
        if nearest_rolling_stock then
            ui_status_image.sprite = "utility/status_working"
            ui_status_label.caption = {"other.ftrainworks-working"}
        else
            ui_status_image.sprite = "utility/status_yellow"
            ui_status_label.caption = {"other.ftrainworks-waiting"}
        end
    else
        ui_status_image.sprite = "utility/status_not_working"
        ui_status_label.caption = {"other.ftrainworks-not-working"}
    end

    -- Fetch description to determine checkbox states
    local description = entity.combinator_description
    if description then
        ui_config_read_type.state = string.find(description, "read-type", 1, true) ~= nil
        ui_config_read_contents.state = string.find(description, "read-contents", 1, true) ~= nil
        ui_config_read_fuel.state = string.find(description, "read-fuel", 1, true) ~= nil
    end
end

local function open_train_sensor_gui(player, entity)
    -- Close the default gui, destroy existing gui if present
    player.opened = nil
    close_train_sensor_gui(player)

    -- Create the window frame
    local screen = player.gui.screen
    local ui_window_frame = screen.add{
        type = "frame",
        name = "ftrainworks-sensor-gui-window",
        direction = "horizontal",
        style = "invisible_frame"
    }
    ui_window_frame.auto_center = true
    player.opened = ui_window_frame -- Set currently opened GUI to our frame

    -- Create the frame
    local ui_frame = ui_window_frame.add{
        type = "frame",
        name = "ftrainworks-sensor-gui",
        direction = "vertical",
        style = "inset_frame_container_frame"
    }
    ui_frame.style.minimal_width = 300

    -- Create the title bar
    local ui_titlebar = ui_frame.add{
        type = "flow",
        name = "ftrainworks-sensor-gui-titlebar",
        direction = "horizontal",
        style = "frame_header_flow"
    }
    ui_titlebar.style.vertically_stretchable = false
    ui_titlebar.style.bottom_margin = -12
    local ui_titlebar_label = ui_titlebar.add{
        type = "label",
        name = "ftrainworks-sensor-gui-titlebar-label",
        caption = entity.localised_name,
        style = "frame_title"
    }
    ui_titlebar_label.style.vertically_stretchable = true
    ui_titlebar_label.style.horizontally_squashable = true
    ui_titlebar_label.style.bottom_padding = 3
    ui_titlebar_label.style.top_margin = -2.5
    local ui_titlebar_drag = ui_titlebar.add{
        type = "empty-widget",
        name = "ftrainworks-sensor-gui-titlebar-drag",
        style = "draggable_space_header"
    }
    ui_titlebar_drag.style.height = 24
    ui_titlebar_drag.style.natural_height = 24
    ui_titlebar_drag.style.horizontally_stretchable = true
    ui_titlebar_drag.style.vertically_stretchable = true
    ui_titlebar_drag.style.right_margin = 4
    ui_titlebar_drag.drag_target = ui_window_frame
    local ui_titlebar_close = ui_titlebar.add{
        type = "sprite-button",
        name = "ftrainworks-sensor-gui-close-button",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        style = "close_button"
    }

    -- Create the content flow
    local ui_content_frame = ui_frame.add{
        type = "frame",
        name = "ftrainworks-sensor-gui-content-frame",
        style = "inside_shallow_frame_with_padding"
    }
    ui_content_frame.style.top_padding = 8
    local ui_content_flow = ui_content_frame.add{
        type = "flow",
        name = "ftrainworks-sensor-gui-content-flow",
        direction = "vertical"
    }
    ui_content_flow.style.vertical_spacing = 8

    -- Create the status widget
    local ui_status_flow = ui_content_flow.add{
        type = "flow",
        name = "ftrainworks-sensor-gui-status-flow",
        direction = "horizontal"
    }
    ui_status_flow.style.vertical_align = "center"
    local ui_status_image = ui_status_flow.add{
        type = "sprite",
        name = "ftrainworks-sensor-gui-status-image",
        sprite = "utility/status_not_working",
        resize_to_sprite = false
    }
    ui_status_image.style.width = 16
    ui_status_image.style.height = 16
    ui_status_image.style.natural_width = 16
    ui_status_image.style.natural_height = 16
    local ui_status_label = ui_status_flow.add{
        type = "label",
        name = "ftrainworks-sensor-gui-status-label",
        caption = {"other.ftrainworks-not-working"}
    }

    -- Create the entity preview
    local ui_preview_frame = ui_content_flow.add{
        type = "frame",
        name = "ftrainworks-sensor-gui-preview-frame",
        style = "deep_frame_in_shallow_frame"
    }
    local ui_preview = ui_preview_frame.add{
        type = "entity-preview",
        name = "ftrainworks-sensor-gui-preview",
        style = "wide_entity_button"
    }
    ui_preview.entity = entity

        -- Line separator
    local ui_content_line = ui_content_flow.add{
        type = "line",
        name = "ftrainworks-sensor-gui-content-line",
        direction = "horizontal"
    }
    ui_content_line.style.top_margin = 6
    ui_content_line.style.bottom_margin = 2

    -- Create controls flow
    local ui_controls_flow = ui_content_flow.add{
        type = "flow",
        name = "ftrainworks-sensor-gui-controls-flow",
        direction = "vertical"
    }
    ui_controls_flow.style.vertical_spacing = 2

    -- Create configuration check boxes
    local ui_controls_checkbox_flow = ui_controls_flow.add{
        type = "flow",
        name = "ftrainworks-sensor-gui-controls-checkbox-flow",
        direction = "vertical"
    }
    ui_controls_checkbox_flow.style.vertical_spacing = 2
    local ui_config_label = ui_controls_checkbox_flow.add{
        type = "label",
        name = "ftrainworks-sensor-gui-controls-checkbox-label",
        caption = {"gui.ftrainworks-sensor-configuration"},
        style = "semibold_label"
    }
    local ui_config_read_type = ui_controls_checkbox_flow.add{
        type = "checkbox",
        name = "ftrainworks-sensor-gui-controls-checkbox-read-type",
        caption = {"gui-control-behavior-modes.read-carriage-type"},
        tooltip = {"gui-control-behavior-modes.read-carriage-type-description"},
        state = false
    }
    local ui_config_read_contents = ui_controls_checkbox_flow.add{
        type = "checkbox",
        name = "ftrainworks-sensor-gui-controls-checkbox-read-contents",
        caption = {"gui-control-behavior-modes.read-carriage-contents"},
        tooltip = {"gui-control-behavior-modes.read-carriage-contents-description"},
        state = true
    }
    local ui_config_read_fuel = ui_controls_checkbox_flow.add{
        type = "checkbox",
        name = "ftrainworks-sensor-gui-controls-checkbox-read-fuel",
        caption = {"gui-control-behavior-modes.read-carriage-fuel"},
        tooltip = {"gui-control-behavior-modes.read-carriage-fuel-description"},
        state = false
    }

    -- Initial GUI update
    update_train_sensor_gui(player, entity)
end

--[[
    GUI event hooks.
--]]
registry.register(defines.events.on_gui_opened, function(event)
    if event.gui_type == defines.gui_type.entity then
        local entity = event.entity
        if not (entity and entity.valid) then return end
        local player = game.get_player(event.player_index)
        if not (player and player.valid) then return end
        if entity.name == "ftrainworks-coupler-inserter" then
            open_coupler_gui(player, entity)
        elseif entity.name == "ftrainworks-sensor" then
            open_train_sensor_gui(player, entity)
        end
    end
end)

registry.register(defines.events.on_gui_click, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    if element.name == "ftrainworks-coupler-inserter-gui-close-button" then
        close_coupler_gui(player)
    elseif element.name == "ftrainworks-sensor-gui-close-button" then
        close_train_sensor_gui(player)
    end
end)

registry.register(defines.events.on_gui_checked_state_changed, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    if element.name == "ftrainworks-coupler-inserter-gui-controls-radio-prioritize-coupling" or
       element.name == "ftrainworks-coupler-inserter-gui-controls-radio-prioritize-uncoupling" then
        -- Get the preview to fetch the entity
        local screen = player.gui.screen
        local ui_window_frame = screen["ftrainworks-coupler-inserter-gui-window"]
        if not ui_window_frame then return end
        local ui_frame = ui_window_frame["ftrainworks-coupler-inserter-gui"]
        local ui_content_frame = ui_frame["ftrainworks-coupler-inserter-gui-content-frame"]
        local ui_content_flow = ui_content_frame["ftrainworks-coupler-inserter-gui-content-flow"]
        local ui_preview_frame = ui_content_flow["ftrainworks-coupler-inserter-gui-preview-frame"]
        local ui_preview = ui_preview_frame["ftrainworks-coupler-inserter-gui-preview"]
        local entity = ui_preview.entity
        if not (entity and entity.valid) then return end

        -- Update the filter for slot 1
        if element.name == "ftrainworks-coupler-inserter-gui-controls-radio-prioritize-coupling" then
            entity.set_filter(1, {name = "ftrainworks-coupler-priority-couple"})
        elseif element.name == "ftrainworks-coupler-inserter-gui-controls-radio-prioritize-uncoupling" then
            entity.set_filter(1, {name = "ftrainworks-coupler-priority-uncouple"})
        end

        -- Update the gui
        update_coupler_gui(player, entity)
    elseif element.name == "ftrainworks-sensor-gui-controls-checkbox-read-type" or
           element.name == "ftrainworks-sensor-gui-controls-checkbox-read-contents" or
            element.name == "ftrainworks-sensor-gui-controls-checkbox-read-fuel" then
        -- Get the preview to fetch the entity
        local screen = player.gui.screen
        local ui_window_frame = screen["ftrainworks-sensor-gui-window"]
        if not ui_window_frame then return end
        local ui_frame = ui_window_frame["ftrainworks-sensor-gui"]
        local ui_content_frame = ui_frame["ftrainworks-sensor-gui-content-frame"]
        local ui_content_flow = ui_content_frame["ftrainworks-sensor-gui-content-flow"]
        local ui_preview_frame = ui_content_flow["ftrainworks-sensor-gui-preview-frame"]
        local ui_preview = ui_preview_frame["ftrainworks-sensor-gui-preview"]
        local entity = ui_preview.entity
        if not (entity and entity.valid) then return end

        -- Update the combinator description
        local description = entity.combinator_description or ""
        if element.name == "ftrainworks-sensor-gui-controls-checkbox-read-type" then
            if element.state then
                if not string.find(description, " read-type", 1, true) then
                    description = description .. " read-type"
                end
            else
                description = string.gsub(description, " read%-type", "")
            end
        elseif element.name == "ftrainworks-sensor-gui-controls-checkbox-read-contents" then
            if element.state then
                if not string.find(description, " read-contents", 1, true) then
                    description = description .. " read-contents"
                end
            else
                description = string.gsub(description, " read%-contents", "")
            end
        elseif element.name == "ftrainworks-sensor-gui-controls-checkbox-read-fuel" then
            if element.state then
                if not string.find(description, " read-fuel", 1, true) then
                    description = description .. " read-fuel"
                end
            else
                description = string.gsub(description, " read%-fuel", "")
            end
        end
        entity.combinator_description = description

        -- Update the gui
        update_train_sensor_gui(player, entity)
    end
end)

registry.register(defines.events.on_gui_closed, function(event)
    if event.gui_type == defines.gui_type.custom then
        local player = game.get_player(event.player_index)
        if not (player and player.valid) then return end
        local screen = player.gui.screen
        local gui = screen[event.element.name]
        if not (gui and gui.valid) then return end
        if gui.name == "ftrainworks-coupler-inserter-gui-window" then
            close_coupler_gui(player)
        elseif gui.name == "ftrainworks-sensor-gui-window" then
            close_train_sensor_gui(player)
        end
    end
end)