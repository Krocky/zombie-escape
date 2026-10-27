extends SceneTree
## Lot 4 (e) : deux musiques. Piste « base » sur la base et la carte, sans redémarrage entre les deux (position de
## lecture qui continue) ; piste « niveaux » dans un lieu, après un fondu enchaîné (l'autre piste s'efface puis se
## met en pause) ; elle continue pendant la pause ; retour à la piste « base » sur l'écran de fin, reprise où elle
## en était ; la défense de la base (niveau 4) prend la piste « niveaux ». Les deux pistes bouclent.
## Affiche « ECHEC » à chaque vérification ratée.
var f := 0
var partie
var musique
var echecs := 0
var pos_base := 0.0
var pos_niveaux := 0.0


func _initialize():
	partie = root.get_node("Partie")
	musique = root.get_node("Musique")
	partie.remede = 0; partie.remede_annonce = false
	change_scene_to_file("res://scenes/base.tscn")


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _centre(n): return n.get_global_rect().get_center()
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1
func _lecteur(p) -> AudioStreamPlayer: return musique._lecteurs[p]


func _physics_process(_d):
	f += 1
	if f == 1:
		_verifier("deux pistes chargees, en boucle", musique._lecteurs.size() == 2
			and _lecteur("base").stream.loop and _lecteur("niveaux").stream.loop)
	if f == 30:
		_verifier("base : piste base (" + musique.piste() + ")", musique.piste() == "base")
		_verifier("base : piste base audible, niveaux muette", musique._gains["base"] == 1.0 and musique._gains["niveaux"] == 0.0)
		pos_base = musique.position_lecture("base")
		_touch(_centre(current_scene.get_node("Interface/Start")), true)
	if f == 36: _touch(Vector2.ZERO, false)
	if f == 100:
		_verifier("carte : scene " + current_scene.name, current_scene.name == "Carte")
		_verifier("carte : piste base", musique.piste() == "base" and _lecteur("base").playing and not _lecteur("base").stream_paused)
		var p: float = musique.position_lecture("base")
		_verifier("carte : pas de redemarrage (%.2f s puis %.2f s)" % [pos_base, p], p > pos_base)
		partie.choisir_lieu("supermarche")
		change_scene_to_file(partie.scene_lieu())
	if f == 110:
		_verifier("lieu : piste niveaux demandee", musique.piste() == "niveaux")
		_verifier("lieu : fondu en cours (base %.2f, niveaux %.2f)" % [musique._gains["base"], musique._gains["niveaux"]],
			musique._gains["base"] > 0.0 and musique._gains["niveaux"] < 1.0)
	if f == 200:
		_verifier("lieu : fondu fini (base %.2f, niveaux %.2f)" % [musique._gains["base"], musique._gains["niveaux"]],
			musique._gains["base"] == 0.0 and musique._gains["niveaux"] == 1.0)
		_verifier("lieu : piste base en pause, niveaux joue", _lecteur("base").stream_paused and _lecteur("niveaux").playing)
		pos_base = musique.position_lecture("base")
		current_scene.mettre_en_pause(true)
	if f == 230:
		pos_niveaux = musique.position_lecture("niveaux")
	if f == 260:
		var p: float = musique.position_lecture("niveaux")
		_verifier("pause : la musique des niveaux continue (%.2f s puis %.2f s)" % [pos_niveaux, p],
			paused and p > pos_niveaux and musique.piste() == "niveaux")
		current_scene.mettre_en_pause(false)
		current_scene._finir(false, 0.0)
	if f == 300:
		_verifier("fin : scene " + current_scene.name, current_scene.name == "Fin")
		_verifier("fin : piste base", musique.piste() == "base" and not _lecteur("base").stream_paused)
		var p: float = musique.position_lecture("base")
		_verifier("fin : piste base reprise ou elle en etait (%.2f s puis %.2f s)" % [pos_base, p], p >= pos_base and p < pos_base + 3.0)
	if f == 400:
		_verifier("fin : fondu fini, niveaux en pause", musique._gains["base"] == 1.0 and _lecteur("niveaux").stream_paused)
		change_scene_to_file("res://scenes/lieux/defense.tscn")
	if f == 430:
		_verifier("defense de la base : piste niveaux", current_scene.name == "Defense" and musique.piste() == "niveaux")
		print("test_ae : ", "tout OK" if echecs == 0 else "%d ECHEC(s)" % echecs)
		quit()
	return false
