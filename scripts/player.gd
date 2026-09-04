class_name Player
extends CharacterBody3D
## Third-person character with WoW-style mouse controls:
## free cursor; left-drag orbits the camera, right-drag steers the character,
## both buttons run forward; wheel zooms; left-click targets, right-click
## interacts within range; E interacts with the current target.

const WALK_SPEED := 5.2
const SPRINT_SPEED := 8.8
const BACKPEDAL_FACTOR := 0.6
const JUMP_VEL := 5.4
const GRAVITY := 14.0
const MOUSE_SENS := 0.22
const INTERACT_RANGE := 4.0
const CAM_FOLLOW_RATE := 2.5
const DRAG_THRESHOLD := 6.0
const BASE_FOV := 72.0
const SPY_FOV := 16.0
const SPY_RANGE := 300.0
const DISCOVER_RANGE := 22.0
const SPY_AIM_DEG := 2.3      ## how tightly a node must be centered to log it
const SPRINT_SECONDS := 5.5   ## full-to-empty sprint time
const STAMINA_REGEN := 3.5    ## empty-to-full seconds (after a short delay)
const CLIMB_SPEED := 3.2
const TURN_SPEED := 2.6       ## keyboard turn rate, rad/s (~150°/s)

var hud: Hud = null
var main: Node = null
var zoom_target := 4.3
var yaw_node: Node3D
var pitch_node: Node3D
var arm: SpringArm3D
var cam: Camera3D
var body_vis: Node3D
var target: Interactable = null

var facing := 0.0
var cam_yaw := 0.0
var dist_walked := 0.0
var stamina := 1.0
var climbing := false
var crouched := false
var autorun := false
var _stamina_locked := false
var _lock_until_ms := 0
var _regen_delay := 0.0
var _last_walk_pos := Vector2.ZERO
var _cshape: CollisionShape3D
var _lmb := false
var _rmb := false
var _dragging := false
var _press_accum := 0.0
var _saved_cursor := Vector2.ZERO


func _init() -> void:
	name = "Player"
	collision_layer = 1
	collision_mask = 3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	_cshape = cs
	_build_visual()
	yaw_node = Node3D.new()
	yaw_node.position = Vector3(0, 1.55, 0)
	add_child(yaw_node)
	pitch_node = Node3D.new()
	pitch_node.rotation_degrees.x = -14
	yaw_node.add_child(pitch_node)
	arm = SpringArm3D.new()
	arm.spring_length = 4.3
	arm.margin = 0.3
	arm.collision_mask = 1
	pitch_node.add_child(arm)
	cam = Camera3D.new()
	cam.far = 900.0
	cam.fov = 72.0
	arm.add_child(cam)


func _ready() -> void:
	arm.add_excluded_object(get_rid())
	cam.current = true


