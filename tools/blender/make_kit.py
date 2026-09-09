# Seeker asset kit generator — run headless:
#   blender --background --python tools/blender/make_kit.py
# Writes .glb files into assets/kit/. Materials are flat placeholders named
# "bark" / "leaves" / "snow" / "rock"; the game replaces them by name with
# its own (TexF) materials at load time, so one mesh serves every palette.
import bpy
import bmesh
import math
import os
import random

OUT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "kit"))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
    return m


def bm_object(name, mat, build):
    """Creates an object from a bmesh built by `build(bm)`."""
    bm = bmesh.new()
    build(bm)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def jitter(bm, amt, rng, keep_z=False):
    for v in bm.verts:
        v.co.x += rng.uniform(-amt, amt)
        v.co.y += rng.uniform(-amt, amt)
        if not keep_z:
            v.co.z += rng.uniform(-amt * 0.6, amt * 0.6)


def cone(bm, r1, r2, depth, z, segments=9, dx=0.0, dy=0.0):
    ret = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=True, segments=segments,
        radius1=r1, radius2=r2, depth=depth)
    for v in ret["verts"]:
        v.co.x += dx
        v.co.y += dy
        v.co.z += z


def sphere(bm, r, x, y, z, subdiv=1, squash=0.8):
    ret = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    for v in ret["verts"]:
        v.co.z *= squash
        v.co.x += x
        v.co.y += y
        v.co.z += z


def branch(bm, r, length, z, azim_deg, tilt_deg, segments=6):
    """A tapered branch cylinder leaning outward from the trunk."""
    ret = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=True, segments=segments,
        radius1=r, radius2=r * 0.35, depth=length)
    az = math.radians(azim_deg)
    tl = math.radians(tilt_deg)
    for v in ret["verts"]:
        # stand the cylinder up, tilt it, swing it around the trunk
        x, y, zz = v.co.x, v.co.y, v.co.z + length * 0.5
        x2 = x * math.cos(tl) + zz * math.sin(tl)
        z2 = -x * math.sin(tl) + zz * math.cos(tl)
        v.co.x = x2 * math.cos(az) - y * math.sin(az) + 0.12 * math.cos(az)
        v.co.y = x2 * math.sin(az) + y * math.cos(az) + 0.12 * math.sin(az)
        v.co.z = z2 + z


def join_and_export(objs, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, filename + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, use_selection=True, export_format="GLB",
        export_yup=True)
    print("wrote", path)


def make_pine(with_snow):
    reset()
    rng = random.Random(7)
    bark = material("bark", (0.28, 0.19, 0.12))
    leaves = material("leaves", (0.14, 0.3, 0.14))
    trunk = bm_object("trunk", bark, lambda bm: (
        cone(bm, 0.30, 0.10, 2.4, 1.2, 8),
        jitter(bm, 0.03, rng, True)))
    tiers = [(1.65, 2.3, 2.35), (1.35, 2.1, 3.35), (1.02, 1.9, 4.35),
             (0.66, 1.7, 5.35)]

    def foliage(bm):
        for (r, h, z) in tiers:
            cone(bm, r, 0.06, h, z, 9,
                 rng.uniform(-0.14, 0.14), rng.uniform(-0.14, 0.14))
        jitter(bm, 0.13, rng)
    fol = bm_object("foliage", leaves, foliage)
    objs = [trunk, fol]
    if with_snow:
        snow = material("snow", (0.95, 0.96, 1.0))

        def caps(bm):
            for (r, h, z) in tiers:
                cone(bm, r * 0.9, 0.05, h * 0.35, z + h * 0.36, 9)
            jitter(bm, 0.09, rng)
        objs.append(bm_object("snowcaps", snow, caps))
    join_and_export(objs, "pine_snow" if with_snow else "pine")


def make_oak():
    reset()
    rng = random.Random(11)
    bark = material("bark", (0.3, 0.2, 0.13))
    leaves = material("leaves", (0.2, 0.36, 0.14))

    def wood(bm):
        cone(bm, 0.44, 0.24, 2.9, 1.45, 9)
        branch(bm, 0.15, 1.7, 2.5, 30, 38)
        branch(bm, 0.13, 1.5, 2.7, 160, 44)
        branch(bm, 0.12, 1.3, 2.3, 265, 50)
        jitter(bm, 0.04, rng, True)
    trunk = bm_object("trunk", bark, wood)

    def canopy(bm):
        sphere(bm, 1.55, 0.0, 0.0, 4.35, 1, 0.78)
        sphere(bm, 1.15, 1.25, 0.45, 3.75, 1, 0.8)
        sphere(bm, 1.05, -1.15, -0.5, 3.7, 1, 0.8)
        sphere(bm, 0.95, -0.15, 1.15, 3.85, 1, 0.82)
        sphere(bm, 0.9, 0.35, -1.2, 3.9, 1, 0.82)
        jitter(bm, 0.17, rng)
    fol = bm_object("foliage", leaves, canopy)
    join_and_export([trunk, fol], "oak")


def make_bare():
    reset()
    rng = random.Random(23)
    bark = material("bark", (0.32, 0.26, 0.2))

    def wood(bm):
        cone(bm, 0.30, 0.05, 4.4, 2.2, 8)
        branch(bm, 0.09, 1.7, 2.5, 20, 48)
        branch(bm, 0.08, 1.5, 3.0, 130, 55)
        branch(bm, 0.07, 1.3, 3.4, 240, 42)
        branch(bm, 0.06, 1.0, 3.8, 75, 60)
        branch(bm, 0.04, 0.8, 2.9, 300, 65)
        jitter(bm, 0.03, rng, True)
    trunk = bm_object("trunk", bark, wood)
    join_and_export([trunk], "bare")


def make_boulder():
    reset()
    rng = random.Random(31)
    rock = material("rock", (0.45, 0.44, 0.42))

    def build(bm):
        ret = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        for v in ret["verts"]:
            d = 1.0 + rng.uniform(-0.22, 0.24)
            v.co.x *= d
            v.co.y *= 1.0 + rng.uniform(-0.22, 0.24)
            v.co.z *= (1.0 + rng.uniform(-0.16, 0.16)) * 0.72
            if v.co.z < -0.45:
                v.co.z = -0.45
    b = bm_object("boulder", rock, build)
    join_and_export([b], "boulder")


make_pine(False)
make_pine(True)
make_oak()
make_bare()
make_boulder()
print("KIT DONE")
