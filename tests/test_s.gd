extends SceneTree
## Écrans V3 : carte (bg_map défilable, vignettes, pharmacie qui ouvre sa fiche (« Bientôt » avant le lot 3 f1), fiche même mise en page),
## victoire (illustration sur ciel d'aube, étoiles, sac), défaite (plein écran, étiquette SORTIE, objets perdus).
## Captures garçon et fille. Efface la sauvegarde à la fin.
var f := 0
var partie
var FICHIER: String:   # sauvegarde de la partie en cours (lot 4 d)
	get:
		return root.get_node("Partie").fichier()


func _initialize():
	partie = root.get_node("Partie")
	_effacer()
	partie.skin = "heros"; partie.prenom = "Eliott"
	change_scene_to_file("res://scenes/carte.tscn")


func _effacer():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.rescapes = 0; partie.lieux_sauves = []; partie.batiments_vus = []


func _touch(pos, pressed, index := 0):
	var e = InputEventScreenTouch.new(); e.index = index; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _drag(pos, relatif):
	var e = InputEventScreenDrag.new(); e.index = 0; e.position = pos; e.relative = relatif
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_s_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
func _dans_ecran(n): return current_scene.get_viewport_rect().encloses(n.get_global_rect())


func _fin(skin, victoire, objets, rescape, intact):
	partie.skin = skin; partie.prenom = "Eliott" if skin == "heros" else "Léa"
	partie.choisir_lieu("supermarche")
	partie.terminer(victoire, objets, rescape, intact)
	print(skin, " victoire=", victoire, " etoiles: ", partie.etoiles(), " mission: ", partie.resultat["mission"],
		" perdus: ", partie.resultat["perdus"].size())
	change_scene_to_file("res://scenes/fin.tscn")


func _verifier_fin():
	var b = current_scene.get_node("RetourBase")
	print("  titre '", current_scene.get_node("Titre").text, "' bouton dans l'ecran: ", _dans_ecran(b), " taille: ", b.size,
		" titre dans l'ecran: ", _dans_ecran(current_scene.get_node("Titre")), " illustration: '", current_scene._illustration, "'")
	print("  resume: ", current_scene.get_node("Resume").text.replace("\n", " | "))


func _physics_process(_d):
	f += 1
	# --- Carte ---
	if f == 40:
		var c = current_scene
		var ecran = c.get_viewport_rect()
		for id in ["base"] + partie.LIEUX.keys():
			print("lieu ", id, " a l'ecran: ", ecran.has_point(c._place(id)), " disponible: ", partie.lieu_disponible(id) if id != "base" else true)
		print("carte: ", c._taille_carte(), " ecran: ", ecran.size, " decalage: ", c._decalage)
		_snap("carte")
		_touch(c._place("pharmacie"), true)
	if f == 46: _touch(Vector2.ZERO, false)
	if f == 52:
		# Pharmacie disponible depuis le lot 3 f1 : sa fiche s'ouvre ; on la referme pour la suite
		print("pharmacie touchee: fiche visible=", current_scene.get_node("Fiche").visible, " (attendu true)")
		current_scene._ouvrir("")
		# Glisser le doigt : la carte défile, aucune fiche ne s'ouvre
		_touch(Vector2(current_scene.size.x / 2.0, 140), true)
	if f == 54: _drag(Vector2(current_scene.size.x / 2.0 - 60, 140), Vector2(-60, 0))
	if f == 56: _drag(Vector2(current_scene.size.x / 2.0 - 120, 140), Vector2(-60, 0))
	if f == 58: _drag(Vector2(current_scene.size.x / 2.0 - 180, 140), Vector2(-60, 0))
	if f == 60:
		print("glisse: decalage ", current_scene._decalage, " (attendu x plus petit si la carte depasse)")
		_touch(Vector2.ZERO, false)
	if f == 66:
		print("apres glisse: fiche visible=", current_scene.get_node("Fiche").visible, " (attendu false)")
		_snap("carte_glissee")
		current_scene._placer()
		_touch(current_scene._place("maison"), true)
	if f == 72: _touch(Vector2.ZERO, false)
	if f == 100:
		var fiche = current_scene.get_node("Fiche")
		print("fiche maison: visible=", fiche.visible, " dans l'ecran: ", _dans_ecran(fiche))
		var cache := false
		for id in ["base"] + partie.LIEUX.keys():
			if fiche.get_global_rect().has_point(current_scene._place(id)): cache = true
		print("fiche cache un lieu: ", cache, " (attendu false)")
		_snap("fiche_maison")
		_touch(current_scene._place("supermarche"), true)
	if f == 106: _touch(Vector2.ZERO, false)
	if f == 130:
		_snap("fiche_supermarche")
		# --- Victoire : mission + rescapé = 3 étoiles ---
		_fin("heros", true, ["fiole", "eau", "conserve", "piles"], true, false)
	if f == 330:
		_verifier_fin()
		_snap("victoire_heros")
		_fin("heroine", true, ["eau"], false, true)
	if f == 530:
		_verifier_fin()
		_snap("victoire_heroine")
		_fin("heros", false, ["eau", "conserve", "piles", "bandage"], false, false)
	if f == 600:
		_verifier_fin()
		_snap("defaite_heros")
		_fin("heroine", false, ["eau", "conserve", "bandage"], false, false)
	if f == 670:
		_verifier_fin()
		_snap("defaite_heroine")
		_touch(_centre(current_scene.get_node("RetourBase")), true)
	if f == 676: _touch(Vector2.ZERO, false)
	if f == 700:
		print("scene: ", current_scene.name, " (attendu Base)")
		_effacer()
		quit()
