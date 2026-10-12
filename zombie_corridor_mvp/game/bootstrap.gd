extends Node3D

const UI_SCENE := preload("res://scenes/ui.tscn")
const PRESENTATION_SCENE := preload("res://scenes/presentation.tscn")

func _ready() -> void:
	NetSession.world_root = self
	NetSession.players_root = $Players
	NetSession.launch()
	if not NetSession.is_server and not NetSession.is_bot:
		var ui := UI_SCENE.instantiate() as CorridorUI
		add_child(ui)
		var presentation := PRESENTATION_SCENE.instantiate() as CorridorPresentation
		add_child(presentation)
