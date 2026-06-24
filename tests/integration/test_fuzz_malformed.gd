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
const SEEDS: int = 8 # outer seed sweep — each draws a fresh corpus from the same generators
const CASES: int = 800
const WALK_DEPTH: int = 6
const WALK_ELEMS: int = 16
const WALK_BUDGET: int = 2000 # max nodes per message — bounds the HARNESS's own fan-out
const MUTATE_MAX: int = 12

var _bases: Array[PackedByteArray] = []
var _budget: int = 0


func before_all() -> void:
	# Diverse valid bases so mutate/truncate corrupt decode paths a single small
	# AddressBook frame can't reach: a union-bearing struct list, a multi-segment
	# message (forces double-far pointer resolution), and nested List(List(...)).
	_bases = [_build_valid(), _build_multiseg(), _build_nested()]


func test_never_faults_on_hostile_input() -> void:
	var walked: int = 0
	var s: int = 0
	# Outer seed sweep: each seed yields a fresh corpus from the same four
	# generators. SEEDS * CASES distinct hostile buffers, deterministic per run.
	while s < SEEDS:
		seed(SEED + s)
		var case_i: int = 0
		while case_i < CASES:
			var bytes: PackedByteArray = _gen_case(case_i)
			var packed: bool = randi() % 2 == 0
			# Must return a Message or null, never fault. Limits default (64 MiB / depth 64).
			var msg: CapnReader.Message = CapnReader.open(bytes, packed)
			if msg != null:
				walked += _walk_message(msg)
			case_i += 1
		s += 1
	# Reached here -> no crash/hang/OOM across every hostile case.
	assert_gt(walked, 0, "walked at least some decoded structure (sanity)")
	assert_true(true, "survived %d hostile inputs" % (SEEDS * CASES))


## #1 hardening: surviving without faulting is necessary but not sufficient — a
## decoder that *silently accepts* garbage (returns plausible-but-wrong data,
## had_error unset) would pass the no-fault test above. The four hand-crafted
## limit traps below each target a specific guard (oversized list, word
## overclaim, far-pointer self-loop). Opened from their as-built unpacked frame
## and fully walked, each MUST either fail to open (null) or set had_error — the
## reader is not allowed to hand back a clean Message for any of them.
func test_crafted_adversarial_flags_error() -> void:
	var pick: int = 0
	while pick < 4:
		var bytes: PackedByteArray = _craft(pick)
		var msg: CapnReader.Message = CapnReader.open(bytes, false)
		if msg != null:
			_walk_message(msg) # follows trip the guards that set had_error
		assert_true(
			msg == null or msg.had_error,
			"crafted pick %d must return null or set had_error, not silently accept" % pick,
		)
		pick += 1


## List-amplification OOM guard. A List(Void) pointer carries a 29-bit element
## count but a ZERO-word body (void elements hold no data), so a huge void list
## passes the segment bounds check yet would drive an eager get_<field>() to
## resize() an Array to that count — a ~8 GB allocation from 24 input bytes. The
## traversal limit must charge one word per void element (capnp amplifiedRead
## parity) and reject it: the list reads back empty with had_error set, never the
## claimed half-billion elements. Message: root struct -> ptr[0] = void list,
## count 0x1FFFFFFF.
func test_void_list_amplification_capped() -> void:
	var b: PackedByteArray = []
	b.resize(24)
	b.encode_u32(0, 0) # segCount-1 = 0
	b.encode_u32(4, 2) # seg0 = 2 words
	b.encode_u32(8, 0x00000000) # word0 lo: root struct ptr, offset 0
	b.encode_u32(12, 0x00010000) # word0 hi: data_words=0, ptr_words=1
	b.encode_u32(16, 0x00000001) # word1 lo: list ptr (kind=1), offset 0
	b.encode_u32(20, 0xfffffff8) # word1 hi: elem_size=VOID(0), count=0x1FFFFFFF
	var msg: CapnReader.Message = CapnReader.open(b, false)
	assert_not_null(msg, "frame is well-formed; open must succeed")
	var lr: CapnReader.ListReader = msg.get_root().get_list(0)
	assert_eq(lr.size(), 0, "amplified void list must read back empty, not 2^29 elements")
	assert_true(msg.had_error, "traversal limit must flag the amplified void list")


