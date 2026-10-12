extends SceneTree

const SHOT_COUNT := 120
const TRACER_LIFETIME_SECONDS := 0.075
const PREDICTED_COLOR := Color(.98, .8, .35)
const CONFIRMED_COLOR := Color(.4, 1, .7)
const TRACER_MESH_RESOURCE := "res://scenes/resources/tracer_mesh.tres"
const TRACER_PREDICTED_RESOURCE := "res://scenes/resources/tracer_predicted.tres"
const TRACER_CONFIRMED_RESOURCE := "res://scenes/resources/tracer_confirmed.tres"
const PRESENTATION_SCENE := "res://scenes/presentation.tscn"
const ORIGIN := Vector3(0, 1.55, -2)
const ENDPOINT := Vector3(0, 1.55, -32)
const VERTICAL_ENDPOINT := ORIGIN + Vector3(0, 10, 0)
const OWN_ACTOR_POSITION := Vector3(2, 0, -4)

var failures: Array[String] = []
var assertions := 0
var presentation: Node3D
var net_session: Node
var world: Node3D
var camera: Camera3D
var pool_snapshot := {}
var harness_actor: Node
var original_players_root: Node3D
var original_own_life := 0
var actor_key := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_setup_scene()
	await process_frame
	var baseline := OS.get_cmdline_user_args().has("--tracer-baseline")
	pool_snapshot = _capture_pool_identity("after setup")
	await _behavior_checks()
	await _wait_for_expiration("pre-benchmark cleanup")
	_check_pool_identity(pool_snapshot, "pre-benchmark cleanup")
	var measurement := await _measure_sequential_shots()
	await _wait_for_expiration("post-benchmark cleanup")
	_check_pool_identity(pool_snapshot, "post-benchmark cleanup")
	var result := {
		"kind": "tracer_harness",
		"mode": "baseline" if baseline else "regression",
		"production_tracer": "bounded_pool" if _pool_capacity() > 0 else "unchanged",
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"display_server": DisplayServer.get_name(),
		"headless": DisplayServer.get_name().to_lower().contains("headless"),
		"sample_count": measurement.sample_count,
		"submission_usec": measurement.submission_usec,
		"frame_interval_usec": measurement.frame_interval_usec,
		"visible_tracer_nodes": measurement.visible_tracer_nodes,
		"visible_tracer_resources": measurement.visible_tracer_resources,
		"pool_capacity": _pool_capacity(),
		"assertions": assertions,
		"failures": failures,
		"notes": [
			"submission_usec measures signal emission and tracer submission only, not rendered FPS or GPU time",
			"frame_interval_usec measures awaited process_frame intervals in this harness",
			"resource counts are sampled from visible tracer MeshInstance3D nodes after each sequential shot"
		]
	}
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _setup_scene() -> void:
	net_session = root.get_node("NetSession")
	world = Node3D.new()
	world.name = "TracerHarnessWorld"
	root.add_child(world)
	camera = Camera3D.new()
	camera.name = "TracerHarnessCamera"
	camera.position = Vector3(0, 4, 8)
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.2, -16), Vector3.UP)
	var light := DirectionalLight3D.new()
	light.name = "TracerHarnessLight"
	light.rotation_degrees = Vector3(-45, 25, 0)
	world.add_child(light)
	var presentation_packed := load(PRESENTATION_SCENE) as PackedScene
	check(presentation_packed != null, "production presentation scene loads")
	if presentation_packed == null:
		return
	presentation = presentation_packed.instantiate() as CorridorPresentation
	check(presentation != null, "production presentation scene instantiates")
	if presentation == null:
		return
	presentation.name = "CorridorPresentationUnderTest"
	world.add_child(presentation)

