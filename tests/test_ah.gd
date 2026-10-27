extends SceneTree
## Lot 4 (h1) : défense de la base. Sur la carte, le lieu est verrouillé sans rescapé (« Bientôt »), disponible avec
## des rescapés (fiche : objectif, vagues, rescapés à protéger, « Y aller ») ; dans le niveau : pas d'interface de la
## base ni de Cacher, rescapés devant leur tente, 3 vagues dans l'ordre (« Vague N / 3 » au centre), une flèche pour un
## zombie hors de l'écran, rescapé emporté par un zombie (retiré de la base, son lieu redevient à sauver), victoire
## (étoiles : victoire + sans blessure, pas « défense parfaite », 2 objets en bonus), puis défaite du héros (rien de
## perdu). Les entrées des zombies sont gardées libres dans la base.
## Captures : carte verrouillée, fiche, vague, flèches, rescapé emporté, fin, défaite.
## Affiche « ECHEC » à chaque vérification ratée. Efface la sauvegarde à la fin.
var g := 0
var phase := "verrou"
var partie
var reg
var echecs := 0
var vagues_vues := []      # vagues dans l'ordre où elles ont commencé
var annonces := []         # annonces au centre (« Vague 2 / 3 »)
var entres_par_vague := {} # vague -> zombies entrés
var tuer := false          # le test bat chaque zombie dès qu'il entre
var zombie_loin: Node2D = null
var loin_choisi := false
var victime: Node2D = null
var inventaire_avant := {}
var FICHIER: String:   # sauvegarde de la partie en cours (lot 4 d)
	get:
		return root.get_node("Partie").fichier()
const ORIGINE := {"DEFENSE_VAGUES": [4, 6, 8], "DEFENSE_DEBUT": 3.0, "DEFENSE_DELAI_ZOMBIE": 1.5, "DEFENSE_PAUSE_VAGUES": 8.0}


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_ah_%s.png" % n)
func _sens() -> String: return "paysage" if root.get_visible_rect().size.x > root.get_visible_rect().size.y else "portrait"
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1
func _aller(p):
	phase = p; g = 0
func _effacer():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	partie.inventaire = {}; partie.constructions = []; partie.poses = []; partie.remede = 0; partie.remede_annonce = false
	partie.rescapes = 0; partie.lieux_sauves = []; partie.batiments_vus = []; partie.etoiles_lieux = {}
	partie.balles_tourelles = []; partie.fruit = false
func _d(): return current_scene
func _heros(): return current_scene.get_node("Monde/Heros")
func _hud(): return current_scene.get_node("HUD")
func _zombies(): return get_nodes_in_group("zombies")
## Deux rescapés à la base (supermarché et maison sauvés), une tourelle vide
func _deux_rescapes():
	partie.rescapes = 2
	partie.lieux_sauves = ["supermarche", "maison"]
	partie.batiments_vus = ["abri_1", "feu", "tente_1", "tente_2"]
	partie.inventaire = {"conserve": 3, "eau": 1}
	partie.sauvegarder()


