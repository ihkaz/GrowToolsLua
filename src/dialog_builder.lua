local DialogBuilder = {}
DialogBuilder.__index = DialogBuilder

local function string_value(value)
    return tostring(value)
end

local function bool_int(value)
    return value and 1 or 0
end

local function size_value(big)
    return big and "big" or "small"
end

local function append(builder, text)
    builder.dialog = builder.dialog .. text
    return builder
end

function DialogBuilder.new(color)
    if color == nil then
        error("DialogBuilder.new requires explicit color, for example '`0' or '`o'", 2)
    end
    return setmetatable({
        dialog = "set_default_color|" .. string_value(color) .. "\n",
    }, DialogBuilder)
end

function DialogBuilder.to_string(builder)
    return builder.dialog
end

function DialogBuilder.raw(builder, dialog_text)
    return append(builder, string_value(dialog_text))
end

function DialogBuilder.set_custom_spacing(builder, x, y)
    return append(builder, "\nset_custom_spacing|x:" .. string_value(x) .. ";y:" .. string_value(y) .. "|")
end

function DialogBuilder.add_break(builder)
    return append(builder, "\nadd_custom_break|")
end

function DialogBuilder.add_item_picker(builder, name, message)
    return append(builder, "\nadd_item_picker|" .. string_value(name) .. "|" .. string_value(message) .. "|Choose an item from your inventory|")
end

function DialogBuilder.add_player_info(builder, name, current_level, current_exp, exp_required)
    return append(builder, "\nadd_player_info|" .. string_value(name) .. "|" .. string_value(current_level) .. "|" .. string_value(current_exp) .. "|" .. string_value(exp_required) .. "|")
end

function DialogBuilder.add_checkbox(builder, checked, name, message)
    return append(builder, "\nadd_checkbox|" .. string_value(name) .. "|" .. string_value(message) .. "|" .. bool_int(checked) .. "|")
end

function DialogBuilder.add_selector_checkbox(builder, id, name, messages, index_checked)
    for index, message in ipairs(messages) do
        append(builder, "\nadd_checkbox|" .. string_value(name) .. "_" .. (index - 1) .. "_" .. string_value(id) .. "|" .. string_value(message) .. "|" .. bool_int((index - 1) == index_checked) .. "|")
    end
    return builder
end

function DialogBuilder.add_smalltext(builder, message)
    return append(builder, "\nadd_smalltext|" .. string_value(message) .. "|")
end

function DialogBuilder.end_list(builder)
    return append(builder, "\nadd_button_with_icon||END_LIST|noflags|0|0|")
end

function DialogBuilder.add_dual_layer(builder, big, icon_left, foreground, background, size, message)
    return append(builder, "\nadd_dual_layer_icon_label|" .. size_value(big) .. "|" .. string_value(message) .. "|left|" .. string_value(background) .. "|" .. string_value(foreground) .. "|" .. string_value(size) .. "|" .. bool_int(not icon_left) .. "|")
end

function DialogBuilder.add_text_input(builder, length, name, message, default_input)
    return append(builder, "\nadd_text_input|" .. string_value(name) .. "|" .. string_value(message) .. "|" .. string_value(default_input) .. "|" .. string_value(length) .. "|")
end

function DialogBuilder.add_seed_icon(builder, item_id)
    return append(builder, "\nadd_seed_color_icons|" .. string_value(item_id) .. "|")
end

function DialogBuilder.add_static_icon_button(builder, name, id, message, hover_number)
    return append(builder, "\nadd_button_with_icon|" .. string_value(name) .. "|" .. string_value(message) .. "|staticBlueFrame|" .. string_value(id) .. "|" .. string_value(hover_number) .. "|")
end

function DialogBuilder.add_label_icon(builder, big, id, message)
    return append(builder, "\nadd_label_with_icon|" .. size_value(big) .. "|" .. string_value(message) .. "|left|" .. string_value(id) .. "|")
end

function DialogBuilder.add_icon_button(builder, button_name, text, option, item_id, unknown_value)
    return append(builder, "\nadd_button_with_icon|" .. string_value(button_name) .. "|" .. string_value(text) .. "|" .. string_value(option) .. "|" .. string_value(item_id) .. "|" .. string_value(unknown_value) .. "|")
end

function DialogBuilder.add_kit_disabled_button(builder, button_name, progress, item_id)
    return append(builder, "\nadd_button_with_icon|" .. string_value(button_name) .. "|`4" .. string_value(progress) .. "|staticGreyFrame,no_padding_x,is_count_label,disabled|" .. string_value(item_id) .. "||")
end