func _behavior_checks() -> void:
	check(_visible_tracers().is_empty(), "presentation starts with no visible tracers")
	var initial_tracer_count := _all_tracers().size()
	check(initial_tracer_count == _pool_capacity(), "all preinitialized tracer nodes are pool slots")
	check(_pool_capacity() == 8, "production tracer pool keeps exactly eight slots")
	_check_authored_pool_resources("initial authored pool")
	net_session.shot_submitted.emit(ORIGIN, ENDPOINT)
	var tracer := _single_visible_tracer("predicted tracer is visible after shot submission")
	if tracer:
		_check_tracer_geometry(tracer, ORIGIN, ENDPOINT, PREDICTED_COLOR, "predicted")
		_check_recent_tracer_stays_visible(tracer, "predicted")
	_check_pool_identity(pool_snapshot, "predicted shot")
	net_session.shot_confirmed.emit({"hit": false, "end": ENDPOINT})
	check(_visible_tracers().size() == 1, "confirmed miss does not add a tracer")
	net_session.shot_confirmed.emit({"hit": true, "end": ENDPOINT})
	check(_visible_tracers().size() == 1, "confirmed hit without own actor does not add a tracer")
	await _check_confirmed_signal_with_own_actor()
	await process_frame
	check(_all_tracers().size() == initial_tracer_count, "shots do not add tracer nodes after setup")
	_check_pool_identity(pool_snapshot, "confirmed signal checks")
	_check_saturation(initial_tracer_count)
	await _wait_for_expiration("after saturation")
	_check_pool_identity(pool_snapshot, "natural expiry after saturation")
	await _check_reuse_after_expiration()
	await _check_degenerate_geometry()

func _check_confirmed_signal_with_own_actor() -> void:
	_cleanup_harness_actor()
	original_players_root = net_session.players_root
	original_own_life = net_session.own_life
	net_session.players_root = world
	net_session.own_life = 99
	actor_key = "%s_%s" % [net_session.local_peer(), net_session.own_life]
	net_session._create_actor({"peer": net_session.local_peer(), "life": net_session.own_life, "pose": OWN_ACTOR_POSITION, "spawn_tick": 0})
	harness_actor = net_session.actors.get(actor_key)
	check(harness_actor != null, "confirmed-hit harness creates a valid own actor")
	if harness_actor:
		net_session.shot_confirmed.emit({"hit": true, "end": ENDPOINT})
		var confirmed := _latest_visible_tracer("confirmed hit with own actor adds a tracer through NetSession signal")
		if confirmed:
			_check_tracer_geometry(confirmed, harness_actor.position + Vector3(0, 1.55, 0), ENDPOINT, CONFIRMED_COLOR, "confirmed signal")
	_cleanup_harness_actor()

func _cleanup_harness_actor() -> void:
	if net_session == null:
		return
	if actor_key != "" and net_session.actors.has(actor_key):
		net_session.actors.erase(actor_key)
	if harness_actor and is_instance_valid(harness_actor):
		if "rb" in harness_actor and harness_actor.rb and harness_actor.rb.has_method("_connect_signals"):
			harness_actor.rb._connect_signals()
		harness_actor.queue_free()
	harness_actor = null
	actor_key = ""
	if original_players_root != null:
		net_session.players_root = original_players_root
	net_session.own_life = original_own_life

func _check_saturation(initial_tracer_count: int) -> void:
	var capacity := _pool_capacity()
	if capacity <= 0:
		return
	for index in range(capacity + 5):
		net_session.shot_submitted.emit(ORIGIN + Vector3(index, 0, 0), ENDPOINT + Vector3(index, 0, 0))
	var visible := _visible_tracers()
	check(visible.size() == capacity, "saturation keeps visible tracers capped at pool capacity")
	check(_all_tracers().size() == initial_tracer_count, "saturation reuses existing tracer nodes")
	check(_unique_mesh_count(visible) <= 1, "saturation reuses one tracer mesh resource")
	check(_unique_material_count(visible) <= 2, "saturation reuses bounded tracer materials")
	_check_pool_identity(pool_snapshot, "saturation")
	var latest := _latest_visible_tracer("saturation keeps the most recent shot visible")
	if latest:
		_check_tracer_geometry(latest, ORIGIN + Vector3(capacity + 4, 0, 0), ENDPOINT + Vector3(capacity + 4, 0, 0), PREDICTED_COLOR, "saturated latest")

