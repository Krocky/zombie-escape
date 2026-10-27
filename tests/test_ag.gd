extends SceneTree
## Lot 4 (g) : tourelles. Construction par le placement (comme les barricades) jusqu'au maximum de 4 (carte « x4 »,
## puis « Construit ») ; sans zombie, une tourelle chargée ne tire pas ; une boîte de balles ramassée au supermarché
## va dans l'inventaire (écran de fin), jamais dans les trouvailles des rescapés ; Recharger près d'une tourelle
## (bouton >= 100 px, plafond de capacité, caché sans boîte) ; tir sur un zombie ajouté dans la base par le test
## (balles consommées, dégâts, arrêt à 0 balle) ; sauvegarde version 9 (balles de chaque tourelle) et reprise
## d'une version 8. Captures : tourelles, fin avec la boîte, recharge, tir.
## Affiche « ECHEC » à chaque vérification ratée. Efface la sauvegarde à la fin.
var g := 0
var phase := "depart"
var partie
var reg
var iso
var echecs := 0
var zombie: Node2D = null
var pv_apres := 0
const FICHIER := "user://sauvegarde.json"
const INVENTAIRE := {"conserve": 10, "eau": 2, "piles": 20}
## Places des 4 tourelles (centre de l'emprise, monde)
const PLACES := [Vector2(950, 1050), Vector2(1450, 1200), Vector2(1450, 450), Vector2(1300, 1050)]


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")
	iso = root.get_node("Iso")


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_ag_%s.png" % n)
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
	partie.balles_tourelles = []
func _b(): return current_scene
func _ui(n): return current_scene.get_node("Interface/" + n)
func _heros(): return current_scene.get_node("Monde/Heros")
func _carte(nom):
	for c in _ui("Constructions").get_children():
		if c.construction == nom: return c
func _lire():
	return JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
func _paysage() -> bool:
	return root.get_visible_rect().size.x > root.get_visible_rect().size.y
## Met le héros juste devant une tourelle (sous son emprise, dans le monde)
func _pres_de(t) -> void:
	_heros().position = t.emprise().get_center() + Vector2(0, t.emprise().size.y / 2.0 + 40)
