extends SceneTree
## Lot 4 (b) : placement libre des constructions et barricades. « Construire » ouvre le placement sans rien payer :
## fantôme vert (place libre) puis rouge sur la voiture (Poser inactif) ; toucher le sol le déplace, glisser fait
## défiler la vue ; Annuler ne retire rien ; Poser retire les objets et sauvegarde la position ; 3 barricades posées
## puis rechargées aux mêmes positions (une seule donne un cœur) ; un emplacement qui enfermerait le héros est refusé ;
## maximum de barricades ; retour Android = Annuler ; une sauvegarde version 7 reprise (constructions à leur place
## d'origine). Captures : fantôme vert, rouge, héros enfermé, 3 barricades.
## Affiche « ECHEC » à chaque vérification ratée. Efface la sauvegarde à la fin.
var g := 0
var phase := "depart"
var partie
var reg
var iso
var echecs := 0
var centres := []      # centres des 3 barricades posées
var emprises := []     # leurs emprises
var taille_barricade := Vector2.ZERO
const FICHIER := "user://sauvegarde.json"
const INVENTAIRE := {"conserve": 20, "eau": 10, "piles": 4}
## Places libres du parking pour les barricades 2 et 3 (la 1re est touchée à l'écran près de P1)
const P1 := Vector2(950, 1050)
const P2 := Vector2(1450, 1200)
const P3 := Vector2(1800, 1100)


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")
	iso = root.get_node("Iso")


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _glisser(pos, relatif):
	var e = InputEventScreenDrag.new(); e.index = 0; e.position = pos; e.relative = relatif
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_ab_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
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
func _b(): return current_scene
func _ui(n): return current_scene.get_node("Interface/" + n)
func _heros(): return current_scene.get_node("Monde/Heros")
func _carte(nom):
	for c in _ui("Constructions").get_children():
		if c.construction == nom: return c
## Point du monde -> position à l'écran (vue isométrique, caméra du héros)
func _ecran(p: Vector2) -> Vector2:
	return current_scene.get_canvas_transform() * iso.ecran(p)
func _vert() -> bool:
	return _b()._fantome != null and _b()._fantome.visuels()["vue"].modulate == _b().FANTOME_LIBRE
func _rouge() -> bool:
	return _b()._fantome != null and _b()._fantome.visuels()["vue"].modulate == _b().FANTOME_REFUSE
func _lire():
	return JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
## Centre de fantôme pour que son emprise soit `r` (voir Base._creer_batiment : bas de l'emprise = centre.y + 100)
func _centre_pour(r: Rect2) -> Vector2:
	return Vector2(r.get_center().x, r.end.y - _b().TAILLES["barricade"].y / 2.0)


