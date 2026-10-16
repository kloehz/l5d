class_name CorridorPresentation
extends Node3D

const TRACER_POOL_SIZE := 8
const TRACER_LIFETIME_SECONDS := 0.075
const PREDICTED_TRACER_COLOR := Color(.98, .8, .35)
const CONFIRMED_TRACER_COLOR := Color(.4, 1, .7)
const MOB_VISUAL_SCENE := preload("res://scenes/mob_visual.tscn")
const MOB_VISUAL_SAMPLER := preload("res://game/mob_visual_sampler.gd")
const MOB_TIMING := preload("res://game/mob_timing.gd")
const CONFIRMED_TRACER_MATERIAL := preload("res://scenes/resources/tracer_confirmed.tres")

@onready var tracer_slot_0: MeshInstance3D = $ShotTracer0
@onready var tracer_slot_1: MeshInstance3D = $ShotTracer1
@onready var tracer_slot_2: MeshInstance3D = $ShotTracer2
@onready var tracer_slot_3: MeshInstance3D = $ShotTracer3
@onready var tracer_slot_4: MeshInstance3D = $ShotTracer4
@onready var tracer_slot_5: MeshInstance3D = $ShotTracer5
@onready var tracer_slot_6: MeshInstance3D = $ShotTracer6
@onready var tracer_slot_7: MeshInstance3D = $ShotTracer7

var visuals = {}
var _tracer_pool: Array[MeshInstance3D] = []
var _tracer_expires_usec: Array[int] = []
var _tracer_mesh: ArrayMesh
var _predicted_tracer_material: StandardMaterial3D
var _confirmed_tracer_material: StandardMaterial3D
var _tracer_sequence := 0
var _display_cursor_tick := 0.0
var _last_network_tick := 0.0
var _clock_initialized := false
var _session_epoch := -1
var _connection_generation := -1
const NETWORK_TICK_RATE_HZ := MOB_TIMING.NETWORK_TICK_RATE_HZ
const DISPLAY_DELAY_TICKS := MOB_TIMING.INTERPOLATION_DELAY_SECONDS * MOB_TIMING.NETWORK_TICK_RATE_HZ
const CLOCK_SLEW_FRACTION := 0.25
const MAX_RENDER_STEP_SECONDS := 0.1
const MAX_RESYNC_TICKS := 6.0
const MAX_CURSOR_LEAD_TICKS := 0.5

func _ready() -> void:
	add_to_group("mob_presentation")
	_bind_authored_tracer_pool()
	var net_session := _net_session()
	net_session.shot_confirmed.connect(_confirmed)
	net_session.shot_submitted.connect(_predicted)

func _process(delta: float) -> void:
	_expire_tracers(Time.get_ticks_usec())
	var net_session := _net_session()
	_reset_for_session_change(net_session)
	var view_tick := _advance_display_cursor(delta)
	for id in visuals.keys():
		if not net_session.store.records.has(id):
			visuals[id].queue_free()
			visuals.erase(id)
	for id in net_session.store.records:
		var row = net_session.store.records[id]
		if not visuals.has(id):
			var mesh := MOB_VISUAL_SCENE.instantiate() as MeshInstance3D
			if mesh.material_override:
				mesh.material_override = mesh.material_override.duplicate()
			add_child(mesh)
			visuals[id]=mesh
		var sample: Dictionary = MOB_VISUAL_SAMPLER.sample(row.history, view_tick, row.position, row.yaw)
		visuals[id].position = sample.position + Vector3(0, .9, 0)
		visuals[id].rotation.y = sample.yaw
		visuals[id].material_override.albedo_color = Color(.4,.45,.49) if row.state==0 else Color(.9,.22,.16).lerp(Color(.95,.67,.1),1.0-row.hp/100.0)

func _reset_for_session_change(net_session: Node) -> void:
	var epoch := int(net_session.epoch)
	var generation := int(net_session.connection_generation)
	if not _clock_initialized or epoch != _session_epoch or generation != _connection_generation:
		_clock_initialized = false
		_session_epoch = epoch
		_connection_generation = generation

func _advance_display_cursor(delta: float) -> float:
	var network_time := _network_time()
	var network_tick := float(network_time.tick) + float(network_time.tick_factor)
	var desired_tick := network_tick - DISPLAY_DELAY_TICKS
	if not _clock_initialized or absf(network_tick - _last_network_tick) > MAX_RESYNC_TICKS:
		_display_cursor_tick = desired_tick
		_clock_initialized = true
	else:
		var elapsed_ticks := minf(maxf(delta, 0.0), MAX_RENDER_STEP_SECONDS) * NETWORK_TICK_RATE_HZ
		var error_ticks := desired_tick - (_display_cursor_tick + elapsed_ticks)
		var correction_ticks := clampf(error_ticks * CLOCK_SLEW_FRACTION, -elapsed_ticks * CLOCK_SLEW_FRACTION, elapsed_ticks * CLOCK_SLEW_FRACTION)
		var stepped_tick := _display_cursor_tick + elapsed_ticks + correction_ticks
		_display_cursor_tick = maxf(_display_cursor_tick, minf(stepped_tick, desired_tick + MAX_CURSOR_LEAD_TICKS))
	_last_network_tick = network_tick
	return _display_cursor_tick

func get_display_tick() -> float:
	return _display_cursor_tick

func get_display_time_seconds() -> float:
	# Stored row.tick is the pose at (tick + 1) / network rate.
	return (_display_cursor_tick + 1.0) / NETWORK_TICK_RATE_HZ

func get_rendered_mob_foot(id: Variant) -> Variant:
	var visual: MeshInstance3D = visuals.get(id)
	if visual == null or not is_instance_valid(visual):
		return null
	return visual.position - Vector3(0, .9, 0)