## Composite twin of the void-list guard. A List(struct) of ZERO-width elements
## (the tag declares data_words=0, ptr_words=0) carries no body, so the tag's
## element count can claim 2^29 with a 1-word body (just the tag) — the eager
## get_<field>() would resize() an Array to that count. The reader must charge the
## amplified count and reject (capnp layout.c++ :2340). Message: root struct ->
## ptr[0] = composite list, body=1 word (tag only), tag count 0x1FFFFFFF / size 0.
func test_zero_width_composite_amplification_capped() -> void:
	var b: PackedByteArray = []
	b.resize(32)
	b.encode_u32(0, 0) # segCount-1 = 0
	b.encode_u32(4, 3) # seg0 = 3 words (root ptr + list ptr + tag)
	b.encode_u32(8, 0x00000000) # word0 lo: root struct ptr, offset 0
	b.encode_u32(12, 0x00010000) # word0 hi: data_words=0, ptr_words=1
	b.encode_u32(16, 0x00000001) # word1 lo: list ptr (kind=1), offset 0 -> tag at word2
	b.encode_u32(20, 0x00000007) # word1 hi: elem_size=COMPOSITE(7), body word count=0
	b.encode_u32(24, 0x7ffffffc) # word2 lo: tag struct ptr, elem count 0x1FFFFFFF
	b.encode_u32(28, 0x00000000) # word2 hi: data_words=0, ptr_words=0 (zero width)
	var msg: CapnReader.Message = CapnReader.open(b, false)
	assert_not_null(msg, "frame is well-formed; open must succeed")
	var lr: CapnReader.ListReader = msg.get_root().get_list(0)
	assert_eq(lr.size(), 0, "amplified zero-width composite list must read back empty")
	assert_true(msg.had_error, "traversal limit must flag the amplified composite list")


## Slow-path twin of the composite guard. Routing the amplified composite list
## behind a FAR pointer forces fill_list's fast path to bail to _fill_list_slow ->
## populate_from_target, so this covers the guard on the layered follow path the
## two fast-path tests above don't reach. Two segments: seg0 root struct -> ptr[0]
## = far pointer into seg1, whose landing-pad list pointer claims a zero-width
## composite of 0x1FFFFFFF elements.
func test_far_composite_amplification_capped() -> void:
	var b: PackedByteArray = []
	b.resize(48)
	b.encode_u32(0, 1) # segCount-1 = 1 (two segments)
	b.encode_u32(4, 2) # seg0 = 2 words
	b.encode_u32(8, 2) # seg1 = 2 words
	# bytes 12..16 = pad to a word boundary (header is 12 bytes); content @ 16.
	# seg0:
	b.encode_u32(16, 0x00000000) # w0 lo: root struct ptr, offset 0
	b.encode_u32(20, 0x00010000) # w0 hi: data_words=0, ptr_words=1
	b.encode_u32(24, 0x00000002) # w1 lo: FAR (kind=2), single, offset 0
	b.encode_u32(28, 0x00000001) # w1 hi: target segment id = 1
	# seg1:
	b.encode_u32(32, 0x00000001) # w0 lo: landing-pad list ptr, offset 0 -> tag @ seg1 w1
	b.encode_u32(36, 0x00000007) # w0 hi: elem_size=COMPOSITE(7), body word count=0
	b.encode_u32(40, 0x7ffffffc) # w1 lo: tag struct ptr, elem count 0x1FFFFFFF
	b.encode_u32(44, 0x00000000) # w1 hi: data_words=0, ptr_words=0 (zero width)
	var msg: CapnReader.Message = CapnReader.open(b, false)
	assert_not_null(msg, "frame is well-formed; open must succeed")
	assert_eq(msg.segments.segment_count(), 2, "two-segment frame")
	var lr: CapnReader.ListReader = msg.get_root().get_list(0)
	assert_eq(lr.size(), 0, "amplified composite via far pointer must read back empty")
	assert_true(msg.had_error, "traversal limit must flag the far-routed amplified list")


## Element-size confusion guard. capnp forbids primitive element-size promotion,
## so reading a list through a bulk getter whose width disagrees with the wire
## element size is a malformed message — the reader must fail loud (had_error +
## empty) instead of silently slicing wrong-width bytes. Message: root struct ->
## ptr[0] = a 4-element BYTE list. Read as bytes it is valid; read as int32 it
## must be rejected.
func test_bulk_getter_element_size_mismatch_flagged() -> void:
	var b: PackedByteArray = []
	b.resize(32)
	b.encode_u32(0, 0) # segCount-1 = 0
	b.encode_u32(4, 3) # seg0 = 3 words
	b.encode_u32(8, 0x00000000) # w0 lo: root struct ptr, offset 0
	b.encode_u32(12, 0x00010000) # w0 hi: data_words=0, ptr_words=1
	b.encode_u32(16, 0x00000001) # w1 lo: list ptr, offset 0 -> body at w2
	b.encode_u32(20, 0x00000022) # w1 hi: elem_size=BYTE(2), count=4
	b.encode_u32(24, 0x04030201) # w2: 4 body bytes
	b.encode_u32(28, 0x00000000)
	var msg: CapnReader.Message = CapnReader.open(b, false)
	assert_not_null(msg, "frame is well-formed; open must succeed")
	var lr: CapnReader.ListReader = msg.get_root().get_list(0)
	assert_eq(lr.size(), 4, "byte list decodes with its real count")
	assert_eq(lr.to_byte_array().size(), 4, "matching-width view is valid")
	assert_false(msg.had_error, "a matching-width view sets no error")
	assert_true(lr.to_int32_array().is_empty(), "int32 view of a byte list must be rejected")
	assert_true(msg.had_error, "element-size mismatch must set had_error")

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
	var b: PackedByteArray = []
	b.resize(n)
	var k: int = 0
	while k < n:
		b[k] = randi() & 0xff
		k += 1
	return b


