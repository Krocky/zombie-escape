extends SceneTree
var f := 0
func _initialize():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sauvegarde.json"))
	root.get_node("Partie").inventaire = {}
	change_scene_to_file("res://scenes/titre.tscn")
func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_e_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
func _process(_d):
	f += 1
	if f == 20:
		_snap("titre")
		_touch(_centre(current_scene.get_node("Centre/Colonne/Jouer")), true)
	if f == 22: _touch(Vector2.ZERO, false)
	if f == 40:
		print("scene: ", current_scene.name)
		var h = current_scene.get_node("Monde/Heros")
		for z in get_nodes_in_group("zombies"): z.position = Vector2(2300, 1550); z._depart = z.position; z.patrouille = Vector2.ZERO
		h.position = current_scene.get_node("Monde/ObjetFiole").position
	if f == 45: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/ObjetEau").position
	if f == 50: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/ObjetPiles").position
	if f == 52: _snap("hud"); print("hud: ", current_scene.get_node("HUD/CompteurObjets").text)
	if f == 55: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/Sortie").position + Vector2(0, 30)
	if f == 120:
		print("scene: ", current_scene.name, " resultat: ", root.get_node("Partie").resultat)
		_snap("victoire")
		_touch(_centre(current_scene.get_node("Centre/Colonne/Rejouer")), true)
	if f == 122: _touch(Vector2.ZERO, false)
	if f == 140:
		print("scene: ", current_scene.name)
		var h = current_scene.get_node("Monde/Heros")
		h.position = current_scene.get_node("Monde/ObjetBandage").position
	if f == 145: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/ObjetConserve").position
	if f == 147: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/ObjetEau").position
	if f == 150:
		var h = current_scene.get_node("Monde/Heros")
		h._pv = 1; h.recevoir_degats(1, h.position + Vector2(10, 0))
	if f == 300:
		print("scene: ", current_scene.name, " resultat: ", root.get_node("Partie").resultat)
		print("sauvegarde: ", FileAccess.get_file_as_string("user://sauvegarde.json"))
		_snap("defaite")
		quit()
	return false
