extends GutTest
## Robustness property: CapnReader must never crash, hang, or OOM on hostile
## bytes — it parses untrusted input. Feed thousands of seeded-random corrupt
## buffers (pure random / mutated-valid / truncated / crafted-adversarial),
## packed and unpacked, then fully traverse whatever Message comes back. The
## decoder's job is to return null / empty / default and set had_error, never
## to fault. Reaching the end of this test IS the assertion (a fault would kill
## the run); the explicit asserts just confirm termination + sane shape.
##
## The walker is depth- and element-bounded so a crafted deep/huge message can't
## blow the TEST's own stack or loop — the reader's traversal/depth limits do the
## real capping; these bounds keep the harness honest if a limit ever regresses.

const SEED: int = 0x6D616C66
const CASES: int = 800
const WALK_DEPTH: int = 6
const WALK_ELEMS: int = 16
const WALK_BUDGET: int = 2000 # max nodes per message — bounds the HARNESS's own fan-out
const MUTATE_MAX: int = 12

var _valid: PackedByteArray = PackedByteArray()
var _budget: int = 0


func before_all() -> void:
	_valid = _build_valid()


func test_never_faults_on_hostile_input() -> void:
	seed(SEED)
	var walked: int = 0
	var case_i: int = 0
	while case_i < CASES:
		var bytes: PackedByteArray = _gen_case(case_i)
		var packed: bool = randi() % 2 == 0
		# Must return a Message or null, never fault. Limits default (64 MiB / depth 64).
		var msg: CapnReader.Message = CapnReader.open(bytes, packed)
		if msg != null:
			walked += _walk_message(msg)
		case_i += 1
	# Reached here -> no crash/hang/OOM across every hostile case.
	assert_gt(walked, 0, "walked at least some decoded structure (sanity)")
	assert_true(true, "survived %d hostile inputs" % CASES)

# --- hostile input generators -------------------------------------------


func _gen_case(i: int) -> PackedByteArray:
	var strat: int = i % 4
	if strat == 0:
		return _random_bytes()
	if strat == 1:
		return _mutated_valid()
	if strat == 2:
		return _truncated_valid()
	return _crafted_adversarial()


func _random_bytes() -> PackedByteArray:
	var n: int = randi() % 512
	var b: PackedByteArray = PackedByteArray()
	b.resize(n)
	var k: int = 0
	while k < n:
		b[k] = randi() & 0xff
		k += 1
	return b


func _mutated_valid() -> PackedByteArray:
	# Flip a handful of random bytes in a real message — corrupts pointers,
	# counts, and offsets while keeping a plausible frame.
	var b: PackedByteArray = _valid.duplicate()
	if b.is_empty():
		return b
	var muts: int = 1 + randi() % MUTATE_MAX
	var m: int = 0
	while m < muts:
		b[randi() % b.size()] = randi() & 0xff
		m += 1
	return b


func _truncated_valid() -> PackedByteArray:
	if _valid.is_empty():
		return _valid
	return _valid.slice(0, randi() % _valid.size())


func _crafted_adversarial() -> PackedByteArray:
	# Hand-shaped danger: implausible header counts, a giant list, a far-pointer
	# loop, deep nesting. Each targets a specific limit/guard.
	var pick: int = randi() % 5
	var b: PackedByteArray = PackedByteArray()
	if pick == 0:
		# Huge segment count in the stream frame header.
		b.resize(8)
		b.encode_u32(0, 0x7fffffff) # segCount-1
		return b
	if pick == 1:
		# One segment, root = list pointer claiming a massive element count.
		b.resize(24)
		b.encode_u32(0, 0) # segCount-1 = 0
		b.encode_u32(4, 2) # seg0 = 2 words
		b.encode_u32(8, 0x00000001) # root: list ptr, offset 0
		b.encode_u32(12, 0x7ffffff8) # huge elem_count, byte elems
		return b
	if pick == 2:
		# Root struct claims more data+ptr words than the segment holds.
		b.resize(16)
		b.encode_u32(0, 0)
		b.encode_u32(4, 1) # seg0 = 1 word (just the root ptr)
		b.encode_u32(8, 0x00000000) # struct ptr offset 0
		b.encode_u32(12, 0xffffffff) # data_words=0xffff ptr_words=0xffff
		return b
	if pick == 3:
		# Far pointer pointing at itself (loop bait — depth/traversal must cap).
		b.resize(16)
		b.encode_u32(0, 0)
		b.encode_u32(4, 1)
		b.encode_u32(8, 0x00000002) # FAR, landing pad word 0
		b.encode_u32(12, 0) # segment 0 -> itself
		return b
	# pick == 4: valid frame, then nonsense pointer soup in the body.
	b = _valid.duplicate()
	if not b.is_empty():
		var k: int = 8
		while k < b.size():
			b[k] = randi() & 0xff
			k += 1
	return b

