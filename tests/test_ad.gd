extends SceneTree
## Lot 4 (d) : plusieurs parties sauvegardées. Migration d'une sauvegarde version 7 en première partie
## (« Partie d'Eliott », fichier de secours créé une seule fois et jamais écrasé) ; bouton Partie de la base et son
## menu (Sauvegarder force la sauvegarde et affiche le message 1,5 s) ; Nouvelle partie (nom, Non puis Oui) ;
## bascule entre deux parties par « Mes parties » sans mélange (inventaires différents) ; la partie en cours ne
## s'efface pas (bouton grisé) ; effacement d'une autre partie (Non puis Oui) ; liste qui défile au doigt ; geste
## « retour » d'Android. Captures : menu, nouvelle partie, liste, confirmation.
## Affiche « ECHEC » à chaque vérification ratée. Efface toutes les parties (environnement de test) à la fin.
var g := 0
var phase := "migration"
var partie
var echecs := 0
var ecran_parties = load("res://scripts/parties.gd")
## Ancienne sauvegarde unique (version 7), telle qu'elle est sur la tablette avant le lot 4 d
const ANCIENNE := {"version": 7, "inventaire": {"conserve": 3, "eau": 2}, "constructions": ["barricade"], "remede": 1,
	"remede_annonce": false, "skin": "heroine", "prenom": "Eliott", "rescapes": 2, "lieux_sauves": ["maison"],
	"batiments_vus": [], "etoiles": {"maison": 2}}


func _initialize():
	partie = root.get_node("Partie")


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _drag(pos, relatif):
	var e = InputEventScreenDrag.new(); e.index = 0; e.position = pos; e.relative = relatif
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_ad_%s_%s.png" % [n, "paysage" if _paysage() else "portrait"])
func _paysage() -> bool:
	return root.get_visible_rect().size.x > root.get_visible_rect().size.y
func _centre(n): return n.get_global_rect().get_center()
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1
func _aller(p):
	phase = p; g = 0
func _s(): return current_scene
func _lire(id):
	return JSON.parse_string(FileAccess.get_file_as_string(partie.DOSSIER + id + ".json"))
func _ecrire(chemin, texte):
	var f = FileAccess.open(chemin, FileAccess.WRITE); f.store_string(texte); f.close()
## Efface toutes les parties, l'index, l'ancienne sauvegarde et la copie de secours (environnement de test seulement).
func _tout_effacer():
	for nom in DirAccess.get_files_at(partie.DOSSIER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(partie.DOSSIER + nom))
	for chemin in [partie.ANCIEN_FICHIER, partie.SECOURS]:
		Fichier.effacer(chemin)


