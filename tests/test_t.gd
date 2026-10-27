extends SceneTree
## Robustesse (lot 3 a) : bouton Pause du HUD (jeu figé, joystick relâché), Reprendre, geste « retour »
## d'Android (pause dans un lieu, écran précédent ailleurs, rien sur le titre), « Retour à la base » = défaite
## normale ; recul annulé en se cachant (B6) ; zombie coincé qui repart d'où il est (B5) ;
## sauvegardes (Partie, ParametresJeu) reprises depuis le .tmp quand le fichier principal est illisible.
## Affiche « ECHEC » à chaque vérification ratée. Efface la sauvegarde et les réglages à la fin.
var g := 0
var phase := "lieu"
var partie
var pj
var reg
var niveau
var h
var hud
var zombie
var avant := {}
var echecs := 0

var SAUVEGARDE: String:   # sauvegarde de la partie en cours (lot 4 d)
	get:
		return root.get_node("Partie").fichier()
const REGLAGES := "user://reglages.json"


func _initialize():
	partie = root.get_node("Partie")
	pj = root.get_node("ParametresJeu")
	reg = root.get_node("Reglages")
	partie.skin = "heros"
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.choisir_lieu("supermarche")
	change_scene_to_file("res://scenes/lieux/supermarche.tscn")


func _touch(pos, pressed, idx := 0):
	var e = InputEventScreenTouch.new(); e.index = idx; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _drag(pos, idx):
	var e = InputEventScreenDrag.new(); e.index = idx; e.position = pos
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_t_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
func _aller(p):
	phase = p; g = 0
func _appui(noeud, debut):
	if g == debut: _touch(_centre(noeud), true)
	if g == debut + 6: _touch(Vector2.ZERO, false)
func _retour_android():
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1
func _scene() -> String:
	return current_scene.name if current_scene else ""


