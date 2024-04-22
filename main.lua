-- Scrappers v1.0.0
-- Klehrik

log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

local sPrinter      = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/Sprites/sPrinter.png", 23, false, false, 36, 48)
local sScrapWhite   = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/Sprites/sScrapWhite.png", 1, false, false, 16, 16)
local sScrapGreen   = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/Sprites/sScrapGreen.png", 1, false, false, 16, 16)
local sScrapRed     = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/Sprites/sScrapRed.png", 1, false, false, 16, 16)
local sScrapYellow  = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/Sprites/sScrapYellow.png", 1, false, false, 16, 16)

local class_item    = nil
local class_stage   = nil

local create_scrapper = false

local scrap_names = {"White", "Green", "Red", "Yellow"}
local scrap_sprites = {sScrapWhite, sScrapGreen, sScrapRed, sScrapYellow}


-- Parameters
local scrapper_chance   = 1
local max_scrap_amount  = 10    -- Upper limit to how many can be scrapped at once



-- ========== Functions ==========

local function spawn_command_crate(x, y)
    local c = gm.instance_create_depth(x, y, 1, gm.constants.oCustomObject_pInteractableCrate)

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


function spawn_scrapper(x, y)
    local s = spawn_command_crate(x, y)
    s.is_scrapper = true
    s.sprite_index = sPrinter
    s.text = "Use scrapper"
end


function spawn_scrap(x, y, rarity)
    local base = gm.instance_create_depth(x, y, 0, gm.constants.oNugget)
    base.item_id = gm.item_find("scrappers-scrap"..scrap_names[rarity])

    local item = class_item[base.item_id + 1]
    base.text1 = item[3]
    base.text2 = item[4]
    base.tier = item[7]
    base.sprite_index = item[8]
    base.image_speed = 0.0
end


-- ========== Main ==========

gm.pre_script_hook(gm.constants.__input_system_tick, function()
    -- Get global references
    if not class_item then
        -- Global references
        class_item = gm.variable_global_get("class_item")
        class_stage = gm.variable_global_get("class_stage")
    end

    -- Create scrap items
    if not gm.item_find("scrappers-scrapWhite") then
        for i = 1, #scrap_names do
            local id = gm.item_create("scrappers", "scrap"..scrap_names[i])
            local item = class_item[id + 1]
            gm.array_set(item, 2, "Item Scrap ("..scrap_names[i]..")")
            gm.array_set(item, 3, "Prioritized by printers.")
            gm.array_set(item, 6, (i == 4 and 4) or (i - 1))
            gm.array_set(item, 7, scrap_sprites[i])
        end
    end


    -- Place down scrapper on stage load (check when the player exists)
    if create_scrapper and Helper.get_client_player() then
        create_scrapper = false

        -- Prevent scrappers from spawning on the Contact Light
        if class_stage[gm.variable_global_get("stage_id") + 1][2] ~= "riskOfRain" then

            -- Get valid terrain
            local blocks = Helper.find_active_instance_all(gm.constants.oB)
            local tp = Helper.get_teleporter()

            -- Maybe spawn a scrapper
            if Helper.chance(scrapper_chance) then
                -- Make sure the scrapper doesn't spawn on the teleporter,
                -- as that prevents the player from using it
                while true do
                    local block = blocks[gm.irandom_range(1, #blocks)]
                    local x, y = block.bbox_left + gm.irandom_range(0, block.bbox_right - block.bbox_left), block.bbox_top - 1
                    if gm.point_distance(x, y, tp.x, tp.y) > 64 then
                        spawn_scrapper(x, y)
                        break
                    end
                end
            end
            
        end
    end
end)


gm.pre_script_hook(gm.constants.interactable_set_active, function(self, other, result, args)
    -- Check if this is a scrapper
    if self.is_scrapper then

        local contents = gm.array_create()
        local contents_ids = gm.array_create()
        local contents_count = gm.array_create()

        -- Replace contents with player inventory
        if gm.array_length(other.inventory_item_order) > 0 then
            -- Get ids of scrap items
            local ids = {}
            for i = 1, #scrap_names do
                table.insert(ids, gm.item_find("scrappers-scrap"..scrap_names[i]))
            end

            -- Loop through inventory and add
            for _, i in ipairs(other.inventory_item_order) do

                -- Do not allow scraps to be scrapped
                if not (i == ids[1] or i == ids[2] or i == ids[3] or i == ids[4]) then

                    -- Do not allow purple+ items to be scrapped
                    if class_item[i + 1][7] <= 4.0 then

                        local count = gm.item_count(other, i, false)
                        if count > 0 then
                            gm.array_push(contents, class_item[i + 1][9])
                            gm.array_push(contents_ids, i)
                            gm.array_push(contents_count, count)
                        end
                    end
                end
            end
        end

        if #contents <= 0 then
            gm.audio_play_sound(gm.constants.wError, 0, false)
            return false
        end

        self.contents = contents
        self.contents_ids = contents_ids
        self.contents_count = contents_count
    end
end)


gm.pre_code_execute(function(self, other, code, result, flags)
    -- Check if this is a scrapper
    if self.is_scrapper then
        if code.name:match("oCustomObject_pInteractableCrate_Draw_0") then

            -- Scrapper is used
            if self.active > 1.0 then

                -- Prevent destruction of the scrapper
                -- and give back player control
                self.active = 0.0
                self.activator.activity = 0.0
                self.activator.activity_free = true
                self.activator.activity_move_factor = 1.0
                self.activator.activity_type = 0.0
                self.last_move_was_mouse = true


                -- Start scrapper animation
                local id = self.contents_ids[self.selection + 1]
                local count = math.min(self.contents_count[self.selection + 1], max_scrap_amount)
                local rarity = class_item[id + 1][7]

                gm.item_take(self.activator, id, count, false)
                for i = 1, count do spawn_scrap(self.x, self.y, (rarity == 4 and 4) or (rarity + 1)) end
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
gui.add_imgui(function()
    local player = Helper.find_active_instance(gm.constants.oP)
    if player and ImGui.Begin("Scrappers") then

        if ImGui.Button("Spawn command crate") then
            spawn_command_crate(player.x, player.y)
        elseif ImGui.Button("Spawn scrapper") then
            spawn_scrapper(player.x, player.y)
        elseif ImGui.Button("Give white scrap") then
            for i = 1, 4 do spawn_scrap(player.x, player.y, i) end
        end

    end

    ImGui.End()
end)