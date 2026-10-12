extends SceneTree

const LOOK_SCALE := 0.0025
const DEFAULT_CAMERA_DISTANCE := 3.241
const UI_SCENE := preload("res://scenes/ui.tscn")
const PLAYER_ACTOR_SCENE := "res://scenes/player_actor.tscn"

var failures: Array[String] = []
var assertions := 0
var world: Node3D
var players_root: Node3D
var ui: CorridorUI
var net_session: Node
var local_actor: CorridorPlayer
var remote_actor: CorridorPlayer
var original_ready := false
var original_look := Vector2.ZERO
var original_move := Vector2.ZERO
var original_fire := false
var original_players_root: Node3D
var original_own_life := 0
var completed := false
var capture_supported := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	net_session = root.get_node("NetSession")
	_capture_original_state()
	_setup_world()
	await process_frame
	await _check_viewport_input_routing()
	await _check_player_camera_and_aim()
	await _check_camera_obstruction_recovery()
	_cleanup()
	completed = true
	check(completed, "third-person harness reaches completion before quit")
	print(JSON.stringify({
		"kind": "third_person_harness",
		"assertions": assertions,
		"failures": failures,
		"display_server": DisplayServer.get_name(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"headless": DisplayServer.get_name().to_lower().contains("headless"),
		"capture_supported": capture_supported,
		"input_route": "viewport_push_input_to_CorridorUI._input",
		"capture_note": "headless capture coverage uses engine mouse_mode state; rendered run exercises the same viewport path with a window"
	}))
	quit(0 if failures.is_empty() else 1)

func _capture_original_state() -> void:
	original_ready = net_session.is_ready
	original_look = net_session.control_look
	original_move = net_session.control_move
	original_fire = net_session.control_fire
	original_players_root = net_session.players_root
	original_own_life = net_session.own_life

func _setup_world() -> void:
	world = Node3D.new()
	world.name = "ThirdPersonHarnessWorld"
	root.add_child(world)
	players_root = Node3D.new()
	players_root.name = "ThirdPersonPlayers"
	world.add_child(players_root)
	net_session.players_root = players_root
	net_session.is_server = false
	net_session.is_bot = false
	net_session.own_life = 1
	ui = UI_SCENE.instantiate() as CorridorUI
	ui.name = "ThirdPersonUI"
	root.add_child(ui)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 15, 0)
	world.add_child(light)

func _check_viewport_input_routing() -> void:
	net_session.is_ready = false
	net_session.control_look = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	capture_supported = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if capture_supported:
		await _push_mouse_motion(Vector2(60, -40))
		check(net_session.control_look == Vector2.ZERO, "captured mouse does not rotate before ready gameplay")
		net_session.is_ready = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _push_mouse_motion(Vector2(60, -40))
		check(net_session.control_look == Vector2.ZERO, "released mouse does not rotate ready gameplay")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await _push_mouse_motion(Vector2(80, -20))
		check(is_equal_approx(net_session.control_look.x, 80.0 * LOOK_SCALE), "viewport mouse motion reaches gameplay yaw through fullscreen HUD")
		check(is_equal_approx(net_session.control_look.y, 20.0 * LOOK_SCALE), "viewport mouse motion reaches gameplay pitch through fullscreen HUD")
		await _push_key(KEY_ESCAPE)
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases captured mouse")
		await _push_mouse_motion(Vector2(80, -20))
		check(is_equal_approx(net_session.control_look.x, 80.0 * LOOK_SCALE), "menu/released mouse motion does not duplicate rotate")
		net_session.control_look = Vector2(PI - 0.001, 1.39)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await _push_mouse_motion(Vector2(10, -100))
		check(net_session.control_look.x < -3.0, "yaw wraps at the PI boundary")
		check(is_equal_approx(net_session.control_look.y, 1.4), "pitch clamps at upper bound")
	else:
		check(DisplayServer.get_name().to_lower().contains("headless"), "only headless runs may report unsupported captured mouse")
		net_session.is_ready = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _push_mouse_motion(Vector2(60, -40))
		check(net_session.control_look == Vector2.ZERO, "headless unsupported capture still preserves released-mouse gate")
	await _push_key(KEY_F3)
	check(ui.show_debug, "F3 still toggles diagnostics through viewport input")
	net_session.control_look = Vector2.ZERO

func _push_mouse_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(320, 240) + relative
	event.global_position = event.position
	event.relative = relative
	root.push_input(event, true)
	await process_frame

func _push_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)
	await process_frame

