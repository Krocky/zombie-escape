extends SceneTree
var f := 0
func _initialize():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sauvegarde.json"))
	root.get_node("Partie").inventaire = {}
	root.get_node("Partie").skin = "heros"   # héros déjà choisi : Jouer mène à la base
	change_scene_to_file("res://scenes/titre.tscn")
func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_e_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
## Carte : toucher le supermarché puis « Y aller » (g = pas depuis l'arrivée sur la carte)
func _carte(g):
	if g == 0:
		print("scene: ", current_scene.name)
		_touch(current_scene._place("supermarche"), true)
	if g == 6: _touch(Vector2.ZERO, false)
	if g == 12: _touch(_centre(current_scene.get_node("Fiche/YAller")), true)
	if g == 18: _touch(Vector2.ZERO, false)
func _physics_process(_d):
	f += 1
	if f == 20:
		_snap("titre")
		_touch(_centre(current_scene.get_node("Centre/Colonne/Jouer")), true)
	if f == 28: _touch(Vector2.ZERO, false)
	if f == 34:
		print("scene: ", current_scene.name)
		_touch(_centre(current_scene.get_node("Partir")), true)
	if f == 40: _touch(Vector2.ZERO, false)
	if f >= 50 and f < 70: _carte(f - 50)
	if f == 80:
		print("scene: ", current_scene.name)
		var h = current_scene.get_node("Monde/Heros")
		for z in get_nodes_in_group("zombies"): z.position = Vector2(2300, 1550); z._depart = z.position; z.patrouille = Vector2.ZERO
		h.position = current_scene.get_node("Monde/ObjetFiole").position
	if f == 85: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/ObjetEau").position
	if f == 90: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/ObjetPiles").position
	if f == 92: _snap("hud"); print("hud: ", current_scene.get_node("HUD/CompteurObjets").text)
	if f == 95: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/Sortie").position + Vector2(0, 30)
	if f == 150:
		print("scene: ", current_scene.name, " resultat: ", root.get_node("Partie").resultat)
		_snap("victoire")
		_touch(_centre(current_scene.get_node("RetourBase")), true)
	if f == 158: _touch(Vector2.ZERO, false)
	if f == 162:
		print("scene: ", current_scene.name)
		_touch(_centre(current_scene.get_node("Partir")), true)
	if f == 168: _touch(Vector2.ZERO, false)
	if f >= 180 and f < 200: _carte(f - 180)
	if f == 210:
		print("scene: ", current_scene.name)
		var h = current_scene.get_node("Monde/Heros")
		h.position = current_scene.get_node("Monde/ObjetBandage").position
	if f == 215: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/ObjetConserve").position
	if f == 217: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/ObjetEau").position
	if f == 220:
		var h = current_scene.get_node("Monde/Heros")
		h._pv = 1; h.recevoir_degats(1, h.position + Vector2(10, 0))
	if f == 370:
		print("scene: ", current_scene.name, " resultat: ", root.get_node("Partie").resultat)
		print("sauvegarde: ", FileAccess.get_file_as_string("user://sauvegarde.json"))
		_snap("defaite")
		quit()
	return false
