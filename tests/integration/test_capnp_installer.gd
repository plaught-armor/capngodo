extends GutTest

## CapnInstaller: the platform asset-name contract and the zip-extraction step.
## The network path (GitHub release fetch/download) needs real release assets
## and is verified manually; here we cover what's deterministic: the asset name
## stays in lock-step with the CI job names, and a crafted zip extracts to the
## cache path with executable content intact.

const KNOWN_ASSETS: PackedStringArray = [
	"capnp-windows-x86_64.zip", "capnp-macos-universal.zip", "capnp-linux-x86_64.zip",
]


func test_expected_asset_matches_a_ci_built_name() -> void:
	# Parity guard: expected_asset() must name an asset the release workflow
	# actually produces. Drift here = silent "no asset found" at install time.
	var asset: String = CapnInstaller.expected_asset()
	assert_true(KNOWN_ASSETS.has(asset), "expected_asset '%s' is one of the CI assets" % asset)


func test_extract_binary_round_trips_a_zip() -> void:
	var zip_path: String = "user://_capngodo_test.zip"
	var packer: ZIPPacker = ZIPPacker.new()
	assert_eq(packer.open(ProjectSettings.globalize_path(zip_path)), OK, "zip opens for writing")
	packer.start_file("capnp")
	packer.write_file("DUMMY_CAPNP_BINARY".to_utf8_buffer())
	packer.close()

	var f: FileAccess = FileAccess.open(zip_path, FileAccess.READ)
	assert_not_null(f, "crafted zip readable")
	var zip_bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()

	var inst: CapnInstaller = CapnInstaller.new()
	var out_path: String = inst._extract_binary(zip_bytes)
	inst.free()

	assert_false(out_path.is_empty(), "extraction returned a path")
	assert_eq(out_path, CapnTool.cached_binary_path(), "extracted to the cache path")
	var bf: FileAccess = FileAccess.open(out_path, FileAccess.READ)
	assert_not_null(bf, "extracted binary readable")
	if bf != null:
		assert_eq(bf.get_as_text(), "DUMMY_CAPNP_BINARY", "binary content intact")
		bf.close()

	# Clean up so the dummy doesn't masquerade as a real capnp for resolve_capnp.
	DirAccess.remove_absolute(out_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(zip_path))