func _mutated_valid() -> PackedByteArray:
	# Flip a handful of random bytes in a real message — corrupts pointers,
	# counts, and offsets while keeping a plausible frame. Rotates across the
	# base corpus so each decode path gets mutated.
	var b: PackedByteArray = _bases[randi() % _bases.size()].duplicate()
	if b.is_empty():
		return b
	var muts: int = 1 + randi() % MUTATE_MAX
	var m: int = 0
	while m < muts:
		b[randi() % b.size()] = randi() & 0xff
		m += 1
	return b


func _truncated_valid() -> PackedByteArray:
	var base: PackedByteArray = _bases[randi() % _bases.size()]
	if base.is_empty():
		return base
	return base.slice(0, randi() % base.size())


func _crafted_adversarial() -> PackedByteArray:
	return _craft(randi() % 5)


func _craft(pick: int) -> PackedByteArray:
	# Hand-shaped danger: implausible header counts, a giant list, a far-pointer
	# loop, deep nesting. Each targets a specific limit/guard.
	var b: PackedByteArray = []
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
		# upper word = (count << 3) | elem_size; 0x...A => BYTE elems (code 2),
		# count 0x0FFFFFFF. A huge *byte* list body overruns the 2-word segment
		# (a huge VOID list, code 0, would be spec-legal — zero-width body).
		b.encode_u32(12, 0x7ffffffa) # huge elem_count, byte elems
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
	b = _bases[0].duplicate()
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
		# Set the employment union so a union arm is live on the wire (mutating it
		# exercises union-discriminant decode, which the default arm never does).
		if i % 2 == 0:
			p.set_employment_employer("Employer %d" % i)
		else:
			p.set_employment_school("School %d" % i)
		i += 1
	return ab.to_bytes()


# A multi-segment message: cap_words=4 forces objects past segment 0, so
# cross-segment references emit double-far landing pads. Mutating/truncating this
# corrupts the far-pointer + landing-pad decode paths a single-segment AddressBook
# never reaches.
func _build_multiseg() -> PackedByteArray:
	var root: CapnBuilder.StructBuilder = CapnBuilder.new_message(1, 2, 4)
	root.set_u32(0, 0xABCDEF)
	root.set_text(0, "a far-away string long enough to land in its own segment")
	var child: CapnBuilder.StructBuilder = root.init_struct(1, 1, 0)
	child.set_u32(0, 999)
	return CapnBuilder.to_bytes(root)


# Nested List(List(...)) over primitive, text, and composite inner lists, so the
# corpus carries the recursive list-of-lists decode path.
func _build_nested() -> PackedByteArray:
	var nb: NestedListsCapnp.Nested.Builder = NestedListsCapnp.new_nested()
	var mat: CapnBuilder.ListBuilder = nb.init_matrix(2)
	var r0: CapnBuilder.ListBuilder = mat.init_list_at(0, CapnPointer.ElemSize.FOUR_BYTES, 3)
	r0.set_i32(0, 1)
	r0.set_i32(1, 2)
	r0.set_i32(2, 3)
	mat.init_list_at(1, CapnPointer.ElemSize.FOUR_BYTES, 1).set_i32(0, 4)
	var rows: CapnBuilder.ListBuilder = nb.init_rows(1)
	var t0: CapnBuilder.ListBuilder = rows.init_list_at(0, CapnPointer.ElemSize.POINTER, 2)
	t0.set_text(0, "alpha")
	t0.set_text(1, "beta")
	var cells: CapnBuilder.ListBuilder = nb.init_cells(1)
	var c0: CapnBuilder.ListBuilder = cells.init_composite_list_at(
		0,
		1,
		NestedListsCapnp.Cell.DATA_WORDS,
		NestedListsCapnp.Cell.PTR_WORDS,
	)
	NestedListsCapnp.Cell.Builder.wrap(c0.init_struct(0)).set_v(10)
	return nb.to_bytes()
