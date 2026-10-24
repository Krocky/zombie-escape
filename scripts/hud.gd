extends CanvasLayer
## Interface tactile. Relaie les commandes du joueur vers le niveau par signaux.

signal deplacement(direction: Vector2)
signal attaque
signal cacher


func _ready() -> void:
	$Joystick.direction_changee.connect(deplacement.emit)
	$BoutonAttaquer.couleur = Palette.LAMPE
	$BoutonAttaquer.appuye.connect(attaque.emit)
	$BoutonCacher.couleur = Palette.CONGELATEUR
	$BoutonCacher.appuye.connect(cacher.emit)


func afficher_pv(pv: int, pv_max: int) -> void:
	$JaugePV.afficher(pv, pv_max)


## Le bouton Cacher n'est actif que près d'une cachette (ou pour en sortir).
func etat_cachette(proche: bool, cache: bool) -> void:
	$BoutonCacher.actif = proche or cache
	$BoutonCacher.texte = "Sortir" if cache else "Cacher"
	$BoutonAttaquer.actif = not cache
