extends Node3D
## SOUTH POLE machinery. Place at identity and assign the player before adding it.

signal suit_hit(amount: int, origin: Vector3)
signal cue(kind: String, origin: Vector3)

const RailCrawler = preload("res://scripts/polar/threat_crawler.gd")
const SampleArm = preload("res://scripts/polar/threat_sampler.gd")
const WORLD_LAYER := 1
const EYE_OFFSET := Vector3(0, 1.65, 0)

var player: CharacterBody3D
var crawler: RailCrawler
var sampler: SampleArm
var middle_busy: bool:
	get:
		return is_instance_valid(sampler) and sampler.phase == SampleArm.Phase.SWEEP


func _ready() -> void:
	name = "Threats"
	var track := Node3D.new()
	track.name = "InspectionTrack"
	add_child(track)
	RailCrawler.build_track(track)

	crawler = RailCrawler.new()
	crawler.name = "Crawler"
	crawler.suit_hit.connect(suit_hit.emit)
	crawler.cue.connect(cue.emit)
	add_child(crawler)

	sampler = SampleArm.new()
	sampler.name = "Sampler"
	sampler.suit_hit.connect(suit_hit.emit)
	sampler.cue.connect(cue.emit)
	add_child(sampler)

	# Keep both drive bodies shootable on layer 4 without blocking player movement.
	if is_instance_valid(player):
		player.add_collision_exception_with(crawler)
		player.add_collision_exception_with(sampler)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var feet := player.global_position
	var view := player.get_node_or_null(^"Head/Camera") as Camera3D
	var eye := view.global_position if view != null else feet + EYE_OFFSET
	crawler.tick(delta, feet, eye, _unoccluded)
	sampler.tick(delta, feet, eye, _unoccluded)


func reset() -> void:
	if is_instance_valid(crawler):
		crawler.reset()
	if is_instance_valid(sampler):
		sampler.reset()


func _unoccluded(origin: Vector3, target: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(origin, target, WORLD_LAYER, [player.get_rid()])
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
