extends CanvasLayer
## Interface tactile. Relaie les commandes du joueur vers le niveau par signaux.

signal deplacement(direction: Vector2)
signal attaque
signal cacher

var _attente_ips := 0.0
var _pv := -1
var _flash := TextureRect.new()   # bords rouges quand le héros est touché


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
	var degrade := Gradient.new()
	degrade.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	degrade.colors = PackedColorArray([Color(Palette.DEGATS, 0.0), Color(Palette.DEGATS, 0.2), Palette.DEGATS])
	var texture := GradientTexture2D.new()
	texture.gradient = degrade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.05, 0.5)
	_flash.texture = texture
	_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	move_child(_flash, 0)   # sous les boutons et les cœurs


## Images par seconde, mises à jour deux fois par seconde (test de fluidité).
func _process(delta: float) -> void:
	_attente_ips -= delta
	if _attente_ips <= 0.0:
		_attente_ips = 0.5
		$Ips.text = "%d ips" % Engine.get_frames_per_second()


func afficher_pv(pv: int, pv_max: int) -> void:
	$JaugePV.afficher(pv, pv_max)
	if _pv >= 0 and pv < _pv:
		# Flash rouge qui s'efface
		_flash.modulate.a = 1.0
		create_tween().tween_property(_flash, "modulate:a", 0.0, 0.5)
	_pv = pv


## Le bouton Cacher n'est actif que près d'une cachette (ou pour en sortir).
func etat_cachette(proche: bool, cache: bool) -> void:
	$BoutonCacher.actif = proche or cache
	$BoutonCacher.texte = "Sortir" if cache else "Cacher"
	$BoutonAttaquer.actif = not cache


func afficher_objets(ramasses: int, total: int) -> void:
	$CompteurObjets.text = "Objets : %d / %d" % [ramasses, total]
