extends RefCounted

const ATLAS: Texture2D = preload("res://assets/art/woodland-atlas-v1.png")
const PAINT: Shader = preload("res://shaders/painted_surface.gdshader")
static var _cache: Dictionary = {}


static func painted(kind: int, scale: float = 0.45, tint: Color = Color.WHITE) -> ShaderMaterial:
	var key := "%d:%s:%s" % [kind, scale, tint.to_html()]
	if not _cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = PAINT
		material.set_shader_parameter("atlas", ATLAS)
		material.set_shader_parameter("material_kind", kind)
		material.set_shader_parameter("texture_scale", scale)
		material.set_shader_parameter("tint", tint)
		_cache[key] = material
	return _cache[key]
