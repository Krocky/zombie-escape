extends CanvasLayer
## Interface tactile. Relaie les commandes du joueur vers le niveau par signaux.

signal deplacement(direction: Vector2)
signal attaque


func _ready() -> void:
	$Joystick.direction_changee.connect(deplacement.emit)
	$BoutonAttaquer.couleur = Palette.LAMPE
	$BoutonAttaquer.appuye.connect(attaque.emit)


func afficher_pv(pv: int, pv_max: int) -> void:
	$JaugePV.afficher(pv, pv_max)
