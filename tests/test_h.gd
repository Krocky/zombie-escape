extends SceneTree
## Lot 2 (a) : écran Base. Reprise d'une sauvegarde version 1, Titre -> Base -> Partir -> Carte -> Supermarché,
## Fin -> Retour à la base -> Base, sauvegarde réécrite en version 2.
var f := 0
var partie
func _initialize():
	partie = root.get_node("Partie")
	# Ancienne sauvegarde (lot 1, version 1)
	var fichier := FileAccess.open("user://sauvegarde.json", FileAccess.WRITE)
	fichier.store_string('{"version": 1, "inventaire": {"conserve": 3, "piles": 2, "fiole": 1}}')
	fichier.close()
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.charger()
	print("reprise v1: ", partie.inventaire, " constructions: ", partie.constructions)
	print("reecrite: ", FileAccess.get_file_as_string("user://sauvegarde.json"))
	partie.skin = "heros"   # héros déjà choisi : Jouer mène à la base (écran de choix : test_m)
	partie.sauvegarder()
	change_scene_to_file("res://scenes/titre.tscn")
func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_h_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
## Carte : toucher le supermarché puis « Y aller » (g = pas depuis l'arrivée sur la carte)
func _carte(g):
	if g == 0: _touch(current_scene._place("supermarche"), true)
	if g == 6: _touch(Vector2.ZERO, false)
	if g == 12: _touch(_centre(current_scene.get_node("Fiche/YAller")), true)
	if g == 18: _touch(Vector2.ZERO, false)
func _physics_process(_d):
	f += 1
	if f == 10:
		_touch(_centre(current_scene.get_node("Centre/Colonne/Jouer")), true)
	if f == 16: _touch(Vector2.ZERO, false)
	if f == 30:
		print("scene: ", current_scene.name, " (attendu Base)")
		var b = current_scene.get_node("Partir")
		print("bouton Partir: ", b.size, " >= 100 px: ", b.size.y >= 100 and b.size.x >= 100,
			" dans l'ecran: ", current_scene.get_viewport_rect().encloses(b.get_global_rect()))
		_snap("base")
		_touch(_centre(b), true)
	if f == 36: _touch(Vector2.ZERO, false)
	if f >= 44 and f < 64: _carte(f - 44)
	if f == 74:
		print("scene: ", current_scene.name, " (attendu Supermarche)")
		var h = current_scene.get_node("Monde/Heros")
		for z in get_nodes_in_group("zombies"): z.position = Vector2(2300, 1550); z._depart = z.position; z.patrouille = Vector2.ZERO
		h.position = current_scene.get_node("Monde/ObjetEau").position
	if f == 79: current_scene.get_node("Monde/Heros").position = current_scene.get_node("Monde/Sortie").position + Vector2(0, 30)
	if f == 144:
		print("scene: ", current_scene.name, " (attendu Fin)")
		var b = current_scene.get_node("Centre/Colonne/RetourBase")
		print("bouton Retour: '", b.texte, "' ", b.size, " >= 100 px: ", b.size.y >= 100,
			" dans l'ecran: ", current_scene.get_viewport_rect().encloses(b.get_global_rect()))
		_snap("fin")
		_touch(_centre(b), true)
	if f == 150: _touch(Vector2.ZERO, false)
	if f == 164:
		print("scene: ", current_scene.name, " (attendu Base) inventaire: ", partie.inventaire)
		print("sauvegarde: ", FileAccess.get_file_as_string("user://sauvegarde.json"))
		_snap("base_retour")
		quit()
	return false