func _build_visual() -> void:
	body_vis = Node3D.new()
	body_vis.rotation.y = PI
	add_child(body_vis)
	var shirt := TexF.plain(Color(0.2, 0.35, 0.6))
	var pants := TexF.plain(Color(0.35, 0.26, 0.18))
	var skin := TexF.plain(Color(0.9, 0.72, 0.58))
	var torso := CapsuleMesh.new()
	torso.radius = 0.26
	torso.height = 0.95
	torso.material = shirt
	Util.mesh(body_vis, torso, Vector3(0, 1.02, 0))
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	head.material = skin
	Util.mesh(body_vis, head, Vector3(0, 1.62, 0))
	var hat := CylinderMesh.new()
	hat.top_radius = 0.16
	hat.bottom_radius = 0.19
	hat.height = 0.1
	hat.material = TexF.plain(Color(0.65, 0.2, 0.15))
	Util.mesh(body_vis, hat, Vector3(0, 1.76, 0))
	var arm_m := CapsuleMesh.new()
	arm_m.radius = 0.09
	arm_m.height = 0.62
	arm_m.material = shirt
	Util.mesh(body_vis, arm_m, Vector3(-0.36, 1.08, 0))
	Util.mesh(body_vis, arm_m, Vector3(0.36, 1.08, 0))
	var leg := BoxMesh.new()
	leg.size = Vector3(0.15, 0.62, 0.18)
	leg.material = pants
	Util.mesh(body_vis, leg, Vector3(-0.11, 0.31, 0))
	Util.mesh(body_vis, leg, Vector3(0.11, 0.31, 0))
	var eye := SphereMesh.new()
	eye.radius = 0.028
	eye.height = 0.056
	eye.material = TexF.plain(Color(0.08, 0.08, 0.1))
	Util.mesh(body_vis, eye, Vector3(-0.06, 1.65, 0.145))
	Util.mesh(body_vis, eye, Vector3(0.06, 1.65, 0.145))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_spot"):
		if main:
			main.cycle_spot()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_map"):
		if hud:
			hud.toggle_big_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_pad"):
		if hud:
			hud.toggle_big_pad()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("crouch"):
		set_crouch(not crouched)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("autorun"):
		autorun = not autorun
		if hud:
			hud.toast("Autorun on." if autorun else "Autorun off.")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_mouse_button(event, true)
			MOUSE_BUTTON_RIGHT:
				_mouse_button(event, false)
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_target = clampf(zoom_target - 0.7, 1.4, 11.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom_target = clampf(zoom_target + 0.7, 1.4, 11.0)
	elif event is InputEventMouseMotion:
		_mouse_motion(event)


func _mouse_button(e: InputEventMouseButton, is_left: bool) -> void:
	if e.pressed:
		if not _lmb and not _rmb:
			_saved_cursor = get_viewport().get_mouse_position()
			_press_accum = 0.0
		if is_left:
			_lmb = true
		else:
			_rmb = true
			if _dragging:
				facing = cam_yaw
	else:
		if is_left:
			_lmb = false
		else:
			_rmb = false
		if not _lmb and not _rmb:
			if _dragging:
				_dragging = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_viewport().warp_mouse(_saved_cursor)
			else:
				_click(is_left, e.position)


func _mouse_motion(e: InputEventMouseMotion) -> void:
	if not (_lmb or _rmb):
		return
	if not _dragging:
		_press_accum += e.relative.length()
		if _press_accum > DRAG_THRESHOLD:
			_dragging = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _dragging:
		# Sensitivity scales with FOV so the spyglass aims steadily.
		var sens := MOUSE_SENS * (cam.fov / BASE_FOV)
		pitch_node.rotation_degrees.x = clampf(
			pitch_node.rotation_degrees.x + e.relative.y * sens, -75.0, 55.0)
		cam_yaw -= deg_to_rad(e.relative.x * sens)
		if _rmb:
			facing = cam_yaw


func _click(is_left: bool, pos: Vector2) -> void:
	var s := _pick(pos)
	if is_left:
		set_target(s)
	elif s:
		set_target(s)
		try_interact(s)


func _pick(pos: Vector2) -> Interactable:
	var origin := cam.project_ray_origin(pos)
	var dirn := cam.project_ray_normal(pos)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dirn * 120.0, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.collider is Interactable:
		return hit.collider
	return null


## Instantly snap character facing and camera together (used on spawn).
func set_facing(f: float) -> void:
	facing = f
	cam_yaw = f
	yaw_node.rotation.y = f
	body_vis.rotation.y = f + PI


## Crouch toggle: a shrunken profile at half speed, for cellar mouths,
## crawlspaces, and other tight places. Standing back up needs headroom.
func set_crouch(on: bool) -> void:
	if crouched == on:
		return
	if not on and _headroom_blocked():
		if hud:
			hud.toast("Not enough room to stand here.")
		return
	crouched = on
	var cap: CapsuleShape3D = _cshape.shape
	cap.height = 1.05 if on else 1.75
	_cshape.position.y = 0.55 if on else 0.9
	body_vis.scale.y = 0.62 if on else 1.0
	yaw_node.position.y = 1.0 if on else 1.55


func _headroom_blocked() -> bool:
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.6, 0),
		global_position + Vector3(0, 1.95, 0), 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Abort any in-progress mouse drag (used when the menu opens mid-drag).
func release_drag() -> void:
	_lmb = false
	_rmb = false
	if _dragging:
		_dragging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_target(s: Interactable) -> void:
	if target and is_instance_valid(target):
		target.set_selected(false)
	target = s
	if target:
		target.set_selected(true)
	elif hud:
		hud.hide_target()