func _check_reuse_after_expiration() -> void:
	net_session.shot_submitted.emit(ORIGIN, ENDPOINT)
	var first := _single_visible_tracer("reuse setup shot is visible")
	var first_id := first.get_instance_id() if first else 0
	if first:
		_check_recent_tracer_stays_visible(first, "reuse setup")
	await _wait_for_expiration("before reuse")
	net_session.shot_submitted.emit(ORIGIN + Vector3(1, 0, 0), ENDPOINT + Vector3(1, 0, 0))
	var second := _single_visible_tracer("expired tracer slot becomes visible again")
	if second and first_id != 0:
		check(second.get_instance_id() == first_id, "expired tracer slot is reused")
	_check_pool_identity(pool_snapshot, "reuse after natural expiry")

func _check_degenerate_geometry() -> void:
	await _wait_for_expiration("before zero-length tracer")
	net_session.shot_submitted.emit(ORIGIN, ORIGIN)
	var zero := _single_visible_tracer("zero-length tracer is visible and finite")
	if zero:
		_check_tracer_geometry(zero, ORIGIN, ORIGIN, PREDICTED_COLOR, "zero-length")
		check(_basis_is_finite(zero.global_transform.basis), "zero-length tracer transform remains finite")
	await _wait_for_expiration("before vertical tracer")
	net_session.shot_submitted.emit(ORIGIN, VERTICAL_ENDPOINT)
	var vertical := _single_visible_tracer("vertical tracer is visible and finite")
	if vertical:
		_check_tracer_geometry(vertical, ORIGIN, VERTICAL_ENDPOINT, PREDICTED_COLOR, "vertical")
		check(_basis_is_finite(vertical.global_transform.basis), "vertical tracer transform remains finite")
	_check_pool_identity(pool_snapshot, "degenerate geometry")

func _measure_sequential_shots() -> Dictionary:
	var submission_samples: Array[int] = []
	var frame_samples: Array[int] = []
	var max_visible_nodes := 0
	var max_mesh_resources := 0
	var max_material_resources := 0
	for index in range(SHOT_COUNT):
		var origin := ORIGIN + Vector3(float(index % 3) * 0.1, 0, 0)
		var endpoint := ENDPOINT + Vector3(float(index % 5) * 0.1, 0, 0)
		var submit_start := Time.get_ticks_usec()
		net_session.shot_submitted.emit(origin, endpoint)
		submission_samples.append(Time.get_ticks_usec() - submit_start)
		var frame_start := Time.get_ticks_usec()
		await process_frame
		frame_samples.append(Time.get_ticks_usec() - frame_start)
		var visible := _visible_tracers()
		max_visible_nodes = maxi(max_visible_nodes, visible.size())
		max_mesh_resources = maxi(max_mesh_resources, _unique_mesh_count(visible))
		max_material_resources = maxi(max_material_resources, _unique_material_count(visible))
	_check_pool_identity(pool_snapshot, "120-shot benchmark")
	return {
		"sample_count": SHOT_COUNT,
		"submission_usec": _stats(submission_samples),
		"frame_interval_usec": _stats(frame_samples),
		"visible_tracer_nodes": {"max": max_visible_nodes, "final": _visible_tracers().size()},
		"visible_tracer_resources": {"max_meshes": max_mesh_resources, "max_materials": max_material_resources}
	}

func _wait_for_expiration(label: String) -> void:
	var deadline_usec := Time.get_ticks_usec() + int((TRACER_LIFETIME_SECONDS + 0.5) * 1000000.0)
	while Time.get_ticks_usec() < deadline_usec and not _visible_tracers().is_empty():
		await process_frame
	check(_visible_tracers().is_empty(), "%s: visible tracers expire through production _process after 75ms lifetime" % label)

