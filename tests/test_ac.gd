extends SceneTree
## Lot 4 (c) : rescapés vivants dans la base. Sauvegarde avec 3 rescapés (et 10 rescapés : 10 tentes au plus) ;
## chaque rescapé apparaît devant sa tente, se promène (il se déplace) sans jamais entrer dans un obstacle (bâtiment,
## voiture, bloc, muret) ; le héros approche : il s'arrête, se tourne vers lui et une bulle « merci » apparaît,
## puis disparaît et ne revient pas avant le délai ; aller_devant_tente les amène devant leur tente et les y garde.
## Captures : promenade, bulle, devant les tentes, 10 tentes. Affiche « ECHEC » à chaque vérification ratée.
## Efface la sauvegarde à la fin.
var g := 0
var phase := "trois"
var partie
var reg
var echecs := 0
var departs := {}
var dans_obstacle := 0
var proche = null        # rescapé que le héros va voir
var delai_origine := 0.0
const FICHIER := "user://sauvegarde.json"
const TOUS := ["abri_1", "abri_2", "feu", "barricade", "atelier", "lampe", "jardin"]


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")
	partie.remede = 0
	delai_origine = reg.RESCAPE_BASE_DELAI_MERCI


func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_ac_%s.png" % n)
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1
func _aller(p):
	phase = p; g = 0
func _effacer():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.rescapes = 0; partie.lieux_sauves = []; partie.batiments_vus = []; partie.etoiles_lieux = {}
	partie.skin = ""; partie.prenom = ""
func _heros(): return current_scene.get_node("Monde/Heros")
func _rescapes(): return current_scene._rescapes.values()
## Sauvegarde : tout construit, n rescapés (lieux sauvés puis guéris), tout déjà vu (pas de chute).
func _base(n: int):
	_effacer()
	partie.constructions = ["barricade", "atelier", "lampe", "infirmerie", "jardin"]
	partie.rescapes = n
	partie.lieux_sauves = ["supermarche", "maison", "pharmacie"].slice(0, mini(n, 3))
	partie.skin = "heros"; partie.prenom = "Eliott"
	partie.batiments_vus = TOUS.duplicate()
	for k in n: partie.batiments_vus.append("tente_%d" % (k + 1))
	partie.sauvegarder()
	change_scene_to_file("res://scenes/base.tscn")
