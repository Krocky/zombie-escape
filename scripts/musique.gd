extends Node
## Musique de fond, deux pistes jouées en boucle (lot 4 e) : « base » (« Zombie Escape Groove », sons/musique.mp3)
## sur la base, le titre, la carte, les réglages, le choix du héros, les écrans de fin et de parties ; « niveaux »
## (sons/musique_niveaux.mp3, générée par Eliott) dans les lieux et la défense de la base. La scène en cours choisit
## sa piste (`piste_musique()`, sinon « base ») ; on passe de l'une à l'autre en fondu enchaîné
## (Reglages.MUSIQUE_FONDU). Une piste qui s'efface est mise en pause, pas arrêtée : elle reprend où elle en était.
## Autoload toujours actif : la musique continue pendant la pause et d'un écran à l'autre sans coupure.

const FICHIERS := {"base": "res://sons/musique.mp3", "niveaux": "res://sons/musique_niveaux.mp3"}

var _lecteurs := {}     # piste -> AudioStreamPlayer
var _gains := {}        # piste -> 0..1 (amplitude du fondu)
var _piste := ""        # piste demandée


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in FICHIERS:
		var son := load(FICHIERS[p]) as AudioStreamMP3
		if son == null:
			continue
		son.loop = true
		var l := AudioStreamPlayer.new()
		l.stream = son
		add_child(l)
		_lecteurs[p] = l
		_gains[p] = 0.0
	_choisir(_piste_de_la_scene(), true)


func _process(delta: float) -> void:
	var p := _piste_de_la_scene()
	if p != _piste:
		_choisir(p, false)
	var pas := delta / maxf(Reglages.MUSIQUE_FONDU, 0.01)
	for q in _lecteurs:
		var l: AudioStreamPlayer = _lecteurs[q]
		var cible := 1.0 if q == _piste else 0.0
		_gains[q] = move_toward(_gains[q], cible, pas)
		if _gains[q] <= 0.0 and l.playing and not l.stream_paused:
			l.stream_paused = true
	regler_volume()


## Piste demandée par la scène en cours (« base » sans scène, par exemple pendant un changement d'écran : on garde
## alors la piste actuelle).
func _piste_de_la_scene() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return _piste if _piste != "" else "base"
	if scene.has_method("piste_musique"):
		return scene.piste_musique()
	return "base"


func _choisir(p: String, aussitot: bool) -> void:
	if not _lecteurs.has(p):
		p = "base"   # piste absente : on garde l'autre
	_piste = p
	if not _lecteurs.has(p):
		return
	var l: AudioStreamPlayer = _lecteurs[p]
	if l.stream_paused:
		l.stream_paused = false   # reprend où elle en était
	elif not l.playing:
		l.play()
	if aussitot:
		_gains[p] = 1.0
	regler_volume()


## Piste qui joue (pour les tests).
func piste() -> String:
	return _piste


## Position de lecture d'une piste en secondes (pour les tests).
func position_lecture(p: String) -> float:
	return _lecteurs[p].get_playback_position() if _lecteurs.has(p) else 0.0


## Appelé quand le volume change dans l'écran Réglages (et à chaque image pendant un fondu).
func regler_volume() -> void:
	for q in _lecteurs:
		var g: float = _gains[q]
		_lecteurs[q].volume_db = Reglages.MUSIQUE_VOLUME + (linear_to_db(g) if g > 0.0 else -80.0)