func try_interact(s: Interactable) -> void:
	if s.opened:
		if hud:
			hud.toast("The %s has already been searched." % s.display_name)
	elif global_position.distance_to(s.global_position) > INTERACT_RANGE:
		if hud:
			hud.toast("Out of range — get closer.")
	else:
		s.interact()


func _physics_process(delta: float) -> void:
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _lmb and _rmb:
		iv.y = -1.0
	# Autorun (` toggles): keep walking forward; backpedal input cancels it.
	if autorun:
		if iv.y > 0.1:
			autorun = false
		else:
			iv.y = -1.0

	# Climbing irons: near a great tree, W climbs, S descends.
	var climb := _near_climbable()
	climbing = false
	if not climb.is_empty() and main.tools.irons:
		var to_axis := Vector3(climb.axis.x - global_position.x, 0.0,
			climb.axis.z - global_position.z)
		if iv.y < -0.1 and global_position.y < climb.top_y + 0.35:
			climbing = true
			if global_position.y >= climb.top_y - 0.15:
				# Crest the top: glide onto the platform.
				velocity = to_axis.normalized() * 2.6 + Vector3(0, 1.6, 0)
			else:
				velocity = Vector3(0, CLIMB_SPEED, 0) + to_axis.normalized() * 0.8
		elif iv.y > 0.1 and not is_on_floor() and global_position.y < climb.top_y + 0.35:
			climbing = true
			velocity = Vector3(0, -2.6, 0)
		if climbing:
			body_vis.rotation.y = lerp_angle(body_vis.rotation.y,
				atan2(to_axis.x, to_axis.z), minf(1.0, 12.0 * delta))

	# Arrow keys: keyboard turning — character and camera swing together.
	var turn := Input.get_axis("turn_right", "turn_left")
	if turn != 0.0 and not climbing:
		facing += turn * TURN_SPEED * delta
		cam_yaw += turn * TURN_SPEED * delta

	# Sprint stamina: Shift drains the meter; it refills after a pause.
	# Coffee suspends the whole economy for its duration.
	var caffeinated: bool = main != null and main.coffee_active()
	var moving := iv.length() > 0.05
	var sprinting := Input.is_action_pressed("sprint") and moving and not climbing \
		and (caffeinated or (stamina > 0.0 and not _stamina_locked))
	if sprinting and not caffeinated:
		stamina = maxf(stamina - delta / SPRINT_SECONDS, 0.0)
		_regen_delay = 1.0
		if stamina <= 0.0 and not _stamina_locked:
			# Full depletion: one-minute penalty before sprinting again.
			_stamina_locked = true
			_lock_until_ms = Time.get_ticks_msec() + 60000
			if hud:
				hud.toast("Winded! Sprint needs a minute to recover.")
	else:
		_regen_delay -= delta
		if _regen_delay <= 0.0:
			stamina = minf(stamina + delta / STAMINA_REGEN, 1.0)
	if _stamina_locked and Time.get_ticks_msec() >= _lock_until_ms:
		_stamina_locked = false
	if hud:
		var lock_left := 0.0
		if _stamina_locked:
			lock_left = maxf(0.0, (_lock_until_ms - Time.get_ticks_msec()) / 1000.0)
		hud.set_stamina(stamina, _stamina_locked, lock_left)

	if not climbing:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VEL
		var dir := Basis(Vector3.UP, facing) * Vector3(iv.x, 0, iv.y)
		dir.y = 0.0
		if dir.length() > 1.0:
			dir = dir.normalized()
		var sp := SPRINT_SPEED if sprinting else WALK_SPEED
		if iv.y > 0.0:
			sp *= BACKPEDAL_FACTOR
		if crouched:
			sp *= 0.5
		# Frozen ponds barely grip: acceleration and braking crawl, so
		# momentum carries you sliding across the ice.
		var icy: bool = is_on_floor() and main != null and main.on_ice(global_position)
		var accel := 1.6 if icy else 10.0
		velocity.x = lerpf(velocity.x, dir.x * sp, minf(1.0, accel * delta))
		velocity.z = lerpf(velocity.z, dir.z * sp, minf(1.0, accel * delta))
	move_and_slide()
	var wp := Vector2(global_position.x, global_position.z)
	var step := wp.distance_to(_last_walk_pos)
	if step < 5.0:
		dist_walked += step
	_last_walk_pos = wp

	if not climbing:
		body_vis.rotation.y = lerp_angle(body_vis.rotation.y, facing + PI, minf(1.0, 14.0 * delta))

	# Camera swings back behind the character while moving (unless the
	# player is holding a left-drag orbit).
	if iv.length() > 0.05 and not (_dragging and _lmb and not _rmb):
		cam_yaw = lerp_angle(cam_yaw, facing, minf(1.0, CAM_FOLLOW_RATE * delta))
	yaw_node.rotation.y = cam_yaw

	# Spyglass: hold Z (once found) to zoom in and spot structures far away.
	var spy: bool = main != null and main.tools.spyglass \
		and Input.is_action_pressed("spyglass")
	cam.fov = lerpf(cam.fov, SPY_FOV if spy else BASE_FOV, minf(1.0, 10.0 * delta))
	arm.spring_length = lerpf(arm.spring_length,
		0.6 if spy else zoom_target, minf(1.0, 10.0 * delta))
	body_vis.visible = cam.fov > 40.0
	_update_discovery(spy)

	if hud:
		if target and is_instance_valid(target):
			var d := global_position.distance_to(target.global_position)
			hud.update_target(target.display_name, d, d <= INTERACT_RANGE, target.opened)
		else:
			hud.hide_target()
		if not _dragging:
			var mp := get_viewport().get_mouse_position()
			var hs := _pick(mp)
			hud.set_hover(hs.display_name if hs else "", mp)
		else:
			hud.set_hover("", Vector2.ZERO)

	# Climb hint when standing at a great tree.
	if hud and not climb.is_empty() and is_on_floor() and hud.prompt.text.is_empty():
		if main.tools.irons:
			hud.prompt.text = "Hold W against the trunk to climb"
		else:
			hud.prompt.text = "These heights need climbing irons"

	if Input.is_action_just_pressed("interact") and target and is_instance_valid(target):
		try_interact(target)