func _physics_process(_d):
	if current_scene == null:
		return
	g += 1
	match phase:
		"lieu":
			if g == 10:
				niveau = current_scene
				h = niveau.get_node("Monde/Heros")
				hud = niveau.get_node("HUD")
				var b: Control = hud._pause
				_verifier("bouton Pause: taille %s dans l'ecran %s, sous l'objectif" % [b.size, niveau.get_viewport_rect().encloses(b.get_global_rect())],
					b.size.x >= 100 and b.size.x < 140 and niveau.get_viewport_rect().encloses(b.get_global_rect())
					and b.get_global_rect().position.y >= hud.get_node("Objectif").get_global_rect().end.y)
				# Joystick tenu (doigt 1) : le héros marche à droite
				_touch(Vector2(200, niveau.get_viewport_rect().size.y - 200), true, 1)
			if g == 14:
				_drag(Vector2(320, niveau.get_viewport_rect().size.y - 200), 1)
			if g == 40:
				_verifier("joystick tenu: le heros marche (vitesse %.0f)" % h.velocity.length(), h.velocity.length() > 100)
				avant = {"heros": h.global_position, "zombies": get_nodes_in_group("zombies").map(func(z): return z.global_position)}
			if g == 40 or g == 46: _appui(hud._pause, 40)
			if g == 50:
				_verifier("apres Pause: jeu fige %s, menu visible %s" % [paused, niveau.get_node("Pause").visible], paused and niveau.get_node("Pause").visible)
				avant = {"heros": h.global_position, "zombies": get_nodes_in_group("zombies").map(func(z): return z.global_position),
					"temps": get_nodes_in_group("zombies")[0]._temps}
			if g == 80:
				_snap("pause")
			if g == 110:
				var bouge := false
				for i in get_nodes_in_group("zombies").size():
					bouge = bouge or get_nodes_in_group("zombies")[i].global_position != avant["zombies"][i]
				_verifier("60 pas en pause: heros immobile %s, zombies immobiles %s, animation figee %s" % [h.global_position == avant["heros"], not bouge,
					get_nodes_in_group("zombies")[0]._temps == avant["temps"]],
					h.global_position == avant["heros"] and not bouge and get_nodes_in_group("zombies")[0]._temps == avant["temps"])
				_verifier("joystick relache pendant la pause: doigt %d" % hud.get_node("Joystick")._doigt, hud.get_node("Joystick")._doigt == -1)
				_touch(Vector2.ZERO, false, 1)   # lever du doigt du joystick (perdu : jeu figé)
			if g == 120 or g == 126: _appui(niveau.get_node("Pause/Centre/Colonne/Reprendre"), 120)
			if g == 140:
				_verifier("Reprendre: jeu fige %s, menu visible %s" % [paused, niveau.get_node("Pause").visible], not paused and not niveau.get_node("Pause").visible)
				avant["zombies"] = get_nodes_in_group("zombies").map(func(z): return z.global_position)
			if g == 170:
				var bouge := false
				for i in get_nodes_in_group("zombies").size():
					bouge = bouge or get_nodes_in_group("zombies")[i].global_position != avant["zombies"][i]
				_verifier("apres Reprendre: les zombies bougent %s, heros arrete (vitesse %.0f)" % [bouge, h.velocity.length()], bouge and h.velocity.length() < 1.0)
				_retour_android()
			if g == 175:
				_verifier("retour Android dans le lieu: pause %s" % paused, paused and niveau.get_node("Pause").visible)
				_retour_android()
			if g == 180:
				_verifier("2e retour Android: reprise %s" % (not paused), not paused and not niveau.get_node("Pause").visible)
				# B6 : un coup reçu juste avant de se cacher ne fait pas glisser le héros
				var cachette = get_nodes_in_group("cachettes")[0]
				h.position = cachette.global_position + Vector2(0, 40); h.velocity = Vector2.ZERO
				h._invulnerable = 0.0
				h.recevoir_degats(1, h.global_position + Vector2(-30, 0))
			if g == 182:
				niveau._sur_cacher()
				avant["heros"] = h.global_position
			if g == 210:
				_verifier("B6 cache apres un coup: glisse de %.1f px" % h.global_position.distance_to(avant["heros"]),
					h._cache and h.global_position.distance_to(avant["heros"]) < 1.0)
				niveau._sur_cacher()
				# B5 : zombie qui patrouille droit dans une cachette (décor) : coincé, il repart d'où il est
				var cachette = get_nodes_in_group("cachettes")[0]
				h.position = Vector2(2300, 200); h.get_node("Camera2D").reset_smoothing()
				zombie = get_nodes_in_group("zombies")[0]
				zombie.position = cachette.global_position + Vector2(0, 50)
				zombie._depart = zombie.position; zombie.patrouille = Vector2(0, -400); zombie._vers_bout = true
				zombie._changer_etat(0)
				avant["depart"] = zombie._depart
			if g == 330:
				_verifier("B5 coince 2 s contre le decor: etat %d, nouveau depart %s (avant %s)" % [zombie._etat, zombie._depart, avant["depart"]],
					zombie._etat == 0 and zombie._depart != avant["depart"])
				avant["position"] = zombie.global_position
			if g == 400:
				_verifier("B5 il repart dans l'autre sens: %.0f px" % zombie.global_position.distance_to(avant["position"]),
					zombie.global_position.distance_to(avant["position"]) > 40.0)
				niveau._ramasses = ["eau", "piles", "conserve"]
				avant["inventaire"] = partie.inventaire.duplicate()
				_retour_android()
			if g == 430:
				_snap("pause2")
			if g == 440: _touch(_centre(niveau.get_node("Pause/Centre/Colonne/RetourBase")), true)
			if g == 446: _touch(Vector2.ZERO, false)   # le niveau est déjà parti
			if g == 470:
				var r: Dictionary = partie.resultat
				_verifier("Retour a la base: scene %s, victoire %s, perdus %d, rapportes %d, pause %s" % [_scene(), r["victoire"], r["perdus"].size(),
					r["rapportes"].size(), paused], _scene() == "Fin" and not r["victoire"] and r["perdus"].size() == 1 and r["rapportes"].size() == 2 and not paused)
				_retour_android()
			if g == 490:
				_verifier("retour Android sur la fin: %s (attendu Base)" % _scene(), _scene() == "Base")
				_aller("ecrans")
		"ecrans":
			if g == 10:
				_retour_android()
			if g == 30:
				_verifier("retour Android sur la base: %s (attendu Titre)" % _scene(), _scene() == "Titre")
				_retour_android()
			if g == 50:
				_verifier("retour Android sur le titre: %s (attendu Titre, rien)" % _scene(), _scene() == "Titre")
				change_scene_to_file("res://scenes/carte.tscn")
			if g == 70:
				_retour_android()
			if g == 90:
				_verifier("retour Android sur la carte: %s (attendu Base)" % _scene(), _scene() == "Base")
				change_scene_to_file("res://scenes/parametres.tscn")
			if g == 110:
				_retour_android()
			if g == 130:
				_verifier("retour Android dans les reglages: %s (attendu Base)" % _scene(), _scene() == "Base")
				change_scene_to_file("res://scenes/choix_heros.tscn")
			if g == 150:
				current_scene._choisi = "heroine"
				_retour_android()
			if g == 170:
				_verifier("retour Android au choix du heros: %s skin %s (attendu Base, heros garde)" % [_scene(), partie.skin],
					_scene() == "Base" and partie.skin == "heros")
				_aller("sauvegarde")
		"sauvegarde":
			if g == 5:
				partie.inventaire = {"eau": 3}
				partie.sauvegarder()
				_verifier("ecriture sure: .tmp renomme %s, fichier lisible %s" % [not FileAccess.file_exists(SAUVEGARDE + ".tmp"),
					JSON.parse_string(FileAccess.get_file_as_string(SAUVEGARDE)) is Dictionary],
					not FileAccess.file_exists(SAUVEGARDE + ".tmp") and JSON.parse_string(FileAccess.get_file_as_string(SAUVEGARDE)) is Dictionary)
				partie.inventaire = {"eau": 4}
				partie.sauvegarder()   # par-dessus un fichier existant
				_verifier("2e ecriture par-dessus: %s" % FileAccess.get_file_as_string(SAUVEGARDE).contains("\"eau\":4"),
					FileAccess.get_file_as_string(SAUVEGARDE).contains("\"eau\":4"))
				# Appli tuée pendant l'écriture : fichier principal tronqué, .tmp complet
				var texte := FileAccess.get_file_as_string(SAUVEGARDE).replace("\"eau\":4", "\"eau\":7")
				var f := FileAccess.open(SAUVEGARDE + ".tmp", FileAccess.WRITE); f.store_string(texte); f.close()
				f = FileAccess.open(SAUVEGARDE, FileAccess.WRITE); f.store_string(texte.left(25)); f.close()
				partie.inventaire = {}
				partie.charger()
				_verifier("sauvegarde illisible: reprise du .tmp, eau %d (attendu 7)" % partie.inventaire.get("eau", 0), partie.inventaire.get("eau", 0) == 7)
				# Réglages : pareil
				var pv = reg.HEROS_PV
				f = FileAccess.open(REGLAGES + ".tmp", FileAccess.WRITE); f.store_string("{\"HEROS_PV\": 7}"); f.close()
				f = FileAccess.open(REGLAGES, FileAccess.WRITE); f.store_string("{\"HERO"); f.close()
				pj.charger()
				_verifier("reglages illisibles: reprise du .tmp, coeurs %d (attendu 7)" % reg.HEROS_PV, reg.HEROS_PV == 7)
				reg.HEROS_PV = pv
				pj.sauvegarder()
				_verifier("reglages reecrits: .tmp renomme %s" % (not FileAccess.file_exists(REGLAGES + ".tmp")), not FileAccess.file_exists(REGLAGES + ".tmp"))
				# Rien de lisible : rien n'est chargé (pas d'erreur)
				Fichier.effacer(SAUVEGARDE)
				f = FileAccess.open(SAUVEGARDE, FileAccess.WRITE); f.store_string("{"); f.close()
				partie.inventaire = {"eau": 1}
				partie.charger()
				_verifier("aucun fichier lisible: inventaire garde %s" % partie.inventaire, partie.inventaire == {"eau": 1})
				Fichier.effacer(SAUVEGARDE)
				Fichier.effacer(REGLAGES)
				print("test_t: ", echecs, " echec(s)")
				quit()