func _predicted(origin: Vector3, endpoint: Vector3) -> void: _tracer(origin,endpoint,PREDICTED_TRACER_COLOR)

func _confirmed(result: Dictionary) -> void:
	var actor = _net_session().own_actor()
	if actor and result.hit: _tracer(actor.position+Vector3(0,1.55,0),result.end,CONFIRMED_TRACER_COLOR)

func _net_session() -> Node:
	return get_node("/root/NetSession")

func _network_time() -> Node:
	return get_node("/root/NetworkTime")

func _bind_authored_tracer_pool() -> void:
	var slots: Array[MeshInstance3D] = [
		tracer_slot_0,
		tracer_slot_1,
		tracer_slot_2,
		tracer_slot_3,
		tracer_slot_4,
		tracer_slot_5,
		tracer_slot_6,
		tracer_slot_7,
	]
	var configuration_errors := _tracer_pool_configuration_errors(slots)
	if not configuration_errors.is_empty():
		var message := "Invalid authored tracer pool: %s" % "; ".join(configuration_errors)
		push_error(message)
		assert(false, message)
		return
	_tracer_mesh = slots[0].mesh as ArrayMesh
	_predicted_tracer_material = slots[0].material_override as StandardMaterial3D
	_confirmed_tracer_material = CONFIRMED_TRACER_MATERIAL
	for index in range(slots.size()):
		var slot := slots[index]
		slot.name = "ShotTracer%d" % index
		slot.visible = false
		slot.set_meta("shot_tracer", true)
		_tracer_pool.append(slot)
		_tracer_expires_usec.append(0)

func _tracer_pool_configuration_errors(slots: Array[MeshInstance3D]) -> Array[String]:
	var errors: Array[String] = []
	if slots.size() != TRACER_POOL_SIZE:
		errors.append("expected %d declared slots, found %d" % [TRACER_POOL_SIZE, slots.size()])
	var expected_mesh: Mesh = null
	var expected_predicted_material: Material = null
	for index in range(slots.size()):
		var slot := slots[index]
		if slot == null:
			errors.append("ShotTracer%d is missing or not a MeshInstance3D" % index)
			continue
		if slot.get_parent() != self:
			errors.append("%s must be a direct child of CorridorPresentation" % slot.name)
		if slot.name != "ShotTracer%d" % index:
			errors.append("slot %d must be named ShotTracer%d" % [index, index])
		if not slot.has_meta("shot_tracer") or slot.get_meta("shot_tracer") != true:
			errors.append("%s must author shot_tracer metadata" % slot.name)
		if slot.visible:
			errors.append("%s must start hidden" % slot.name)
		if not slot.mesh is ArrayMesh:
			errors.append("%s must reference the authored ArrayMesh" % slot.name)
		elif expected_mesh == null:
			expected_mesh = slot.mesh
		elif slot.mesh != expected_mesh:
			errors.append("%s must share the authored tracer mesh" % slot.name)
		if not slot.material_override is StandardMaterial3D:
			errors.append("%s must reference the predicted StandardMaterial3D" % slot.name)
		elif expected_predicted_material == null:
			expected_predicted_material = slot.material_override
		elif slot.material_override != expected_predicted_material:
			errors.append("%s must share the authored predicted material" % slot.name)
	if not CONFIRMED_TRACER_MATERIAL is StandardMaterial3D:
		errors.append("confirmed tracer material must be authored as StandardMaterial3D")
	return errors

func _tracer(origin: Vector3, endpoint: Vector3, color: Color) -> void:
	var now := Time.get_ticks_usec()
	_expire_tracers(now)
	var slot_index := _claim_tracer_slot()
	var instance := _tracer_pool[slot_index]
	instance.transform = _tracer_transform(origin, endpoint)
	instance.material_override = _predicted_tracer_material if _same_color(color, PREDICTED_TRACER_COLOR) else _confirmed_tracer_material
	_tracer_sequence += 1
	instance.set_meta("shot_tracer_sequence", _tracer_sequence)
	instance.visible = true
	_tracer_expires_usec[slot_index] = now + int(TRACER_LIFETIME_SECONDS * 1000000.0)

func _claim_tracer_slot() -> int:
	var earliest_index := 0
	var earliest_expiry := _tracer_expires_usec[0]
	for index in range(_tracer_pool.size()):
		if not _tracer_pool[index].visible:
			return index
		if _tracer_expires_usec[index] < earliest_expiry:
			earliest_expiry = _tracer_expires_usec[index]
			earliest_index = index
	return earliest_index

func _expire_tracers(now_usec: int) -> void:
	for index in range(_tracer_pool.size()):
		if _tracer_pool[index].visible and now_usec >= _tracer_expires_usec[index]:
			_tracer_pool[index].visible = false
			_tracer_expires_usec[index] = 0

func _tracer_transform(origin: Vector3, endpoint: Vector3) -> Transform3D:
	var z_axis := endpoint - origin
	var x_axis := Vector3.RIGHT
	var y_axis := Vector3.UP
	var length := z_axis.length()
	if length > 0.00001:
		var direction := z_axis / length
		var helper := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		x_axis = helper.cross(direction).normalized()
		y_axis = direction.cross(x_axis).normalized()
	return Transform3D(Basis(x_axis, y_axis, z_axis), origin)

func _same_color(actual: Color, expected: Color) -> bool:
	return is_equal_approx(actual.r, expected.r) and is_equal_approx(actual.g, expected.g) and is_equal_approx(actual.b, expected.b) and is_equal_approx(actual.a, expected.a)
