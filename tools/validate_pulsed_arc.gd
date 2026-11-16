extends "res://tools/validate_magnetic_pulse.gd"
func _initialize() -> void:
	OUT = "res://docs/validation/pulsed-arc-v1/"
	expected_effect = "PulsedIonArc"
	super._initialize()
func check_effect() -> void:
	check("two_seeded_variants",fx.arc_variants.size()==2 and fx.branch_variants.size()==2)
	for points in fx.arc_variants:
		check("arc_exact_endpoints",points[0]==fx.start and points[-1]==fx.finish)
		var axis: Vector3 = (fx.finish-fx.start).normalized()
		var max_offset := 0.0
		for point in points:
			var relative: Vector3 = point-fx.start
			max_offset = maxf(max_offset,(relative-axis*relative.dot(axis)).length())
		check("bounded_visible_jagged_shape",max_offset>.002 and max_offset<.26,str(max_offset))
	for branches in fx.branch_variants:
		check("two_short_branches",branches.size()==2)
		for branch in branches: check("branch_bounded",branch[0].distance_to(branch[-1])<.4)
	fx.age=.008;fx.refresh()
	check("local_coil_discharge",fx.coil_arc.visible)
	check("first_arc_phase",fx.arc_phase==0 and fx.arc_visible)
	fx.age=.020;fx.refresh()
	check("local_arc_expired",not fx.coil_arc.visible and not fx.flash.visible)
	check("stable_first_phase",fx.arc_phase==0)
	fx.age=.030;fx.refresh()
	check("single_restrike",fx.arc_phase==1 and fx.arc_visible)
	fx.age=.049;fx.refresh()
	check("stable_second_phase",fx.arc_phase==1)
	fx.age=.060;fx.refresh()
	check("no_sustained_beam",not fx.arc_visible)
	fx.age=0;fx.refresh()

func extra_checks() -> void:
	# Isolate a branch collision in open space, away from level and player geometry.
	var a := Vector3(0,25,0)
	var b := Vector3(0,25,-10)
	fx.build_paths(a,b,777,false)
	var original: Array = fx.branch_variants[0][0].duplicate()
	var blocker := StaticBody3D.new()
	blocker.collision_layer=1
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new(); shape.radius=.008
	collider.shape=shape;blocker.add_child(collider);world.add_child(blocker)
	blocker.position=original[0].lerp(original[1],.55)
	await physics_frame;await physics_frame
	fx.build_paths(a,b,777,false)
	var branch: Array = fx.branch_variants[0][0]
	check("branch_stops_at_first_obstacle",branch.size()==2 and branch[0].distance_to(branch[-1])<original[0].distance_to(original[1]))
	blocker.queue_free();await frames()

func extra_capture(label: String) -> void:
	await capture(label+"-032ms",.032)
	if not native or label != "hip": return
	fx.age=.008;fx.refresh();fx.set_process(false)
	await frames(4);await RenderingServer.frame_post_draw
	var on := root.get_texture().get_image()
	on.save_png(OUT+"coil-local-on.png")
	fx.coil_arc.hide()
	await frames(4);await RenderingServer.frame_post_draw
	var off := root.get_texture().get_image()
	off.save_png(OUT+"coil-local-off.png")
	var changed := 0
	for y in range(560,850):
		for x in range(900,1150):
			var a := on.get_pixel(x,y)
			var b := off.get_pixel(x,y)
			if absf(a.g-b.g)+absf(a.b-b.b) > .06: changed+=1
	check("local_coil_visible_pixels",changed>5,str(changed))
	fx.set_process(true)
