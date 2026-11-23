extends RefCounted
## World anchors; the rendered and physical routes use these same deck elevations.

const SPAWN := Vector3(1.8, .05, 68.6)
const PIT := -17.0
const MID := -8.5
const RIM := 0.0
const SHAFT_Z := 37.5
const DOCKS: Array[float] = [PIT, MID, RIM]
const CARRIER_Z := -17.4
const CORE := Vector3(1.20, PIT+1.12, CARRIER_Z+.70)
const RECORD := Vector3(5.3, PIT+1.28, -29.9)
const SUPPLY := Vector3(-28.9, MID+1.35, 22.0)
const SHIP := Vector3(-11.5, 0, 57.6)
const EXTRACT := SHIP + Vector3(0, 1.91, -4.43)
const STEP_X := 19.0
const STEPS: Array[Vector2] = [Vector2(44.8,0), Vector2(37.5,-2.85), Vector2(30.2,-5.7), Vector2(22.9,-8.55), Vector2(15.6,-11.4), Vector2(8.3,-14.25), Vector2(1,-17)]
