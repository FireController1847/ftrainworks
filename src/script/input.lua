local function connect_disconnect_rolling_stock(player, selected)
    local nearby = player.surface.find_entities_filtered{
        area={
            {selected.position.x - 2.5, selected.position.y - 2.5},
            {selected.position.x + 2.5, selected.position.y + 2.5}
        }
    }

    -- Find all carriages in the area
    local carriages = {}
    for _, entity in pairs(nearby) do
        if not entity or not entity.valid then goto continue end
        if not entity.train then goto continue end
        if entity.type == "locomotive" or entity.type:sub(-6) == "-wagon" then
            table.insert(carriages, entity)
        end
        ::continue::
    end
    if not (#carriages >= 2) then return end

    -- Sort by distance to the coupler
    table.sort(carriages, function(a, b)
        local da = (a.position.x - selected.position.x) ^ 2 + (a.position.y - selected.position.y) ^ 2
        local db = (b.position.x - selected.position.x) ^ 2 + (b.position.y - selected.position.y) ^ 2
        return da < db
    end)

    -- Determine relative direction
    local carriage1 = carriages[1]
    local carriage2 = carriages[2]
    local front_connected = carriage1.get_connected_rolling_stock(defines.rail_direction.front)
    local back_connected = carriage1.get_connected_rolling_stock(defines.rail_direction.back)
    if front_connected and (front_connected == carriage2) then
        carriage1.disconnect_rolling_stock(defines.rail_direction.front)
        player.surface.play_sound{
            path = "ftrainworks-decouple",
            position = selected.position
        }
    elseif back_connected and (back_connected == carriage2) then
        carriage1.disconnect_rolling_stock(defines.rail_direction.back)
        player.surface.play_sound{
            path = "ftrainworks-decouple",
            position = selected.position
        }
    else
        if not carriage1.connect_rolling_stock(defines.rail_direction.front) then
            if not carriage1.connect_rolling_stock(defines.rail_direction.back) then
                player.print("Failed to connect carriages.");
                return
            end
        end
        player.surface.play_sound{
            path = "ftrainworks-couple",
            position = selected.position
        }
        return
    end
end

script.on_event("ftrainworks-left-click", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local selected = player.selected
    if not selected then return end
    if selected.name == "ftrainworks-coupler" then
        connect_disconnect_rolling_stock(player, selected)
    end
end);