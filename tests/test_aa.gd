extends SceneTree
## Lot 4 (a) : la base devient un parking où l'on marche. Une sauvegarde version 7 (toutes les constructions,
## 4 rescapés) est reprise sans rien perdre (réécrite en version 8 depuis le lot 4 b, constructions à leur place d'origine) ; aucun zombie, pas de bouton d'action ; chaque construction et chaque
## tente a ses pieds au sol dans son emprise, dans le parking, sans chevauchement, avec collision ; le héros arrive près
## de la voiture et se déplace au joystick ; une construction faite apparaît aussitôt et finit posée ; voiture -> Start
## -> Carte ; retour Android -> Titre. Captures : camp en paysage / portrait, chute, Start.
## Affiche « ECHEC » à chaque vérification ratée. Efface la sauvegarde à la fin.
var g := 0
var phase := "sauvegarde"
var partie
var reg
var echecs := 0
var depart := Vector2.ZERO
const FICHIER := "user://sauvegarde.json"
## Les pieds d'une image (ancre « pieds » = bas de l'ombre peinte sous le socle) sont dans l'emprise à ce nombre
## d'unités du monde près (une dizaine de pixels à l'écran)
const PRES := 16.0
const TOUS := ["abri_1", "abri_2", "feu", "barricade", "atelier", "lampe", "jardin", "tente_1", "tente_2", "tente_3", "tente_4"]
## Sauvegarde version 7 écrite à la main, comme celle de la tablette
var v7 := {"version": 7, "inventaire": {"conserve": 4, "eau": 2, "bandage": 1, "piles": 3, "fiole": 0},
	"constructions": ["barricade", "atelier", "lampe", "infirmerie", "jardin"], "remede": 2, "remede_annonce": false,
	"skin": "heroine", "prenom": "Lou", "rescapes": 4, "lieux_sauves": ["supermarche", "maison", "pharmacie"],
	"batiments_vus": TOUS, "etoiles": {"supermarche": 3, "maison": 2, "pharmacie": 1}}


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")
	partie.remede = 0


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _glisser(pos):
	var e = InputEventScreenDrag.new(); e.index = 0; e.position = pos
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_aa_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
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
## Emprise au sol de chaque obstacle du parking (bâtiments, voitures, blocs), murs exclus.
func _emprises():
	var liste = {}
	for e in current_scene.get_node("Monde").get_children():
		if e is StaticBody2D and not e.name.begins_with("Mur"):
			liste[e.name if not "id" in e else e.id] = e.emprise()
	return liste


## Contenu de la sauvegarde comparable (les nombres JSON sont relus en float).
func _lire():
	return JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
func _pareil(a, b) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


