if string.lower(RequiredScript) == "lib/managers/experiencemanager" then	
	local first_xp = 0

	local function total_xp() 
		return managers.experience:get_xp_dissected(true, managers.network:session():amount_of_alive_players(), not Utils:IsInCustody())
	end

	Hooks:PostHook(ExperienceManager, "init", "initial_thingies", function()
		Global.level_reached = 0
		
		if Idstring("russian"):key() == SystemInfo:language():key() then
			LocalizationManager:add_localized_strings({
				menu_reached_level_title = "Уровень получен!",
				menu_reached_level_desc = "\nДостигнут уровень:   ",
				hud_potential_xp = "Всего получено опыта: $XP",
				hud_level_ups = "Уровней репутации достигнуто: $LEVELS",
				hud_ingame_rewarded_xp = "Получено опыта: $REWARD",
			})
		else
			LocalizationManager:add_localized_strings({
				menu_reached_level_title = "Level Up!",
				menu_reached_level_desc = "\nReached Level:   ",
				hud_potential_xp = "Total XP gained: $XP",
				hud_level_ups = "Reputation Levels Reached: $LEVELS",
				hud_ingame_rewarded_xp = "XP gained: $REWARD",
			})
		end
	end)
	
	local data = ExperienceManager.mission_xp_award
	function ExperienceManager:mission_xp_award(amount)
		first_xp = total_xp()
	
		data(self, amount)
		
		local second_xp = total_xp()
		local xp_added = second_xp - first_xp
		
		if not managers.crime_spree:is_active() then
			managers.experience:add_points(xp_added, true)
			
			if managers.hud then
				managers.hud:on_ext_inventory_changed()
			end
			
			MenuCallbackHandler:save_progress()
			managers.savefile._gui_script:set_text(managers.localization:to_upper_text("hud_ingame_rewarded_xp", {REWARD = managers.money:add_decimal_marks_to_string(tostring(xp_added))}))
		end
	end

	Hooks:PostHook(ExperienceManager, "_level_up", "get_level_up_message", function(self)
		local hud = managers.hud
		
		if not hud then
			return
		end
		
		tweak_data.hud_icons["Level_Up_icon"] = {
			texture = "guis/textures/pd2/blackmarket/xp_drop",
			texture_rect = {
				0,
				0,
				128,
				128
			}
		}
		
		local level = self:current_level()
		local function level_up_icon()
			if level == 5 then
				return "Other_H_All_AllLevel005"
			elseif level == 10 then
				return "Other_H_All_AllLevel010"
			elseif level == 25 then
				return "Other_H_All_AllLevel025"
			elseif level == 50 then
				return "Other_H_All_AllLevel050"
			elseif level == 75 then
				return "Other_H_All_AllLevel075"
			elseif level == 100 then
				return "Other_H_All_AllLevel100"
			else
				return "Level_Up_icon"
			end
		end
		
		hud:custom_ingame_popup_text(managers.localization:to_upper_text("menu_reached_level_title"), managers.localization:to_upper_text("menu_reached_level_desc") .. tostring(level), level_up_icon())
		hud:post_event("infamous_stinger_generic")
		Global.level_reached = Global.level_reached + 1
	end)
	
	function ExperienceManager:give_experience(xp, force_or_debug)
		managers.skilltree:give_specialization_points(xp)
		managers.custom_safehouse:give_upgrade_points(xp)

		return {
			gained = 0,
			start_t = {
				level = self:current_level()
			}
		}
	end
end
if string.lower(RequiredScript) == "lib/managers/hud/hudstageendscreen" then
	local data = HUDStageEndScreen.stage_experience_init
	function HUDStageEndScreen:stage_experience_init(t, dt)
		local next_level_data = managers.experience:next_level_data() or {}
		if self._data.gained == 0  then
			self._lp_text:show()
			self._lp_circle:show()
			self._lp_backpanel:child("bg_progress_circle"):show()
			self._lp_forepanel:child("level_progress_text"):show()
			self._lp_text:set_text(tostring(self._data.start_t.level))
			self._lp_circle:set_color(Color((next_level_data.current_points or 1) / (next_level_data.points or 1), 1, 1))
			managers.menu_component:post_event("box_tick")
			
			self:step_stage_to_end()
			
			return
		end
		data(self, t, dt)
	end
