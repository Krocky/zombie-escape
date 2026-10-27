extends SceneTree
## Lot 2 (e) : objectifs et remède. Fiche de la carte et HUD avec l'objectif ; supermarché avec la fiole ->
## « Mission réussie ! » + bonus, fiole versée dans la jauge (plus dans l'inventaire) ; maison avec 1 seul bandage ->
## « Victoire ! » sans bonus, puis avec 2 bandages -> mission ; jauge pleine -> écran « Remède trouvé ! » une seule fois ;
## fioles en trop gardées ; reprise d'une sauvegarde version 2.
var f := 0
var partie
func _initialize():
	partie = root.get_node("Partie")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.get_node("Partie").fichier()))
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	change_scene_to_file("res://scenes/carte.tscn")
func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_l_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
func _heros(): return current_scene.get_node("Monde/Heros")
func _calmer():
	for z in get_nodes_in_group("zombies"): z.position = Vector2(2300, 1550); z._depart = z.position; z.patrouille = Vector2.ZERO
func _physics_process(_d):
	f += 1
	if f == 10:
		print("objectifs: supermarche '", partie.texte_objectif("supermarche"), "' maison '", partie.texte_objectif("maison"), "'")
		_touch(current_scene._place("supermarche"), true)
	if f == 16: _touch(Vector2.ZERO, false)
	if f == 22:
		var fiche = current_scene.get_node("Fiche")
		print("fiche visible: ", fiche.visible, " dans l'ecran: ", current_scene.get_viewport_rect().encloses(fiche.get_global_rect()))
		_snap("fiche_supermarche")
		_touch(current_scene._place("maison"), true)
	if f == 28: _touch(Vector2.ZERO, false)
	if f == 50: print("fiche ouverte: ", current_scene._choisi, " (attendu maison)")
	if f == 70:
		_snap("fiche_maison")
		_touch(current_scene._place("supermarche"), true)
	if f == 80: _touch(Vector2.ZERO, false)
	if f == 86: _touch(_centre(current_scene.get_node("Fiche/YAller")), true)
	if f == 92: _touch(Vector2.ZERO, false)
	# --- Supermarché : objectif rempli ---
	if f == 110:
		_calmer()
		var o = current_scene.get_node("HUD/Objectif")
		print("scene: ", current_scene.name, " HUD: '", o.text, "' visible: ", o.visible)
		_snap("hud_debut")
		_heros().position = current_scene.get_node("Monde/ObjetFiole").position
	if f == 116:
		print("HUD apres la fiole: '", current_scene.get_node("HUD/Objectif").text, "'")
		_snap("hud_rempli")
		_heros().position = current_scene.get_node("Monde/Sortie").position + Vector2(0, 30)
	if f == 170:
		var r = partie.resultat
		print("scene: ", current_scene.name, " titre: '", current_scene.get_node("Titre").text, "' (attendu Mission reussie !)")
		print("mission: ", r["mission"], " bonus: ", r["bonus"], " fioles versees: ", r["fioles"], " jauge: ", partie.remede, " inventaire: ", partie.inventaire)
		print("resume: ", current_scene.get_node("Resume").text.replace("\n", " | "))
		var b = current_scene.get_node("RetourBase")
		print("bouton dans l'ecran: ", current_scene.get_viewport_rect().encloses(b.get_global_rect()))
		_snap("fin_mission")
		_touch(_centre(b), true)
	if f == 176: _touch(Vector2.ZERO, false)
	if f == 190:
		print("scene: ", current_scene.name, " (attendu Base) jauge dans l'ecran: ", current_scene.get_viewport_rect().encloses(current_scene.get_node("Interface/Remede").get_global_rect()))
		_snap("base_jauge")
		partie.choisir_lieu("maison")
		change_scene_to_file(partie.scene_lieu())
	# --- Maison : un seul bandage, puis les deux ---
	if f == 210:
		_calmer()
		print("maison HUD: '", current_scene.get_node("HUD/Objectif").text, "'")
		_heros().position = current_scene.get_node("Monde/ObjetBandage").position
	if f == 216:
		print("maison HUD 1 bandage: '", current_scene.get_node("HUD/Objectif").text, "'")
		_snap("hud_maison")
		_heros().position = current_scene.get_node("Monde/Sortie").position + Vector2(0, 30)
	if f == 270:
		var r = partie.resultat
		print("1 bandage: titre '", current_scene.get_node("Titre").text, "' mission: ", r["mission"], " bonus: ", r["bonus"], " (attendu Victoire !, false, [])")
		print("resume: ", current_scene.get_node("Resume").text.replace("\n", " | "))
		_snap("fin_sans_objectif")
		change_scene_to_file(partie.scene_lieu())
	if f == 290:
		_calmer()
		_heros().position = current_scene.get_node("Monde/ObjetBandage").position
	if f == 294: _heros().position = current_scene.get_node("Monde/ObjetBandage2").position
	if f == 298: _heros().position = current_scene.get_node("Monde/Sortie").position + Vector2(0, 30)
	if f == 350:
		var r = partie.resultat
		print("2 bandages: titre '", current_scene.get_node("Titre").text, "' mission: ", r["mission"], " bonus: ", r["bonus"])
		# Défaite avec l'objectif : pas de mission
		partie.terminer(false, ["bandage", "bandage"])
		print("defaite avec 2 bandages: mission ", partie.resultat["mission"], " (attendu false)")
		# --- Remède : la 3e fiole remplit la jauge ---
		partie.remede = 2; partie.inventaire["fiole"] = 0
		partie.choisir_lieu("supermarche")
		partie.terminer(true, ["fiole"])
		print("3e fiole: jauge ", partie.remede, " inventaire fiole ", partie.inventaire.get("fiole", 0), " (attendu 3, 0)")
		change_scene_to_file("res://scenes/fin.tscn")
	if f == 370:
		print("resume: ", current_scene.get_node("Resume").text.replace("\n", " | "))
		_snap("fin_3e_fiole")
		_touch(_centre(current_scene.get_node("RetourBase")), true)
	if f == 376: _touch(Vector2.ZERO, false)
	if f == 390:
		print("scene: ", current_scene.name, " (attendu Remede) sauvegarde: ", FileAccess.get_file_as_string(root.get_node("Partie").fichier()))
		var c = current_scene.get_node("Centre/Colonne/Continuer")
		print("bouton Continuer: ", c.size, " dans l'ecran: ", current_scene.get_viewport_rect().encloses(c.get_global_rect()))
		_snap("remede")
		_touch(_centre(c), true)
	if f == 396: _touch(Vector2.ZERO, false)
	if f == 410:
		print("scene: ", current_scene.name, " (attendu Base)")
		_snap("base_remede")
		change_scene_to_file("res://scenes/base.tscn")
	if f == 425:
		print("2e passage a la base: ", current_scene.name, " (attendu Base, pas de nouvel ecran)")
		partie.terminer(true, ["fiole"])
		print("fiole apres le remede: inventaire ", partie.inventaire.get("fiole", 0), " jauge ", partie.remede, " (attendu 1, 3)")
		# Reprise d'une sauvegarde version 2 : ses fioles vont dans la jauge
		var fichier := FileAccess.open(root.get_node("Partie").fichier(), FileAccess.WRITE)
		fichier.store_string('{"version": 2, "inventaire": {"conserve": 1, "fiole": 2}, "constructions": []}')
		fichier.close()
		partie.inventaire = {}; partie.remede = 0; partie.remede_annonce = false
		partie.charger()
		print("reprise v2: inventaire ", partie.inventaire, " jauge ", partie.remede, " (attendu fiole 0, jauge 2)")
		print("reecrite: ", FileAccess.get_file_as_string(root.get_node("Partie").fichier()))
		# Ne pas laisser de remède aux autres tests
		DirAccess.remove_absolute(ProjectSettings.globalize_path(root.get_node("Partie").fichier()))
		partie.inventaire = {}; partie.remede = 0; partie.remede_annonce = false
		quit()
	return false
