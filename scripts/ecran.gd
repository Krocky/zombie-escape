extends Node
## Adapte la taille de base au sens de l'écran : 1280x720 en paysage, 720x1280 en portrait.
## Ainsi les personnages et les boutons gardent la même taille dans les deux sens.


func _ready() -> void:
	get_tree().root.size_changed.connect(_adapter)
	_adapter()


func _adapter() -> void:
	var fenetre := get_tree().root
	var taille := DisplayServer.window_get_size()
	if taille.y > taille.x:
		fenetre.content_scale_size = Vector2i(720, 1280)
	else:
		fenetre.content_scale_size = Vector2i(1280, 720)
