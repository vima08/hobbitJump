"""Build the original low-poly hero. Run with Blender --background --python this_file.

Coordinates in the helpers use Godot's Y-up, +Z-forward convention. The source
is intentionally kept alongside the exported GLB so the asset is reproducible.
"""
from pathlib import Path
import math
import random
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "characters" / "hobbit.glb"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def coord(v):
    return (v[0], -v[2], v[1])


def material(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.9
    return m


skin = material("Warm skin", (0.72, 0.44, 0.24))
shirt = material("Linen shirt", (0.87, 0.78, 0.57))
vest = material("Moss waistcoat", (0.18, 0.30, 0.10))
trousers = material("Ochre shorts", (0.34, 0.23, 0.11))
hair = material("Chestnut curls", (0.13, 0.065, 0.027))
hair_light = material("Sunlit curls", (0.20, 0.10, 0.038))
eyes = material("Eyes", (0.025, 0.020, 0.015))
gold = material("Brass buttons", (0.72, 0.44, 0.08))


def pivot(name, at, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = coord(at)
    return obj


def oval(name, at, size, mat, parent, segments=12, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.parent = parent
    obj.location = coord(at)
    obj.data.materials.append(mat)
    return obj


root = pivot("Hobbit", (0, 0, 0))
torso = pivot("Torso", (0, 0, 0), root)
oval("Shirt", (0, 0.70, 0), (0.28, 0.26, 0.19), shirt, torso)
oval("Waistcoat", (0, 0.68, -0.015), (0.30, 0.23, 0.195), vest, torso)
oval("ShirtFront", (0, 0.73, 0.175), (0.10, 0.18, 0.025), shirt, torso)
for y in [0.61, 0.71, 0.81]:
    oval("Button", (0.115, y, 0.177), (0.018, 0.018, 0.014), gold, torso, 8, 4)
oval("CollarLeft", (-0.08, 0.89, 0.12), (0.09, 0.045, 0.07), shirt, torso)
oval("CollarRight", (0.08, 0.89, 0.12), (0.09, 0.045, 0.07), shirt, torso)

for side, suffix in [(-1, "Left"), (1, "Right")]:
    leg = pivot("Leg" + suffix, (side * 0.145, 0.43, 0), root)
    oval("Shorts" + suffix, (0, -0.055, 0), (0.135, 0.14, 0.135), trousers, leg)
    oval("Shin" + suffix, (0, -0.235, 0), (0.080, 0.12, 0.080), skin, leg)
    oval("Foot" + suffix, (0, -0.35, 0.095), (0.125, 0.080, 0.22), skin, leg)
    for toe in range(3):
        oval("Toe", ((toe - 1) * 0.055, -0.35, 0.285), (0.035, 0.048, 0.045), skin, leg, 8, 4)
    arm = pivot("Arm" + suffix, (side * 0.30, 0.82, 0), torso)
    oval("Sleeve" + suffix, (side * 0.04, -0.075, 0), (0.10, 0.13, 0.105), shirt, arm)
    oval("Hand" + suffix, (side * 0.06, -0.25, 0.01), (0.072, 0.12, 0.075), skin, arm)

head = pivot("Head", (0, 1.075, 0.02), torso)
oval("Face", (0, 0, 0), (0.235, 0.245, 0.205), skin, head, 16, 8)
oval("Nose", (0, -0.015, 0.205), (0.055, 0.055, 0.065), skin, head)
for side in [-1, 1]:
    oval("Ear", (side * 0.235, 0.015, 0), (0.07, 0.09, 0.045), skin, head)
    oval("Eye", (side * 0.083, 0.035, 0.191), (0.025, 0.032, 0.018), eyes, head, 8, 4)
    oval("Eyebrow", (side * 0.083, 0.096, 0.183), (0.045, 0.016, 0.020), hair, head, 8, 4)
oval("Smile", (0, -0.10, 0.18), (0.047, 0.012, 0.012), hair, head, 8, 4)
oval("HairCap", (0, 0.13, -0.035), (0.25, 0.17, 0.21), hair, head)
rng = random.Random(17)
for index in range(23):
    angle = index * math.tau / 13
    radius = 0.17 if index < 13 else 0.11
    at = (math.cos(angle) * radius, 0.20 + (0.06 if index >= 13 else 0), math.sin(angle) * radius - 0.035)
    oval("Curl%02d" % index, at, (0.072, 0.067, 0.075), hair_light if rng.random() < 0.3 else hair, head, 8, 4)

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", export_yup=True,
                          export_animations=False, export_cameras=False, export_lights=False)
print("HOBBIT_EXPORTED", OUTPUT)
