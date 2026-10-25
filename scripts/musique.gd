extends Node
## Musique de fond (« Zombie Escape Groove », fournie par le père) : jouée en boucle, sans
## coupure d'un écran à l'autre (autoload, il ne change jamais de scène).


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var son := load("res://sons/musique.mp3") as AudioStreamMP3
	if son == null:
		return
	son.loop = true
	var lecteur := AudioStreamPlayer.new()
	lecteur.stream = son
	lecteur.volume_db = Reglages.MUSIQUE_VOLUME
	add_child(lecteur)
	lecteur.play()