func _check_recent_tracer_stays_visible(tracer: MeshInstance3D, label: String) -> void:
	var elapsed := int(TRACER_LIFETIME_SECONDS * 1000000.0) - 1
	if presentation and "_tracer_expires_usec" in presentation and tracer in presentation._tracer_pool:
		var slot_index: int = presentation._tracer_pool.find(tracer)
		elapsed = Time.get_ticks_usec() - int(presentation._tracer_expires_usec[slot_index] - int(TRACER_LIFETIME_SECONDS * 1000000.0))
	check(elapsed < int(TRACER_LIFETIME_SECONDS * 1000000.0), "%s tracer is checked before its 75ms deadline" % label)
	check(tracer.visible, "%s tracer remains visible before its 75ms deadline" % label)

func _capture_pool_identity(label: String) -> Dictionary:
	var tracers := _all_tracers()
	var node_ids: Array[int] = []
	var mesh_ids := {}
	for tracer in tracers:
		node_ids.append(tracer.get_instance_id())
		if tracer.mesh:
			mesh_ids[tracer.mesh.get_instance_id()] = true
	node_ids.sort()
	var material_ids := _configured_tracer_material_ids()
	check(not tracers.is_empty(), "%s: tracer pool exists" % label)
	check(tracers.size() == 8, "%s: tracer pool has exactly eight authored slots" % label)
	check(mesh_ids.size() == 1, "%s: tracer pool starts with one shared mesh" % label)
	check(material_ids.size() == 2, "%s: tracer pool has two shared materials" % label)
	_check_authored_pool_resources(label)
	return {"node_ids": node_ids, "mesh_ids": mesh_ids.keys(), "material_ids": material_ids}

func _check_pool_identity(snapshot: Dictionary, label: String) -> void:
	var current := _capture_pool_identity(label)
	check(_same_int_array(current.node_ids, snapshot.node_ids), "%s: tracer pool keeps the same node instances" % label)
	check(_same_int_array(current.mesh_ids, snapshot.mesh_ids), "%s: tracer pool keeps the same shared mesh" % label)
	check(_same_int_array(_configured_tracer_material_ids(), snapshot.material_ids), "%s: tracer pool keeps the same two material resources" % label)
	var allowed := {}
	for id in snapshot.material_ids:
		allowed[id] = true
	for tracer in _all_tracers():
		var material := _tracer_material(tracer)
		if material:
			check(allowed.has(material.get_instance_id()), "%s: visible tracer material comes from the fixed material pair" % label)

func _check_authored_pool_resources(label: String) -> void:
	var mesh := load(TRACER_MESH_RESOURCE)
	var predicted := load(TRACER_PREDICTED_RESOURCE)
	var confirmed := load(TRACER_CONFIRMED_RESOURCE)
	check(mesh != null and predicted != null and confirmed != null, "%s: authored tracer resources load" % label)
	if presentation and "_tracer_mesh" in presentation:
		check(presentation._tracer_mesh == mesh, "%s: presentation uses the serialized shared tracer mesh" % label)
	if presentation and "_predicted_tracer_material" in presentation:
		check(presentation._predicted_tracer_material == predicted, "%s: presentation uses the serialized predicted material" % label)
	if presentation and "_confirmed_tracer_material" in presentation:
		check(presentation._confirmed_tracer_material == confirmed, "%s: presentation uses the serialized confirmed material" % label)
	for tracer in _all_tracers():
		check(tracer.mesh == mesh, "%s: tracer slot references the serialized mesh" % label)

func _configured_tracer_material_ids() -> Array[int]:
	var ids: Array[int] = []
	if presentation and "_predicted_tracer_material" in presentation and presentation._predicted_tracer_material:
		ids.append(presentation._predicted_tracer_material.get_instance_id())
	if presentation and "_confirmed_tracer_material" in presentation and presentation._confirmed_tracer_material:
		ids.append(presentation._confirmed_tracer_material.get_instance_id())
	ids.sort()
	return ids