func _physics_process(_d):
	g += 1
	match phase:
		"sauvegarde":
			if g == 1:
				_effacer()
				var f = FileAccess.open(FICHIER, FileAccess.WRITE)
				f.store_string(JSON.stringify(v7)); f.close()
				partie.charger()
				_verifier("v7 relue : inventaire %s" % partie.inventaire, _pareil(partie.inventaire, v7["inventaire"]))
				_verifier("v7 relue : constructions %s" % [partie.constructions], partie.constructions == v7["constructions"])
				_verifier("v7 relue : remede %d, skin %s, prenom %s, rescapes %d" % [partie.remede, partie.skin, partie.prenom, partie.rescapes],
					partie.remede == 2 and partie.skin == "heroine" and partie.prenom == "Lou" and partie.rescapes == 4)
				_verifier("v7 relue : lieux sauves, batiments vus, etoiles", partie.lieux_sauves == v7["lieux_sauves"]
					and partie.batiments_vus == TOUS and _pareil(partie.etoiles_lieux, v7["etoiles"]))
				change_scene_to_file("res://scenes/base.tscn")
			if g == 40:
				var b = current_scene
				_verifier("scene %s (attendu Base)" % b.name, b.name == "Base")
				# Reprise : version 8, rien de perdu, constructions posées à leur place d'origine (lot 4 b)
				var lu = _lire()
				var attendu = JSON.parse_string(JSON.stringify(v7))
				var pareil = lu["version"] == partie.VERSION
				for cle in attendu:
					if cle != "version": pareil = pareil and _pareil(lu[cle], attendu[cle])
				var poses = []
				for nom in ["barricade", "atelier", "lampe", "jardin"]:
					poses.append({"nom": nom, "x": partie.PLACES_DEPART[nom].x, "y": partie.PLACES_DEPART[nom].y})
				_verifier("sauvegarde reprise en version 8, rien de perdu, poses d'origine %s" % [lu.get("poses")],
					pareil and _pareil(lu.get("poses"), JSON.parse_string(JSON.stringify(poses))))
				_verifier("aucun zombie", get_nodes_in_group("zombies").is_empty())
				var hud = b.get_node("HUD")
				var caches = true
				for n in [hud.get_node("BoutonAttaquer"), hud.get_node("BoutonCacher"), hud._soin, hud._guerir, hud._pause,
						hud.get_node("Objectif"), hud.get_node("CompteurObjets")]:
					caches = caches and not n.visible
				_verifier("HUD : ni Frapper, Cacher, Soigner, Guerir, Pause, ni objectif", caches)
				_verifier("HUD : joystick", hud.get_node("Joystick").visible)
				for n in ["Haut/Inventaire", "Remede", "Tiroir", "Reglages", "Heros"]:
					_verifier("interface : %s visible" % n, b.get_node("Interface/" + n).is_visible_in_tree())
				var voiture = b.get_node("Monde/Voiture")
				_verifier("heros a cote de la voiture (%d)" % voiture.distance_a(_heros().position),
					voiture.distance_a(_heros().position) <= reg.VOITURE_PORTEE)
				var start = b.get_node("Interface/Start")
				_verifier("Start visible pres de la voiture, %s >= 100 px" % start.size, start.visible and start.size.x >= 100 and start.size.y >= 100)
				_verifier("lampe du heros eteinte", not _heros()._lampe.enabled and not _heros()._halo.enabled)
				_verifier("base eclairee (pas de nuit noire)", b.get_node("Nuit").color.get_luminance() > 0.5)
				# Le camp : chaque bâtiment posé au sol, ses pieds dans son emprise, dans le parking
				var parking = Rect2(40, 40, b.taille.x - 80, b.taille.y - 80)
				var ids = b._batiments.keys()
				ids.sort()
				var attendus = TOUS.duplicate(); attendus.erase("abri_1"); attendus.sort()
				_verifier("batiments %s" % [ids], ids == attendus)
				for id in ids:
					var bat = b._batiments[id]
					var e = bat.emprise()
					_verifier("%s : pose, pieds %s dans l'emprise %s, dans le parking" % [id, bat.pieds().round(), e],
						bat.pose() and e.grow(PRES).has_point(bat.pieds()) and parking.encloses(e))
				for k in 4:
					var tente = b._batiments["tente_%d" % (k + 1)]
					var r = b._rescapes.get("tente_%d" % (k + 1))
					_verifier("tente_%d dans le coin du fond a droite, son rescape %s" % [k + 1, r.perso if r else "absent"],
						tente.emprise().get_center().x > b.taille.x * 0.7 and tente.emprise().get_center().y < b.taille.y * 0.5 and r != null)
				var emprises = _emprises()
				var noms = emprises.keys()
				var libres = true
				for i in noms.size():
					for j in range(i + 1, noms.size()):
						if emprises[noms[i]].intersects(emprises[noms[j]]):
							print("  chevauchement: ", noms[i], " / ", noms[j]); libres = false
				_verifier("aucun chevauchement entre bâtiments, voitures et blocs (%d)" % noms.size(), libres)
				# Collision : le héros posé à gauche de chaque emprise ne peut pas avancer dedans
				var h = _heros()
				var bloque = true
				for nom in emprises:
					var e = emprises[nom]
					var t = Transform2D(0.0, Vector2(e.position.x - 30, e.get_center().y))
					if not h.test_move(t, Vector2(80, 0)):
						print("  pas de collision: ", nom); bloque = false
				_verifier("collision avec chaque bâtiment, voiture et bloc", bloque)
				_snap("depart_" + ("paysage" if b.get_viewport_rect().size.x > b.get_viewport_rect().size.y else "portrait"))
				h.get_node("Camera2D").zoom = Vector2(0.5, 0.5)
				h.position = Vector2(1450, 800)   # au milieu du camp, libre
			if g == 100:
				_snap("camp")
				_heros().get_node("Camera2D").zoom = Vector2.ONE
				_heros().position = Vector2(720, 1160)
				_aller("marche")
		"marche":
			var doigt = Vector2(220, root.get_visible_rect().size.y - 260)
			if g == 10:
				depart = _heros().position
				_touch(doigt, true)
			if g >= 12 and g < 50: _glisser(doigt + Vector2(140, 0))
			if g == 50:
				var d = _heros().position.distance_to(depart)
				_verifier("le heros marche au joystick (%d)" % d, d > 100)
				_verifier("Start cache loin de la voiture", not current_scene.get_node("Interface/Start").visible)
				_touch(doigt + Vector2(140, 0), false)
				_snap("marche")
			if g == 60:
				# Une construction faite apparaît aussitôt à sa place et tombe du ciel
				partie.constructions.erase("jardin"); partie.batiments_vus.erase("jardin")
				partie.inventaire = {"conserve": 2, "eau": 2}
				partie.sauvegarder()
				change_scene_to_file("res://scenes/base.tscn")
			if g == 80:
				_verifier("sans jardin", not current_scene._batiments.has("jardin"))
				current_scene.ouvrir_tiroir(true)
			if g == 100:
				for c in current_scene.get_node("Interface/Constructions").get_children():
					if c.construction == "jardin": _touch(_centre(c.get_node("Bouton")), true)
			if g == 106: _touch(Vector2.ZERO, false)
			if g == 112:
				# Lot 4 b : placement, puis Poser
				_verifier("jardin en placement", current_scene.en_placement() and current_scene.raison_refus() == "")
				_touch(_centre(current_scene.get_node("Interface/Poser")), true)
			if g == 118: _touch(Vector2.ZERO, false)
			if g == 124:
				var jardin = current_scene._batiments.get("jardin")
				_verifier("jardin construit et ajoute aussitot", partie.est_construit("jardin") and jardin != null and jardin.is_inside_tree())
				_verifier("jardin en train de tomber", jardin != null and not jardin.pose())
				_heros().position = jardin.emprise().get_center() + Vector2(0, 220)
			if g == 152: _snap("chute")
			if g == 200:
				var jardin = current_scene._batiments["jardin"]
				_verifier("jardin pose au sol, pieds dans l'emprise", jardin.pose() and jardin.emprise().grow(PRES).has_point(jardin.pieds()))
				_verifier("jardin vu (ne retombe plus)", "jardin" in partie.batiments_vus)
				_aller("voiture")
		"voiture":
			if g == 1: _heros().position = Vector2(720, 1160)
			if g == 10:
				var start = current_scene.get_node("Interface/Start")
				_verifier("Start visible pres de la voiture", start.visible)
				_snap("start")
				_touch(_centre(start), true)
			if g == 16: _touch(Vector2.ZERO, false)
			if g == 40:
				_verifier("Start -> %s (attendu Carte)" % current_scene.name, current_scene.name == "Carte")
				change_scene_to_file("res://scenes/base.tscn")
			if g == 60:
				root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
			if g == 80:
				_verifier("retour Android dans la base -> %s (attendu Titre)" % current_scene.name, current_scene.name == "Titre")
				_effacer()
				print("test_aa : %d échec(s)" % echecs)
				quit()
