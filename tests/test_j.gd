extends SceneTree
## Lot 2 (c) : la carte. Base -> Partir -> Carte ; la Maison (disponible depuis l'étape d) ouvre sa fiche ; le supermarché
## ouvre sa fiche (3 zombies, 5 objets) ; toucher ailleurs la ferme ; « Y aller » lance le supermarché
## (lieu retenu par Partie) ; « Retour » ramène à la base.
var f := 0
var partie
func _initialize():
	partie = root.get_node("Partie")
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.lieu = ""
	change_scene_to_file("res://scenes/base.tscn")
func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_j_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
func _physics_process(_d):
	f += 1
	if f == 20: _touch(_centre(current_scene.get_node("Interface/Start")), true)
	if f == 26: _touch(Vector2.ZERO, false)
	if f == 40:
		print("scene: ", current_scene.name, " (attendu Carte)")
		var ecran = current_scene.get_viewport_rect()
		var r = current_scene.get_node("Retour")
		print("bouton Retour: ", r.size, " >= 100 px: ", r.size.y >= 100 and r.size.x >= 100, " dans l'ecran: ", ecran.encloses(r.get_global_rect()))
		for id in partie.LIEUX:
			print("lieu ", id, " a l'ecran: ", ecran.has_point(current_scene._place(id)), " disponible: ", partie.lieu_disponible(id))
		print("fiche cachee au depart: ", not current_scene.get_node("Fiche").visible)
		_snap("carte")
		_touch(current_scene._place("maison"), true)
	if f == 46: _touch(Vector2.ZERO, false)
	if f == 52:
		print("maison touchee: fiche visible=", current_scene.get_node("Fiche").visible, " (attendu true, maison disponible)")
		_touch(current_scene._place("supermarche"), true)
	if f == 58: _touch(Vector2.ZERO, false)
	if f == 64:
		var fiche = current_scene.get_node("Fiche")
		var ecran = current_scene.get_viewport_rect()
		var b = fiche.get_node("YAller")
		print("supermarche touche: fiche visible=", fiche.visible, " (attendu true) dans l'ecran: ", ecran.encloses(fiche.get_global_rect()))
		print("bouton Y aller: ", b.size, " >= 100 px: ", b.size.y >= 100 and b.size.x >= 100)
		var cache := false
		for id in ["base"] + partie.LIEUX.keys():
			if fiche.get_global_rect().has_point(current_scene._place(id)): cache = true
		print("fiche cache un lieu: ", cache, " (attendu false)")
		print("infos: ", partie.infos_lieu("supermarche"), " (attendu 3 zombies [0, 1, 2], 5 objets)")
		_snap("fiche")
		_touch(Vector2(current_scene.size.x / 2.0, 130), true)
	if f == 70: _touch(Vector2.ZERO, false)
	if f == 76:
		print("toucher ailleurs: fiche visible=", current_scene.get_node("Fiche").visible, " (attendu false)")
		_touch(current_scene._place("supermarche"), true)
	if f == 82: _touch(Vector2.ZERO, false)
	if f == 88: _touch(_centre(current_scene.get_node("Fiche/YAller")), true)
	if f == 94: _touch(Vector2.ZERO, false)
	if f == 110:
		print("scene: ", current_scene.name, " (attendu Supermarche) lieu retenu: ", partie.lieu)
		var h = current_scene.get_node("Monde/Heros")
		print("heros: ", h.position, " (attendu (1200, 1450)) zombies: ", get_nodes_in_group("zombies").size(),
			" objets: ", get_nodes_in_group("objets").size(), " cachettes: ", get_nodes_in_group("cachettes").size(),
			" sortie: ", current_scene.has_node("Monde/Sortie"), " taille: ", current_scene.taille,
			" brume: ", current_scene.get_node("BrumeSol").position, " ", current_scene.get_node("BrumeSol").taille)
		_snap("supermarche")
		change_scene_to_file("res://scenes/carte.tscn")
	if f == 125: _touch(_centre(current_scene.get_node("Retour")), true)
	if f == 131: _touch(Vector2.ZERO, false)
	if f == 140:
		print("Retour: scene ", current_scene.name, " (attendu Base)")
		quit()
	return false