func _single_visible_tracer(message: String) -> MeshInstance3D:
	var tracers := _visible_tracers()
	check(tracers.size() == 1, message)
	if tracers.size() != 1:
		return null
	return tracers[0]

func _latest_visible_tracer(message: String) -> MeshInstance3D:
	var tracers := _visible_tracers()
	check(not tracers.is_empty(), message)
	if tracers.is_empty():
		return null
	var latest := tracers[0]
	for tracer in tracers:
		if int(tracer.get_meta("shot_tracer_sequence", 0)) > int(latest.get_meta("shot_tracer_sequence", 0)):
			latest = tracer
	return latest

func _visible_tracers() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for tracer in _all_tracers():
		if tracer.visible:
			found.append(tracer)
	return found

func _all_tracers() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	_collect_tracers(presentation, found)
	return found

func _collect_tracers(node: Node, found: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and (child.has_meta("shot_tracer") or child.mesh is ImmediateMesh):
			found.append(child)
		_collect_tracers(child, found)

func _check_tracer_geometry(tracer: MeshInstance3D, origin: Vector3, endpoint: Vector3, color: Color, label: String) -> void:
	var mesh := tracer.mesh
	check(mesh != null, "%s tracer has a mesh" % label)
	if mesh == null:
		return
	check(mesh.get_surface_count() == 1, "%s tracer has one line surface" % label)
	if mesh.get_surface_count() < 1:
		return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	check(vertices.size() == 2, "%s tracer has two endpoints" % label)
	if vertices.size() == 2:
		var actual_origin := tracer.global_transform * vertices[0]
		var actual_endpoint := tracer.global_transform * vertices[1]
		check(actual_origin.is_equal_approx(origin), "%s tracer preserves origin" % label)
		check(actual_endpoint.is_equal_approx(endpoint), "%s tracer preserves endpoint" % label)
	var material := _tracer_material(tracer)
	check(material != null, "%s tracer has a standard material" % label)
	if material:
		check(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "%s tracer remains unshaded" % label)
		check(_same_color(material.albedo_color, color), "%s tracer preserves color" % label)

func _tracer_material(tracer: MeshInstance3D) -> StandardMaterial3D:
	if tracer.material_override is StandardMaterial3D:
		return tracer.material_override
	if tracer.mesh and tracer.mesh.get_surface_count() > 0:
		return tracer.mesh.surface_get_material(0) as StandardMaterial3D
	return null

func _pool_capacity() -> int:
	var capacity := 0
	for tracer in _all_tracers():
		if tracer.has_meta("shot_tracer"):
			capacity += 1
	return capacity

func _unique_mesh_count(tracers: Array[MeshInstance3D]) -> int:
	var ids := {}
	for tracer in tracers:
		ids[tracer.mesh.get_instance_id()] = true
	return ids.size()

func _unique_material_count(tracers: Array[MeshInstance3D]) -> int:
	var ids := {}
	for tracer in tracers:
		var material := _tracer_material(tracer)
		if material:
			ids[material.get_instance_id()] = true
	return ids.size()

func _stats(samples: Array[int]) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	return {
		"p50": _percentile(sorted, 0.50),
		"p95": _percentile(sorted, 0.95),
		"max": sorted[-1] if not sorted.is_empty() else 0
	}

func _percentile(sorted: Array[int], fraction: float) -> int:
	if sorted.is_empty():
		return 0
	var index := clampi(int(ceil(float(sorted.size()) * fraction)) - 1, 0, sorted.size() - 1)
	return sorted[index]

func _same_int_array(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if int(left[index]) != int(right[index]):
			return false
	return true

func _basis_is_finite(basis: Basis) -> bool:
	return _vector_is_finite(basis.x) and _vector_is_finite(basis.y) and _vector_is_finite(basis.z)

func _vector_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _same_color(actual: Color, expected: Color) -> bool:
	return is_equal_approx(actual.r, expected.r) and is_equal_approx(actual.g, expected.g) and is_equal_approx(actual.b, expected.b) and is_equal_approx(actual.a, expected.a)

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
