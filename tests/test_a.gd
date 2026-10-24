extends SceneTree

var niveau
var depart
var depart_arret
var f := 0

func _initialize():
	niveau = load("res://scenes/niveau.tscn").instantiate()
	root.add_child(niveau)

func _touch(idx, pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = idx; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)

func _drag(idx, pos):
	var e = InputEventScreenDrag.new(); e.index = idx; e.position = pos
	Input.parse_input_event(e)

func _physics_process(_d):
	f += 1
	var h = niveau.get_node("Monde/Heros")
	if f == 5:
		depart = h.position
		_touch(0, Vector2(300, 500), true)
	if f == 7:
		_drag(0, Vector2(400, 440))
	if f == 60:
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_a.png")
		print("deplacement: ", h.position - depart)
		_touch(0, Vector2(400, 440), false)
	if f == 70:
		depart_arret = h.position
	if f == 78:
		print("arret: ", h.position == depart_arret)
		# Vue isométrique : le héros suit le doigt à l'écran (vers la droite et vers le haut)
		var ecran = root.get_node("Iso").ecran(h.position - depart)
		print("deplacement a l'ecran: ", ecran)
		print("OK" if ecran.x > 50 and ecran.y < -20 else "ECHEC")
		quit()
	return false
