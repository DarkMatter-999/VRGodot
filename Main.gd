class_name VisionTask
extends Node3D


@onready var btn_back: Button = $Control/Back
@onready var btn_start: Button = $Control/Start

func _ready():
	btn_start.pressed.connect(get_tree().change_scene_to_file.bind("res://HandLandMark.tscn"))

func _process(delta):
	pass
