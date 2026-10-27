extends SceneTree
## Lot 4 (h2) : barricades qui cassent, ferraille, réparation. Dans la défense de la base (sans vague : le test fait
## entrer lui-même un zombie) : réparation d'une barricade abîmée avec le bouton Réparer tenu (un point toutes les
## REPARATION_DELAI s, une ferraille par point, héros arrêté), qui s'arrête sans ferraille ou au relâchement ; un
## zombie bloqué contre une barricade la frappe un coup par ZOMBIE_DELAI_CASSE jusqu'à l'effondrement, puis passe ;
## une barricade effondrée ne se répare pas. Après le niveau, les barricades de la base sont entières. Ferraille
## ramassée au supermarché puis rapportée dans l'inventaire (7 types dans le cadre de la base).
## Captures : réparation, barricade abîmée, effondrée, base, inventaire.
## Affiche « ECHEC » à chaque vérification ratée. Efface la sauvegarde à la fin.
var g := 0
var phase := "reparation"
var partie
var reg
var echecs := 0
var b_casse: Node2D = null     # barricade que le zombie casse
var b_repare: Node2D = null    # barricade que le héros répare
var zombie: Node2D = null
var coups := []                # pas où la solidité de b_casse a baissé
var solidites := []            # solidités successives de b_casse
var effondree_a := -1
var depart_heros := Vector2.ZERO
var ferraille_avant := 0
var tenu_a := -1               # pas où le bouton Réparer est tenu (le toucher simulé arrive quelques pas après)
var tenu_b := -1               # même chose, deuxième réparation
var a_casse := false           # le zombie a été vu en train de casser
var passe := false             # le zombie a passé la barricade effondrée
var FICHIER: String:   # sauvegarde de la partie en cours (lot 4 d)
	get:
		return root.get_node("Partie").fichier()
const ORIGINE := {"DEFENSE_DEBUT": 3.0, "BARRICADE_PV": 6, "ZOMBIE_DELAI_CASSE": 1.0, "REPARATION_DELAI": 0.5}
const PLACE_CASSE := Vector2(1500, 520)
const PLACE_REPARE := Vector2(600, 600)


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_ai_%s.png" % n)
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
func _bouton_reparer(): return _hud()._reparer
func _ferraille() -> int: return partie.inventaire.get("ferraille", 0)
func _collision_active(b) -> bool:
	for c in b.get_children():
		if c is CollisionShape2D:
			return not c.disabled
	return false


