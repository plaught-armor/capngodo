extends SceneTree
## Headless benchmark for the bulk primitive-list decode (the Packed*Array path).
##
## Run:
##   godot --headless --path . --import
##   godot --headless --path . -s tools/bench_packed.gd
##
## Optional env:
##   CAPNGODO_BENCH_N      floats per List(Float32) payload (default 4096)
##   CAPNGODO_BENCH_ITERS  timed iterations per phase       (default 200)
##
## Decodes one List(Float32) two ways and reports both:
##   per-element  — Array[float] built with one get_f32() call per element
##   bulk         — PackedFloat32Array via one slice + to_float32_array()
## The codegen emits the bulk path for the fixed-width primitive types; the
## per-element column is the prior strategy, kept here to show the delta.
## Pure measurement — writes nothing.

const DEFAULT_N: int = 4096
const DEFAULT_ITERS: int = 200


func _initialize() -> void:
	var n: int = _env_int("CAPNGODO_BENCH_N", DEFAULT_N)
	var iters: int = _env_int("CAPNGODO_BENCH_ITERS", DEFAULT_ITERS)

	var bytes: PackedByteArray = _build_float_list(n)
	var root: CapnReader.StructReader = CapnReader.open(bytes, false).get_root()
	print("=== capngodo packed-list bench ===")
	print("payload: List(Float32) x %d = %d bytes, iters=%d" % [n, bytes.size(), iters])
	print("")

	_bench("per-element Array[float]", root, iters, n, _decode_per_element)
	_bench("bulk        PackedFloat32", root, iters, n, _decode_bulk)
	quit(0)


func _bench(label: String, root: CapnReader.StructReader, iters: int, n: int, fn: Callable) -> void:
	var _warm: int = (fn.call(root) as PackedFloat32Array).size()
	var best_us: int = 1 << 62
	var rep: int = 0
	while rep < 3:
		var start: int = Time.get_ticks_usec()
		var i: int = 0
		while i < iters:
			var _v: PackedFloat32Array = fn.call(root)
			i += 1
		best_us = mini(best_us, Time.get_ticks_usec() - start)
		rep += 1
	var per_elem_ns: float = (best_us * 1000.0) / (iters * n)
	print("  %s  %8.4f ms/iter  %7.1f ns/elem" % [label, (best_us / 1000.0) / iters, per_elem_ns])


func _decode_per_element(root: CapnReader.StructReader) -> PackedFloat32Array:
	var lr: CapnReader.ListReader = root.get_list(0)
	var out: PackedFloat32Array = []
	out.resize(lr.size())
	var i: int = 0
	var count: int = lr.size()
	while i < count:
		out[i] = lr.get_f32(i)
		i += 1
	return out


func _decode_bulk(root: CapnReader.StructReader) -> PackedFloat32Array:
	return root.get_list(0).to_float32_array()


func _build_float_list(n: int) -> PackedByteArray:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var values: PackedFloat32Array = PackedFloat32Array()
	values.resize(n)
	var i: int = 0
	while i < n:
		values[i] = float(i) * 1.5
		i += 1
	bb.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, n).set_float32_array(values)
	return CapnBuilder.to_bytes(bb, false)


func _env_int(key: String, fallback: int) -> int:
	var raw: String = OS.get_environment(key)
	if raw.is_empty():
		return fallback
	return raw.to_int()
