extends SceneTree
## Décor V3 de la base (parking où l'on marche depuis le lot 4 a) : bâtiments selon la sauvegarde (abri 1 puis 2 dès
## 2 constructions, feu, barricade, atelier, projecteur, une tente par rescapé), chute du ciel une seule fois
## (mémorisée, sauvegarde version 6), tiroir des constructions (fermé au départ, cartes intouchables fermé, se ferme
## après une construction, la construction apparaît aussitôt à sa place).
## Captures : 0 construction, puis 3 constructions + 2 rescapés. Efface la sauvegarde à la fin.
var f := 0
var partie
const FICHIER := "user://sauvegarde.json"


func _initialize():
	partie = root.get_node("Partie")
	_effacer()
	partie.skin = "heros"; partie.prenom = "Eliott"
	partie.inventaire = {"conserve": 3, "eau": 1, "piles": 3}
	partie.sauvegarder()
	change_scene_to_file("res://scenes/base.tscn")


func _effacer():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.rescapes = 0; partie.lieux_sauves = []; partie.batiments_vus = []


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_r_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
func _carte(nom):
	for c in current_scene.get_node("Interface/Constructions").get_children():
		if c.construction == nom: return c


## Aucun bouton ne se chevauche, tous dans l'écran.
func _boutons():
	var ecran = current_scene.get_viewport_rect()
	var noms = ["Interface/Tiroir", "Interface/Start", "Interface/Heros", "Interface/Reglages", "Interface/Remede", "Interface/Haut/Inventaire"]
	var ok = true
	for i in noms.size():
		var a = current_scene.get_node(noms[i]).get_global_rect()
		ok = ok and ecran.encloses(a)
		for j in range(i + 1, noms.size()):
			if a.intersects(current_scene.get_node(noms[j]).get_global_rect()):
				print("  chevauchement: ", noms[i], " / ", noms[j]); ok = false
	return ok


## Bâtiments qui vont tomber ou tombent encore.
func _chutes():
	var ids = []
	for id in current_scene._batiments:
		if current_scene._batiments[id]._chute >= 0.0: ids.append(id)
	return ids


func _physics_process(_d):
	f += 1
	if f == 10:
		var b = current_scene
		print("batiments: ", b._batiments_visibles(), " (attendu abri_1, feu)")
		print("chutes prevues: ", _chutes(), " vus: ", partie.batiments_vus)
		print("tiroir ferme au depart: ", not b.get_node("Interface/Constructions").visible, " bouton '", b.get_node("Interface/Tiroir").texte, "'")
		print("boutons dans l'ecran sans chevauchement: ", _boutons())
		# Toucher une carte fermée : rien
		_touch(_centre(_carte("barricade").get_node("Bouton")), true)
	if f == 16:
		_touch(Vector2.ZERO, false)
		print("carte touchee tiroir ferme: construite=", partie.est_construit("barricade"), " (attendu false)")
	if f == 150:
		_snap("0_construction")
		_touch(_centre(current_scene.get_node("Interface/Tiroir")), true)
	if f == 156: _touch(Vector2.ZERO, false)
	if f == 190:
		var b = current_scene
		print("tiroir ouvert: ", b.get_node("Interface/Constructions").visible, " bouton '", b.get_node("Interface/Tiroir").texte, "' cartes dans l'ecran: ",
			b.get_viewport_rect().encloses(b.get_node("Interface/Constructions").get_global_rect()))
		_snap("tiroir")
		_touch(_centre(_carte("barricade").get_node("Bouton")), true)
	if f == 196: _touch(Vector2.ZERO, false)
	if f == 230:
		var b = current_scene
		print("apres construction: barricade=", partie.est_construit("barricade"), " tiroir ferme: ", not b.get_node("Interface/Constructions").visible,
			" barricade a sa place: ", b._batiments.has("barricade") and b._batiments["barricade"].is_inside_tree(),
			" chute barricade: ", "barricade" in _chutes() or "barricade" in partie.batiments_vus)
		var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
		print("sauvegarde: version ", d["version"], " batiments_vus ", d["batiments_vus"])
		# 3 constructions + 2 rescapés : abri 2, atelier, projecteur, 2 tentes tombent
		partie.constructions = ["barricade", "atelier", "lampe"]; partie.rescapes = 2; partie.lieux_sauves = ["supermarche", "maison"]
		partie.sauvegarder()
		change_scene_to_file("res://scenes/base.tscn")
	if f == 240:
		print("batiments: ", current_scene._batiments_visibles())
		print("chutes prevues: ", _chutes(), " (attendu abri_2, atelier, lampe, tente_1, tente_2)")
		print("boutons dans l'ecran sans chevauchement: ", _boutons())
	# Instant figé juste après l'impact de l'abri (poussière, aplatissement) pour la capture
	if f == 250:
		var abri = current_scene._batiments["abri_2"]
		abri.set_process(false)
		abri._temps = abri._chute + abri.DUREE_CHUTE + 0.12
		abri._appliquer_chute()
		current_scene.get_node("Monde/Heros").position = abri.emprise().get_center() + Vector2(0, 260)
	if f == 290:
		_snap("chute")
		current_scene._batiments["abri_2"].set_process(true)
	if f == 420:
		_snap("3_constructions")
		# Revenir : plus aucune chute
		change_scene_to_file("res://scenes/base.tscn")
	if f == 430:
		print("retour a la base: chutes ", _chutes(), " (attendu [])")
		partie.charger()
		print("batiments vus relus: ", partie.batiments_vus)
		_effacer()
		quit()
