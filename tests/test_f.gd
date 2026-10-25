extends SceneTree
var niveau; var f := 0; var h; var zl
func _initialize():
	niveau = load("res://scenes/lieux/supermarche.tscn").instantiate()
	root.add_child(niveau); current_scene = niveau
func _touch(idx, pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = idx; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _drag(idx, pos):
	var e = InputEventScreenDrag.new(); e.index = idx; e.position = pos
	Input.parse_input_event(e)
func _physics_process(_d):
	f += 1
	var taille = root.get_visible_rect().size
	if f == 3:
		h = niveau.get_node("Monde/Heros"); zl = niveau.get_node("Monde/ZombieLent")
		zl.patrouille = Vector2.ZERO; zl.position = Vector2(1150, 760); zl._depart = zl.position; zl._regard = Vector2.LEFT
		h.position = Vector2(700, 760); h.get_node("Camera2D").reset_smoothing()
		_touch(0, Vector2(200, taille.y - 200), true)
	if f == 5:
		# Vue isométrique : pousser le joystick dans la direction écran du « vers la droite » du monde
		var d = root.get_node("Iso").ecran(Vector2(1, 0)).normalized() * 100.0
		_drag(0, Vector2(200, taille.y - 200) + d)
	if f == 30:
		print("zombie etat: ", zl._etat, " cri joue: ", zl.get_node("Cri").playing)
		_touch(0, Vector2(200, taille.y - 200), false)
	if f == 40: root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_f.png")
	if f == 41: quit()
	return false
