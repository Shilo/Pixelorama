extends ImageEffect

enum { LINEAR, RADIAL, LINEAR_DITHERING, RADIAL_DITHERING }
enum Animate { POSITION, SIZE, ANGLE, CENTER_X, CENTER_Y, RADIUS_X, RADIUS_Y }

var shader := preload("res://src/Shaders/Effects/Gradient.gdshader")
var selected_dither_matrix := ShaderLoader.dither_matrices[0]

@onready var options_cont: Container = $VBoxContainer/ScrollContainer/GradientOptions
@onready var gradient_edit: GradientEditNode = $VBoxContainer/GradientEdit
@onready var shape_option_button: OptionButton = $"%ShapeOptionButton"
@onready var dithering_option_button: OptionButton = $"%DitheringOptionButton"
@onready var repeat_option_button: OptionButton = $"%RepeatOptionButton"
@onready var sample_count_spinbox: SpinBox = $"%SampleCountSpinBox"
@onready var reset_sample_count_button: TextureButton = $"%ResetSampleCountButton"
@onready var position_slider: ValueSlider = $"%PositionSlider"
@onready var size_slider: ValueSlider = $"%SizeSlider"
@onready var angle_slider: ValueSlider = $"%AngleSlider"
@onready var center_slider := $"%CenterSlider" as ValueSliderV2
@onready var radius_slider := $"%RadiusSlider" as ValueSliderV2

var _initial_sample_count := 64


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)
	reset_sample_count_button.modulate = Global.modulate_icon_color

	for matrix in ShaderLoader.dither_matrices:
		dithering_option_button.add_item(matrix.name)

	# Set as in the Animate enum
	animate_panel.add_float_property("Position", position_slider)
	animate_panel.add_float_property("Size", size_slider)
	animate_panel.add_float_property("Angle", angle_slider)
	animate_panel.add_float_property("Center X", center_slider.get_sliders()[0])
	animate_panel.add_float_property("Center Y", center_slider.get_sliders()[1])
	animate_panel.add_float_property("Radius X", radius_slider.get_sliders()[0])
	animate_panel.add_float_property("Radius Y", radius_slider.get_sliders()[1])


func _about_to_popup() -> void:
	_initial_sample_count = mini(
		maxi(
			ceili(Vector2(Global.current_project.size).length()),
			int(sample_count_spinbox.min_value)
		),
		int(sample_count_spinbox.max_value)
	)
	sample_count_spinbox.set_value_no_signal(_initial_sample_count)
	_update_sample_count_reset_button()
	_update_gradient_texture_samples()
	super._about_to_popup()


func commit_action(cel: Image, project := Global.current_project) -> void:
	_update_gradient_texture_samples()

	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project, project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	var center := Vector2(
		animate_panel.get_animated_value(commit_idx, Animate.CENTER_X),
		animate_panel.get_animated_value(commit_idx, Animate.CENTER_Y)
	)
	var radius := Vector2(
		animate_panel.get_animated_value(commit_idx, Animate.RADIUS_X),
		animate_panel.get_animated_value(commit_idx, Animate.RADIUS_Y)
	)
	var params := {
		"gradient_texture": gradient_edit.texture,
		"gradient_texture_no_interpolation": gradient_edit.get_gradient_texture_no_interpolation(),
		"gradient_offset_texture": gradient_edit.get_gradient_offsets_texture(),
		"use_dithering": dithering_option_button.selected > 0,
		"selection": selection_tex,
		"repeat": repeat_option_button.selected,
		"position": (animate_panel.get_animated_value(commit_idx, Animate.POSITION) / 100.0) - 0.5,
		"size": animate_panel.get_animated_value(commit_idx, Animate.SIZE) / 100.0,
		"angle": animate_panel.get_animated_value(commit_idx, Animate.ANGLE),
		"center": center / 100.0,
		"radius": radius,
		"dither_texture": selected_dither_matrix.texture,
		"shape": shape_option_button.selected,
	}

	if !has_been_confirmed:
		preview.material.shader = shader
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_ShapeOptionButton_item_selected(index: int) -> void:
	for child in options_cont.get_children():
		if not child.is_in_group("gradient_common"):
			child.visible = false

	match index:
		LINEAR:
			get_tree().set_group("gradient_linear", "visible", true)
		RADIAL:
			get_tree().set_group("gradient_radial", "visible", true)
	update_preview()


func _update_gradient_texture_samples() -> void:
	gradient_edit.texture.width = maxi(roundi(sample_count_spinbox.value), 2)
	gradient_edit.texture.height = 2


func _on_sample_count_spin_box_value_changed(_value: float) -> void:
	_update_gradient_texture_samples()
	_update_sample_count_reset_button()
	update_preview()


func _update_sample_count_reset_button() -> void:
	reset_sample_count_button.visible = roundi(sample_count_spinbox.value) != _initial_sample_count


func _on_reset_sample_count_button_pressed() -> void:
	sample_count_spinbox.set_value_no_signal(_initial_sample_count)
	_update_gradient_texture_samples()
	_update_sample_count_reset_button()
	update_preview()


func _value_changed(_value: float) -> void:
	update_preview()


func _value_v2_changed(_value: Vector2) -> void:
	update_preview()


func _on_DitheringOptionButton_item_selected(index: int) -> void:
	if index > 0:
		selected_dither_matrix = ShaderLoader.dither_matrices[index - 1]
	update_preview()


func _on_GradientEdit_updated(_gradient, _cc) -> void:
	update_preview()


func _on_RepeatOptionButton_item_selected(_index: int) -> void:
	update_preview()
