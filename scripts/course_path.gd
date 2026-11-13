extends RefCounted
## Shared river centre for the course, its banks and the playable boundary.


static func center_x(z: float) -> float:
	return 10.0 * sin((clampf(z, -53.0, 4.5) - 4.5) * 0.085)