func _check_player_camera_and_aim() -> void:
	local_actor = _spawn_actor(net_session.local_peer(), 1, Vector3(0, 0, -8))
	remote_actor = _spawn_actor(net_session.local_peer() + 100, 1, Vector3(1.5, 0, -8))
	await process_frame
	net_session.control_look = Vector2(0.35, -0.25)
	local_actor._process(0.016)
	remote_actor.facing = Vector2(-0.7, 0)
	remote_actor._process(0.016)
	check(local_actor.camera != null and local_actor.camera.current, "local player owns the current shoulder camera")
	check(_visible_meshes(local_actor.visual) > 0, "local third-person body remains visible")
	check(local_actor.camera.get_child_count() == 0, "first-person camera-attached gun is not left floating")
	check(remote_actor.camera != null and not remote_actor.camera.current, "remote player keeps authored camera non-current")
	check(remote_actor.visual.global_position.distance_to(remote_actor.global_position) < 1.0, "remote interpolation presentation remains active")
	check(is_equal_approx(local_actor.visual.rotation.y, -net_session.control_look.x), "mouse yaw turns the visible player and camera rig")
	check(is_equal_approx(local_actor.camera.rotation.x, net_session.control_look.y), "mouse pitch tilts the camera")
	var expected_target := _camera_center_target(local_actor)
	var expected_direction := (expected_target - local_actor.shot_origin()).normalized()
	var actual_direction := local_actor.camera_aim_direction(net_session.weapon_range)
	check(actual_direction.is_equal_approx(expected_direction), "client aim direction converges from head origin to camera-center target")
	check(actual_direction.distance_to(Vector3(0,0,-1).rotated(Vector3.RIGHT, net_session.control_look.y).rotated(Vector3.UP, -net_session.control_look.x).normalized()) > 0.01, "third-person parallax is not a parallel first-person head ray")
	net_session.actors["%s_%s" % [net_session.local_peer(), net_session.own_life]] = local_actor
	check(net_session.local_shot_direction().is_equal_approx(actual_direction), "NetSession uses local camera-center direction when a local camera exists")
	net_session.actors.erase("%s_%s" % [net_session.local_peer(), net_session.own_life])
	check(net_session.local_shot_direction().is_equal_approx(Vector3(0,0,-1).rotated(Vector3.RIGHT,net_session.control_look.y).rotated(Vector3.UP,-net_session.control_look.x).normalized()), "NetSession preserves bot/no-camera fallback direction")
	_check_near_camera_center_mob_convergence()
	_check_nearest_mob_and_wall_precedence()
	_check_invalid_mob_records_preserve_wall_target()

func _spawn_actor(peer: int, life: int, pose: Vector3) -> CorridorPlayer:
	var actor_scene := load(PLAYER_ACTOR_SCENE) as PackedScene
	var actor := actor_scene.instantiate() as CorridorPlayer if actor_scene else null
	check(actor != null, "authored player actor scene instantiates for third-person harness")
	if actor == null:
		return null
	actor.configure(peer, life, pose, 0)
	players_root.add_child(actor)
	return actor

