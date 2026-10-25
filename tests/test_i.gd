extends SceneTree
## Lot 2 (b) : constructions de la base. Cartes (Construire actif seulement si assez d'objets, Construit),
## objets retirés, sauvegarde, effets dans le niveau (cœurs, dégâts de la batte, portée de la lampe).
var f := 0
var partie
var zombie
var pv_zombie := 0
func _initialize():
	partie = root.get_node("Partie")
	partie.inventaire = {"conserve": 3, "eau": 1, "piles": 3, "fiole": 1}
	partie.constructions = []
	partie.sauvegarder()
	change_scene_to_file("res://scenes/base.tscn")
func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_i_%s.png" % n)
func _carte(nom):
	for c in current_scene.get_node("Constructions").get_children():
		if c.construction == nom: return c
func _etat():
	var t := []
	for c in current_scene.get_node("Constructions").get_children():
		var b = c.get_node("Bouton")
		t.append("%s: '%s' actif=%s" % [c.construction, b.texte, b.actif])
	return ", ".join(t)
func _appuyer(nom): _touch(_carte(nom).get_node("Bouton").get_global_rect().get_center(), true)
## Carte : toucher le supermarché puis « Y aller » (g = pas depuis l'arrivée sur la carte)
func _vers_supermarche(g):
	if g == 0: _touch(current_scene._place("supermarche"), true)
	if g == 6: _touch(Vector2.ZERO, false)
	if g == 12: _touch(current_scene.get_node("Fiche/YAller").get_global_rect().get_center(), true)
	if g == 18: _touch(Vector2.ZERO, false)
func _physics_process(_d):
	f += 1
	if f == 20:
		print("avant: ", _etat(), " (attendu les 3 actifs)")
		var ecran = current_scene.get_viewport_rect()
		for c in current_scene.get_node("Constructions").get_children():
			var b = c.get_node("Bouton")
			print("carte ", c.construction, " ", c.size, " dans l'ecran: ", ecran.encloses(c.get_global_rect()),
				" bouton >= 100 px: ", b.size.y >= 100 and b.size.x >= 100)
		_snap("avant")
		_appuyer("barricade")
	if f == 26: _touch(Vector2.ZERO, false)
	if f == 34: _appuyer("atelier")
	if f == 40: _touch(Vector2.ZERO, false)
	if f == 48:
		print("apres 2 constructions: ", _etat(), " (attendu barricade et atelier 'Construit' inactifs, lampe inactive)")
		print("inventaire: ", partie.inventaire, " (attendu conserve 0, eau 0, piles 1, fiole 1)")
		_appuyer("lampe")
	if f == 54: _touch(Vector2.ZERO, false)
	if f == 62:
		print("lampe sans assez de piles: construite=", partie.est_construit("lampe"), " (attendu false)")
		_snap("apres")
		partie.constructions = []; partie.inventaire = {}
		partie.charger()
		print("sauvegarde relue: constructions ", partie.constructions, " inventaire ", partie.inventaire)
		_touch(current_scene.get_node("Partir").get_global_rect().get_center(), true)
	if f == 68: _touch(Vector2.ZERO, false)
	if f >= 74 and f < 94: _vers_supermarche(f - 74)
	if f == 104:
		print("scene: ", current_scene.name, " (attendu Supermarche)")
		var h = current_scene.get_node("Monde/Heros")
		print("coeurs: ", h._pv, "/", h._pv_max, " (attendu ", Reglages.HEROS_PV + Reglages.BARRICADE_COEURS, ")")
		print("lampe: portee ", partie.portee_lampe(), " (attendu ", Reglages.LAMPE_PORTEE, " sans lampe renforcee)")
		for z in get_nodes_in_group("zombies"): z.position = Vector2(2300, 1550); z._depart = z.position; z.patrouille = Vector2.ZERO
		zombie = get_nodes_in_group("zombies")[0]
		zombie.position = h.position + h._regard * 50.0; zombie._depart = zombie.position
		pv_zombie = zombie._pv
		h.attaquer()
	if f == 108:
		print("coup de batte: zombie ", pv_zombie, " -> ", zombie._pv, " PV (attendu -", Reglages.ATTAQUE_DEGATS + Reglages.ATELIER_DEGATS, ")")
		_snap("niveau")
		partie.constructions.append("lampe")
		print("portee avec lampe renforcee: ", partie.portee_lampe(), " (attendu ", Reglages.LAMPE_PORTEE * (1 + Reglages.LAMPE_RENFORCEE_PORTEE / 100.0), ")")
		change_scene_to_file("res://scenes/lieux/supermarche.tscn")
	if f == 124:
		var h = current_scene.get_node("Monde/Heros")
		var lampe = null
		for n in h._vue.get_children(): if n.name == "Lampe": lampe = n
		print("faisceau: texture_scale ", lampe.texture_scale, " (attendu ", partie.portee_lampe() * root.get_node("Iso").K / 256.0, ")")
		_snap("niveau_lampe")
		change_scene_to_file("res://scenes/base.tscn")
	if f == 139:
		print("base, 3 constructions: ", _etat())
		_snap("base_complete")
		# Ne pas laisser de constructions aux autres tests
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sauvegarde.json"))
		partie.constructions = []; partie.inventaire = {}
		quit()
	return false