end
if string.lower(RequiredScript) == "lib/managers/hud/newhudstatsscreen" then
	function HUDStatsScreen:recreate_bottom()
		if managers.crime_spree:is_active() then
			return
		end
		self._bottom:clear()
		self._bottom:bitmap({
			texture = "guis/textures/test_blur_df",
			layer = -1,
			render_template = "VertexColorTexturedBlur3D",
			valign = "grow",
			w = self._bottom:w(),
			h = self._bottom:h()
		})

		local rb = HUDBGBox_create(self._bottom, {}, {
			blend_mode = "normal",
			color = Color.white
		})

		rb:child("bg"):set_color(Color(0, 0, 0):with_alpha(0.75))
		rb:child("bg"):set_alpha(1)
		self:exp_progress()
	end

	function HUDStatsScreen:exp_progress()
		local extended_inventory_panel = self._right:child("extended_inventory_panel")
		
		local offset = 15
		local profile_wrapper_panel = self._bottom:panel({name = "profile_wrapper_panel", x = offset, y = -22})
		
		local next_level_data = managers.experience:next_level_data() or {}
		local bg_ring = profile_wrapper_panel:bitmap({
			texture = "guis/textures/pd2/level_ring_small",
			w = 64,
			h = 64,
			alpha = 0.4,
			color = Color.black
		})
		local exp_ring = profile_wrapper_panel:bitmap({
			texture = "guis/textures/pd2/level_ring_small",
			h = 64,
			render_template = "VertexColorTexturedRadial",
			w = 64,
			blend_mode = "add",
			rotation = 360,
			layer = 1,
			color = Color((next_level_data.current_points or 1) / (next_level_data.points or 1), 1, 1)
		})

		bg_ring:set_bottom(profile_wrapper_panel:h())
		exp_ring:set_bottom(profile_wrapper_panel:h())

		local gain_xp = managers.experience:get_xp_dissected(true, 0, true)
		local at_max_level = managers.experience:current_level() == managers.experience:level_cap()
		local can_lvl_up = managers.experience:current_level() ~= 0 and not at_max_level and next_level_data.current_points <= gain_xp
		local progress = (next_level_data.current_points or 1) / (next_level_data.points or 1)
		local gain_progress = (gain_xp or 1) / (next_level_data.points or 1)
		local exp_gain_ring = profile_wrapper_panel:bitmap({
			texture = "guis/textures/pd2/level_ring_potential_small",
			h = 64,
			render_template = "VertexColorTexturedRadial",
			w = 64,
			blend_mode = "normal",
			rotation = 360,
			layer = 2,
			color = Color(gain_progress, 1, 0)
		})

		exp_gain_ring:rotate(360 * (progress - gain_progress))
		exp_gain_ring:set_center(exp_ring:center())

		local level_text = profile_wrapper_panel:text({
			name = "level_text",
			font = tweak_data.menu.pd2_medium_font,
			font_size = tweak_data.hud_stats.day_description_size,
			text = tostring(managers.experience:current_level()),
			color = tweak_data.screen_colors.text
		})

		managers.hud:make_fine_text(level_text)
		level_text:set_center(exp_ring:center())

		if at_max_level then
			local text = managers.localization:to_upper_text("hud_at_max_level")
			local at_max_level_text = profile_wrapper_panel:text({
				name = "at_max_level_text",
				text = text,
				font_size = tweak_data.menu.pd2_small_font_size,
				font = tweak_data.menu.pd2_small_font,
				color = tweak_data.hud_stats.potential_xp_color
			})

			managers.hud:make_fine_text(at_max_level_text)
			at_max_level_text:set_left(math.round(exp_ring:right() + 4))
			at_max_level_text:set_center_y(math.round(exp_ring:center_y()) + 0)
		else
			local next_level_in = profile_wrapper_panel:text({
				text = "",
				name = "next_level_in",
				font_size = tweak_data.menu.pd2_small_font_size,
				font = tweak_data.menu.pd2_small_font,
				color = tweak_data.screen_colors.text
			})
			local points = next_level_data.points - next_level_data.current_points

			next_level_in:set_text(utf8.to_upper(managers.localization:text("menu_es_next_level") .. " " .. managers.money:add_decimal_marks_to_string(tostring(points))))
			managers.hud:make_fine_text(next_level_in)
			next_level_in:set_left(math.round(exp_ring:right() + 4))
			next_level_in:set_center_y(math.round(exp_ring:center_y()) - 20)

			local text = managers.localization:to_upper_text("hud_potential_xp", {XP = managers.money:add_decimal_marks_to_string(tostring(gain_xp))})
			local gain_xp_text = profile_wrapper_panel:text({
				name = "gain_xp_text",
				text = text,
				font_size = tweak_data.menu.pd2_small_font_size,
				font = tweak_data.menu.pd2_small_font,
				color = tweak_data.hud_stats.potential_xp_color
			})

			managers.hud:make_fine_text(gain_xp_text)
			gain_xp_text:set_left(math.round(exp_ring:right() + 4))
			gain_xp_text:set_center_y(math.round(exp_ring:center_y()) + 0)

			if can_lvl_up then
				local text = managers.localization:to_upper_text("hud_level_ups", {LEVELS = tostring(Global.level_reached)})
				local potential_level_up_text = profile_wrapper_panel:text({
					vertical = "center",
					name = "potential_level_up_text",
					blend_mode = "normal",
					align = "left",
					layer = 3,
					visible = can_lvl_up,
					text = text,
					font_size = tweak_data.menu.pd2_small_font_size,
					font = tweak_data.menu.pd2_small_font,
					color = tweak_data.hud_stats.potential_xp_color
				})

				managers.hud:make_fine_text(potential_level_up_text)
				potential_level_up_text:set_left(math.round(exp_ring:right() + 4))
				potential_level_up_text:set_center_y(math.round(exp_ring:center_y()) + 20)
				potential_level_up_text:animate(callback(self, self, "_animate_text_pulse"), exp_gain_ring, exp_ring, bg_ring)
			end
		end	
	end

	local original_init = HUDStatsScreen.init
	function HUDStatsScreen:init(...)
		original_init(self, ...)
		self._full_hud_panel = managers.hud:script(managers.hud.STATS_SCREEN_FULLSCREEN).panel
		self._bottom = ExtendedPanel:new(self, {
			h = 114,
			w = self._full_hud_panel:w() / 3 - 10 * 2
		})
		self._bottom:set_center_x(self._full_hud_panel:center_x())
		self._bottom:set_bottom(self._full_hud_panel:bottom() - 10)
		self:recreate_bottom()
	end

	local original_init = HUDStatsScreen._animate_show_stats_left_panel
	function HUDStatsScreen:_animate_show_stats_left_panel(...)
		original_init(self, ...)
		self._full_hud_panel = managers.hud:script(managers.hud.STATS_SCREEN_FULLSCREEN).panel
		self._bottom:set_center_x(self._full_hud_panel:center_x())
		self._bottom:set_bottom(self._full_hud_panel:bottom() - 10)
	end

	function HUDStatsScreen:_animate_text_pulse(text, exp_gain_ring, exp_ring, bg_ring)
		local t = 0
		local c = text:color()
		local w, h = text:size()
		local cx, cy = text:center()
		local ecx, ecy = exp_gain_ring:center()

		while true do
			local dt = coroutine.yield()
			t = t + dt
			local alpha = math.abs(math.sin(t * 180 * 1))

			text:set_size(math.lerp(w * 2, w, alpha), math.lerp(h * 2, h, alpha))
			text:set_font_size(math.lerp(25, tweak_data.menu.pd2_small_font_size, alpha * alpha))
			text:set_center_y(cy)
			exp_gain_ring:set_size(math.lerp(72, 64, alpha * alpha), math.lerp(72, 64, alpha * alpha))
			exp_gain_ring:set_center(ecx, ecy)
			exp_ring:set_size(exp_gain_ring:size())
			exp_ring:set_center(exp_gain_ring:center())
			bg_ring:set_size(exp_gain_ring:size())
			bg_ring:set_center(exp_gain_ring:center())
		end
	end
	
	local data = HUDStatsScreen.on_ext_inventory_changed
	function HUDStatsScreen:on_ext_inventory_changed()
		data(self)
		self:recreate_bottom()
	end
end