func _visible_meshes(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is MeshInstance3D and child.visible:
			total += 1
		total += _visible_meshes(child)
	return total

func _camera_center_target(actor: CorridorPlayer) -> Vector3:
	var origin := actor.camera.global_position
	var direction := -actor.camera.global_transform.basis.z.normalized()
	var distance := CorridorGeometry.wall_distance(origin, direction, net_session.weapon_range)
	return origin + direction * distance

func _check_near_camera_center_mob_convergence() -> void:
	var saved_records: Dictionary = net_session.store.records.duplicate(true)
	net_session.store.records.clear()
	var camera_origin := local_actor.camera.global_position
	var camera_direction := -local_actor.camera.global_transform.basis.z.normalized()
	var mob_foot := _mob_foot_on_camera_ray(local_actor, 5.0)
	var camera_hit := CorridorGeometry.ray_capsule(camera_origin, camera_direction, mob_foot, net_session.weapon_range)
	check(is_finite(camera_hit), "regression setup: camera-center ray intersects the nearby mob capsule")
	net_session.store.records[101] = _mob_row(101, mob_foot)
	var actual_direction := local_actor.camera_aim_direction(net_session.weapon_range)
	var head_hit := CorridorGeometry.ray_capsule(local_actor.shot_origin(), actual_direction, mob_foot, net_session.weapon_range)
	check(is_finite(head_hit), "head-origin aim converges onto a nearby mob intersected by the camera-center ray")
	net_session.store.records = saved_records

func _check_nearest_mob_and_wall_precedence() -> void:
	var saved_records: Dictionary = net_session.store.records.duplicate(true)
	net_session.store.records.clear()
	var near_foot := _mob_foot_on_camera_ray(local_actor, 4.5)
	var far_foot := _mob_foot_on_camera_ray(local_actor, 8.0)
	net_session.store.records[201] = _mob_row(201, far_foot)
	net_session.store.records[202] = _mob_row(202, near_foot)
	var nearest_direction := local_actor.camera_aim_direction(net_session.weapon_range)
	var near_hit := CorridorGeometry.ray_capsule(local_actor.shot_origin(), nearest_direction, near_foot, net_session.weapon_range)
	var far_hit := CorridorGeometry.ray_capsule(local_actor.shot_origin(), nearest_direction, far_foot, net_session.weapon_range)
	check(is_finite(near_hit), "nearest camera-center mob is targeted from the head")
	check(is_inf(far_hit) or near_hit <= far_hit, "farther camera-center mob does not override the nearest one")
	net_session.store.records.clear()
	net_session.control_look = Vector2.ZERO
	local_actor.position = Vector3(0, 0, -68)
	local_actor._process(0.016)
	var camera_origin := local_actor.camera.global_position
	var camera_direction := -local_actor.camera.global_transform.basis.z.normalized()
	var wall_distance := CorridorGeometry.wall_distance(camera_origin, camera_direction, net_session.weapon_range)
	var behind_wall_foot := camera_origin + camera_direction * (wall_distance + 2.0) - Vector3(0, 0.9, 0)
	net_session.store.records[203] = _mob_row(203, behind_wall_foot)
	var wall_direction := local_actor.camera_aim_direction(net_session.weapon_range)
	var expected_wall_direction := (camera_origin + camera_direction * wall_distance - local_actor.shot_origin()).normalized()
	check(wall_direction.is_equal_approx(expected_wall_direction), "wall target remains before a camera-center mob behind the wall")
	net_session.store.records = saved_records
	net_session.control_look = Vector2(0.35, -0.25)
	local_actor.position = Vector3(0, 0, -8)
	local_actor._process(0.016)

func _check_invalid_mob_records_preserve_wall_target() -> void:
	var saved_records: Dictionary = net_session.store.records.duplicate(true)
	net_session.store.records.clear()
	var fallback_direction := ( _camera_center_target(local_actor) - local_actor.shot_origin()).normalized()
	var mob_foot := _mob_foot_on_camera_ray(local_actor, 4.5)
	net_session.store.records[301] = _mob_row(301, mob_foot, 0, 1)
	net_session.store.records[302] = _mob_row(302, mob_foot, 100, 3)
	net_session.store.records[303] = {"id":303,"position":Vector3(NAN,0,0),"hp":100,"state":1}
	var direction := local_actor.camera_aim_direction(net_session.weapon_range)
	check(direction.is_equal_approx(fallback_direction), "invalid and dead client mob records do not alter camera-center wall/range aim")
	net_session.store.records = saved_records

func _mob_foot_on_camera_ray(actor: CorridorPlayer, distance: float) -> Vector3:
	var camera_origin := actor.camera.global_position
	var camera_direction := -actor.camera.global_transform.basis.z.normalized()
	return camera_origin + camera_direction * distance - Vector3(0, 0.9, 0)

func _mob_row(id: int, foot: Vector3, hp: int = 100, state: int = 1) -> Dictionary:
	return {"id":id,"generation":id,"revision":1,"interest_epoch":1,"position":foot,"hp":hp,"state":state,"yaw":0.0,"tick":0}

func _check_camera_obstruction_recovery() -> void:
	net_session.control_look = Vector2.ZERO
	local_actor.position = Vector3(0, 0, -20)
	local_actor._process(0.016)
	var clear_distance := local_actor.camera.global_position.distance_to(local_actor.shot_origin())
	check(abs(clear_distance - DEFAULT_CAMERA_DISTANCE) < 0.08, "clear shoulder camera starts at the intended distance")
	var blocker := StaticBody3D.new()
	blocker.name = "CameraBlocker"
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.35)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = local_actor.shot_origin() + Vector3(0, 0, 1.15)
	world.add_child(blocker)
	await physics_frame
	local_actor._process(0.016)
	var clamped_distance := local_actor.camera.global_position.distance_to(local_actor.shot_origin())
	check(clamped_distance < clear_distance - 0.75, "wall obstruction clamps camera closer than the clear shoulder distance")
	check(_finite_vector(local_actor.camera.global_position), "obstructed camera transform stays finite")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	local_actor._process(0.016)
	var recovered_distance := local_actor.camera.global_position.distance_to(local_actor.shot_origin())
	check(abs(recovered_distance - clear_distance) < 0.08, "camera reclaims intended distance after obstruction clears")
	for pitch in [-1.4, 1.4]:
		net_session.control_look = Vector2(0.0, pitch)
		local_actor._process(0.016)
		check(_finite_vector(local_actor.camera.global_position), "camera transform remains finite at pitch clamp %s" % pitch)
		check(_basis_is_finite(local_actor.camera.global_transform.basis), "camera basis remains finite at pitch clamp %s" % pitch)

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _basis_is_finite(value: Basis) -> bool:
	return _finite_vector(value.x) and _finite_vector(value.y) and _finite_vector(value.z)

func _cleanup() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	net_session.is_ready = original_ready
	net_session.control_look = original_look
	net_session.control_move = original_move
	net_session.control_fire = original_fire
	net_session.players_root = original_players_root
	net_session.own_life = original_own_life
	net_session.actors.clear()
	_prime_actor_sync_disconnects(world)
	if world and is_instance_valid(world):
		world.queue_free()
	if ui and is_instance_valid(ui):
		ui.queue_free()

func _prime_actor_sync_disconnects(node: Node) -> void:
	if node == null:
		return
	if node is CorridorPlayer and node.rb and node.rb.has_method("_connect_signals"):
		node.rb._connect_signals()
	for child in node.get_children():
		_prime_actor_sync_disconnects(child)

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
