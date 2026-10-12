class_name CorridorUI
extends CanvasLayer

@onready var root_control: Control = $Root
@onready var background: ColorRect = $Root/Background
@onready var panel: PanelContainer = $Root/MenuPanel
@onready var status_label: Label = $Root/MenuPanel/MenuMargin/MenuStack/StatusLabel
@onready var local_button: Button = $Root/MenuPanel/MenuMargin/MenuStack/LocalButton
@onready var ip: LineEdit = $Root/MenuPanel/MenuMargin/MenuStack/EndpointRow/IP
@onready var port: SpinBox = $Root/MenuPanel/MenuMargin/MenuStack/EndpointRow/Port
@onready var connect_button: Button = $Root/MenuPanel/MenuMargin/MenuStack/ConnectButton
@onready var resume_button: Button = $Root/MenuPanel/MenuMargin/MenuStack/ResumeButton
@onready var disconnect_button: Button = $Root/MenuPanel/MenuMargin/MenuStack/DisconnectButton
@onready var quit_button: Button = $Root/MenuPanel/MenuMargin/MenuStack/QuitButton
@onready var hud: Label = $Root/HUD
@onready var debug: Label = $Root/Debug
@onready var feedback: Label = $Root/Feedback
@onready var crosshair: Label = $Root/Crosshair

var feedback_until = 0.0
var show_debug = false

func _net() -> Node:
	return Engine.get_main_loop().root.get_node("NetSession")

func _network_time() -> Node:
	return Engine.get_main_loop().root.get_node("NetworkTime")

func _ready() -> void:
	show_debug = _net().args.has("capture-debug")
	status_label.text = _net().status
	_connect_button(local_button, _on_local_button_pressed)
	_connect_button(connect_button, _on_connect_button_pressed)
	_connect_button(resume_button, _on_resume_button_pressed)
	_connect_button(disconnect_button, _on_disconnect_button_pressed)
	_connect_button(quit_button, _on_quit_button_pressed)
	_net().status_changed.connect(_on_status_changed)
	_net().shot_confirmed.connect(_on_shot_confirmed)

func _connect_button(button: Button, callback: Callable) -> void:
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _on_local_button_pressed() -> void:
	_net().start_local()

func _on_connect_button_pressed() -> void:
	_net().connect_to(ip.text.strip_edges(), int(port.value))

func _on_resume_button_pressed() -> void:
	if _net().is_ready:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_disconnect_button_pressed() -> void:
	_net().disconnect_session()

func _on_quit_button_pressed() -> void:
	_net().shutdown()

func _on_status_changed() -> void:
	status_label.text = _net().status
	if _net().is_ready:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_shot_confirmed(result: Dictionary) -> void:
	if result.hit:
		feedback.text = "ELIMINATED" if result.kill else "HIT • %s HP" % result.hp
		feedback_until = Time.get_ticks_msec() / 1000.0 + .3

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else (Input.MOUSE_MODE_CAPTURED if _net().is_ready else Input.MOUSE_MODE_VISIBLE)
		elif event.keycode == KEY_F3:
			show_debug = not show_debug
	if event is InputEventMouseMotion and _net().is_ready and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_net().control_look.x = wrapf(_net().control_look.x + event.relative.x * .0025, -PI, PI)
		_net().control_look.y = clampf(_net().control_look.y - event.relative.y * .0025, -1.4, 1.4)

func _process(_delta: float) -> void:
	panel.visible = not _net().is_ready or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	background.visible = not _net().is_ready
	_net().control_move = Vector2.ZERO
	_net().control_fire = false
	if _net().is_ready and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_net().control_move = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length(1)
		_net().control_fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var own = _net().gameplay.get(_net().local_peer(), {})
	var metrics = _net().last_metrics
	crosshair.visible = _net().is_ready
	hud.visible = _net().is_ready
	hud.text = "HP %s  |  Kills %s  |  Wave %s%s" % [own.get("hp", 100), own.get("kills", 0), metrics.get("wave", 1), "  • Respawning…" if own.get("hp", 100) <= 0 else ""]
	feedback.visible = _net().is_ready and Time.get_ticks_msec() / 1000.0 < feedback_until
	debug.visible = show_debug and _net().is_ready
	debug.text = "SERVER • active %s / dormant %s / relevant-to-me %s\nNetwork %.1f Hz • physics %.1f Hz • loop %.1f Hz • poll %.1f Hz\nSnapshot %.1f Hz • app TX %.0f B/s • RX %.0f B/s\nSimulation %.3f ms • movement rollback %.3f ms • last loop replays %s\nLOCAL • %.0f FPS • ping %.1f ms • rejected snapshots %s\nEsc: menu / mouse • F3: diagnostics" % [metrics.get("active_mobs", 0), metrics.get("dormant_mobs", 0), _net().store.records.size(), metrics.get("network_hz", 0), metrics.get("physics_hz", 0), metrics.get("main_loop_hz", 0), metrics.get("poll_hz", 0), metrics.get("snapshot_hz", 0), metrics.get("tx_bytes_s", 0), metrics.get("rx_bytes_s", 0), metrics.get("server_tick_ms", 0), metrics.get("rollback_ms", 0), metrics.get("rollback_replays", 0), Engine.get_frames_per_second(), _network_time().remote_rtt * 1000, _net().store.rejected]