func _physics_process(_d):
	g += 1
	match phase:
		"migration":
			if g == 1:
				_tout_effacer()
				var texte := JSON.stringify(ANCIENNE)
				_ecrire(partie.ANCIEN_FICHIER, texte)
				partie._preparer_parties()
				partie.charger()
				_verifier("fichier de secours = ancienne sauvegarde", FileAccess.file_exists(partie.SECOURS)
					and FileAccess.get_file_as_string(partie.SECOURS) == texte)
				_verifier("une partie « %s » en cours (%s)" % [partie.nom_partie(partie.en_cours), partie.en_cours],
					partie.parties.size() == 1 and partie.en_cours == "p1" and partie.nom_partie("p1") == "Partie d'Eliott")
				_verifier("rien de perdu : inventaire %s, rescapés %d, constructions %s, prénom %s" % [partie.inventaire,
					partie.rescapes, partie.constructions, partie.prenom], partie.inventaire.get("conserve") == 3
					and partie.inventaire.get("eau") == 2 and partie.rescapes == 2 and partie.constructions == ["barricade"]
					and partie.prenom == "Eliott" and partie.skin == "heroine" and partie.meilleures_etoiles("maison") == 2
					and partie.rescape_sauve("maison"))
				var lu = _lire("p1")
				_verifier("partie p1 réécrite en version %s" % lu["version"], lu["version"] == partie.VERSION)
				_verifier("index écrit (Fichier)", FileAccess.file_exists(partie.INDEX))
				# Second lancement : l'ancienne sauvegarde a changé (elle n'est plus lue), le secours n'est pas écrasé
				_ecrire(partie.ANCIEN_FICHIER, JSON.stringify({"version": 7, "inventaire": {"piles": 50}}))
				partie._preparer_parties()
				partie.charger()
				_verifier("2e lancement : secours jamais écrasé", FileAccess.get_file_as_string(partie.SECOURS) == texte)
				_verifier("2e lancement : toujours une partie, pas de nouvelle migration (%s)" % partie.inventaire,
					partie.parties.size() == 1 and partie.inventaire.get("piles", 0) == 0 and partie.inventaire.get("conserve") == 3)
				partie.remede = 0   # sinon une jauge pleine ouvrirait « Remède trouvé ! »
				partie.sauvegarder()
				change_scene_to_file("res://scenes/base.tscn")
			if g == 40:
				var bouton: Control = _s().get_node("Interface/Partie")
				_verifier("bouton Partie visible, %s >= 100 px" % [bouton.size], bouton.visible and bouton.size.y >= 100 and bouton.size.x >= 100)
				_touch(_centre(bouton), true)
			if g == 46: _touch(Vector2.ZERO, false)
			if g == 70:
				_verifier("menu Partie ouvert, autres boutons et joystick cachés", _s().menu_ouvert()
					and not _s().get_node("Interface/Tiroir").visible and not _s().get_node("Interface/Start").visible
					and not _s().get_node("HUD/Joystick").visible)
				_verifier("boutons du menu >= 100 px", _s().get_node("Interface/MenuPartie/Sauvegarder").size.y >= 100)
				partie.inventaire["piles"] = 7   # changé en mémoire, pas encore écrit
				_touch(_centre(_s().get_node("Interface/MenuPartie/Sauvegarder")), true)
			if g == 76: _touch(Vector2.ZERO, false)
			if g == 100:
				_verifier("Sauvegarder : fichier à jour (%s)" % [_lire("p1")["inventaire"]], _lire("p1")["inventaire"].get("piles") == 7.0)
				_verifier("message « Partie sauvegardée ! »", _s().get_node("Interface/MenuPartie").message_visible())
				_snap("menu")
			if g == 200:
				_verifier("message effacé après 1,5 s", not _s().get_node("Interface/MenuPartie").message_visible())
				root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
			if g == 210:
				_verifier("retour Android : menu fermé, toujours la base", current_scene.name == "Base" and not _s().menu_ouvert()
					and _s().get_node("Interface/Tiroir").visible)
				_s().ouvrir_menu(true)
			if g == 230: _touch(_centre(_s().get_node("Interface/MenuPartie/Nouvelle")), true)
			if g == 236: _touch(Vector2.ZERO, false)
			if g == 270:
				_verifier("écran Nouvelle partie", current_scene.name == "Parties" and _s().get_node("Nom").visible)
				_s().get_node("Nom").text = "Deuxième"
				_touch(_centre(_s().get_node("Creer")), true)
			if g == 276: _touch(Vector2.ZERO, false)
			if g == 300:
				_verifier("« Êtes-vous sûr ? »", _s().confirmation_ouverte() and "sûr" in _s().get_node("Confirmation/Question").text)
				_snap("nouvelle")
				_touch(_centre(_s().get_node("Confirmation/Non")), true)
			if g == 306: _touch(Vector2.ZERO, false)
			if g == 330:
				_verifier("Non : rien de créé", not _s().confirmation_ouverte() and partie.parties.size() == 1)
				_touch(_centre(_s().get_node("Creer")), true)
			if g == 336: _touch(Vector2.ZERO, false)
			if g == 360: _touch(_centre(_s().get_node("Confirmation/Oui")), true)
			if g == 366: _touch(Vector2.ZERO, false)
			if g == 400:
				_verifier("Oui : choix du héros, 2 parties, « %s » en cours et vide (%s)" % [partie.nom_partie(partie.en_cours), partie.inventaire],
					current_scene.name == "ChoixHeros" and partie.parties.size() == 2 and partie.en_cours == "p2"
					and partie.nom_partie("p2") == "Deuxième" and partie.inventaire.is_empty() and partie.skin == "")
				_verifier("l'ancienne partie a été sauvegardée avant (%s)" % [_lire("p1")["inventaire"]], _lire("p1")["inventaire"].get("piles") == 7.0)
				partie.choisir_heros("heros", "Lou")
				partie.inventaire = {"eau": 9}
				partie.sauvegarder()
				_aller("bascule")
		"bascule":
			if g == 1:
				ecran_parties.ouvrir(self, "liste", false)
			if g == 40:
				_verifier("liste : 2 parties", current_scene.name == "Parties" and _s()._ids == ["p1", "p2"])
				_verifier("bouton Effacer >= 100 px", _s().TAILLE_EFFACER.y >= 100)
				_snap("liste")
				_touch(_s().centre_ligne("p1"), true)
			if g == 46: _touch(Vector2.ZERO, false)
			if g == 80:
				_verifier("toucher p1 : chargée, base (scène %s)" % current_scene.name, current_scene.name == "Base" and partie.en_cours == "p1")
				_verifier("pas de mélange : p1 %s" % [partie.inventaire], partie.inventaire.get("conserve") == 3
					and partie.inventaire.get("piles") == 7 and not partie.inventaire.has("eau") and partie.prenom == "Eliott")
				_verifier("pas de mélange : p2 %s" % [_lire("p2")["inventaire"]], _lire("p2")["inventaire"] == {"eau": 9.0}
					and _lire("p2")["prenom"] == "Lou")
				ecran_parties.ouvrir(self, "liste", true)
			if g == 120:
				_touch(_s().centre_ligne("p1", true), true)
			if g == 126: _touch(Vector2.ZERO, false)
			if g == 150:
				_verifier("Effacer la partie en cours : rien (grisé)", not _s().confirmation_ouverte() and not partie.effacer_partie("p1")
					and partie.parties.size() == 2 and current_scene.name == "Parties")
				_touch(_s().centre_ligne("p2", true), true)
			if g == 156: _touch(Vector2.ZERO, false)
			if g == 180:
				_verifier("« %s »" % _s().get_node("Confirmation/Question").text, _s().confirmation_ouverte()
					and _s().get_node("Confirmation/Question").text == "Effacer Deuxième ?")
				_snap("effacer")
				_touch(_centre(_s().get_node("Confirmation/Non")), true)
			if g == 186: _touch(Vector2.ZERO, false)
			if g == 210:
				_verifier("Non : toujours 2 parties", partie.parties.size() == 2 and not _s().confirmation_ouverte())
				_touch(_s().centre_ligne("p2", true), true)
			if g == 216: _touch(Vector2.ZERO, false)
			if g == 240: _touch(_centre(_s().get_node("Confirmation/Oui")), true)
			if g == 246: _touch(Vector2.ZERO, false)
			if g == 270:
				_verifier("Oui : p2 effacée (fichier compris)", partie.parties.size() == 1 and _s()._ids == ["p1"]
					and not FileAccess.file_exists(partie.DOSSIER + "p2.json") and partie.en_cours == "p1")
				# Assez de parties pour que la liste dépasse l'écran
				for k in 6:
					partie.nouvelle_partie("Essai %d" % k)
				partie.charger_partie("p1")
				ecran_parties.ouvrir(self, "liste", true)
			if g == 310:
				_verifier("7 parties dans la liste", _s()._ids.size() == 7)
				var p = _s().get_node("Liste").get_global_rect().get_center()
				_touch(p, true)
				_drag(p + Vector2(0, -30), Vector2(0, -30))
				_drag(p + Vector2(0, -120), Vector2(0, -90))
				_drag(p + Vector2(0, -200), Vector2(0, -80))
			if g == 318: _touch(Vector2.ZERO, false)
			if g == 345:
				_verifier("glisser fait défiler (%.0f px) sans charger de partie" % _s()._defilement,
					_s()._defilement > 100 and current_scene.name == "Parties" and partie.en_cours == "p1")
				_snap("defile")
				root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
			if g == 365:
				_verifier("retour Android depuis la base : base, partie inchangée", current_scene.name == "Base" and partie.en_cours == "p1")
				ecran_parties.ouvrir(self, "liste", false)
			if g == 395:
				root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
			if g == 415:
				_verifier("retour Android depuis le titre : titre", current_scene.name == "Titre")
				_aller("fin")
		"fin":
			if g == 1:
				change_scene_to_file("res://scenes/titre.tscn")
			if g == 20:
				_tout_effacer()
				print("test_ad : ", echecs, " echec(s)")
				quit()
