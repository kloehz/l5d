class_name CorridorInput
extends Node
var movement: Vector2 = Vector2.ZERO:
	set(v):
		movement = v.limit_length(1.0) if is_finite(v.x) and is_finite(v.y) else Vector2.ZERO
var look: Vector2 = Vector2.ZERO:
	set(v):
		look = Vector2(wrapf(v.x,-PI,PI),clampf(v.y,-1.4,1.4)) if is_finite(v.x) and is_finite(v.y) else Vector2.ZERO

func _ready() -> void:
	NetworkTime.before_tick.connect(_gather)

func _exit_tree() -> void:
	if NetworkTime.before_tick.is_connected(_gather): NetworkTime.before_tick.disconnect(_gather)

func _gather(_delta: float, _tick: int) -> void:
	if is_multiplayer_authority():
		movement = NetSession.control_move
		look = NetSession.control_look
