class_name Util
## Small helpers for building geometry in code.


## Adds a BoxMesh child at a local position. If `collide` is true and `parent`
## is a CollisionObject3D, a matching BoxShape3D is added to it as well.
static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		collide := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	if collide and parent is CollisionObject3D:
		shape_box(parent, size, pos, rot)
	return mi


static func cyl(parent: Node3D, r_top: float, r_bottom: float, height: float,
		pos: Vector3, mat: Material, rot := Vector3.ZERO, rseg := 20) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = height
	cm.radial_segments = rseg
	cm.material = mat
	return mesh(parent, cm, pos, rot)


static func mesh(parent: Node3D, m: Mesh, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func shape_box(body: CollisionObject3D, size: Vector3, pos: Vector3,
		rot := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation_degrees = rot
	body.add_child(cs)
	return cs


static func shape_cyl(body: CollisionObject3D, radius: float, height: float,
		pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)
	return cs
