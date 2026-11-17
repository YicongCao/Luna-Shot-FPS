extends SceneTree
# Test actual resource selection; EXPECT_WEAPON_REVISION is supplied by the runner.
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/training.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var weapon = scene.player.weapon
	var expected = OS.get_environment("EXPECT_WEAPON_REVISION")
	var roots = {"ml06":"res://assets/weapons/lc01/", "ml07":"res://assets/weapons/lc01/ls01_v1/", "ml09":"res://assets/weapons/lc01/ls01_v2/", "ml20":"res://assets/weapons/lc01/ml20/", "ml21":"res://assets/weapons/lc01/ml21/"}
	var passed = weapon.revision == expected and weapon.asset_root == roots.get(expected) and weapon.ls01 == (expected in ["ml07", "ml09"])
	print("WEAPON_SELECTION ", "PASS" if passed else "FAIL", " expected=", expected, " actual=", weapon.revision, " root=", weapon.asset_root)
	quit(0 if passed else 1)
