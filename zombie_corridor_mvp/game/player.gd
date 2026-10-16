class_name CorridorPlayer
extends CharacterBody3D

const RemotePlayerVisualScript = preload("res://game/remote_player_visual.gd")
var owner_peer_id = 0
var life_id = 1
var spawn_tick = 0
var retire_tick = 2147483647
var accepted_position = Vector3.ZERO
var rb
var input
var facing = Vector2.ZERO
var last_motion_tick = -1
var visual: Node3D
var camera: Camera3D
var camera_rest_position := Vector3.ZERO
var correction_m = 0.0
var last_simulated_input_tick = -1
var _remote_visual_playback: Variant
var _remote_visual_context: Array[int] = []

const AIM_HEAD_OFFSET := Vector3(0, 1.55, 0)
const CAMERA_COLLISION_MARGIN := 0.18

func _net() -> Node:
	return Engine.get_main_loop().root.get_node("NetSession")
func _network_time() -> Node:
	return Engine.get_main_loop().root.get_node("NetworkTime")

func configure(peer: int, life: int, pose: Vector3, born: int) -> void:
	owner_peer_id = peer
	life_id = life
	spawn_tick = born
	retire_tick = 2147483647
	name = "p_%s_%s" % [peer, life]
	position = pose
	accepted_position = pose
	facing = Vector2.ZERO
	last_motion_tick = -1
	last_simulated_input_tick = -1
	correction_m = 0.0
	if _remote_visual_playback:
		_remote_visual_playback.reset()
	_remote_visual_playback = null
	_remote_visual_context.clear()
	set_multiplayer_authority(1)
	_bind_authored_children()
	_configure_input(peer)
	_configure_movement_sync(peer)
	_configure_visual_role(peer)

func _bind_authored_children() -> void:
	input = get_node_or_null("Input")
	rb = get_node_or_null("MovementSync")
	visual = get_node_or_null("Visual") as Node3D
	camera = get_node_or_null("Visual/ShoulderCamera") as Camera3D
	if camera:
		camera_rest_position = camera.position
	if input == null:
		push_error("CorridorPlayer scene is missing authored Input child")
	if rb == null:
		push_error("CorridorPlayer scene is missing authored MovementSync child")
	if visual == null and not _is_non_visual_role():
		push_error("CorridorPlayer scene is missing authored Visual child")

func _configure_input(peer: int) -> void:
	if input == null:
		return
	input.set_multiplayer_authority(peer)
	input.movement = Vector2.ZERO
	input.look = Vector2.ZERO

func _configure_movement_sync(peer: int) -> void:
	if rb == null:
		return
	rb.root = self
	rb.state_properties.assign([":position", ":velocity", ":facing"])
	rb.input_properties.assign(["Input:movement", "Input:look"])
	rb.enable_input_broadcast = false
	rb.enable_prediction = _net().is_server or peer == _net().local_peer()
	# Netfox's strict scheduler sends every 8 ticks, leaving delivery margin in history 16.
	rb.full_state_interval = 7

func _configure_visual_role(peer: int) -> void:
	if _is_non_visual_role():
		_remove_visual_subtree()
		return
	if visual:
		visual.top_level = true
		if is_inside_tree():
			visual.global_position = global_position
		else:
			visual.position = position
		visual.rotation = Vector3.ZERO
		visual.visible = true
	if camera:
		camera.position = camera_rest_position
		camera.current = peer == _net().local_peer()

func _is_non_visual_role() -> bool:
	var session := _net()
	return session.is_server or session.is_bot

func _remove_visual_subtree() -> void:
	camera = null
	camera_rest_position = Vector3.ZERO
	if visual and is_instance_valid(visual):
		remove_child(visual)
		visual.free()
	visual = null

func _ready() -> void:
	if rb:
		rb.process_settings()
		rb.visibility_filter.add_visibility_filter(func(peer):
			return _net().player_in_interest(owner_peer_id, peer))
	if not _is_non_visual_role():
		_configure_visual_role(owner_peer_id)

func _rollback_tick(_delta: float, tick: int, _fresh: bool) -> void:
	if tick < spawn_tick or tick >= retire_tick: return
	if not _net().is_server and owner_peer_id != _net().local_peer(): return
	var before = Time.get_ticks_usec()
	var motion = input.movement
	last_simulated_input_tick = tick-rb.get_input_age() if rb.has_input() else -1
	if not rb.has_input() or rb.get_input_age() > 11: motion = Vector2.ZERO
	if not is_finite(motion.x) or not is_finite(motion.y): motion = Vector2.ZERO
	motion = motion.limit_length(1.0)
	facing = input.look
	var world = Vector3(motion.x,0,motion.y).rotated(Vector3.UP,-facing.x)
	velocity = world*5.0
	var factor: float = _network_time().physics_factor
	velocity *= factor
	move_and_slide()
	velocity /= factor
	position.y = 0.0
	_net().motion_us += Time.get_ticks_usec()-before
	if tick <= last_motion_tick:
		_net().motion_replays += 1
		_net().movement_replays_sample += 1
		_net().rollback_unique_replays[tick] = true
	else:
		_net().motion_new += 1
		_net().movement_new_sample += 1
	last_motion_tick = maxi(last_motion_tick,tick)

