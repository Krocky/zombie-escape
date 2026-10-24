extends CanvasLayer
## Interface tactile. Relaie les commandes du joueur vers le niveau par signaux.

signal deplacement(direction: Vector2)
signal attaque
signal cacher

var _attente_ips := 0.0


func _ready() -> void:
	$Joystick.direction_changee.connect(deplacement.emit)
	$BoutonAttaquer.couleur = Palette.LAMPE
	$BoutonAttaquer.appuye.connect(attaque.emit)
	$BoutonCacher.couleur = Palette.CONGELATEUR
	$BoutonCacher.appuye.connect(cacher.emit)
	$CompteurObjets.add_theme_color_override("font_color", Palette.LAMPE)
	$CompteurObjets.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Ips.visible = Reglages.AFFICHER_IPS
	$Ips.add_theme_color_override("font_color", Palette.UI_TEXTE)
	$Ips.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	set_process(Reglages.AFFICHER_IPS)


## Images par seconde, mises à jour deux fois par seconde (test de fluidité).
func _process(delta: float) -> void:
	_attente_ips -= delta
	if _attente_ips <= 0.0:
		_attente_ips = 0.5
		$Ips.text = "%d ips" % Engine.get_frames_per_second()


func afficher_pv(pv: int, pv_max: int) -> void:
	$JaugePV.afficher(pv, pv_max)


## Le bouton Cacher n'est actif que près d'une cachette (ou pour en sortir).
func etat_cachette(proche: bool, cache: bool) -> void:
	$BoutonCacher.actif = proche or cache
	$BoutonCacher.texte = "Sortir" if cache else "Cacher"
	$BoutonAttaquer.actif = not cache


func afficher_objets(ramasses: int, total: int) -> void:
	$CompteurObjets.text = "Objets : %d / %d" % [ramasses, total]