func _physics_process(_d):
	g += 1
	match phase:
		"reparation":
			if g == 1:
				_effacer()
				partie.prenom = "Eliott"; partie.skin = "heros"
				partie.constructions = ["barricade"]
				partie.poses = [["barricade", PLACE_CASSE], ["barricade", PLACE_REPARE]]
				partie.batiments_vus = ["abri_1", "feu", "barricade", "barricade_2"]
				partie.inventaire = {"conserve": 2, "ferraille": 2}
				partie.sauvegarder()
				reg.DEFENSE_DEBUT = 1000.0   # pas de vague : le test fait entrer son zombie
				reg.BARRICADE_PV = 6
				reg.ZOMBIE_DELAI_CASSE = 1.0
				reg.REPARATION_DELAI = 0.5
				partie.choisir_lieu("defense")
				change_scene_to_file(partie.scene_lieu())
			if g == 30:
				_verifier("niveau de defense (%s)" % current_scene.name, current_scene.name == "Defense")
				var liste = _d().barricades()
				_verifier("2 barricades dans la defense", liste.size() == 2)
				for b in liste:
					if b.emprise().has_point(PLACE_CASSE): b_casse = b
					if b.emprise().has_point(PLACE_REPARE): b_repare = b
				_verifier("barricades entieres au depart (%d)" % b_repare.solidite, b_repare.solidite == 6 and b_casse.solidite == 6
					and not b_repare.abimee())
				_heros().position = Vector2(PLACE_REPARE.x, b_repare.emprise().end.y + 60)
			if g == 40:
				_verifier("barricade entiere : pas de bouton Reparer", not _bouton_reparer().visible)
				for i in 3:
					b_repare.abimer()
			if g == 46:
				_verifier("barricade abimee (3/6) : bouton Reparer (%s)" % _bouton_reparer().visible,
					b_repare.solidite == 3 and _bouton_reparer().visible and _d().barricade_a_reparer() == b_repare)
				_verifier("bouton Reparer >= 100 px", _bouton_reparer().size.x >= 100 and _bouton_reparer().size.y >= 100)
				_touch(_bouton_reparer().get_global_rect().get_center(), true)
			if g > 46 and g < 100 and tenu_a < 0 and _bouton_reparer().tenu():
				tenu_a = g
				depart_heros = _heros().global_position
				_d()._sur_deplacement(Vector2.RIGHT)   # le joystick pousse : le héros ne bouge pas tant qu'il répare
			if g == 100:
				_verifier("bouton Reparer tenu (pas %d)" % tenu_a, tenu_a > 0)
			if tenu_a > 0 and g == tenu_a + 14:
				_verifier("tenu 0,23 s : pas encore de point (%d)" % b_repare.solidite, b_repare.solidite == 3 and _ferraille() == 2)
			if tenu_a > 0 and g == tenu_a + 40:
				_verifier("tenu 0,67 s : +1 point, 1 ferraille (%d, %d)" % [b_repare.solidite, _ferraille()], b_repare.solidite == 4 and _ferraille() == 1)
				_verifier("heros immobile pendant la reparation", _heros().global_position.distance_to(depart_heros) < 2.0)
				_snap("reparation_" + _sens())
			if g == 180:
				_verifier("sans ferraille : arret a 5/6 (%d, %d)" % [b_repare.solidite, _ferraille()], b_repare.solidite == 5 and _ferraille() == 0)
				_verifier("sans ferraille : bouton cache", not _bouton_reparer().visible)
				_verifier("bouton cache : le heros repart", _heros().global_position.distance_to(depart_heros) > 20.0)
				_d()._sur_deplacement(Vector2.ZERO)
				_touch(Vector2.ZERO, false)
			if g == 190:
				_heros().position = Vector2(PLACE_REPARE.x, b_repare.emprise().end.y + 60)
				partie.inventaire["ferraille"] = 5
				b_repare.abimer(); b_repare.abimer()
			if g == 200:
				_verifier("de nouveau abimee (3/6), bouton la", b_repare.solidite == 3 and _bouton_reparer().visible)
				_touch(_bouton_reparer().get_global_rect().get_center(), true)
			if g > 200 and g < 260 and tenu_b < 0 and _bouton_reparer().tenu():
				tenu_b = g
			if tenu_b > 0 and g == tenu_b + 40:
				_verifier("tenu 0,67 s : +1 (%d)" % b_repare.solidite, b_repare.solidite == 4 and _ferraille() == 4)
				_touch(_bouton_reparer().get_global_rect().get_center(), false)
			if g == 340:
				_verifier("relache : plus de reparation (%d, %d)" % [b_repare.solidite, _ferraille()], b_repare.solidite == 4 and _ferraille() == 4)
				_aller("casse")
		"casse":
			if g == 1:
				# Héros derrière la barricade, zombie devant : il marche vers le héros (aucun rescapé à la base)
				_heros().position = Vector2(PLACE_CASSE.x, b_casse.emprise().position.y - 330)
				zombie = _d().faire_entrer(0, Vector2(PLACE_CASSE.x, b_casse.emprise().end.y + 260))
				solidites = [b_casse.solidite]
			if zombie != null and is_instance_valid(zombie) and effondree_a < 0:
				a_casse = a_casse or zombie.casse_barricade()
				if b_casse.solidite != solidites[-1]:
					solidites.append(b_casse.solidite)
					coups.append(g)
				if b_casse.solidite == 3 and coups.size() == 3 and g == coups[-1] + 25:
					_snap("abimee_" + _sens())
				if not b_casse.solide():
					effondree_a = g
			if effondree_a > 0 and g == effondree_a + 3:
				_verifier("zombie bloque contre la barricade : il la casse", a_casse)
				_verifier("solidite point par point %s" % [solidites], solidites == [6, 5, 4, 3, 2, 1, 0])
				var ecarts := []
				for i in range(1, coups.size()):
					ecarts.append(coups[i] - coups[i - 1])
				_verifier("un coup par seconde %s" % [ecarts], ecarts.all(func(e): return absi(e - 60) <= 3))
				_verifier("effondree : ne bloque plus", not _collision_active(b_casse) and not b_casse.abimee())
			if effondree_a > 0 and g == effondree_a + 30:
				_snap("effondree_" + _sens())
				_verifier("barricade effondree : pas de bouton Reparer", partie.inventaire.get("ferraille", 0) > 0 and not _bouton_reparer().visible)
			if effondree_a > 0 and g > effondree_a + 3 and is_instance_valid(zombie) and not zombie._battu \
					and zombie.global_position.y < b_casse.emprise().position.y - 20:
				_verifier("le zombie passe la barricade effondree (%d pas)" % (g - effondree_a), true)
				passe = true
				zombie.recevoir_coup(99, zombie.global_position + Vector2(10, 0))
				_heros().position = Vector2(PLACE_CASSE.x, b_casse.emprise().end.y + 60)
			if effondree_a > 0 and g == effondree_a + 400:
				_verifier("pres de la barricade effondree : rien a reparer", _d().barricade_a_reparer() == null)
				_verifier("zombie passe et battu", passe and (not is_instance_valid(zombie) or zombie._battu))
				_d()._finir(false, 0.0)
				_aller("base")
			if g == 1500:
				_verifier("barricade effondree a temps (solidites %s)" % [solidites], false)
				_d()._finir(false, 0.0)
				_aller("base")
		"base":
			if g == 30:
				_verifier("fin de la defense (%s)" % current_scene.name, current_scene.name == "Fin")
				_verifier("ferraille depensee gardee (%d)" % _ferraille(), _ferraille() == 4)
				var lu = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
				_verifier("ferraille sauvegardee", lu["inventaire"].get("ferraille", 0) == 4.0)
				change_scene_to_file("res://scenes/base.tscn")
			if g == 80:
				var entieres := true
				var nombre := 0
				for id in _d()._batiments:
					if id.begins_with("barricade"):
						nombre += 1
						var b = _d()._batiments[id]
						entieres = entieres and b.solidite == b.solidite_max() and _collision_active(b)
				_verifier("base : %d barricades remises en etat" % nombre, nombre == 2 and entieres)
				_snap("base_" + _sens())
				_aller("ferraille")
		"ferraille":
			if g == 1:
				ferraille_avant = _ferraille()
				partie.choisir_lieu("supermarche")
				change_scene_to_file(partie.scene_lieu())
			if g == 30:
				var objets = get_nodes_in_group("objets").filter(func(o): return o.type == "ferraille")
				_verifier("une ferraille a trouver au supermarche", objets.size() == 1)
				_verifier("comptee dans les objets du lieu", partie.infos_lieu("supermarche")["objets"].has("ferraille"))
				_heros().position = objets[0].global_position
			if g == 45:
				_verifier("ferraille ramassee", _d()._ramasses.has("ferraille"))
				_d()._finir(true, 0.0)
			if g == 80:
				var r = partie.resultat
				_verifier("ferraille rapportee", r["rapportes"].has("ferraille") and not r["bonus"].has("ferraille")
					and not r["trouvailles"].has("ferraille"))
				_verifier("inventaire : %d -> %d ferraille" % [ferraille_avant, _ferraille()], _ferraille() == ferraille_avant + 1)
				_verifier("ferraille hors gains et hors objectifs", partie.HORS_GAINS.has("ferraille")
					and partie.texte_objectif("supermarche").find("ferraille") == -1)
				_snap("fin_" + _sens())
				change_scene_to_file("res://scenes/base.tscn")
			if g == 130:
				_verifier("inventaire de la base : 7 types", partie.NOMS.size() == 7)
				_snap("inventaire_" + _sens())
				for nom in ORIGINE:
					reg.set(nom, ORIGINE[nom])
				_effacer()
				print("== test_ai : ", "tout est OK" if echecs == 0 else "%d ECHEC(S)" % echecs)
				quit()