func pose_at(tick: int) -> Vector3:
	var snapshot = rb._states.get_snapshot(tick+1).as_dictionary()
	return snapshot.get(":position",accepted_position)

func _process(delta: float) -> void:
	if not visual: return
	if owner_peer_id == _net().local_peer():
		correction_m = visual.global_position.distance_to(global_position)
		visual.global_position = global_position
		visual.rotation.y = -_net().control_look.x
		if camera:
			camera.position = camera_rest_position
			camera.rotation.x = _net().control_look.y
			_update_camera_obstruction()
	else:
		# Playback consumes only complete states acknowledged by the pinned adapter.
		# An empty receipt history intentionally leaves the authored spawn pose visible.
		var session := _net()
		var adapter_generation := int(rb.get_received_generation()) if rb and rb.has_method("get_received_generation") else -1
		var context: Array[int] = [owner_peer_id, life_id, int(session.epoch), int(session.connection_generation), adapter_generation]
		if _remote_visual_context != context:
			if _remote_visual_playback:
				_remote_visual_playback.reset()
			_remote_visual_playback = RemotePlayerVisualScript.new()
			_remote_visual_context = context
		var received: Dictionary = rb.get_latest_received_state_sample() if rb and rb.has_method("get_latest_received_state_sample") else {}
		if not received.is_empty():
			_remote_visual_playback.ingest(received, life_id)
		var network_time := _network_time()
		var public_tick := float(network_time.tick) + float(network_time.tick_factor)
		_remote_visual_playback.advance(delta, public_tick)
		var displayed: Dictionary = _remote_visual_playback.sample_at(_remote_visual_playback.get_display_tick())
		if not displayed.is_empty():
			visual.global_position = displayed.position
			visual.rotation.y = displayed.yaw
		if camera:
			camera.current = false
	visual.visible = _network_time().tick < retire_tick

func shot_origin() -> Vector3:
	return global_position + AIM_HEAD_OFFSET

func camera_aim_direction(max_range: float) -> Vector3:
	if camera and is_instance_valid(camera) and camera.current:
		var camera_origin := camera.global_position
		var camera_direction := -camera.global_transform.basis.z.normalized()
		if _finite_vector(camera_origin) and _finite_vector(camera_direction):
			var target_distance := CorridorGeometry.wall_distance(camera_origin, camera_direction, max_range)
			target_distance = _nearest_camera_mob_distance(camera_origin, camera_direction, target_distance)
			var target := camera_origin + camera_direction * target_distance
			var direction := _direction_from_head_to_target(target, camera_direction)
			if direction != Vector3.ZERO:
				return direction
	return Vector3(0,0,-1).rotated(Vector3.RIGHT,_net().control_look.y).rotated(Vector3.UP,-_net().control_look.x).normalized()

func _nearest_camera_mob_distance(camera_origin: Vector3, camera_direction: Vector3, limit: float) -> float:
	var nearest := limit
	for row in _net().store.records.values():
		if not row is Dictionary: continue
		if int(row.get("hp", 0)) <= 0: continue
		if int(row.get("state", 0)) == 3: continue
		var fallback_foot = row.get("position", null)
		if not fallback_foot is Vector3 or not _finite_vector(fallback_foot): continue
		var foot: Vector3 = _net().displayed_mob_foot(row.get("id", null), fallback_foot)
		if not _finite_vector(foot): continue
		var distance := CorridorGeometry.ray_capsule(camera_origin, camera_direction, foot, nearest)
		if is_finite(distance) and distance > 0.001 and distance < nearest:
			nearest = distance
	return nearest

func _direction_from_head_to_target(target: Vector3, camera_direction: Vector3) -> Vector3:
	var from_head := target - shot_origin()
	if _finite_vector(from_head) and from_head.length() > 0.001 and from_head.dot(camera_direction) > 0.001:
		return from_head.normalized()
	return Vector3.ZERO

func _update_camera_obstruction() -> void:
	if not camera or not is_instance_valid(camera): return
	var head := visual.global_transform * AIM_HEAD_OFFSET
	var desired := visual.global_transform * camera.position
	var actual := desired
	var offset := desired - head
	if _finite_vector(head) and _finite_vector(desired) and offset.length() > 0.001:
		var query := PhysicsRayQueryParameters3D.create(head, desired, 1)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var space := get_world_3d().direct_space_state if get_world_3d() else null
		var hit := space.intersect_ray(query) if space else {}
		if not hit.is_empty():
			var point: Vector3 = hit.get("position", desired)
			var normal: Vector3 = hit.get("normal", -offset.normalized())
			actual = point + normal.normalized() * CAMERA_COLLISION_MARGIN
			if (actual - head).dot(offset.normalized()) < 0.0:
				actual = head
	if _finite_vector(actual):
		camera.global_position = actual

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _exit_tree() -> void:
	if rb and rb.visibility_filter and rb.visibility_filter.has_method("clear_visibility_filters"):
		rb.visibility_filter.clear_visibility_filters()
