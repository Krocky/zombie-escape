extends CanvasLayer
## Interface tactile. Relaie les commandes du joueur vers le niveau par signaux.

signal deplacement(direction: Vector2)
signal attaque
signal cacher

var _attente_ips := 0.0
var _pv := -1
var _flash := TextureRect.new()   # bords rouges quand le héros est touché
var _icones := Control.new()      # objets ramassés, sous le compteur
var _ramasses := []
var _nombre := 0


func _ready() -> void:
	$Joystick.direction_changee.connect(deplacement.emit)
	$BoutonAttaquer.couleur = Palette.LAMPE
	$BoutonAttaquer.icone = "batte"
	$BoutonAttaquer.appuye.connect(attaque.emit)
	$BoutonCacher.couleur = Palette.UI_BOUTON
	$BoutonCacher.icone = "cacher"
	$BoutonCacher.appuye.connect(cacher.emit)
	$CompteurObjets.add_theme_color_override("font_color", Palette.LAMPE)
	$CompteurObjets.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	# Cadre sombre arrondi derrière le compteur
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.UI_BORD
	cadre.set_border_width_all(3)
	cadre.set_corner_radius_all(20)
	cadre.content_margin_left = 16
	cadre.content_margin_right = 16
	$CompteurObjets.add_theme_stylebox_override("normal", cadre)
	$CompteurObjets.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$CompteurObjets.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Icônes des objets ramassés, en ligne sous le cadre
	_icones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icones.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_icones.position = Vector2(-324, 92)
	_icones.size = Vector2(300, 50)
	_icones.draw.connect(_dessiner_icones)
	add_child(_icones)
	$Objectif.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Objectif.visible = false
	get_viewport().size_changed.connect(_placer_objectif)
	_placer_objectif()
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
		$Ips.text = "%d ips%s" % [Engine.get_frames_per_second(), " (qualité basse)" if Qualite.basse else ""]


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
	$BoutonCacher.icone = "sortir" if cache else "cacher"
	$BoutonAttaquer.actif = not cache


## types : les objets ramassés (pour leurs icônes).
func afficher_objets(ramasses: int, total: int, types := []) -> void:
	$CompteurObjets.text = "Objets : %d / %d" % [ramasses, total]
	_ramasses = types
	_icones.queue_redraw()
	if ramasses > _nombre:
		# Le compteur saute un peu à chaque objet
		var compteur: Label = $CompteurObjets
		compteur.pivot_offset = compteur.size / 2.0
		compteur.scale = Vector2(1.25, 1.25)
		create_tween().tween_property(compteur, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	_nombre = ramasses


## Objectif de la mission, en haut au centre ("" : caché). Vert quand il est rempli.
func afficher_objectif(texte: String, avancee: int, total: int) -> void:
	$Objectif.visible = texte != ""
	$Objectif.text = "Objectif : %s (%d/%d)" % [texte, avancee, total]
	$Objectif.add_theme_color_override("font_color", Palette.SORTIE if avancee >= total else Palette.UI_TEXTE)


## Entre les cœurs et le compteur en paysage ; sous eux en portrait (pas la place sur la même ligne).
func _placer_objectif() -> void:
	var ecran := get_viewport().get_visible_rect().size
	$Objectif.offset_top = 52.0 if ecran.x > ecran.y else 150.0
	$Objectif.offset_bottom = $Objectif.offset_top + 48.0


func _dessiner_icones() -> void:
	for i in _ramasses.size():
		Dessin.icone_objet(_icones, _ramasses[i], Vector2(_icones.size.x - 26 - i * 54, 46), 40.0)
