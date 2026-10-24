extends SceneTree

var niveau
var depart
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

func _process(_d):
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
		var p = h.position
		await physics_frame; await physics_frame
		print("arret: ", h.position == p)
		print("OK" if (h.position - depart).x > 50 and (h.position - depart).y < -20 else "ECHEC")
		quit()
	return false
