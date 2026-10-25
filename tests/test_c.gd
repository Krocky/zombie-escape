extends SceneTree
var niveau; var f := 0; var h; var zr; var zl; var pvs := []
func _initialize():
	niveau = load("res://scenes/lieux/supermarche.tscn").instantiate()
	root.add_child(niveau)
	current_scene = niveau
func _touch(idx, pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = idx; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _physics_process(_d):
	f += 1
	var taille = root.get_visible_rect().size
	var bouton = taille - Vector2(130, 130)
	if f == 3:
		h = niveau.get_node("Monde/Heros"); zr = niveau.get_node("Monde/ZombieRapide"); zl = niveau.get_node("Monde/ZombieLent")
		h.pv_change.connect(func(p, m): pvs.append(p))
		h.position = zr.position + Vector2(-60, 0)
		zl.position = Vector2(300, 1400)  # loin
		h.get_node('Camera2D').reset_smoothing()
		_touch(0, Vector2(200, taille.y - 200), true)  # doigt sur joystick, tenu
	if f == 6: _touch(1, bouton, true)
	if f == 8:
		pass
	if f == 10:
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_c.png")
		_touch(1, bouton, false)
	if f == 50: _touch(1, bouton, true)
	if f == 58: _touch(1, bouton, false)
	if f == 84: _touch(1, bouton, true)  # 3e coup : le maigre a 3 PV depuis le lot 3 b
	if f == 92: _touch(1, bouton, false)
	if f == 100:
		print("zombie rapide battu: ", not is_instance_valid(zr) or zr._pv <= 0, " (OK si true)")
		_touch(0, Vector2(200, taille.y - 200), false)
		zl.position = h.position + Vector2(-100, 0)
	if f == 200: print("pv apres contact zombie lent: ", pvs)
	if f == 400: print("zombie rapide enleve apres le son: ", not is_instance_valid(zr))
	if f == 700: print("pv: ", pvs, " scene rechargee: ", not is_instance_valid(niveau), " nouvelle scene: ", current_scene != null); quit()
	return false
