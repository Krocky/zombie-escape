extends CanvasLayer
## Interface tactile. Relaie les commandes du joueur vers le niveau par signaux.

signal deplacement(direction: Vector2)
signal attaque
signal cacher
signal pause_demandee
signal soigner
signal guerir

const BOUTON := preload("res://scenes/bouton_tactile.tscn")
const TAILLE_PAUSE := Vector2(100, 100)
const TAILLE_SOIN := Vector2(110, 110)
const TAILLE_GUERIR := Vector2(110, 110)

var _attente_ips := 0.0
var _pv := -1
var _flash := TextureRect.new()   # bords rouges quand le héros est touché
var _icones := Control.new()      # objets ramassés, sous le compteur
var _ramasses := []
var _nombre := 0
var _rescape := Control.new()     # icône du rescapé, sous les cœurs
var _rescape_suit := false
var _clef := Control.new()        # clefs ramassées (teintes), sous l'icône du rescapé
var _clefs := []
var _pause: Control = BOUTON.instantiate()   # bouton Pause, en haut au centre sous l'objectif
var _soin: Control = BOUTON.instantiate()    # bouton Soigner, à gauche de Frapper
var _guerir: Control = BOUTON.instantiate()  # bouton Guérir (après le remède), à gauche de Cacher


func _ready() -> void:
	$Joystick.direction_changee.connect(deplacement.emit)
	$BoutonAttaquer.couleur = Palette.BOUTON_FRAPPER
	$BoutonAttaquer.icone = "batte"
	$BoutonAttaquer.appuye.connect(attaque.emit)
	$BoutonCacher.couleur = Palette.BOUTON_CACHER
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
	_rescape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rescape.position = Vector2(24, 92)
	_rescape.size = Vector2(72, 84)
	_rescape.visible = false
	_rescape.draw.connect(_dessiner_rescape)
	add_child(_rescape)
	_clef.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clef.position = Vector2(24, 184)
	_clef.size = Vector2(72, 72)
	_clef.visible = false
	_clef.draw.connect(_dessiner_clefs)
	add_child(_clef)
	_pause.texte = "Pause"
	_pause.icone = "pause"
	_pause.couleur = Palette.UI_BOUTON
	_pause.custom_minimum_size = TAILLE_PAUSE   # la scène impose 140 x 140
	_pause.appuye.connect(pause_demandee.emit)
	add_child(_pause)   # après le joystick : il prend le doigt avant lui
	_pause.size = TAILLE_PAUSE
	_soin.texte = "Soigner"
	_soin.icone = "soigner"
	_soin.couleur = Palette.SORTIE
	_soin.actif = false
	_soin.custom_minimum_size = TAILLE_SOIN
	_soin.appuye.connect(soigner.emit)
	add_child(_soin)
	_soin.size = TAILLE_SOIN
	_guerir.texte = "Guérir"
	_guerir.icone = "guerir"
	_guerir.couleur = Palette.BOUTON_GUERIR
	_guerir.actif = false
	_guerir.visible = false
	_guerir.custom_minimum_size = TAILLE_GUERIR
	_guerir.appuye.connect(guerir.emit)
	add_child(_guerir)
	_guerir.size = TAILLE_GUERIR
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


## Soigner n'est actif que si le héros est blessé et a un bandage (soins de la mission pas épuisés).
func etat_soin(possible: bool) -> void:
	_soin.actif = possible


## Guérir : caché tant que le remède n'est pas trouvé ; actif avec une fiole ramassée près d'un zombie.
func etat_guerison(visible: bool, possible: bool) -> void:
	_guerir.visible = visible
	_guerir.actif = visible and possible


## Délai entre deux coups : fraction restante (0 = Frapper disponible), jauge autour du bouton.
func afficher_recharge(fraction: float) -> void:
	$BoutonAttaquer.recharge = fraction


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