function DialogBuilder.add_kit_claim_button(builder, button_name, under_text, item_id)
    return append(builder, "\nadd_button_with_icon|" .. string_value(button_name) .. "|`2" .. string_value(under_text) .. "|staticYellowFrame,no_padding_x,is_count_label|" .. string_value(item_id) .. "||")
end

function DialogBuilder.add_kit_claimed_button(builder, button_name, item_id)
    return append(builder, "\nadd_button_with_icon|" .. string_value(button_name) .. "|`5CLAIMED`|staticBlueFrame,no_padding_x,is_count_label|" .. string_value(item_id) .. "||")
end

function DialogBuilder.add_label_icon_button(builder, big, message, id, name)
    return append(builder, "\nadd_label_with_icon_button|" .. size_value(big) .. "|" .. string_value(message) .. "|left|" .. string_value(id) .. "|" .. string_value(name) .. "|")
end

function DialogBuilder.add_spacer(builder, big)
    return append(builder, "\nadd_spacer|" .. size_value(big) .. "|")
end

function DialogBuilder.add_textbox(builder, message)
    return append(builder, "\nadd_textbox|" .. string_value(message) .. "|")
end

function DialogBuilder.add_quick_exit(builder)
    return append(builder, "\nadd_quick_exit|")
end

function DialogBuilder.start_custom_tabs(builder)
    return append(builder, "\nstart_custom_tabs|")
end

function DialogBuilder.reset_placement_x(builder)
    return append(builder, "\nreset_placement_x|")
end

function DialogBuilder.reset_placement_y(builder)
    return append(builder, "\nreset_placement_y|")
end

function DialogBuilder.add_custom_margin(builder, x, y)
    return append(builder, "\nadd_custom_margin|x:" .. string_value(x) .. ";y:" .. string_value(y) .. "|")
end

function DialogBuilder.add_player_picker(builder, name, button)
    return append(builder, "\nadd_player_picker|" .. string_value(name) .. "|" .. string_value(button) .. "|")
end

function DialogBuilder.add_input(builder, length, name, message, default_input)
    return DialogBuilder.add_text_input(builder, length, name, message, default_input)
end

function DialogBuilder.end_dialog(builder, name, cancel, accept)
    return append(builder, "\nend_dialog|" .. string_value(name) .. "|" .. string_value(cancel) .. "|" .. string_value(accept) .. "|")
end

function DialogBuilder.add_label(builder, big, message)
    return append(builder, "\nadd_label|" .. size_value(big) .. "|" .. string_value(message) .. "|left|")
end

function DialogBuilder.add_button(builder, name, button)
    return append(builder, "\nadd_button|" .. string_value(name) .. "|" .. string_value(button) .. "|noflags|0|0|")
end

function DialogBuilder.add_small_font_button(builder, name, button)
    return append(builder, "\nadd_small_font_button|" .. string_value(name) .. "|" .. string_value(button) .. "|noflags|0|0|")
end

function DialogBuilder.add_disabled_button(builder, name, button)
    return append(builder, "\nadd_button|" .. string_value(name) .. "|" .. string_value(button) .. "|off|0|0|")
end

function DialogBuilder.add_small_font_disabled_button(builder, name, button)
    return append(builder, "\nadd_small_font_button|" .. string_value(name) .. "|" .. string_value(button) .. "|off|0|0|")
end

function DialogBuilder.add_custom_button(builder, name, option)
    return append(builder, "\nadd_custom_button|" .. string_value(name) .. "|" .. string_value(option) .. "|")
end

function DialogBuilder.add_custom_label(builder, option1, option2)
    return append(builder, "\nadd_custom_label|" .. string_value(option1) .. "|" .. string_value(option2) .. "|")
end

function DialogBuilder.add_custom_spacer(builder, x)
    return append(builder, "\nadd_custom_spacer|x:" .. string_value(x) .. "|")
end

function DialogBuilder.add_custom_textbox(builder, text, size)
    return append(builder, "\nadd_custom_textbox|" .. string_value(text) .. "|size:" .. string.lower(string_value(size)) .. "|")
end

function DialogBuilder.embed_data(builder, push_front, embed, data)
    local text = "\nembed_data|" .. string_value(embed) .. "|" .. string_value(data)
    if push_front then
        builder.dialog = text .. "\n" .. builder.dialog
        return builder
    end
    return append(builder, text)
end

function DialogBuilder.add_achieve_button(builder, achievement_name, achievement_to_get, achievement_id, unknown)
    return append(builder, "\nadd_achieve_button|" .. string_value(achievement_name) .. "|" .. string_value(achievement_to_get) .. "|left|" .. string_value(achievement_id) .. "|" .. string_value(unknown) .. "|")
end

return DialogBuilder
