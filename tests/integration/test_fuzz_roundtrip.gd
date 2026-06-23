extends GutTest
## Property test: for random AddressBook data, decode(encode(m)) == m, via both
## the eager get_*() and lazy iter_*() reader paths, packed and unpacked. Exercises
## the build pointer/byte writers and every inline decode fast path (get_text,
## get_list, fill_list) on random shapes/sizes — a drift net for the hand-inlined
## copies. Seeded for reproducibility.

const SEED: int = 0x10692026
const CASES: int = 300
const MAX_PEOPLE: int = 12
const MAX_PHONES: int = 4

# Name pool spans empty / ascii / multibyte / word-boundary-straddling lengths.
var _name_pool: PackedStringArray = [
	"",
	"A",
	"Alice",
	"naïve café",
	"日本語テスト",
	"emoji 🎮🚀 mix",
	"exactly-seven",
	"a-string-that-spans-multiple-eight-byte-words-for-sure",
]


class PersonData:
	extends RefCounted
	var id: int
	var name: String
	var email: String
	var numbers: PackedStringArray
	var types: PackedInt32Array


func test_random_roundtrip_eager_and_lazy() -> void:
	seed(SEED)
	var case_i: int = 0
	while case_i < CASES:
		var people: Array[PersonData] = _gen_people()
		var packed: bool = randi() % 2 == 0
		var bytes: PackedByteArray = _build(people, packed)
		var ab: AddressbookCapnp.AddressBook.Reader = AddressbookCapnp.read_address_book(bytes, packed)
		_assert_eager(ab, people, case_i)
		_assert_lazy(ab, people, case_i)
		case_i += 1


func _gen_people() -> Array[PersonData]:
	var out: Array[PersonData] = []
	var n: int = randi() % (MAX_PEOPLE + 1)
	var i: int = 0
	while i < n:
		var pd: PersonData = PersonData.new()
		pd.id = randi() & 0xffffffff
		pd.name = _name_pool[randi() % _name_pool.size()]
		pd.email = _name_pool[randi() % _name_pool.size()]
		pd.numbers = PackedStringArray()
		pd.types = PackedInt32Array()
		var pc: int = randi() % (MAX_PHONES + 1)
		var j: int = 0
		while j < pc:
			pd.numbers.append(_name_pool[randi() % _name_pool.size()])
			pd.types.append(randi() % 3)
			j += 1
		out.append(pd)
		i += 1
	return out


func _build(people: Array[PersonData], packed: bool) -> PackedByteArray:
	var ab: AddressbookCapnp.AddressBook.Builder = AddressbookCapnp.new_address_book()
	var pb: Array[AddressbookCapnp.Person.Builder] = ab.init_people(people.size())
	var i: int = 0
	while i < people.size():
		var pd: PersonData = people[i]
		var b: AddressbookCapnp.Person.Builder = pb[i]
		b.set_id(pd.id)
		b.set_name(pd.name)
		b.set_email(pd.email)
		var ph: Array[AddressbookCapnp.Person_PhoneNumber.Builder] = b.init_phones(pd.numbers.size())
		var j: int = 0
		while j < pd.numbers.size():
			ph[j].set_number(pd.numbers[j])
			ph[j].set_type(pd.types[j])
			j += 1
		i += 1
	return ab.to_bytes(packed)


func _assert_eager(ab: AddressbookCapnp.AddressBook.Reader, people: Array[PersonData], case_i: int) -> void:
	var rp: Array = ab.get_people()
	assert_eq(rp.size(), people.size(), "case %d eager people count" % case_i)
	var i: int = 0
	while i < people.size():
		var pd: PersonData = people[i]
		var r: AddressbookCapnp.Person.Reader = rp[i]
		assert_eq(r.get_id(), pd.id, "case %d person %d id" % [case_i, i])
		assert_eq(r.get_name(), pd.name, "case %d person %d name" % [case_i, i])
		assert_eq(r.get_email(), pd.email, "case %d person %d email" % [case_i, i])
		var rph: Array = r.get_phones()
		assert_eq(rph.size(), pd.numbers.size(), "case %d person %d phone count" % [case_i, i])
		var j: int = 0
		while j < pd.numbers.size():
			assert_eq(rph[j].get_number(), pd.numbers[j], "case %d p%d phone %d num" % [case_i, i, j])
			assert_eq(rph[j].get_type(), pd.types[j], "case %d p%d phone %d type" % [case_i, i, j])
			j += 1
		i += 1


func _assert_lazy(ab: AddressbookCapnp.AddressBook.Reader, people: Array[PersonData], case_i: int) -> void:
	var i: int = 0
	for r: AddressbookCapnp.Person.Reader in ab.iter_people():
		var pd: PersonData = people[i]
		assert_eq(r.get_id(), pd.id, "case %d lazy person %d id" % [case_i, i])
		assert_eq(r.get_name(), pd.name, "case %d lazy person %d name" % [case_i, i])
		var j: int = 0
		for h: AddressbookCapnp.Person_PhoneNumber.Reader in r.iter_phones():
			assert_eq(h.get_number(), pd.numbers[j], "case %d lazy p%d phone %d num" % [case_i, i, j])
			assert_eq(h.get_type(), pd.types[j], "case %d lazy p%d phone %d type" % [case_i, i, j])
			j += 1
		assert_eq(j, pd.numbers.size(), "case %d lazy p%d phone count" % [case_i, i])
		i += 1
	assert_eq(i, people.size(), "case %d lazy people count" % case_i)