func _physics_process(_d):
	g += 1
	match phase:
		"depart":
			if g == 1:
				_effacer()
				partie.inventaire = INVENTAIRE.duplicate()
				partie.sauvegarder()
				change_scene_to_file("res://scenes/base.tscn")
			if g == 40:
				_verifier("base sans construction", _b().name == "Base" and not _b().en_placement())
				_b().ouvrir_tiroir(true)
			if g == 60: _touch(_centre(_carte("barricade").get_node("Bouton")), true)
			if g == 66: _touch(Vector2.ZERO, false)
			if g == 100:
				_verifier("Construire -> placement, tiroir ferme", _b().en_placement() and not _b().tiroir_ouvert())
				_verifier("fantome vert devant le heros (%s)" % _b().raison_refus(), _vert() and _b().raison_refus() == "")
				taille_barricade = _b()._fantome.emprise().size
				_verifier("objets pas encore retires %s" % partie.inventaire, partie.inventaire == INVENTAIRE)
				var poser = _ui("Poser"); var annuler = _ui("Annuler")
				_verifier("Poser et Annuler visibles, >= 100 px, Poser actif", poser.visible and annuler.visible and poser.actif
					and poser.size.x >= 100 and poser.size.y >= 100 and annuler.size.x >= 100 and annuler.size.y >= 100)
				_verifier("dans l'ecran sans chevauchement", _b().get_viewport_rect().encloses(poser.get_global_rect())
					and _b().get_viewport_rect().encloses(annuler.get_global_rect()) and not poser.get_global_rect().intersects(annuler.get_global_rect()))
				_verifier("tiroir, Heros, Reglages, Start et joystick caches", not _ui("Tiroir").visible and not _ui("Heros").visible
					and not _ui("Reglages").visible and not _ui("Start").visible and not _b().get_node("HUD/Joystick").visible)
				_snap("fantome_vert_" + ("paysage" if _b().get_viewport_rect().size.x > _b().get_viewport_rect().size.y else "portrait"))
				# Toucher la voiture : le fantôme y va, rouge
				_touch(_ecran(_b().get_node("Monde/Voiture").emprise().get_center()), true)
			if g == 108: _touch(_ecran(_b().get_node("Monde/Voiture").emprise().get_center()), false)
			if g == 130:
				_verifier("fantome sur la voiture : rouge (%s), Poser inactif" % _b().raison_refus(),
					_rouge() and _b().raison_refus() == "obstacle" and not _ui("Poser").actif)
				_snap("fantome_rouge")
				_touch(_centre(_ui("Poser")), true)
			if g == 136: _touch(Vector2.ZERO, false)
			if g == 150:
				_verifier("Poser refuse : rien construit, rien retire", not partie.est_construit("barricade") and partie.inventaire == INVENTAIRE and _b().en_placement())
				# Hors du parking
				_b().placer_fantome(Vector2(-300, 800))
				_verifier("hors du parking : rouge (%s)" % _b().raison_refus(), _rouge() and _b().raison_refus() == "parking")
				_b().placer_fantome(_heros().global_position)
				_verifier("sur le heros : rouge (%s)" % _b().raison_refus(), _rouge() and _b().raison_refus() != "")
				# Toucher un endroit libre : vert
				_touch(_ecran(P1), true)
			if g == 158: _touch(_ecran(P1), false)
			if g == 180:
				var c = _b()._centre_fantome
				_verifier("toucher le sol libre : fantome vert en %s (touche %s)" % [c.round(), P1], _vert() and c.distance_to(P1) < 15.0)
				# Glisser : la vue défile, le fantôme ne bouge pas
				_touch(Vector2(900, 400), true)
			if g > 180 and g < 196: _glisser(Vector2(900 - (g - 180) * 10, 400), Vector2(-10, 0))
			if g == 196: _touch(Vector2(750, 400), false)
			if g == 210:
				_verifier("glisser fait defiler la vue (%s), fantome immobile" % _heros().decalage_camera,
					_heros().decalage_camera.x > 50 and _b()._centre_fantome.distance_to(P1) < 15.0)
				_touch(_centre(_ui("Annuler")), true)
			if g == 216: _touch(Vector2.ZERO, false)
			if g == 230:
				_verifier("Annuler : rien construit, rien retire, vue remise", not partie.est_construit("barricade") and partie.inventaire == INVENTAIRE
					and not _b().en_placement() and _b()._fantome == null and _heros().decalage_camera == Vector2.ZERO)
				_verifier("tiroir, Heros, Reglages, joystick revenus", _ui("Tiroir").visible and _ui("Heros").visible and _ui("Reglages").visible
					and _b().get_node("HUD/Joystick").visible)
				var lu = _lire()
				_verifier("sauvegarde sans pose", lu["version"] == 8.0 and lu["poses"].is_empty())
				_aller("poser")
		"poser":
			# 3 barricades : la 1re en touchant le sol, les autres directement à leur place
			if g == 1: _b().ouvrir_tiroir(true)
			if g == 20: _touch(_centre(_carte("barricade").get_node("Bouton")), true)
			if g == 26: _touch(Vector2.ZERO, false)
			if g == 40: _touch(_ecran(P1), true)
			if g == 48: _touch(_ecran(P1), false)
			if g == 70:
				_verifier("1re barricade : fantome vert", _vert())
				centres.append(_b()._centre_fantome); emprises.append(_b()._fantome.emprise())
				_touch(_centre(_ui("Poser")), true)
			if g == 76: _touch(Vector2.ZERO, false)
			if g == 90:
				_verifier("Poser : construite, objets retires %s" % partie.inventaire, partie.nombre_construit("barricade") == 1
					and partie.inventaire["conserve"] == 18 and partie.inventaire["eau"] == 9 and not _b().en_placement())
				var lu = _lire()
				_verifier("position sauvegardee %s" % [lu["poses"]], lu["poses"].size() == 1 and lu["poses"][0]["nom"] == "barricade"
					and Vector2(lu["poses"][0]["x"], lu["poses"][0]["y"]).distance_to(centres[0]) < 0.01)
				var bat = _b()._batiments.get("barricade")
				_verifier("barricade posee a cet endroit, tombe du ciel", bat != null and bat.emprise() == emprises[0] and not bat.pose())
				_verifier("carte : 'Barricade x1', Construire encore actif", _carte("barricade").get_node("Bouton").texte == "Construire"
					and _carte("barricade").get_node("Bouton").actif)
				for k in 2:
					_b()._construire("barricade")
					_b().placer_fantome([P2, P3][k])
					_verifier("barricade %d : fantome vert" % (k + 2), _vert())
					centres.append(_b()._centre_fantome); emprises.append(_b()._fantome.emprise())
					_b().poser_construction()
				_verifier("3 barricades, objets retires 3 fois %s" % partie.inventaire, partie.nombre_construit("barricade") == 3
					and partie.inventaire["conserve"] == 14 and partie.inventaire["eau"] == 7)
				_verifier("ids barricade, barricade_2, barricade_3", _b()._batiments.has("barricade") and _b()._batiments.has("barricade_2")
					and _b()._batiments.has("barricade_3"))
				# Sur une barricade déjà posée : refusé
				_b()._construire("barricade")
				_b().placer_fantome(centres[1])
				_verifier("sur une barricade posee : rouge (%s)" % _b().raison_refus(), _rouge() and _b().raison_refus() == "obstacle")
				_b().annuler_placement()
				_heros().get_node("Camera2D").zoom = Vector2(0.55, 0.55)
				_heros().position = Vector2(1350, 900)
			if g == 150:
				_snap("3_barricades")
				_heros().get_node("Camera2D").zoom = Vector2.ONE
				# Recharger la sauvegarde : mêmes positions
				partie.poses = []; partie.constructions = []
				partie.charger()
				change_scene_to_file("res://scenes/base.tscn")
			if g == 180:
				var pareil = true
				for k in 3:
					var id = "barricade" if k == 0 else "barricade_%d" % (k + 1)
					var bat = _b()._batiments.get(id)
					pareil = pareil and bat != null and bat.emprise().get_center().distance_to(emprises[k].get_center()) < 0.01
				_verifier("3 barricades rechargees aux memes positions", pareil)
				_verifier("carte 'x3' : nombre 3", partie.nombre_construit("barricade") == 3)
				# Collision avec chaque barricade
				var bloque = true
				for e in emprises:
					if not _heros().test_move(Transform2D(0.0, Vector2(e.position.x - 30, e.get_center().y)), Vector2(80, 0)): bloque = false
				_verifier("collision avec chaque barricade", bloque)
				_verifier("une seule barricade donne un coeur : %d" % partie.heros_pv(), partie.heros_pv() == reg.HEROS_PV + reg.BARRICADE_COEURS)
				_verifier("carte barricade : %s" % partie.effet("barricade"), partie.effet("barricade") != "" and not "cœur" in partie.effet("barricade"))
				# Maximum atteint : plus de Construire
				var max_origine = reg.BARRICADE_MAX
				reg.BARRICADE_MAX = 3
				_carte("barricade").actualiser()
				_verifier("maximum atteint : bouton '%s' inactif" % _carte("barricade").get_node("Bouton").texte,
					not partie.peut_construire("barricade") and not _carte("barricade").get_node("Bouton").actif)
				reg.BARRICADE_MAX = max_origine
				_carte("barricade").actualiser()
				_verifier("sous le maximum : Construire actif", _carte("barricade").get_node("Bouton").actif and reg.BARRICADE_MAX == 20)
				_verifier("atelier unique : %s" % partie.maximum("atelier"), partie.maximum("atelier") == 1)
				_aller("enferme")
		"enferme":
			# Héros dans le coin du bas à gauche : une barricade à sa droite, puis une au-dessus refermerait le coin
			if g == 1:
				_heros().position = Vector2(80, 1520)
				var w = taille_barricade.x; var h = taille_barricade.y
				var r1 = Rect2(170, 1560 - h, w, h)
				var r2 = Rect2(40, 1560 - 2.0 * h, w, h)
				_verifier("coin assez large (%s)" % taille_barricade, w > 140.0)
				_b()._construire("barricade")
				_b().placer_fantome(_centre_pour(r1))
				_verifier("barricade a droite du heros : vert (%s) %s" % [_b().raison_refus(), _b()._fantome.emprise()], _vert())
				_b().poser_construction()
				_b()._construire("barricade")
				_b().placer_fantome(_centre_pour(r2))
				_verifier("barricade qui enferme le heros : rouge (%s)" % _b().raison_refus(), _rouge() and _b().raison_refus() == "chemin")
				_verifier("consigne '%s'" % _ui("Consigne").text, _ui("Consigne").visible and _ui("Consigne").text == _b().RAISONS["chemin"])
				_verifier("Poser inactif", not _ui("Poser").actif)
			if g == 40:
				_snap("enferme")
				# Retour Android pendant le placement : annule
				root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
			if g == 60:
				_verifier("retour Android : placement annule, toujours dans la base (%s)" % current_scene.name,
					current_scene.name == "Base" and not _b().en_placement() and partie.nombre_construit("barricade") == 4)
				_aller("v7")
		"v7":
			if g == 1:
				_effacer()
				var v7 = {"version": 7, "inventaire": {"conserve": 3}, "constructions": ["barricade", "atelier", "infirmerie"],
					"remede": 1, "remede_annonce": false, "skin": "heros", "prenom": "Eliott", "rescapes": 1,
					"lieux_sauves": ["maison"], "batiments_vus": ["abri_2", "feu", "barricade", "atelier", "tente_1"], "etoiles": {"maison": 3}}
				var f = FileAccess.open(FICHIER, FileAccess.WRITE)
				f.store_string(JSON.stringify(v7)); f.close()
				partie.charger()
				var lu = _lire()
				_verifier("v7 reprise : version %s, constructions %s" % [lu["version"], lu["constructions"]],
					lu["version"] == 8.0 and lu["constructions"] == v7["constructions"] and lu["inventaire"]["conserve"] == 3.0 and lu["prenom"] == "Eliott")
				_verifier("v7 reprise : poses d'origine %s" % [lu["poses"]], lu["poses"].size() == 2
					and lu["poses"][0]["nom"] == "barricade" and Vector2(lu["poses"][0]["x"], lu["poses"][0]["y"]) == partie.PLACES_DEPART["barricade"]
					and lu["poses"][1]["nom"] == "atelier" and Vector2(lu["poses"][1]["x"], lu["poses"][1]["y"]) == partie.PLACES_DEPART["atelier"])
				change_scene_to_file("res://scenes/base.tscn")
			if g == 30:
				var bat = _b()._batiments.get("barricade")
				_verifier("v7 : barricade a sa place d'origine, posee (deja vue)", bat != null and bat.pose()
					and bat.emprise().get_center().distance_to(partie.PLACES_DEPART["barricade"]) < 60.0)
				_verifier("v7 : tente du rescape", _b()._batiments.has("tente_1"))
				_effacer()
				print("test_ab : %d échec(s)" % echecs)
				quit()
