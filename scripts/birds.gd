class_name Birds
extends Node3D
## Ambient birds that commute between the great-tree nests. Purely visual —
## no collision, no interaction — but a sharp-eyed seeker can follow one
## through the air and let it lead them to a nest.

const SPEED := 7.5
const FLAP_RATE := 22.0  ## wing-beat angular speed, rad/s

var terrain: Terrain = null
var perches: Array = []        ## Vector3 nest-top perch points
var _flock: Array = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0


static func build(parent: Node3D, terr: Terrain, wrng: RandomNumberGenerator,
		nest_tops: Array) -> Birds:
	var b := Birds.new()
	b.name = "Birds"
	b.terrain = terr
	b.perches = nest_tops
	b._rng.seed = wrng.randi()
	parent.add_child(b)
	b._spawn(3 + b._rng.randi_range(0, 2))
	return b


func _spawn(count: int) -> void:
	var feather := TexF.plain(Color(0.16, 0.13, 0.11))
	var breast := TexF.plain(Color(0.58, 0.44, 0.3))
	for i in count:
		var n := Node3D.new()
		add_child(n)
		# Body lies along -Z (forward), head at the front.
		var body := CapsuleMesh.new()
		body.radius = 0.09
		body.height = 0.5
		body.material = feather
		Util.mesh(n, body, Vector3.ZERO, Vector3(90, 0, 0))
		var chest := SphereMesh.new()
		chest.radius = 0.08
		chest.height = 0.16
		chest.material = breast
		Util.mesh(n, chest, Vector3(0, -0.04, -0.08))
		var head := SphereMesh.new()
		head.radius = 0.07
		head.height = 0.14
		head.material = feather
		Util.mesh(n, head, Vector3(0, 0.05, -0.26))
		var tail := PrismMesh.new()
		tail.size = Vector3(0.16, 0.03, 0.22)
		tail.material = feather
		Util.mesh(n, tail, Vector3(0, 0.0, 0.3))
		# Wings pivot at the shoulder so they flap.
		var wing := BoxMesh.new()
		wing.size = Vector3(0.55, 0.02, 0.28)
		wing.material = feather
		var wl := Node3D.new()
		n.add_child(wl)
		Util.mesh(wl, wing, Vector3(-0.32, 0.03, 0))
		var wr := Node3D.new()
		n.add_child(wr)
		Util.mesh(wr, wing, Vector3(0.32, 0.03, 0))

		var at: Vector3 = perches[_rng.randi_range(0, perches.size() - 1)]
		var bd := {node = n, wl = wl, wr = wr, state = "perch", at = at,
			timer = _rng.randf_range(2.0, 14.0),
			from = at, ctrl = at, to = at, t = 0.0, dur = 1.0,
			phase = _rng.randf_range(0.0, TAU)}
		n.position = at + _perch_offset()
		n.rotation.y = _rng.randf_range(0.0, TAU)
		_flock.append(bd)


func _perch_offset() -> Vector3:
	return Vector3(_rng.randf_range(-0.5, 0.5), 0.2, _rng.randf_range(-0.5, 0.5))


func _launch(bd: Dictionary) -> void:
	# Fly to a different nest along an arcing, laterally-bowed path.
	var others: Array = []
	for p in perches:
		if p.distance_to(bd.at) > 1.0:
			others.append(p)
	if others.is_empty():
		bd.timer = 5.0
		return
	var dest: Vector3 = others[_rng.randi_range(0, others.size() - 1)]
	bd.from = bd.node.position
	bd.to = dest + _perch_offset()
	var mid: Vector3 = (bd.from + bd.to) * 0.5
	mid += Vector3(_rng.randf_range(-30.0, 30.0), _rng.randf_range(7.0, 16.0),
		_rng.randf_range(-30.0, 30.0))
	if terrain:
		mid.y = maxf(mid.y, terrain.height_at(mid.x, mid.z) + 9.0)
	bd.ctrl = mid
	bd.t = 0.0
	bd.dur = maxf(bd.from.distance_to(bd.ctrl) + bd.ctrl.distance_to(bd.to), 20.0) / SPEED
	bd.at = dest
	bd.state = "fly"


func _process(delta: float) -> void:
	_time += delta
	for bd in _flock:
		if bd.state == "perch":
			# Folded wings, the odd idle shuffle.
			bd.wl.rotation.z = 0.95
			bd.wr.rotation.z = -0.95
			bd.timer -= delta
			if bd.timer <= 0.0:
				_launch(bd)
			continue
		# Quadratic bezier flight with a wing-beat bob.
		bd.t = minf(bd.t + delta / bd.dur, 1.0)
		var t: float = bd.t
		var u := 1.0 - t
		var pos: Vector3 = bd.from * (u * u) + bd.ctrl * (2.0 * u * t) + bd.to * (t * t)
		pos.y += sin(_time * 3.0 + bd.phase) * 0.15
		if terrain:
			pos.y = maxf(pos.y, terrain.height_at(pos.x, pos.z) + 2.0)
		var dirv: Vector3 = (bd.ctrl - bd.from) * (2.0 * u) + (bd.to - bd.ctrl) * (2.0 * t)
		bd.node.position = pos
		if dirv.length() > 0.01:
			bd.node.basis = Basis.looking_at(dirv.normalized(), Vector3.UP)
		var flap := sin(_time * FLAP_RATE + bd.phase) * 0.75
		bd.wl.rotation.z = flap
		bd.wr.rotation.z = -flap
		if bd.t >= 1.0:
			bd.state = "perch"
			bd.timer = _rng.randf_range(4.0, 18.0)
			bd.node.position = bd.to
			bd.node.rotation = Vector3(0, _rng.randf_range(0.0, TAU), 0)
