extends SceneTree
const Ridges = preload("res://scripts/quarantine/lunar_ridges.gd")
const Smooth = preload("res://scripts/quarantine/lunar_horizon.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var baseline: FastNoiseLite=FastNoiseLite.new()
	baseline.seed=221117
	baseline.frequency=.011
	baseline.fractal_octaves=5
	var ridges: FastNoiseLite=Ridges.create_sampler()
	var smooth: FastNoiseLite=Smooth.create_sampler()
	var sums: Array[float]=[0,0]
	var maxima: Array[float]=[0,0]
	var samples: int=0
	for z in range(-300,301,3):
		for x in range(-300,301,3):
			if Vector2(x,z).length()<70: continue
			var old: float=Smooth.sample_height(x,z,baseline)
			var errors: Array[float]=[absf(Ridges.sample_height(x,z,ridges)-old),absf(Smooth.sample_height(x,z,smooth)-old)]
			for i in 2:
				sums[i]+=errors[i]*errors[i]
				maxima[i]=maxf(maxima[i],errors[i])
			samples+=1
	var rmse: Array[float]=[sqrt(sums[0]/samples),sqrt(sums[1]/samples)]
	# Upper angular silhouette sampled radially from the facility center.
	# This is a shape metric, not a replacement for engine screenshots.
	var silhouette_sums: Array[float]=[0,0]
	var silhouette_max: Array[float]=[0,0]
	for angle in 360:
		var ray: Vector2=Vector2(cos(deg_to_rad(angle)),sin(deg_to_rad(angle)))
		var tops: Array[float]=[-PI,-PI,-PI]
		for distance in range(70,301,2):
			var p: Vector2=ray*distance
			var heights: Array[float]=[Smooth.sample_height(p.x,p.y,baseline),Ridges.sample_height(p.x,p.y,ridges),Smooth.sample_height(p.x,p.y,smooth)]
			for i in 3: tops[i]=maxf(tops[i],atan2(heights[i]-1.65,distance))
		for i in 2:
			var delta: float=absf(rad_to_deg(tops[i+1]-tops[0]))
			silhouette_sums[i]+=delta*delta
			silhouette_max[i]=maxf(silhouette_max[i],delta)
	var silhouette_rms: Array[float]=[sqrt(silhouette_sums[0]/360),sqrt(silhouette_sums[1]/360)]
	var checks: Dictionary={"baseline_frequency_preserved":ridges.frequency==baseline.frequency,"baseline_seed_preserved":ridges.seed==baseline.seed,"baseline_gain_preserved":ridges.fractal_gain==baseline.fractal_gain,"height_rmse_below_2m":rmse[0]<2,"height_rmse_reduced_vs_smooth":rmse[0]<rmse[1]*.25,"silhouette_rms_below_1deg":silhouette_rms[0]<1,"silhouette_better_than_smooth":silhouette_rms[0]<silhouette_rms[1]*.5}
	var report: Dictionary={"samples":samples,"height_rmse_m":{"ridges":rmse[0],"smooth":rmse[1]},"max_height_delta_m":{"ridges":maxima[0],"smooth":maxima[1]},"silhouette_rms_degrees":{"ridges":silhouette_rms[0],"smooth":silhouette_rms[1]},"max_silhouette_delta_degrees":{"ridges":silhouette_max[0],"smooth":silhouette_max[1]},"checks":checks,"boundary":"Height samples and radial silhouette from facility center; not pixel evidence, topology acceptance, or user visual approval."}
	var output: String=OS.get_environment("HORIZON_SHAPE_OUTPUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		var file: FileAccess=FileAccess.open(output+"/shape.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report,"\t"))
	quit(0 if checks.values().all(func(ok):return ok) else 1)
