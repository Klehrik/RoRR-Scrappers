-- Scrappers
-- Klehrik

log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

local sScrapper     = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/sScrapper.png", 1, false, false, 10, 25)
local sScrapWhite   = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/sScrapWhite.png", 1, false, false, 13, 13)
local sScrapGreen   = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/sScrapGreen.png", 1, false, false, 13, 13)
local sScrapRed     = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/sScrapRed.png", 1, false, false, 13, 13)
local sScrapYellow  = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/sScrapYellow.png", 1, false, false, 13, 13)

local class_item    = nil
local class_stage   = nil

local scrapper_base = gm.constants.oCustomObject_pInteractableCrate
local scrap_base = gm.constants.oTshirt
local create_scrapper = false

local scrap_names = {"White", "Green", "Red", "Yellow"}
local scrap_sprites = {sScrapWhite, sScrapGreen, sScrapRed, sScrapYellow}

local scrap_setup_array = {}


-- Parameters
local scrapper_chance       = 0.3
local max_scrap_amount      = 10    -- Upper limit to how many can be scrapped at once

local animation_held_time   = 80
local animation_print_time  = 32
local box_x_offset          = 0     -- Location of the hole of the scrapper relative to the origin
local box_y_offset          = -26
local box_input_scale       = 0     -- Item scale when it enters the scrapper



-- ========== Functions ==========

local function spawn_command_crate(x, y)
    local c = gm.instance_create_depth(x, y, 1, scrapper_base)

    -- All of the following are absolutely necessary,
    -- and are not set from creating the instance directly
    c.active = 0.0
    c.owner = -4.0
    c.activator = -4.0
    c.buy_button_visible = 0.0
    c.can_activate_frame = 0.0
    c.mouse_x_last = 0.0
    c.mouse_y_last = 0.0
    c.last_move_was_mouse = false
    c.using_mouse = false
    c.last_activated_frame = -1.0
    c.cam_rect_x1 = x - 100
    c.cam_rect_y1 = y - 100
    c.cam_rect_x2 = x + 100
    c.cam_rect_y2 = y + 100
    c.contents = nil
    c.inventory = 76.0
    c.flash = 0.0
    c.interact_scroll_index = 6.0
    c.interact_scroll_index_inactive = 5.0
    c.surf_text_cost_large = -1.0
    c.surf_text_cost_small = -1.0
    c.text = "Choose an item."
    c.spawned = true
    c.cost = 0.0
    c.cost_type = 0.0
    c.selection = 0.0
    c.select_cd = 0.0
    c.sprite_death = 1373.0
    c.fade_alpha = 0.0
    c.col_index = 0.0
    c.m_id = 0.0
    c.my_player = -4.0
    c.__custom_id = 0.0
    c.__object_index = 800.0

    return c
end


local function spawn_scrapper(x, y)
    local s = spawn_command_crate(x, y)
    s.is_scrapper = true
    s.sprite_index = sScrapper
    s.text = "Use scrapper"
    s.image_speed = 0.0

    s.animation_state = nil
    s.box_x = s.x + box_x_offset
    s.box_y = s.y + box_y_offset

    -- [Host]  Send setup data to clients
    if Helper.is_lobby_host() then Helper.net_send("Scrapper.setup", {x, y}) end
end


local function spawn_scrap(x, y, rarity)
    if not Helper.is_singleplayer_or_host() then return end

    local base = gm.instance_create_depth(x, y, 0, scrap_base)
    setup_scrap(base, rarity)

    -- [Host]  Send setup data to clients
    if Helper.is_lobby_host() then Helper.net_send("Scrapper.setup_scrap", {x, y, rarity}) end
end


function setup_scrap(base, rarity)
    base.item_id = gm.item_find("scrappers-scrap"..scrap_names[rarity])

    local item = class_item[base.item_id + 1]
    base.text1 = item[3]
    base.text1_key = item[3]
    base.text2 = item[4]
    base.tier = item[7]
    base.sprite_index = item[8]
end


local function get_scrapper(x, y)
    -- Look for base interactable at the given position
    local bases = Helper.find_active_instance_all(scrapper_base)
    for _, b in ipairs(bases) do
        -- Doesn't spawn exactly on position for some reason
        if math.abs(b.x - x) <= 3 and math.abs(b.y - y) <= 3 then return b end
    end
    return nil
