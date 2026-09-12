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
from mathutils import Vector

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


def limb(bm, start, direction, length, r0, r1, segments=6):
    """A tapered limb from `start` along `direction`; returns its tip."""
    d = direction.normalized()
    ret = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=True, segments=segments,
        radius1=r0, radius2=r1, depth=length)
    rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d)
    for v in ret["verts"]:
        v.co.z += length * 0.5
        v.co.rotate(rot)
        v.co += start
    return start + d * length


def grow(bm, rng, start, direction, length, radius, depth, lift=0.3):
    """Recursive limb: a limb that forks into 2-3 thinner, shorter children
    which fork again, `depth` levels deep. Children leave part-way along the
    parent (never all from the tip) and curl upward by `lift`, so the result
    reads as a real tree rather than sticks in a pole."""
    tip_r = radius * (0.55 if depth > 0 else 0.15)
    segs = 6 if radius > 0.05 else 4
    end = limb(bm, start, direction, length, radius, tip_r, segs)
    if depth == 0:
        return
    d = direction.normalized()
    # a perpendicular frame around the parent axis for the fork directions
    up = Vector((0.0, 0.0, 1.0))
    side = d.cross(up)
    if side.length < 1e-3:
        side = Vector((1.0, 0.0, 0.0))
    side.normalize()
    side2 = d.cross(side).normalized()
    n = rng.choice([2, 2, 3])
    base_az = rng.uniform(0.0, math.tau)
    for i in range(n):
        # the first child carries on near the tip; the rest leave lower down
        t = rng.uniform(0.85, 1.0) if i == 0 else rng.uniform(0.45, 0.8)
        pos = start + (end - start) * t
        r_here = radius + (tip_r - radius) * t
        az = base_az + i * math.tau / n + rng.uniform(-0.5, 0.5)
        spread = math.radians(rng.uniform(18.0, 32.0) if i == 0
                              else rng.uniform(35.0, 60.0))
        cd = (d * math.cos(spread)
              + (side * math.cos(az) + side2 * math.sin(az)) * math.sin(spread))
        cd = (cd + up * lift).normalized()
        grow(bm, rng, pos, cd,
             length * rng.uniform(0.55, 0.75),
             r_here * rng.uniform(0.65, 0.85),
             depth - 1, lift * 0.8)


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
        # stout leaning trunk that splits into four spreading limbs, each
        # forking twice into the canopy; one low limb under it
        top = Vector((0.06, -0.04, 2.6))
        limb(bm, Vector((0.0, 0.0, -0.05)), top - Vector((0.0, 0.0, -0.05)),
             2.7, 0.46, 0.3, 9)
        for k, (az, tilt) in enumerate([(30, 48), (120, 55), (215, 50),
                                        (305, 58)]):
            a = math.radians(az + rng.uniform(-8, 8))
            tl = math.radians(tilt)
            d = Vector((math.cos(a) * math.sin(tl), math.sin(a) * math.sin(tl),
                        math.cos(tl)))
            grow(bm, rng, top + d * 0.05, d, 1.4 + 0.15 * (k % 2), 0.17, 2,
                 0.25)
        a = math.radians(170)
        tl = math.radians(68)
        d = Vector((math.cos(a) * math.sin(tl), math.sin(a) * math.sin(tl),
                    math.cos(tl)))
        grow(bm, rng, Vector((0.03, -0.02, 1.9)) + d * 0.12, d, 1.3, 0.11, 1,
             0.2)
        jitter(bm, 0.02, rng, True)
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
    """Dead tree: kinked trunk that forks into a crown of recursively
    branching limbs, plus two lower limbs. Trunk top stays at z=4.4 (the
    game's climb collider height); the crown carries the tree to ~7 m."""
    reset()
    rng = random.Random(23)
    bark = material("bark", (0.32, 0.26, 0.2))

    def wood(bm):
        # trunk in two slightly kinked pieces, top at 4.4
        knee = limb(bm, Vector((0.0, 0.0, -0.05)), Vector((0.02, -0.01, 1.0)),
                    2.5, 0.34, 0.24, 8)
        top = Vector((0.12, 0.08, 4.4))
        limb(bm, knee, top - knee, (top - knee).length + 0.03, 0.24, 0.15, 8)
        # crown: three main limbs forking three levels deep
        for k, (az, tilt) in enumerate([(15, 34), (140, 42), (255, 38)]):
            a = math.radians(az + rng.uniform(-10, 10))
            tl = math.radians(tilt)
            d = Vector((math.cos(a) * math.sin(tl), math.sin(a) * math.sin(tl),
                        math.cos(tl)))
            grow(bm, rng, top + d * 0.05, d, 1.5 + 0.2 * k, 0.13, 3, 0.35)
        # two lower limbs off the trunk, two levels deep
        for (az, tilt, z, ln) in [(80, 62, 2.4, 1.4), (300, 55, 3.3, 1.2)]:
            a = math.radians(az)
            tl = math.radians(tilt)
            d = Vector((math.cos(a) * math.sin(tl), math.sin(a) * math.sin(tl),
                        math.cos(tl)))
            base = Vector((0.04, 0.02, z)) + d * 0.1
            grow(bm, rng, base, d, ln, 0.09, 2, 0.3)
        jitter(bm, 0.015, rng, True)
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
