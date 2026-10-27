extends Control
## Petit menu du bouton « Partie » de la base (lot 4 d) : Sauvegarder, Nouvelle partie, Mes parties, Fermer.
## Il couvre l'écran d'un voile sombre ; la base cache ses autres boutons tant qu'il est ouvert (les boutons tactiles
## captent les doigts partout). Il émet un signal par bouton, la base agit.

signal sauvegarder
signal nouvelle
signal mes_parties
signal ferme

const BOUTONS := ["Sauvegarder", "Nouvelle", "MesParties", "Fermer"]
const TAILLE_BOUTON := Vector2(420, 100)
const ECART := 22.0
const DUREE_MESSAGE := 1.5

var _message: Tween


func _ready() -> void:
	for noeud in [$Titre, $Message]:
		noeud.add_theme_color_override("font_color", Palette.LAMPE)
		noeud.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Message.add_theme_color_override("font_color", Palette.SORTIE)
	$Sauvegarder.couleur = Palette.SORTIE
	$Nouvelle.couleur = Palette.UI_BOUTON
	$MesParties.couleur = Palette.UI_BOUTON
	$Fermer.couleur = Palette.LAMPE
	$Sauvegarder.appuye.connect(sauvegarder.emit)
	$Nouvelle.appuye.connect(nouvelle.emit)
	$MesParties.appuye.connect(mes_parties.emit)
	$Fermer.appuye.connect(ferme.emit)
	resized.connect(_placer)
	_placer()


## Ouvre le menu (titre = nom de la partie en cours) ou le ferme.
func ouvrir(ouvert: bool) -> void:
	visible = ouvert
	$Titre.text = Partie.nom_partie(Partie.en_cours)
	$Message.visible = false
	for nom in BOUTONS:
		get_node(nom).relacher()


## « Partie sauvegardée ! » pendant DUREE_MESSAGE secondes.
func afficher_message(texte: String) -> void:
	$Message.text = texte
	$Message.visible = true
	$Message.modulate.a = 1.0
	if _message:
		_message.kill()
	_message = create_tween()
	_message.tween_interval(DUREE_MESSAGE)
	_message.tween_callback(func() -> void: $Message.visible = false)


func message_visible() -> bool:
	return $Message.visible


## Titre puis les 4 boutons en colonne, au centre ; le message sous le dernier bouton.
func _placer() -> void:
	var hauteur := 70.0 + ECART + BOUTONS.size() * (TAILLE_BOUTON.y + ECART) + 60.0
	var y := (size.y - hauteur) / 2.0
	$Titre.size = Vector2(size.x - 48, 70)
	$Titre.position = Vector2(24, y)
	y += 70.0 + ECART
	for nom in BOUTONS:
		var bouton: Control = get_node(nom)
		bouton.custom_minimum_size = TAILLE_BOUTON   # la scène impose 140 x 140
		bouton.size = TAILLE_BOUTON
		bouton.position = Vector2((size.x - TAILLE_BOUTON.x) / 2.0, y)
		y += TAILLE_BOUTON.y + ECART
	$Message.size = Vector2(size.x - 48, 60)
	$Message.position = Vector2(24, y)
	queue_redraw()


## Voile sombre sur tout l'écran et cadre arrondi derrière les boutons.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.CONTOUR, 0.7))
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.CONTOUR
	cadre.set_border_width_all(5)
	cadre.set_corner_radius_all(28)
	var haut: float = $Titre.position.y - 24.0
	draw_style_box(cadre, Rect2(size.x / 2.0 - TAILLE_BOUTON.x / 2.0 - 40.0, haut, TAILLE_BOUTON.x + 80.0,
		$Message.position.y + 60.0 + 24.0 - haut))