end


local function get_scrap(x, y)
    -- Look for base instances at the given position
    local scrap = {}
    local bases = Helper.find_active_instance_all(scrap_base)
    for _, b in ipairs(bases) do
        -- Doesn't spawn exactly on position for some reason
        if math.abs(b.x - x) <= 3 and math.abs(b.y - y) <= 10 then table.insert(scrap, b) end
    end
    return scrap
end


local function draw_item_sprite(sprite, x, y, scale, alpha)
    gm.draw_sprite_ext(sprite, 0, x, y, scale or 1.0, scale or 1.0, 0.0, 16777215, alpha or 1.0)
end



-- ========== Main ==========

gm.pre_script_hook(gm.constants.__input_system_tick, function()
    -- Get global references
    if not class_item then
        class_item = gm.variable_global_get("class_item")
        class_stage = gm.variable_global_get("class_stage")
    end
    
    -- Create scrap items
    if not gm.item_find("scrappers-scrapWhite") then
        for i = 1, #scrap_names do
            local id = gm.item_create("scrappers", "scrap"..scrap_names[i])
            local item = class_item[id + 1]
            gm.array_set(item, 2, "Item Scrap ("..scrap_names[i]..")")
            gm.array_set(item, 3, "Does nothing. Prioritized when using printers.")
            gm.array_set(item, 6, (i == 4 and 4) or (i - 1))
            gm.array_set(item, 7, scrap_sprites[i])
        end
    end


    -- Toggle initial spawning off if not host
    if not Helper.is_singleplayer_or_host() then create_scrapper = false end

    -- Place down scrapper on stage load (check when the player exists)
    if create_scrapper and Helper.get_client_player() then
        create_scrapper = false

        -- Chance to spawn a scrapper
        -- Also prevent spawning on the Contact Light
        if Helper.chance(scrapper_chance) and class_stage[gm.variable_global_get("stage_id") + 1][2] ~= "riskOfRain" then

            -- Get valid terrain
            local blocks = Helper.find_active_instance_all(gm.constants.oB)
            local tp = Helper.get_teleporter()

            -- Make sure the scrapper doesn't spawn on the teleporter,
            -- as that prevents the player from using it
            while true do
                local block = blocks[gm.irandom_range(1, #blocks)]
                local x, y = (block.bbox_left + 16) + gm.irandom_range(0, block.bbox_right - block.bbox_left - 16), block.bbox_top - 1
                if gm.point_distance(x, y, tp.x, tp.y) > 64 then
                    spawn_scrapper(x, y)
                    break
                end
            end
        end
    end


    -- [Client]  Set up scrapper from sent data
    while Helper.net_has("Scrapper.setup") do
        local data = Helper.net_listen("Scrapper.setup").data
        spawn_scrapper(data[1], data[2])
    end


    -- [Client]  Set up scrap item from sent data
    while Helper.net_has("Scrapper.setup_scrap") do
        local data = Helper.net_listen("Scrapper.setup_scrap").data
        table.insert(scrap_setup_array, data)
    end

    for i = #scrap_setup_array, 1, -1 do
        local data = scrap_setup_array[i]
        local bases = get_scrap(data[1], data[2])
        local setup_done = false
        for _, b in ipairs(bases) do
            setup_scrap(b, data[3])
            setup_done = true
        end
        if setup_done then table.remove(scrap_setup_array, i) end
    end


    -- [All]  Set scrapper contents (and activator)
    while Helper.net_has("Scrapper.contents") do
        local data = Helper.net_listen("Scrapper.contents").data
        local base = get_scrapper(data[1], data[2])
        if base then
            local p = Helper.get_player_from_name(data[3])
            base.active = 1.0
            base.activator = p
            base.owner = p
            base.contents, base.contents_ids, base.contents_count = get_contents(p)
        end
    end


    -- [All]  Receive selection value and start scrapper animation
    while Helper.net_has("Scrapper.selection") do
        local data = Helper.net_listen("Scrapper.selection").data
        local base = get_scrapper(data[1], data[2])
        if base then
            base.selection = data[3]
            start_scrapper_animation(base)
        end
    end


    -- [All]  Reset scrapper variables
    while Helper.net_has("Scrapper.reset") do
        local data = Helper.net_listen("Scrapper.reset").data
        local base = get_scrapper(data[1], data[2])
        if base then base.force_scrapper_reset = 3 end
    end
end)


gm.pre_script_hook(gm.constants.interactable_set_active, function(self, other, result, args)
    -- Observation: For mp clients, active is automatically set to -1.0 as a default behavior when this function is called

    -- Check if this is a scrapper
    if self.is_scrapper then
        local player = args[2].value

        -- Prevent use if it's already in use
        if self.animation_state then
            self.active = 0.0
            gm.audio_play_sound(gm.constants.wError, 0, false)
            return false
        end

        -- Check if this client is the activator
        if player == Helper.get_client_player() then
            self.contents, self.contents_ids, self.contents_count = get_contents(player)

            -- Prevent use if there are no valid items
            if #self.contents <= 0 then
                self.active = 0.0
                gm.audio_play_sound(gm.constants.wError, 0, false)
                return false
            end

            self.active = 1.0
            self.activator = player
            self.owner = player

            -- [Net]  Send contents info to other players
            if not Helper.is_singleplayer() then Helper.net_send("Scrapper.contents", {self.x, self.y, player.user_name}) end
        end

        return false
    end
end)


function get_contents(player)
    -- Get valid items for scrapping in the player's inventory

    local contents = gm.array_create()
    local contents_ids = gm.array_create()
    local contents_count = gm.array_create()

    -- Get ids of scrap items
    local ids = {}
    for i = 1, #scrap_names do table.insert(ids, gm.item_find("scrappers-scrap"..scrap_names[i])) end

    if gm.array_length(player.inventory_item_order) > 0 then
        -- Loop through inventory and add
        for _, i in ipairs(player.inventory_item_order) do

            -- Do not allow scraps to be scrapped
            if not (i == ids[1] or i == ids[2] or i == ids[3] or i == ids[4]) then

                -- Do not allow purple+ items to be scrapped
                if class_item[i + 1][7] <= 4.0 then

                    local count = gm.item_count(player, i, false)
                    if count > 0 then
                        gm.array_push(contents, class_item[i + 1][9])
                        gm.array_push(contents_ids, i)
                        gm.array_push(contents_count, count)
                    end
                end
            end
        end
    end

    return contents, contents_ids, contents_count
end


gm.pre_code_execute("gml_Object_oCustomObject_pInteractableCrate_Draw_0", function(self, other)
    -- Check if this is a scrapper
    if self.is_scrapper then
        -- Fix: Force scrapper reset
        -- I am losing my mind
        if self.force_scrapper_reset and self.force_scrapper_reset > 0 then
            self.force_scrapper_reset = self.force_scrapper_reset - 1
            self.active = 0.0
            self.activator = -4.0
            self.animation_state = nil
        end


        -- Scrapper is used
        if self.active > 1.0 then
            self.active = 0.1
            self.animation_state = 0

            if Helper.get_client_player() == self.activator then
                -- Give back player control
                self.activator.activity = 0.0
                self.activator.activity_free = true
                self.activator.activity_move_factor = 1.0
                self.activator.activity_type = 0.0
                self.last_move_was_mouse = true

                -- Start if Cancel (Better Crates mod) was not selected
                -- This won't run if Better Crates runs first, which is fine
                local cancel = false

                local id = gm.item_find("betterCrates-cancel")
                if id and self.contents_ids[self.selection + 1] == id then cancel = true end

                if not cancel then
                    start_scrapper_animation(self)

                    -- [Net]  Send selection value to other players
                    if not Helper.is_singleplayer() then Helper.net_send("Scrapper.selection", {self.x, self.y, self.selection}) end

                else
                    self.active = 0.0

                    -- [Net]  Send reset signal to other players
                    if not Helper.is_singleplayer() then
                        Helper.net_send("Scrapper.reset", {self.x, self.y})
                    end
                end
            end

        end
    end
end)


function start_scrapper_animation(scrapper)
    -- Start scrapper animation
    scrapper.active = 0.0
    scrapper.animation_state = 1

    scrapper.taken = scrapper.contents_ids[scrapper.selection + 1]
    scrapper.taken_count = math.min(scrapper.contents_count[scrapper.selection + 1], max_scrap_amount)
    scrapper.taken_rarity = class_item[scrapper.taken + 1][7]

    gm.audio_play_sound(gm.constants.wDroneRecycler_Activate, 0, false)

    -- [Single/Host]  Remove item from inventory
    if Helper.is_singleplayer_or_host() then gm.item_take(scrapper.activator, scrapper.taken, scrapper.taken_count, false) end
end


gm.post_code_execute("gml_Object_oInit_Draw_73", function(self, other)
    -- Loop through all scrappers
    local base_obj = Helper.find_active_instance_all(scrapper_base)
    for _, p in ipairs(base_obj) do
        if p.is_scrapper then

            -- Scrapper animation
            if p.animation_state then

                -- Initialize animation stuff
                if p.animation_state == 1 then
                    p.animation_state = 2
                    p.animation_time = 0
                    p.animation_items = gm.array_create()

                    for i = 1, p.taken_count do
                        local offset = ((p.taken_count - 1) * -17) + ((i - 1) * 34)
                        local array = gm.array_create()
                        gm.array_push(array, class_item[p.taken + 1][8], offset, -48, 1.0)   -- Sprite, x offset, y offset, scale
                        gm.array_push(p.animation_items, array)
                    end

                -- Draw above player
                elseif p.animation_state == 2 then
                    for _, i in ipairs(p.animation_items) do
                        draw_item_sprite(i[1], p.activator.x + i[2], p.activator.y + i[3])
                    end

                    if p.animation_time < animation_held_time then p.animation_time = p.animation_time + 1
                    else
                        p.animation_state = 3

                        -- Set offset values to absolute position values
                        for _, i in ipairs(p.animation_items) do
                            gm.array_set(i, 1, p.activator.x + i[2])
                            gm.array_set(i, 2, p.activator.y + i[3])
                        end
                    end

                -- Lerp all items towards hole
                elseif p.animation_state == 3 then
                    for _, i in ipairs(p.animation_items) do
                        draw_item_sprite(i[1], i[2], i[3], Helper.ease_out(i[4], 3))

                        gm.array_set(i, 1, gm.lerp(i[2], p.box_x, 0.1))
                        gm.array_set(i, 2, gm.lerp(i[3], p.box_y, 0.1))
                        gm.array_set(i, 3, gm.lerp(i[4], box_input_scale, 0.1))
                    end

                    local first = p.animation_items[1]
                    if gm.point_distance(first[2], first[3], p.box_x, p.box_y) < 1 then
                        p.animation_state = 4
                        p.animation_time = 0
                        gm.audio_play_sound(gm.constants.wDroneRecycler_Recycling, 0, false)
                    end

                -- Delay for scrapping sfx
                elseif p.animation_state == 4 then
                    if p.animation_time < animation_print_time then p.animation_time = p.animation_time + 1
                    else p.animation_state = 5
                    end

                -- Create scrap drop(s)
                elseif p.animation_state == 5 then
                    p.animation_state = nil
                    p.activator = -4.0

                    for i = 1, p.taken_count do spawn_scrap(p.box_x, p.box_y, (p.taken_rarity == 4 and 4) or (p.taken_rarity + 1)) end

                end
            end
            
        end
    end
end)


gm.post_script_hook(gm.constants.stage_roll_next, function(self, other, result, args)
    create_scrapper = true
end)

gm.post_script_hook(gm.constants.stage_goto, function(self, other, result, args)
    create_scrapper = true
end)


-- Debug
-- gui.add_imgui(function()
--     local player = Helper.find_active_instance(gm.constants.oP)
--     if player and ImGui.Begin("Scrappers") then

--         -- if ImGui.Button("Spawn command crate") then
--         --     spawn_command_crate(player.x, player.y)
--         -- elseif ImGui.Button("Spawn scrapper") then
--         --     spawn_scrapper(player.x, player.y)
--         -- elseif ImGui.Button("Give white scrap") then
--         --     for i = 1, 4 do spawn_scrap(player.x, player.y, i) end
--         -- elseif ImGui.Button("Spawn scrap to the side") then
--         --     spawn_scrap(player.x - 64, player.y, 1)
--         --     spawn_scrap(player.x - 32, player.y, 2)
--         --     spawn_scrap(player.x + 32, player.y, 3)
--         --     spawn_scrap(player.x + 64, player.y, 4)
--         -- end

--         if ImGui.Button("Create scrapper") then
--             create_scrapper = true
--         end

--     end

--     ImGui.End()
-- end)