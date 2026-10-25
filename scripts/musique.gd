extends Node
## Musique de fond (« Zombie Escape Groove », fournie par le père) : jouée en boucle, sans
## coupure d'un écran à l'autre (autoload, il ne change jamais de scène).


var _lecteur: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var son := load("res://sons/musique.mp3") as AudioStreamMP3
	if son == null:
		return
	son.loop = true
	_lecteur = AudioStreamPlayer.new()
	_lecteur.stream = son
	add_child(_lecteur)
	regler_volume()
	_lecteur.play()


## Appelé quand le volume change dans l'écran Réglages.
func regler_volume() -> void:
	if _lecteur:
		_lecteur.volume_db = Reglages.MUSIQUE_VOLUME
