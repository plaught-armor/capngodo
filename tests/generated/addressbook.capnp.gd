class_name AddressbookCapnp extends RefCounted

## GENERATED from addressbook.capnp by capnpc-gdscript — do not edit.

enum Person_PhoneNumber_Type { MOBILE, HOME, WORK }

class Person extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 4
	enum Employment { UNEMPLOYED, EMPLOYER, SCHOOL, SELF_EMPLOYED }

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_id() -> int:
			return self.get_u32(0, 0)

		func get_name() -> String:
			return self.get_text(0, "")

		func get_email() -> String:
			return self.get_text(1, "")

		func get_phones() -> Array[Person_PhoneNumber.Reader]:
			var lr: CapnReader.ListReader = self.get_list(2)
			var out: Array[Person_PhoneNumber.Reader] = []
			out.resize(lr.size())
			for i: int in lr.size():
				var r: Person_PhoneNumber.Reader = Person_PhoneNumber.Reader.new()
				lr.fill_struct(i, r)
				out[i] = r
			return out

		func iter_phones() -> CapnReader.StructListIter:
			return CapnReader.StructListIter.new(self.get_list(2), Person_PhoneNumber.Reader.new())

		func employment_which() -> int:
			return self.get_u16(4, 0)

		func is_employment_unemployed() -> bool:
			return self.get_u16(4, 0) == 0

		func is_employment_employer() -> bool:
			return self.get_u16(4, 0) == 1

		func get_employment_employer() -> String:
			return self.get_text(3, "")

		func is_employment_school() -> bool:
			return self.get_u16(4, 0) == 2

		func get_employment_school() -> String:
			return self.get_text(3, "")

		func is_employment_self_employed() -> bool:
			return self.get_u16(4, 0) == 3

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func set_id(value: int) -> void:
			self.set_u32(0, value, 0)

		func set_name(value: String) -> void:
			self.set_text(0, value)

		func set_email(value: String) -> void:
			self.set_text(1, value)

		func init_phones(n: int) -> Array[Person_PhoneNumber.Builder]:
			var lb: CapnBuilder.ListBuilder = self.init_composite_list(2, n, Person_PhoneNumber.DATA_WORDS, Person_PhoneNumber.PTR_WORDS)
			var out: Array[Person_PhoneNumber.Builder] = []
			out.resize(n)
			for i: int in n:
				var e: Person_PhoneNumber.Builder = Person_PhoneNumber.Builder.new()
				lb.fill_struct(i, e)
				out[i] = e
			return out

		func set_employment_unemployed() -> void:
			self.set_u16(4, 0, 0)

		func set_employment_employer(value: String) -> void:
			self.set_u16(4, 1, 0)
			self.set_text(3, value)

		func set_employment_school(value: String) -> void:
			self.set_u16(4, 2, 0)
			self.set_text(3, value)

		func set_employment_self_employed() -> void:
			self.set_u16(4, 3, 0)

class Person_PhoneNumber extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_number() -> String:
			return self.get_text(0, "")

		func get_type() -> Person_PhoneNumber_Type:
			return self.get_u16(0, 0) as Person_PhoneNumber_Type

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func set_number(value: String) -> void:
			self.set_text(0, value)

		func set_type(value: Person_PhoneNumber_Type) -> void:
			self.set_u16(0, value, 0)

class AddressBook extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_people() -> Array[Person.Reader]:
			var lr: CapnReader.ListReader = self.get_list(0)
			var out: Array[Person.Reader] = []
			out.resize(lr.size())
			for i: int in lr.size():
				var r: Person.Reader = Person.Reader.new()
				lr.fill_struct(i, r)
				out[i] = r
			return out

		func iter_people() -> CapnReader.StructListIter:
			return CapnReader.StructListIter.new(self.get_list(0), Person.Reader.new())

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func init_people(n: int) -> Array[Person.Builder]:
			var lb: CapnBuilder.ListBuilder = self.init_composite_list(0, n, Person.DATA_WORDS, Person.PTR_WORDS)
			var out: Array[Person.Builder] = []
			out.resize(n)
			for i: int in n:
				var e: Person.Builder = Person.Builder.new()
				lb.fill_struct(i, e)
				out[i] = e
			return out


static func read_person(bytes: PackedByteArray, packed: bool = false) -> Person.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Person.Reader = Person.Reader.new()
	msg.fill_root(r)
	return r

static func new_person() -> Person.Builder:
	return Person.Builder.wrap(CapnBuilder.new_message(Person.DATA_WORDS, Person.PTR_WORDS))

static func read_address_book(bytes: PackedByteArray, packed: bool = false) -> AddressBook.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: AddressBook.Reader = AddressBook.Reader.new()
	msg.fill_root(r)
	return r

static func new_address_book() -> AddressBook.Builder:
	return AddressBook.Builder.wrap(CapnBuilder.new_message(AddressBook.DATA_WORDS, AddressBook.PTR_WORDS))
