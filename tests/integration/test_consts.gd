extends GutTest
## Const declarations (CG9): schema-level `const` nodes emit class-scoped
## GDScript consts on the umbrella class. Uses the generated ConstsCapnp (from
## tests/golden/consts.capnp).

func test_scalar_consts() -> void:
	assert_eq(ConstsCapnp.MAX_ITEMS, 100, "Int32 const")
	assert_eq(ConstsCapnp.BIG_NUM, 9000000000, "UInt64 const")
	assert_almost_eq(ConstsCapnp.RATIO, 1.5, 0.0001, "Float32 const")
	assert_true(ConstsCapnp.ENABLED, "Bool const")
	assert_eq(ConstsCapnp.GREETING, "hello", "Text const")


func test_enum_const_is_the_enum_value() -> void:
	# Emitted int-typed; the value equals the enum member (green = 1).
	assert_eq(ConstsCapnp.FAVOURITE, ConstsCapnp.Shade.GREEN, "enum const value")
	assert_eq(ConstsCapnp.FAVOURITE, 1, "enum const is int underneath")


func test_float_edge_consts() -> void:
	assert_almost_eq(ConstsCapnp.PI_, 3.141592653589793, 0.0001, "f64 precision const")
	assert_true(is_inf(ConstsCapnp.INFINITY), "inf const is a valid literal, not 'inf'")
	assert_true(ConstsCapnp.INFINITY > 0.0, "positive inf")
	assert_true(is_nan(ConstsCapnp.NOT_NUMBER), "nan const is a valid literal, not 'nan'")


func test_text_const_escaping() -> void:
	# 'q" b\ t<tab>' — quote, backslash, and tab survive the literal escaping.
	assert_eq(ConstsCapnp.TRICKY, "q\" b\\ t\t", "escaped Text const round-trips")
