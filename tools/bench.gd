extends SceneTree

## Headless micro-benchmark for the capngodo runtime codec.
##
## Run:
##   godot --headless --path . --import        # once, register class_name globals
##   godot --headless --path . -s tools/bench.gd
##
## Optional env:
##   CAPNGODO_BENCH_N      people per AddressBook payload (default 1000)
##   CAPNGODO_BENCH_ITERS  timed iterations per phase     (default 50)
##
## Measures four phases against an AddressBook payload of N people:
##   build   — populate a builder + to_bytes()
##   decode  — CapnReader.open() + full traversal of every field
##   pack    — CapnPacked.pack() of the encoded bytes
##   unpack  — CapnPacked.unpack() back to words
## Reports per-iteration ms, throughput (MB/s for codec phases), and ops/sec.
## Pure measurement — writes nothing, changes nothing.

const DEFAULT_N: int = 1000
const DEFAULT_ITERS: int = 50


func _initialize() -> void:
	var n: int = _env_int("CAPNGODO_BENCH_N", DEFAULT_N)
	var iters: int = _env_int("CAPNGODO_BENCH_ITERS", DEFAULT_ITERS)

	var bytes: PackedByteArray = _build_payload(n)
	print("=== capngodo bench ===")
	print("payload: AddressBook x %d people = %d bytes (%.1f KiB), iters=%d" % [
		n, bytes.size(), bytes.size() / 1024.0, iters,
	])
	print("")

	_bench_build(n, iters, bytes.size())
	_bench_decode(bytes, iters)
	_bench_pack(bytes, iters)

	quit(0)


# --- phases --------------------------------------------------------------

func _bench_build(n: int, iters: int, out_bytes: int) -> void:
	# Warm once (JIT-equivalent: first run pays parse/alloc warmup).
	var _warm: PackedByteArray = _build_payload(n)
	var start: int = Time.get_ticks_usec()
	var i: int = 0
	while i < iters:
		var _b: PackedByteArray = _build_payload(n)
		i += 1
	var elapsed_us: int = Time.get_ticks_usec() - start
	_report("build ", elapsed_us, iters, out_bytes)


func _bench_decode(bytes: PackedByteArray, iters: int) -> void:
	var _warm: int = _decode_traverse(bytes)
	var start: int = Time.get_ticks_usec()
	var i: int = 0
	while i < iters:
		# The traversal itself is the work; the returned checksum is incidental.
		var _sum: int = _decode_traverse(bytes)
		i += 1
	var elapsed_us: int = Time.get_ticks_usec() - start
	_report("decode", elapsed_us, iters, bytes.size())


func _bench_pack(bytes: PackedByteArray, iters: int) -> void:
	var packed: PackedByteArray = CapnPacked.pack(bytes)
	print("  packed size: %d bytes (%.1f%% of plain)" % [
		packed.size(), 100.0 * packed.size() / bytes.size(),
	])
	var start_p: int = Time.get_ticks_usec()
	var i: int = 0
	while i < iters:
		var _p: PackedByteArray = CapnPacked.pack(bytes)
		i += 1
	_report("pack  ", Time.get_ticks_usec() - start_p, iters, bytes.size())

	var start_u: int = Time.get_ticks_usec()
	i = 0
	while i < iters:
		var _u: PackedByteArray = CapnPacked.unpack(packed)
		i += 1
	_report("unpack", Time.get_ticks_usec() - start_u, iters, packed.size())


# --- payload -------------------------------------------------------------

## Build an AddressBook of N people, each with a name/email/id and two phones,
## then serialize. Returns the encoded bytes.
func _build_payload(n: int) -> PackedByteArray:
	var ab: AddressbookCapnp.AddressBook.Builder = AddressbookCapnp.new_address_book()
	var people: Array[AddressbookCapnp.Person.Builder] = ab.init_people(n)
	var i: int = 0
	while i < n:
		var p: AddressbookCapnp.Person.Builder = people[i]
		p.set_id(i)
		p.set_name("Person %d" % i)
		p.set_email("person%d@example.com" % i)
		p.set_employment_employer("Acme %d" % (i % 50))
		var phones: Array[AddressbookCapnp.Person_PhoneNumber.Builder] = p.init_phones(2)
		phones[0].set_number("555-%04d" % (i % 10000))
		phones[0].set_type(AddressbookCapnp.Person_PhoneNumber_Type.MOBILE)
		phones[1].set_number("555-%04d" % ((i + 1) % 10000))
		phones[1].set_type(AddressbookCapnp.Person_PhoneNumber_Type.WORK)
		i += 1
	return ab.to_bytes()


## Decode + touch every field so the reader actually walks the message.
## Returns a checksum to keep the work observable.
func _decode_traverse(bytes: PackedByteArray) -> int:
	var ab: AddressbookCapnp.AddressBook.Reader = AddressbookCapnp.read_address_book(bytes)
	var people: Array[AddressbookCapnp.Person.Reader] = ab.get_people()
	var sum: int = 0
	for person: AddressbookCapnp.Person.Reader in people:
		sum += person.get_id()
		sum += person.get_name().length()
		sum += person.get_email().length()
		var phones: Array[AddressbookCapnp.Person_PhoneNumber.Reader] = person.get_phones()
		for ph: AddressbookCapnp.Person_PhoneNumber.Reader in phones:
			sum += ph.get_number().length()
			sum += ph.get_type()
	return sum


# --- reporting -----------------------------------------------------------

func _report(label: String, elapsed_us: int, iters: int, payload_bytes: int) -> void:
	var per_iter_ms: float = (elapsed_us / 1000.0) / iters
	var ops_per_sec: float = iters * 1_000_000.0 / maxi(elapsed_us, 1)
	var mb_per_sec: float = (payload_bytes * iters) / maxf(elapsed_us, 1.0)  # bytes/us = MB/s
	print("  %s  %8.3f ms/iter   %9.1f ops/s   %7.1f MB/s" % [
		label, per_iter_ms, ops_per_sec, mb_per_sec,
	])


func _env_int(key: String, fallback: int) -> int:
	var raw: String = OS.get_environment(key)
	if raw.is_empty():
		return fallback
	return raw.to_int()
