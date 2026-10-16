extends Node

var failures: Array[String] = []
var assertions := 0
var server_peer: ENetMultiplayerPeer
var client_peer: ENetMultiplayerPeer
var previous_process := false
var previous_physics_process := false
var previous_server := false
var previous_multiplayer_peer: MultiplayerPeer
var evidence := {}

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	previous_process = NetSession.is_processing()
	previous_physics_process = NetSession.is_physics_processing()
	previous_server = NetSession.is_server
	previous_multiplayer_peer = NetSession.multiplayer.multiplayer_peer
	NetSession.set_process(false)
	NetSession.set_physics_process(false)
	NetworkTime.stop()

	_run_native_guard_fixture()

	_cleanup()
	print(JSON.stringify({"disconnected_peers": assertions, "failures": failures, "evidence": evidence}))
	get_tree().quit(0 if failures.is_empty() else 1)

func _run_native_guard_fixture() -> void:
	var pnum := _free_udp_port()
	server_peer = ENetMultiplayerPeer.new()
	var server_result := server_peer.create_server(pnum, 4, 16)
	check(server_result == OK, "native ENet server starts")
	if server_result != OK:
		return
	server_peer.host.bandwidth_limit(0, 0)
	server_peer.host.channel_limit(18)
	NetSession.multiplayer.multiplayer_peer = server_peer
	NetSession._configure_multiplayer_api()
	NetSession.is_server = true
	NetSession.app_tx = 0
	NetSession.tx_by_peer.clear()
	check(NetSession.multiplayer.server_relay == false, "SceneMultiplayer relay disabled on fixture API")

	client_peer = ENetMultiplayerPeer.new()
	check(client_peer.create_client("127.0.0.1", pnum, 16) == OK, "native ENet client starts")
	var peer_id := _wait_for_registered_connected_peer(3000)
	check(peer_id > 1, "server API registers a real connected ENet peer")
	if peer_id <= 1:
		return
	var packet_peer := server_peer.get_peer(peer_id)
	check(packet_peer != null and packet_peer.is_active(), "registered peer has an active native ENet pointer")
	check(packet_peer != null and packet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED, "registered peer is native STATE_CONNECTED before allowed send")

	_clear_native_counters()
	var before_tx: int = NetSession.app_tx
	NetSession.send_rpc("server_metrics", peer_id, [123, {"fixture": "connected"}])
	_pump(8)
	var connected_sent := _pop_sent_bytes()
	check(NetSession.app_tx > before_tx, "connected registered target increments app_tx")
	check(int(NetSession.tx_by_peer.get(peer_id, 0)) > 0, "connected registered target increments tx_by_peer")
	check(connected_sent > 0, "connected registered target emits native ENet bytes")
	evidence["connected"] = {"peer": peer_id, "registered": NetSession.multiplayer.get_peers().has(peer_id), "is_active": packet_peer.is_active(), "state": packet_peer.get_state(), "app_tx_delta": NetSession.app_tx - before_tx, "tx_by_peer": int(NetSession.tx_by_peer.get(peer_id, 0)), "native_sent_bytes": connected_sent}

	_clear_native_counters()
	var tx_after_connected: int = NetSession.app_tx
	var peer_tx_after_connected := int(NetSession.tx_by_peer.get(peer_id, 0))
	NetSession.send_rpc("server_metrics", peer_id + 1000, [123, {"fixture": "absent"}])
	var absent_sent := _pop_sent_bytes()
	check(NetSession.app_tx == tx_after_connected, "absent target drops before app_tx accounting")
	check(int(NetSession.tx_by_peer.get(peer_id, 0)) == peer_tx_after_connected, "absent target leaves tx_by_peer unchanged")
	check(absent_sent == 0, "absent target emits zero native ENet bytes")
	evidence["absent_drop"] = {"app_tx_delta": NetSession.app_tx - tx_after_connected, "tx_by_peer_delta": int(NetSession.tx_by_peer.get(peer_id, 0)) - peer_tx_after_connected, "native_sent_bytes": absent_sent}

	packet_peer.peer_disconnect()
	check(NetSession.multiplayer.get_peers().has(peer_id), "disconnecting peer remains registered before SceneMultiplayer poll")
	check(packet_peer.is_active(), "disconnecting peer still reports active native pointer")
	check(packet_peer.get_state() != ENetPacketPeer.STATE_CONNECTED, "disconnecting peer is not native STATE_CONNECTED before guarded send")
	_clear_native_counters()
	var tx_before_drop: int = NetSession.app_tx
	var peer_tx_before_drop := int(NetSession.tx_by_peer.get(peer_id, 0))
	NetSession.send_rpc("server_metrics", peer_id, [123, {"fixture": "disconnecting"}])
	var disconnecting_sent := _pop_sent_bytes()
	check(NetSession.app_tx == tx_before_drop, "disconnecting registered target drops before app_tx accounting")
	check(int(NetSession.tx_by_peer.get(peer_id, 0)) == peer_tx_before_drop, "disconnecting registered target leaves tx_by_peer unchanged")
	check(disconnecting_sent == 0, "disconnecting registered target emits zero native ENet bytes")
	evidence["disconnecting_drop"] = {"registered_before_poll": NetSession.multiplayer.get_peers().has(peer_id), "is_active": packet_peer.is_active(), "state": packet_peer.get_state(), "app_tx_delta": NetSession.app_tx - tx_before_drop, "tx_by_peer_delta": int(NetSession.tx_by_peer.get(peer_id, 0)) - peer_tx_before_drop, "native_sent_bytes": disconnecting_sent}

func _wait_for_registered_connected_peer(timeout_ms: int) -> int:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		_pump(1)
		for peer_id in NetSession.multiplayer.get_peers():
			var packet_peer := server_peer.get_peer(peer_id)
			if packet_peer != null and packet_peer.is_active() and packet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
				return peer_id
		OS.delay_msec(10)
	return 0

func _pump(iterations: int) -> void:
	for _index in range(iterations):
		if client_peer != null:
			client_peer.poll()
		if NetSession.multiplayer.has_multiplayer_peer():
			NetSession.multiplayer.poll()
		OS.delay_msec(5)

func _clear_native_counters() -> void:
	_pop_sent_bytes()

func _pop_sent_bytes() -> int:
	if server_peer == null or server_peer.host == null:
		return 0
	return int(server_peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA))

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _cleanup() -> void:
	if client_peer != null:
		client_peer.close()
		client_peer = null
	if server_peer != null:
		server_peer.close()
		server_peer = null
	NetSession.multiplayer.multiplayer_peer = previous_multiplayer_peer if previous_multiplayer_peer != null else OfflineMultiplayerPeer.new()
	NetSession.is_server = previous_server
	NetSession.set_process(previous_process)
	NetSession.set_physics_process(previous_physics_process)
	NetSession.tx_by_peer.clear()
	NetSession.app_tx = 0
	NetworkTime.stop()

func _free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	var pnum := 27015 + int(Time.get_ticks_usec() % 2000)
	while pnum < 30000:
		if udp.bind(pnum, "127.0.0.1") == OK:
			udp.close()
			return pnum
		pnum += 1
	return 0