func _near_climbable() -> Dictionary:
	if main == null:
		return {}
	for c in main.climbables:
		var d := Vector2(global_position.x - c.axis.x, global_position.z - c.axis.z).length()
		if d < 2.2 and global_position.y < c.top_y + 1.0:
			return c
	return {}


## Marks nearby structures as discovered; while the spyglass is raised, also
## marks and labels any unsearched structure with a clear line of sight.
func _update_discovery(spy: bool) -> void:
	if main == null:
		return
	# Pencil + a writing surface (map or notepad): ink the path as we walk.
	if main.can_note_spots():
		main.record_trail(Vector2(global_position.x, global_position.z))

	var spots: Array = []
	var space := get_world_3d().direct_space_state
	for s in main.structures:
		if not is_instance_valid(s):
			continue
		var d := global_position.distance_to(s.global_position)
		if d < DISCOVER_RANGE:
			s.seen = true
			# Marks are only made in the moment: a node lands on the map when
			# you see it WHILE holding the pencil and a writing surface —
			# nodes seen earlier must be sighted again to be inked.
			if main.can_note_spots():
				s.noted = true
		if spy and not s.opened and d > 12.0 and d < SPY_RANGE:
			var p3: Vector3 = s.global_position + Vector3.UP * 1.2
			if cam.is_position_behind(p3):
				continue
			var q := PhysicsRayQueryParameters3D.create(
				cam.global_position, p3, 1, [get_rid(), s.get_rid()])
			if space.intersect_ray(q):
				continue
			s.seen = true
			if main.can_note_spots():
				s.noted = true
			# Logging a spot requires actually aiming the scope at it.
			var aim := (p3 - cam.global_position).normalized()
			var centered := (-cam.global_basis.z).dot(aim) > cos(deg_to_rad(SPY_AIM_DEG))
			if centered and main.can_note_spots():
				main.add_spot(s)
			spots.append({pos = p3, centered = centered,
				text = "%s · %d m" % [s.display_name, int(d)]})
	if hud:
		hud.set_spy(spy, spots)
		var entries: Array = []
		for i in main.spotted.size():
			var sp: Interactable = main.spotted[i]
			entries.append({name = sp.display_name,
				dist = global_position.distance_to(sp.global_position),
				selected = i == main.spot_idx})
		hud.update_spots(entries)
