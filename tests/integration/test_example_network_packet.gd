extends GutTest

## Smoke test for the network_packet example (examples/network_packet): each
## packet kind encodes to packed bytes and decodes back to its original values,
## dispatched on the struct-level union discriminant.


func test_chat_round_trips() -> void:
	var wire: PackedByteArray = NetworkPacketDemo.encode_chat(1, 42, "gg wp")
	var d: Dictionary[String, Variant] = NetworkPacketDemo.decode(wire)
	assert_eq(d["kind"], "chat")
	assert_eq(d["seq"], 1)
	assert_eq(d["sender_id"], 42)
	assert_eq(d["text"], "gg wp")


func test_move_round_trips() -> void:
	var wire: PackedByteArray = NetworkPacketDemo.encode_move(
		2, 42, Vector2(12.5, -3.0), Vector2(1.0, 0.0)
	)
	var d: Dictionary[String, Variant] = NetworkPacketDemo.decode(wire)
	assert_eq(d["kind"], "move")
	assert_eq(d["seq"], 2)
	assert_almost_eq((d["pos"] as Vector2).x, 12.5, 0.0001)
	assert_almost_eq((d["pos"] as Vector2).y, -3.0, 0.0001)
	assert_almost_eq((d["vel"] as Vector2).x, 1.0, 0.0001)


func test_spawn_round_trips() -> void:
	var wire: PackedByteArray = NetworkPacketDemo.encode_spawn(3, 7, 1001, Vector2(5.0, 6.0))
	var d: Dictionary[String, Variant] = NetworkPacketDemo.decode(wire)
	assert_eq(d["kind"], "spawn")
	assert_eq(d["entity_id"], 1001)
	assert_almost_eq((d["pos"] as Vector2).x, 5.0, 0.0001)


func test_distinct_kinds_dispatch_independently() -> void:
	# Three different arms decoded through the same reader path must not bleed.
	var kinds: Array[String] = []
	kinds.append(NetworkPacketDemo.decode(NetworkPacketDemo.encode_chat(1, 1, "x"))["kind"])
	kinds.append(NetworkPacketDemo.decode(NetworkPacketDemo.encode_move(1, 1, Vector2.ZERO, Vector2.ZERO))["kind"])
	kinds.append(NetworkPacketDemo.decode(NetworkPacketDemo.encode_spawn(1, 1, 9, Vector2.ZERO))["kind"])
	assert_eq(kinds, ["chat", "move", "spawn"] as Array[String])