## Un rescapé est-il dans un obstacle ? (sa forme de collision chevauche le décor)
func _dans_obstacle(r) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new(); c.radius = 12.0
	q.shape = c; q.collision_mask = 1
	q.transform = Transform2D(0.0, r.global_position + Vector2(0, -8))
	return not r.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _physics_process(_d):
	g += 1
	match phase:
		"trois":
			if g == 1:
				reg.RESCAPE_BASE_PAUSE_MIN = 0.3; reg.RESCAPE_BASE_PAUSE_MAX = 0.6   # qu'ils partent vite
				_base(3)
			if g == 40:
				var b = current_scene
				_verifier("3 rescapes dans la base (%d)" % _rescapes().size(), _rescapes().size() == 3 and get_nodes_in_group("rescapes_base").size() == 3)
				var persos = _rescapes().map(func(r): return r.perso)
				_verifier("persos %s (ceux des lieux sauves)" % [persos], persos == partie.persos_base())
				var visibles = true
				for id in b._rescapes:
					var r = b._rescapes[id]
					visibles = visibles and r.actif and r.visuels()["vue"].visible and r.global_position.distance_to(b._batiments[id].devant()) < 60
					departs[r] = r.global_position
				_verifier("chacun visible, devant sa tente", visibles)
				_verifier("aucun zombie", get_nodes_in_group("zombies").is_empty())
				_heros().position = Vector2(400, 1100)   # loin d'eux : pas de merci
				_heros().get_node("Camera2D").zoom = Vector2(0.5, 0.5)
			if g > 40 and g <= 640:
				for r in _rescapes():
					if _dans_obstacle(r): dans_obstacle += 1
			if g == 300:
				_heros().position = Vector2(1450, 800)
			if g == 340: _snap("promenade")
			if g == 640:
				var bouges = 0
				for r in _rescapes():
					if r.global_position.distance_to(departs[r]) > 60: bouges += 1
				_verifier("les 3 rescapes se sont deplaces (%d)" % bouges, bouges == 3)
				_verifier("jamais dans un obstacle (%d pas fautifs)" % dans_obstacle, dans_obstacle == 0)
				var dans_parking = true
				for r in _rescapes():
					dans_parking = dans_parking and Rect2(40, 40, 2320, 1520).has_point(r.global_position)
				_verifier("tous dans le parking", dans_parking)
				# Le héros approche d'un rescapé (à 80, sous la portée de 120)
				proche = _rescapes()[0]
				_heros().position = Vector2(400, 1100)
				for r in _rescapes(): r._depuis_merci = INF
				_aller("merci")
		"merci":
			if g == 2:
				proche.liberer()
				_heros().position = proche.global_position + Vector2(-80, 0)
			if g == 6:
				_verifier("bulle quand le heros approche : « %s »" % proche.remercie(), proche.remercie() != "")
				var phrases = ["Merci de m'avoir sauvé !", "Sans toi, j'étais fichu !", "Merci Eliott !"]
				_verifier("phrase connue", proche.remercie() in phrases)
				_verifier("il s'est arrete", not proche.marche())
				_verifier("tourne vers le heros (a gauche)", proche._gauche)
				departs[proche] = proche.global_position
			if g == 40: _snap("merci")
			if g == 60:
				_verifier("il reste arrete pendant la bulle", proche.global_position.distance_to(departs[proche]) < 2.0 and proche.remercie() != "")
			if g == int(reg.RESCAPE_BASE_DUREE_MERCI * 60) + 12:
				_verifier("bulle finie apres %.1f s" % reg.RESCAPE_BASE_DUREE_MERCI, proche.remercie() == "")
			if g > int(reg.RESCAPE_BASE_DUREE_MERCI * 60) + 12 and g < 600:
				# Le héros reste tout près : pas de nouvelle bulle avant le délai (20 s)
				_heros().position = proche.global_position + Vector2(-80, 0)
				if proche.remercie() != "":
					_verifier("pas de nouvelle bulle avant le delai (pas %d)" % g, false)
					_aller("tente")
			if g == 600:
				_verifier("pas de nouvelle bulle avant le delai (10 s plus tard)", true)
				# Délai raccourci : la bulle revient
				reg.RESCAPE_BASE_DELAI_MERCI = 1.0
			if g == 620:
				_verifier("bulle de nouveau apres le delai", proche.remercie() != "")
				reg.RESCAPE_BASE_DELAI_MERCI = delai_origine
				_aller("tente")
		"tente":
			if g == 2:
				_heros().position = Vector2(400, 1100)
				current_scene.rescapes_aux_tentes(true)
			if g == 900:
				var b = current_scene
				var tous = true
				for id in b._rescapes:
					var r = b._rescapes[id]
					if not r.devant_tente():
						print("  ", id, " pas devant sa tente: ", r.global_position.round(), " / ", b._batiments[id].devant().round())
						tous = false
				_verifier("aller_devant_tente : tous devant leur tente", tous)
				for r in _rescapes(): departs[r] = r.global_position
				_heros().position = Vector2(1450, 800)
			if g == 930: _snap("tentes")
			if g == 1200:
				var restes = true
				for r in _rescapes():
					restes = restes and r.devant_tente() and r.global_position.distance_to(departs[r]) < 2.0
				_verifier("ils y restent (5 s plus tard)", restes)
				current_scene.rescapes_aux_tentes(false)
			if g == 1260:
				var libres = true
				for r in _rescapes(): libres = libres and not r.devant_tente()
				_verifier("liberes : ils repartent se promener", libres or _rescapes().any(func(r): return r.marche()))
				_aller("dix")
		"dix":
			if g == 1: _base(12)
			if g == 40:
				var b = current_scene
				_verifier("12 rescapes : 10 tentes et 10 personnages (%d, %d)" % [b._batiments_visibles().filter(func(i): return i.begins_with("tente_")).size(), _rescapes().size()],
					_rescapes().size() == 10 and b._batiments.has("tente_10") and not b._batiments.has("tente_11"))
				var dans = true
				for id in b._batiments:
					var t = b._batiments[id]
					if id.begins_with("tente_"):
						dans = dans and t.pose() and t.emprise().get_center().x > b.taille.x * 0.7
						for autre in b._batiments:
							if autre != id and t.emprise().intersects(b._batiments[autre].emprise()): dans = false
				_verifier("10 tentes posees dans le coin de droite, sans chevauchement", dans)
				var libres = true
				for r in _rescapes():
					if _dans_obstacle(r):
						print("  rescape dans un obstacle devant sa tente: ", r.global_position.round()); libres = false
				_verifier("chaque place devant une tente est libre", libres)
				_heros().position = Vector2(1700, 900)
				_heros().get_node("Camera2D").zoom = Vector2(0.5, 0.5)
			if g == 80: _snap("dix_tentes")
			if g == 100:
				_effacer()
				reg.RESCAPE_BASE_PAUSE_MIN = 2.0; reg.RESCAPE_BASE_PAUSE_MAX = 5.0
				print("test_ac : %d échec(s)" % echecs)
				quit()
