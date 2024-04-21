-- Scrappers v1.0.0
-- Klehrik

log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

local sPrinter = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/sPrinter.png", 23, false, false, 36, 48)

local class_item = nil
local class_stage = nil
local lang_map = nil

--local printer_base = gm.constants.oArtifactShrine   -- Unused interactable
--local create_printers = false

local Colors = {
    16777215,   -- White
    5813365,    -- Green
    4007881,    -- Red
    0,
    4312538     -- Yellow
}


-- Parameters




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



-- ========== Main ==========

gm.pre_script_hook(gm.constants.__input_system_tick, function()
    -- Get global references
    if not class_item then
        class_item = gm.variable_global_get("class_item")
        class_stage = gm.variable_global_get("class_stage")
        lang_map = gm.variable_global_get("_language_map")
    end
end)


gm.pre_script_hook(gm.constants.interactable_set_active, function(self, other, result, args)
    -- Check if this is a scrapper
    if self.is_scrapper then

        -- Replace contents with player inventory
        if gm.array_length(other.inventory_item_order) > 0 then
            self.contents = gm.array_create()
            self.contents_ids = gm.array_create()
            for _, i in ipairs(other.inventory_item_order) do
                gm.array_push(self.contents, class_item[i + 1][9])
                gm.array_push(self.contents_ids, i)
            end

        else
            gm.audio_play_sound(gm.constants.wError, 0, false)
            return false
        end
    end
end)


gm.pre_code_execute(function(self, other, code, result, flags)
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


            -- Start scrapper animation
            gm.instance_create_depth(self.activator.x, self.activator.y, 0, self.contents[self.selection + 1])
            gm.item_take(self.activator, self.contents_ids[self.selection + 1], 1, false)
        end
    end
end)


-- Debug
gui.add_imgui(function()
    local player = Helper.find_active_instance(gm.constants.oP)
    if player and ImGui.Begin("Scrappers") then

        if ImGui.Button("Spawn command crate") then
            spawn_command_crate(player.x, player.y)
        elseif ImGui.Button("Spawn scrapper") then
            spawn_scrapper(player.x, player.y)
        end

    end

    ImGui.End()
end)