## Rescapé du lieu : caché s'il n'y en a pas ; grisé tant qu'il ne suit pas, en couleur quand il suit (il saute un peu).
func afficher_rescape(present: bool, suit: bool) -> void:
	_rescape.visible = present
	if suit and not _rescape_suit:
		_rescape.pivot_offset = _rescape.size / 2.0
		_rescape.scale = Vector2(1.3, 1.3)
		create_tween().tween_property(_rescape, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	_rescape_suit = suit
	_rescape.queue_redraw()


## Clefs ramassées (teintes de Palette.CLEF) : une icône par clef dans un cadre, caché sans clef ; elle saute en arrivant.
func afficher_clefs(teintes: Array) -> void:
	if teintes.size() > _clefs.size():
		_clef.pivot_offset = _clef.size / 2.0
		_clef.scale = Vector2(1.3, 1.3)
		create_tween().tween_property(_clef, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	_clefs = teintes.duplicate()
	_clef.visible = not _clefs.is_empty()
	_clef.queue_redraw()


func _dessiner_clefs() -> void:
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.LAMPE
	cadre.set_border_width_all(3)
	cadre.set_corner_radius_all(16)
	_clef.draw_style_box(cadre, Rect2(Vector2.ZERO, _clef.size))
	for i in _clefs.size():
		Dessin.icone_objet(_clef, "clef", Vector2(_clef.size.x / 2.0 + i * 8.0, _clef.size.y - 14.0 - i * 8.0), 44.0, Color.WHITE, _clefs[i])


func _dessiner_rescape() -> void:
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.SORTIE if _rescape_suit else Palette.UI_BORD
	cadre.set_border_width_all(3)
	cadre.set_corner_radius_all(16)
	_rescape.draw_style_box(cadre, Rect2(Vector2.ZERO, _rescape.size))
	var nom := Images.v3_pose(Partie.perso_rescape(Partie.lieu), "follow")
	var couleur := Color.WHITE if _rescape_suit else Color(0.4, 0.4, 0.48, 0.75)
	if nom != "":
		Images.v3_dessiner(_rescape, nom, Vector2(_rescape.size.x / 2.0, _rescape.size.y - 6), 72.0 / Images.v3_taille(nom).y, false, couleur)
	else:
		Dessin.cercle(_rescape, _rescape.size / 2.0, 20.0, couleur)


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
	_pause.position = Vector2((ecran.x - TAILLE_PAUSE.x) / 2.0, $Objectif.offset_bottom + 4.0)
	# Soigner : à gauche de Frapper, bas alignés
	_soin.position = Vector2(ecran.x + $BoutonAttaquer.offset_left - 24.0 - TAILLE_SOIN.x, ecran.y + $BoutonAttaquer.offset_bottom - TAILLE_SOIN.y)
	# Guérir : au-dessus de Soigner, à gauche de Cacher (bas alignés)
	_guerir.position = Vector2(ecran.x + $BoutonCacher.offset_left - 24.0 - TAILLE_GUERIR.x, ecran.y + $BoutonCacher.offset_bottom - TAILLE_GUERIR.y)


## Base (pas de zombie) : seul le joystick reste ; ni boutons d'action ni pause, ni cœurs, objets, objectif.
func mode_base() -> void:
	for noeud in [$BoutonAttaquer, $BoutonCacher, _pause, _soin, _guerir, $JaugePV, $CompteurObjets, $Objectif,
			_icones, _rescape, _clef]:
		noeud.visible = false


## Le jeu se fige : on oublie les doigts posés (joystick, boutons), leur lever n'arrivera pas.
func relacher() -> void:
	$Joystick.relacher()
	for bouton in [$BoutonAttaquer, $BoutonCacher, _pause, _soin, _guerir]:
		bouton.relacher()


func _dessiner_icones() -> void:
	for i in _ramasses.size():
		Dessin.icone_objet(_icones, _ramasses[i], Vector2(_icones.size.x - 26 - i * 54, 46), 40.0)