# --- defensive bounded walker -------------------------------------------


func _walk_message(msg: CapnReader.Message) -> int:
	_budget = WALK_BUDGET
	var root: CapnReader.StructReader = msg.get_root()
	if root == null:
		return 0
	return 1 + _walk_struct(root, 0)


func _walk_struct(r: CapnReader.StructReader, depth: int) -> int:
	if depth >= WALK_DEPTH or _budget <= 0:
		return 0
	_budget -= 1
	var touched: int = 0
	# Primitives at a few offsets (out-of-data returns the default — must not fault).
	touched += r.get_u32(0, 0) & 1
	touched += r.get_u64(8, 0) & 1
	touched += 1 if r.get_bool(0, false) else 0
	# Pointer slots: try every interpretation on each.
	var p: int = 0
	while p < 8:
		if r.has_ptr(p):
			touched += 1
		touched += r.get_text(p, "").length()
		touched += r.get_data(p, PackedByteArray()).size()
		var child: CapnReader.StructReader = r.get_struct(p)
		if child != null and child != r:
			touched += _walk_struct(child, depth + 1)
		var lr: CapnReader.ListReader = r.get_list(p)
		if lr != null:
			touched += _walk_list(lr, depth + 1)
		p += 1
	return touched


func _walk_list(lr: CapnReader.ListReader, depth: int) -> int:
	if depth >= WALK_DEPTH or _budget <= 0:
		return 0
	_budget -= 1
	var n: int = mini(lr.size(), WALK_ELEMS)
	if n < 0:
		return 0
	var touched: int = 0
	var i: int = 0
	while i < n:
		touched += lr.get_u32(i) & 1
		touched += lr.get_text(i, "").length()
		touched += lr.get_data(i, PackedByteArray()).size()
		var s: CapnReader.StructReader = lr.get_struct(i)
		if s != null:
			touched += _walk_struct(s, depth + 1)
		var inner: CapnReader.ListReader = lr.get_list(i)
		if inner != null and inner != lr:
			touched += _walk_list(inner, depth + 1)
		i += 1
	return touched

# --- valid base message --------------------------------------------------


func _build_valid() -> PackedByteArray:
	var ab: AddressbookCapnp.AddressBook.Builder = AddressbookCapnp.new_address_book()
	var people: Array[AddressbookCapnp.Person.Builder] = ab.init_people(6)
	var i: int = 0
	while i < 6:
		var p: AddressbookCapnp.Person.Builder = people[i]
		p.set_id(i)
		p.set_name("Person %d" % i)
		p.set_email("p%d@example.com" % i)
		var phones: Array[AddressbookCapnp.Person_PhoneNumber.Builder] = p.init_phones(2)
		phones[0].set_number("555-%04d" % i)
		phones[0].set_type(AddressbookCapnp.Person_PhoneNumber_Type.MOBILE)
		phones[1].set_number("555-%04d" % (i + 1))
		phones[1].set_type(AddressbookCapnp.Person_PhoneNumber_Type.WORK)
		i += 1
	return ab.to_bytes()