func _physics_process(_d):
	g += 1
	match phase:
		"verrou":
			if g == 1:
				_effacer()
				partie.prenom = "Eliott"; partie.skin = "heros"
				partie.sauvegarder()
				change_scene_to_file("res://scenes/carte.tscn")
			if g == 30:
				_verifier("sans rescapé : defense pas disponible", not partie.lieu_disponible("defense") and partie.LIEUX.has("defense"))
				_touch(_d()._place("defense"), true)
			if g == 36: _touch(_d()._place("defense"), false)
			if g == 70:
				_verifier("toucher la defense verrouillee : pas de fiche", not _d().get_node("Fiche").visible)
				_snap("carte_verrou_" + _sens())
				_deux_rescapes()
				change_scene_to_file("res://scenes/carte.tscn")
			if g == 100:
				_verifier("avec 2 rescapes : defense disponible", partie.lieu_disponible("defense"))
				_verifier("lieu a l'ecran", _d().get_viewport_rect().has_point(_d()._place("defense")))
				_touch(_d()._place("defense"), true)
			if g == 106: _touch(_d()._place("defense"), false)
			if g == 140:
				var fiche = _d().get_node("Fiche")
				_verifier("fiche de la defense ouverte, dans l'ecran", fiche.visible and _d()._choisi == "defense"
					and _d().get_viewport_rect().encloses(fiche.get_global_rect()))
				_snap("fiche_" + _sens())
				# Réglages rapides pour le test : 3 vagues de 1, 2 et 3 zombies
				reg.DEFENSE_VAGUES = [1, 2, 3]
				reg.DEFENSE_DEBUT = 0.5
				reg.DEFENSE_DELAI_ZOMBIE = 0.3
				reg.DEFENSE_PAUSE_VAGUES = 1.0
				var bouton = fiche.get_node("YAller")
				_touch(bouton.get_global_rect().get_center(), true)
			if g == 146: _touch(Vector2.ZERO, false)
			if g == 190:
				_verifier("Y aller -> niveau de defense (%s)" % current_scene.name, current_scene.name == "Defense" and partie.lieu == "defense")
				_aller("vagues")
		"vagues":
			if current_scene == null or current_scene.name != "Defense":
				if current_scene != null and current_scene.name == "Fin" and g > 1100:
					_aller("fin")
				return
			# Suivi des vagues et des annonces
			if not vagues_vues.has(_d().vague()):
				vagues_vues.append(_d().vague())
			var annonce: String = _hud().annonce()
			if annonce != "" and not annonces.has(annonce):
				annonces.append(annonce)
			entres_par_vague[_d().vague()] = entres_par_vague.get(_d().vague(), 0)
			if tuer and not (_d().vague() == 2 and victime == null):
				for z in _zombies():
					z.recevoir_coup(99, z.global_position + Vector2(10, 0))
			if g == 2:
				_verifier("pas d'interface de la base ni de Cacher", not _d().has_node("Interface") or _d().get_node("Interface").is_queued_for_deletion())
				_verifier("bouton Cacher cache, Frapper et Pause la", not _hud().get_node("BoutonCacher").visible
					and _hud().get_node("BoutonAttaquer").visible and _hud()._pause.visible)
				_verifier("2 rescapes dans la base", _d()._rescapes.size() == 2)
				_verifier("heros pres de la voiture", _d().get_node("Monde/Voiture").distance_a(_heros().global_position) <= reg.VOITURE_PORTEE)
				_verifier("entrees des zombies gardees libres dans la base",
					reg.DEFENSE_ENTREES.all(func(e): return _d()._reservees().any(func(r): return r.has_point(e))))
			if g == 30:
				var devant := true
				for r in _d()._rescapes.values():
					devant = devant and r.devant_tente()
				_verifier("rescapes devant leur tente", devant)
				_verifier("vague 1 annoncee", annonces.has("Vague 1 / 3") and _d().vague() == 1)
				_snap("vague1_" + _sens())
			# Vague 1 : un zombie ; le héros va loin de lui (flèche)
			if g > 30 and not loin_choisi and not _zombies().is_empty():
				loin_choisi = true
				zombie_loin = _zombies()[0]
				# Le héros part dans le coin du parking le plus loin du zombie à l'écran
				var iso = root.get_node("Iso")
				var coins := [Vector2(200, 250), Vector2(2250, 250), Vector2(200, 1450), Vector2(2250, 1450)]
				coins.sort_custom(func(a, b): return iso.ecran(a).distance_to(iso.ecran(zombie_loin.global_position)) \
					> iso.ecran(b).distance_to(iso.ecran(zombie_loin.global_position)))
				_heros().position = coins[0]
				g = 100
			if g == 160:
				_verifier("zombie loin : une fleche pour lui (%d)" % _d().fleches().size(), _d().fleches().has(zombie_loin))
			if g == 190:
				_snap("fleches_" + _sens())
				_heros().position = zombie_loin.global_position + Vector2(0, 350)   # à l'écran, pas au contact
			if g == 230:
				_verifier("zombie a l'ecran : plus de fleche", not _d().fleches().has(zombie_loin))
				_heros().position = Vector2(720, 1160)
				tuer = true
			if g == 240:
				_verifier("heros jamais touche jusqu'ici", _heros().intact())
			# Vague 2 : un zombie emporte le rescapé de la première tente
			if g > 240 and g < 1000 and _d().vague() == 2 and victime == null and not _zombies().is_empty():
				tuer = false
				victime = _d()._rescapes["tente_1"]
				_verifier("vague 2 annoncee apres la vague 1", annonces.has("Vague 2 / 3"))
				_zombies()[0].global_position = victime.global_position + Vector2(20, 0)
				_heros().position = victime.global_position + Vector2(-150, 250)   # la caméra montre le nuage
				g = 1000
			if g == 1003:
				tuer = true   # le zombie n'emporte que ce rescapé-là
			if g == 1010:
				_verifier("rescape de la tente 1 emporte", victime.emporte() and _d().emportes() == [0])
			if g == 1030:
				_snap("emporte_" + _sens())
			if g == 1100:
				_verifier("nuage fini : le rescape a disparu", not victime._vue.visible)
			if g == 3000:
				_verifier("victoire atteinte", false)
				_aller("fin")
		"fin":
			if g == 1:
				_verifier("3 vagues dans l'ordre %s" % [vagues_vues], vagues_vues.filter(func(v): return v > 0) == [1, 2, 3])
				_verifier("annonces %s" % [annonces], annonces.has("Vague 3 / 3") and annonces.has("Base défendue !"))
				var r = partie.resultat
				_verifier("victoire de defense, 1 emporte", r["victoire"] and r["defense"] and r["emportes"] == 1 and r["mission"])
				_verifier("etoiles : victoire + sans blessure = %d" % partie.etoiles(), partie.etoiles() == 2 and partie.meilleures_etoiles("defense") == 2)
				_verifier("bonus de %d objets %s" % [reg.DEFENSE_BONUS, r["bonus"]], r["bonus"].size() == reg.DEFENSE_BONUS and r["perdus"].is_empty())
				_verifier("trouvailles des 2 rescapes (%d)" % r["trouvailles"].size(), r["trouvailles"].size() == 2 * reg.RESCAPE_OBJETS)
				_verifier("rescape emporte retire : %d rescape(s), lieux %s" % [partie.rescapes, partie.lieux_sauves],
					partie.rescapes == 1 and partie.lieux_sauves == ["maison"])
				_verifier("supermarche : rescape a sauver de nouveau", not partie.rescape_sauve("supermarche"))
				var lu = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
				_verifier("sauvegarde : %s rescape(s), %s" % [lu["rescapes"], lu["lieux_sauves"]], lu["rescapes"] == 1.0 and lu["lieux_sauves"] == ["maison"]
					and lu["etoiles"].get("defense", 0) == 2.0)
				_verifier("tente 2 plus marquee vue (elle retombera)", not partie.batiments_vus.has("tente_2"))
			if g == 60:
				_verifier("titre « %s »" % current_scene.get_node("Titre").text, current_scene.get_node("Titre").text == "Base défendue !")
				_verifier("ligne des rescapes emportes", current_scene.get_node("Resume").text.contains("1 rescapé emporté : va les rechercher !"))
				_snap("fin_" + _sens())
				change_scene_to_file("res://scenes/base.tscn")
			if g == 100:
				_verifier("base : une seule tente", _d()._rescapes.size() == 1 and _d()._batiments.has("tente_1") and not _d()._batiments.has("tente_2"))
				_aller("defaite")
		"defaite":
			if g == 1:
				inventaire_avant = partie.inventaire.duplicate()
				partie.choisir_lieu("defense")
				change_scene_to_file(partie.scene_lieu())
			if g == 40:
				_verifier("1 rescape : defense encore disponible", partie.lieu_disponible("defense"))
				for i in 30:
					_heros()._invulnerable = 0.0
					_heros().recevoir_degats(1, _heros().global_position + Vector2(30, 0))
			if g == 100:
				_snap("defaite_jeu_" + _sens())
			if g == 200:
				var r = partie.resultat
				_verifier("defaite (%s), rien de perdu, pas de bonus" % current_scene.name, current_scene.name == "Fin" and not r["victoire"]
					and r["defense"] and r["perdus"].is_empty() and r["bonus"].is_empty() and partie.etoiles() == 0)
				_verifier("meilleures etoiles gardees", partie.meilleures_etoiles("defense") == 2)
				_verifier("rescape garde (personne emporte)", partie.rescapes == 1 and r["emportes"] == 0)
			if g == 240:
				_snap("defaite_" + _sens())
				for nom in ORIGINE:
					reg.set(nom, ORIGINE[nom])
				_effacer()
				print("== test_ah : ", "tout est OK" if echecs == 0 else "%d ECHEC(S)" % echecs)
				quit()
