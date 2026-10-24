extends CanvasLayer
## Interface tactile. Relaie les commandes du joueur vers le niveau par signaux.

signal deplacement(direction: Vector2)


func _ready() -> void:
	$Joystick.direction_changee.connect(deplacement.emit)