## Fixe les balles d'une tourelle (partie et bâtiment)
func _balles(k: int, n: int) -> void:
	partie.balles_tourelles[k] = n
	_b()._tourelles[k].balles = n


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
				_verifier("carte Tourelle dans le tiroir, effet « %s »" % partie.effet("tourelle"),
					_carte("tourelle") != null and partie.effet("tourelle") != "" and partie.maximum("tourelle") == 4)
				_b().ouvrir_tiroir(true)
			if g == 60: _touch(_centre(_carte("tourelle").get_node("Bouton")), true)
			if g == 66: _touch(Vector2.ZERO, false)
			if g == 90:
				_verifier("Construire -> placement de la tourelle", _b().en_placement() and _b()._placement == "tourelle")
				_b().placer_fantome(PLACES[0])
				_verifier("fantome vert en %s (%s), sans nombre de balles" % [PLACES[0], _b().raison_refus()],
					_b().raison_refus() == "" and _b()._fantome.montrer_balles == false)
				_touch(_centre(_ui("Poser")), true)
			if g == 96: _touch(Vector2.ZERO, false)
			if g == 110:
				_verifier("1re tourelle posee, objets retires %s" % partie.inventaire, partie.nombre_construit("tourelle") == 1
					and partie.inventaire["piles"] == 17 and partie.inventaire["conserve"] == 9 and partie.balles_tourelles == [0])
				_verifier("carte : « Construire » encore actif", _carte("tourelle").get_node("Bouton").actif)
				# Les 3 suivantes directement
				for k in range(1, 4):
					_b().commencer_placement("tourelle")
					_b().placer_fantome(PLACES[k])
					_verifier("tourelle %d : place libre en %s (%s)" % [k + 1, PLACES[k], _b().raison_refus()], _b().raison_refus() == "")
					_b().poser_construction()
			if g == 200:
				_verifier("4 tourelles construites, 4 dans la base", partie.nombre_construit("tourelle") == 4 and _b()._tourelles.size() == 4)
				_verifier("maximum atteint : plus constructible, carte « Construit »", not partie.peut_construire("tourelle")
					and _carte("tourelle").get_node("Bouton").texte == "Construit" and not _carte("tourelle").get_node("Bouton").actif)
				_verifier("inventaire %s (4 x 3 piles + 1 conserve)" % partie.inventaire, partie.inventaire["piles"] == 8 and partie.inventaire["conserve"] == 6)
				var lu = _lire()
				_verifier("sauvegarde version %s, tourelles %s" % [lu["version"], lu["tourelles"]],
					lu["version"] == partie.VERSION and lu["tourelles"] == [0.0, 0.0, 0.0, 0.0]
					and lu["poses"].filter(func(p): return p["nom"] == "tourelle").size() == 4)
				_verifier("Recharger cache sans boite de balles", not _b()._recharger.visible)
				# Pas de zombie : une tourelle chargée ne tire pas
				_balles(0, 5)
				_pres_de(_b()._tourelles[0])
			if g == 230:
				_b().ouvrir_tiroir(true)
			if g == 260:
				_snap("tiroir_" + ("paysage" if _paysage() else "portrait"))
				_b().ouvrir_tiroir(false)
			if g == 320:
				_verifier("sans zombie : aucun tir (5 balles)", _b()._tourelles[0].balles == 5 and partie.balles_tourelles[0] == 5)
				_snap("tourelles_" + ("paysage" if _paysage() else "portrait"))
				_aller("lieu")
		"lieu":
			# Boîte de balles ramassée au supermarché, rapportée ; les rescapés n'en trouvent jamais
			if g == 1:
				reg.LIEUX_VARIES = false
				partie.choisir_lieu("supermarche")
				partie.rescapes = 30   # beaucoup de trouvailles : aucune ne doit être une boîte de balles
				change_scene_to_file(partie.scene_lieu())
			if g == 40:
				var balles = current_scene.get_node("Monde/ObjetBalles")
				_verifier("boite de balles dans le supermarche, comptee dans les objets",
					balles.type == "balles" and current_scene._total_objets == 6)
				_heros().position = balles.position
			if g == 60:
				_verifier("boite ramassee", "balles" in current_scene._ramasses)
				_heros().position = current_scene.get_node("Monde/Sortie").position + Vector2(0, 30)
			if g == 140:
				_verifier("ecran de fin", current_scene.name == "Fin")
				var r = partie.resultat
				_verifier("boite rapportee, dans l'inventaire (%s)" % partie.inventaire.get("balles", 0),
					"balles" in r["rapportes"] and partie.inventaire.get("balles", 0) == 1)
				_verifier("ni bonus ni trouvailles en balles ou fiole (%d trouvailles)" % r["trouvailles"].size(),
					r["trouvailles"].size() == 30 and not "balles" in r["trouvailles"] + r["bonus"] and not "fiole" in r["trouvailles"] + r["bonus"])
				partie.rescapes = 0
				partie.sauvegarder()
			if g == 170:
				_snap("fin_" + ("paysage" if _paysage() else "portrait"))
				reg.LIEUX_VARIES = true
				_aller("recharge")
		"recharge":
			if g == 1:
				partie.inventaire["balles"] = 4
				partie.sauvegarder()
				change_scene_to_file("res://scenes/base.tscn")
			if g == 40:
				_verifier("4 tourelles revenues avec leurs balles %s" % [partie.balles_tourelles],
					_b()._tourelles.size() == 4 and _b()._tourelles[0].balles == 5 and _b()._tourelles[1].balles == 0)
				_pres_de(_b()._tourelles[1])
			if g == 60:
				var bouton = _b()._recharger
				_verifier("Recharger visible et actif pres d'une tourelle vide", bouton.visible and bouton.actif)
				_verifier("Recharger >= 100 px, dans l'ecran", bouton.size.x >= 100 and bouton.size.y >= 100
					and _b().get_viewport_rect().encloses(bouton.get_global_rect()))
				_snap("recharger_" + ("paysage" if _paysage() else "portrait"))
				_touch(_centre(bouton), true)
			if g == 66: _touch(Vector2.ZERO, false)
			if g == 80:
				_verifier("recharge plafonnee : %d balles (capacite %d), %d boite(s) restante(s)" % [partie.balles_tourelles[1],
					reg.TOURELLE_CAPACITE, partie.inventaire["balles"]], partie.balles_tourelles[1] == 30
					and _b()._tourelles[1].balles == 30 and partie.inventaire["balles"] == 1)
				_verifier("tourelle pleine : Recharger inactif", _b()._recharger.visible and not _b()._recharger.actif)
				var lu = _lire()
				_verifier("sauvegarde : %s" % [lu["tourelles"]], lu["tourelles"] == [5.0, 30.0, 0.0, 0.0] and lu["inventaire"]["balles"] == 1.0)
				_pres_de(_b()._tourelles[0])
			if g == 100:
				_touch(_centre(_b()._recharger), true)
			if g == 106: _touch(Vector2.ZERO, false)
			if g == 130:
				_verifier("2e tourelle : 5 + 10 = %d, plus de boite, Recharger cache" % partie.balles_tourelles[0],
					partie.balles_tourelles[0] == 15 and partie.inventaire["balles"] == 0 and not _b()._recharger.visible)
				_aller("tir")
		"tir":
			if g == 1:
				for k in 4:
					_balles(k, 0)
				_balles(2, 3)
				_heros().position = Vector2(700, 1160)
				# Un gros zombie (5 PV) ajouté par le test, à portée de la tourelle 3 seulement
				zombie = load("res://scenes/zombie.tscn").instantiate()
				zombie.type = 0
				zombie.patrouille = Vector2.ZERO
				zombie.position = PLACES[2] + Vector2(250, 0)
				_b().get_node("Monde").add_child(zombie)
				var v = zombie.visuels()
				_b().get_node("Vue").add_child(v["vue"])
				_b().get_node("Reperes").add_child(v["repere"])
			if g == 20:
				_heros().position = PLACES[2] + Vector2(-60, 200)   # la caméra montre la tourelle et le zombie
			# Capture pendant un tir (éclair et trace)
			if g > 30 and g < 200 and zombie._pv == 4 and _b()._tourelles[2]._tir > 0.12:
				_snap("tir_" + ("paysage" if _paysage() else "portrait"))
			if g == 240:
				var t = _b()._tourelles[2]
				_verifier("3 balles tirees : tourelle a 0 (%d), partie a 0 (%d)" % [t.balles, partie.balles_tourelles[2]],
					t.balles == 0 and partie.balles_tourelles[2] == 0)
				_verifier("degats : le gros zombie a %d PV (5 - 3)" % zombie._pv, zombie._pv == 5 - 3 * reg.TOURELLE_DEGATS)
				_verifier("les autres tourelles n'ont pas tire", _b()._tourelles[0].balles == 0 and _b()._tourelles[1].balles == 0)
				pv_apres = zombie._pv
				# Capture de contrôle : la trace du dernier tir gardée affichée (le rendu a du retard sur les tirs)
				_b()._tourelles[2]._tir = 100.0
			if g == 280:
				_snap("trace_" + ("paysage" if _paysage() else "portrait"))
				_b()._tourelles[2]._tir = 0.0
			if g == 360:
				_verifier("plus de balle : plus de tir (%d PV)" % zombie._pv, zombie._pv == pv_apres)
				_aller("sortie")
		"sortie":
			if g == 1:
				change_scene_to_file("res://scenes/carte.tscn")   # quitter la base sauvegarde les balles tirées
			if g == 20:
				_verifier("balles tirees sauvegardees : %s" % [_lire()["tourelles"]], _lire()["tourelles"] == [0.0, 0.0, 0.0, 0.0])
				_aller("reprise")
		"reprise":
			# Une sauvegarde version 8 (sans balles) est reprise : tourelles vides, réécrite en version 9
			if g == 1:
				var v8 := {"version": 8, "inventaire": {"conserve": 3, "piles": 2}, "constructions": ["barricade"],
					"remede": 0, "remede_annonce": false, "skin": "heros", "prenom": "Eliott", "rescapes": 0, "lieux_sauves": [],
					"batiments_vus": [], "etoiles": {}, "poses": [{"nom": "barricade", "x": 950.0, "y": 1050.0}]}
				var f = FileAccess.open(FICHIER, FileAccess.WRITE)
				f.store_string(JSON.stringify(v8)); f.close()
				_effacer_memoire()
				partie.charger()
				var lu = _lire()
				_verifier("version 8 reprise : %s, inventaire %s, balles %s" % [lu["version"], partie.inventaire, partie.balles_tourelles],
					lu["version"] == partie.VERSION and lu["tourelles"] == [] and partie.balles_tourelles == []
					and partie.inventaire["conserve"] == 3 and partie.nombre_construit("barricade") == 1 and partie.prenom == "Eliott")
				_effacer()
				print("== test_ag : ", "tout est OK" if echecs == 0 else "%d ECHEC(S)" % echecs)
				quit()


func _effacer_memoire():
	partie.inventaire = {}; partie.constructions = []; partie.poses = []; partie.balles_tourelles = []; partie.prenom = ""
