extends Control
## Écran « Choisis ton héros » : garçon ou fille (images V3), et le prénom du joueur.
## Montré avant la première partie (depuis le titre), puis depuis le bouton « Héros » de la base.
## Le choix est sauvegardé (Partie.choisir_heros) ; « C'est parti ! » mène à la base.
## Toucher une carte la choisit : le héros choisi marche sur place dans la lumière de la lampe.

const ORDRE := ["heros", "heroine"]

var _choisi := Partie.perso()
var _depuis_base := Partie.skin != ""   # ouvert depuis la base (sinon depuis le titre, avant la première partie)
var _temps := 0.0
var _cartes := {}   # skin -> Rect2 à l'écran


func _ready() -> void:
	$Titre.add_theme_color_override("font_color", Palette.LAMPE)
	$Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Etiquette.add_theme_color_override("font_color", Palette.UI_TEXTE)
	$Etiquette.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	var champ: LineEdit = $Prenom
	champ.max_length = Partie.PRENOM_MAX
	champ.text = Partie.prenom
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.LAMPE
	cadre.set_border_width_all(5)
	cadre.set_corner_radius_all(20)
	champ.add_theme_stylebox_override("normal", cadre)
	champ.add_theme_stylebox_override("focus", cadre)
	champ.add_theme_color_override("font_color", Palette.UI_TEXTE)
	champ.add_theme_color_override("font_placeholder_color", Palette.UI_BORD * Color(1, 1, 1, 0.6))
	champ.text_submitted.connect(func(_t: String) -> void: champ.release_focus())
	$Valider.couleur = Palette.LAMPE
	$Valider.icone = "jouer"
	$Valider.appuye.connect(_valider)
	resized.connect(_placer)
	_placer()


## Paysage : prénom sous le titre, cartes côte à côte, bouton en bas.
## Portrait : pareil, en plus haut. Le prénom reste en haut pour ne pas être caché par le clavier.
func _placer() -> void:
	var paysage := size.x > size.y
	var y_prenom := 104.0 if paysage else 150.0
	var largeur_ligne: float = $Etiquette.size.x + 20.0 + $Prenom.size.x
	$Etiquette.position = Vector2((size.x - largeur_ligne) / 2.0, y_prenom)
	$Prenom.position = Vector2($Etiquette.position.x + $Etiquette.size.x + 20.0, y_prenom)
	$Valider.position = Vector2((size.x - $Valider.size.x) / 2.0, size.y - $Valider.size.y - (24.0 if paysage else 60.0))
	var haut := y_prenom + 110.0
	var bas: float = $Valider.position.y - 24.0
	var taille_carte := Vector2(minf(300.0, size.x * 0.42), minf(bas - haut, 520.0))
	haut += (bas - haut - taille_carte.y) / 2.0
	var ecart := 40.0
	_cartes[ORDRE[0]] = Rect2(Vector2(size.x / 2.0 - ecart / 2.0 - taille_carte.x, haut), taille_carte)
	_cartes[ORDRE[1]] = Rect2(Vector2(size.x / 2.0 + ecart / 2.0, haut), taille_carte)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch and event.pressed):
		return
	for skin in _cartes:
		if _cartes[skin].has_point(event.position):
			_choisi = skin
			$Prenom.release_focus()
			queue_redraw()


## Geste « retour » d'Android : écran précédent sans changer de héros (la base, ou le titre avant la première partie).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file.call_deferred("res://scenes/base.tscn" if _depuis_base else "res://scenes/titre.tscn")   # pas pendant la diffusion de la notification


func _valider() -> void:
	Partie.choisir_heros(_choisi, $Prenom.text)
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()


func _draw() -> void:
	DecorEcran.fond(self, size)
	for skin in _cartes:
		_carte(skin, _cartes[skin])


## Carte d'un héros : cadre (jaune s'il est choisi), le héros debout, son nom.
func _carte(skin: String, r: Rect2) -> void:
	var choisi := skin == _choisi
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.LAMPE if choisi else Palette.CONTOUR
	cadre.set_border_width_all(8 if choisi else 5)
	cadre.set_corner_radius_all(28)
	draw_style_box(cadre, r)
	var pieds := Vector2(r.get_center().x, r.end.y - 70.0)
	var hauteur := minf(r.size.y - 110.0, r.size.x * 1.3)
	if choisi:
		# Halo de lampe derrière le héros choisi
		draw_circle(pieds - Vector2(0, hauteur * 0.5), minf(hauteur * 0.5, r.size.x * 0.45), Color(Palette.LAMPE, 0.14 + 0.04 * sin(_temps * 3.0)))
	Dessin.ombre(self, Rect2(pieds - Vector2(50, 12), Vector2(100, 24)))
	var anim := Images.v3_animation(skin, _temps, choisi)
	var couleur := Color.WHITE if choisi else Color(0.55, 0.55, 0.68)
	if anim["nom"] != "":
		var nom: String = anim["nom"]
		var echelle := hauteur / Images.v3_taille(Images.v3_pose(skin, "idle")).y
		var base := Transform2D(anim["angle"], pieds + anim["decalage"])
		draw_set_transform_matrix(base)
		Images.v3_dessiner(self, nom, Vector2.ZERO, echelle, false, couleur, base)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		DecorEcran.dessiner_heros(self, skin, pieds, hauteur / 245.0, false, couleur)
	var police := ThemeDB.fallback_font
	var texte: String = Partie.SKINS[skin]
	var taille := 40
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var p := Vector2(r.get_center().x - largeur / 2.0, r.end.y - 20.0)
	draw_string_outline(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 8, Palette.CONTOUR)
	draw_string(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Palette.LAMPE if choisi else Palette.UI_TEXTE)
