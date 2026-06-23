class_name NetworkPacketDemo extends Node

## capngodo example: multiplayer wire packets with a tagged union body.
##
## A `Packet` has a small header (seq, senderId) plus a struct-level union body
## that is exactly one of chat / move / spawn. Each kind is encoded to compact
## packed bytes (what you'd put on the wire), then decoded and dispatched on the
## union discriminant — the same pattern a netcode receive loop uses.
##
## The encode/decode functions are static + pure so they double as a testable
## API (see tests/integration/test_example_network_packet.gd).
##
## Generate the schema classes with:
##   capnp compile -o gdscript examples/network_packet/packet.capnp


func _ready() -> void:
	# Build one packet of each kind, serialize (packed), then decode + dispatch.
	var wire_chat: PackedByteArray = encode_chat(1, 42, "gg wp")
	var wire_move: PackedByteArray = encode_move(2, 42, Vector2(12.5, -3.0), Vector2(1.0, 0.0))
	var wire_spawn: PackedByteArray = encode_spawn(3, 7, 1001, Vector2(0.0, 0.0))

	print("chat  packet: %d bytes -> %s" % [wire_chat.size(), describe(wire_chat)])
	print("move  packet: %d bytes -> %s" % [wire_move.size(), describe(wire_move)])
	print("spawn packet: %d bytes -> %s" % [wire_spawn.size(), describe(wire_spawn)])


# --- encode (one static fn per packet kind) ------------------------------

static func encode_chat(seq: int, sender_id: int, text: String) -> PackedByteArray:
	var p: PacketCapnp.Packet.Builder = PacketCapnp.new_packet()
	p.set_seq(seq)
	p.set_sender_id(sender_id)
	p.set_body_chat(text)
	return p.to_bytes(true)  # packed


static func encode_move(seq: int, sender_id: int, pos: Vector2, vel: Vector2) -> PackedByteArray:
	var p: PacketCapnp.Packet.Builder = PacketCapnp.new_packet()
	p.set_seq(seq)
	p.set_sender_id(sender_id)
	var body: PacketCapnp.MoveBody.Builder = p.init_body_move()
	var bpos: PacketCapnp.Vec2.Builder = body.init_pos()
	bpos.set_x(pos.x)
	bpos.set_y(pos.y)
	var bvel: PacketCapnp.Vec2.Builder = body.init_vel()
	bvel.set_x(vel.x)
	bvel.set_y(vel.y)
	return p.to_bytes(true)


static func encode_spawn(seq: int, sender_id: int, entity_id: int, pos: Vector2) -> PackedByteArray:
	var p: PacketCapnp.Packet.Builder = PacketCapnp.new_packet()
	p.set_seq(seq)
	p.set_sender_id(sender_id)
	var body: PacketCapnp.SpawnBody.Builder = p.init_body_spawn()
	body.set_entity_id(entity_id)
	var bpos: PacketCapnp.Vec2.Builder = body.init_pos()
	bpos.set_x(pos.x)
	bpos.set_y(pos.y)
	return p.to_bytes(true)


# --- decode + dispatch ---------------------------------------------------

## Decode a packed packet to a plain Dictionary, dispatching on the union arm.
## The shape mirrors what a receive loop would switch on.
static func decode(wire: PackedByteArray) -> Dictionary[String, Variant]:
	var p: PacketCapnp.Packet.Reader = PacketCapnp.read_packet(wire, true)  # packed
	var out: Dictionary[String, Variant] = {"seq": p.get_seq(), "sender_id": p.get_sender_id()}
	if p.is_body_chat():
		out["kind"] = "chat"
		out["text"] = p.get_body_chat()
	elif p.is_body_move():
		out["kind"] = "move"
		var m: PacketCapnp.MoveBody.Reader = p.get_body_move()
		out["pos"] = Vector2(m.get_pos().get_x(), m.get_pos().get_y())
		out["vel"] = Vector2(m.get_vel().get_x(), m.get_vel().get_y())
	elif p.is_body_spawn():
		out["kind"] = "spawn"
		var s: PacketCapnp.SpawnBody.Reader = p.get_body_spawn()
		out["entity_id"] = s.get_entity_id()
		out["pos"] = Vector2(s.get_pos().get_x(), s.get_pos().get_y())
	return out


static func describe(wire: PackedByteArray) -> String:
	var d: Dictionary[String, Variant] = decode(wire)
	return "seq=%d sender=%d kind=%s" % [d["seq"], d["sender_id"], d["kind"]]
