extends Control
## Écran Réglages (bouton de la base) : une page par groupe de réglages (ParametresJeu.PAGES),
## chaque réglage avec son libellé, sa valeur (jaune si elle n'est plus celle d'origine) et deux boutons − / +
## (un seul bouton Oui / Non pour un interrupteur). Les changements comptent dès la prochaine partie.
## « Valeurs d'origine » remet seulement la page affichée comme dans data/reglages.gd.
## Paysage : réglages sur deux colonnes ; portrait : une colonne.

const BOUTON := preload("res://scenes/bouton_tactile.tscn")
const HAUTEUR_LIGNE := 116.0
const TAILLE_BOUTON := 100.0

var _page := 0
var _boutons := []   # [ligne, réglage, bouton moins (ou interrupteur), bouton plus]


func _ready() -> void:
	$Titre.add_theme_color_override("font_color", Palette.LAMPE)
	$Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	for b in [$Precedent, $Suivant]:
		b.couleur = Palette.UI_BOUTON
		b.taille_texte = 48
	$Precedent.appuye.connect(_tourner.bind(-1))
	$Suivant.appuye.connect(_tourner.bind(1))
	$Retour.couleur = Palette.LAMPE
	$Retour.appuye.connect(_retour)
	$Remettre.couleur = Palette.UI_BOUTON
	$Remettre.appuye.connect(_remettre)
	resized.connect(_afficher_page)
	_afficher_page()


func _tourner(sens: int) -> void:
	_page = posmod(_page + sens, ParametresJeu.PAGES.size())
	_afficher_page()


func _retour() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _remettre() -> void:
	ParametresJeu.remettre_page(_page)
	_actualiser()


## Construit les lignes de la page et place tout selon le sens de l'écran.
func _afficher_page() -> void:
	var paysage := size.x > size.y
	var page: Array = ParametresJeu.PAGES[_page]
	$Titre.text = "%s  (%d/%d)" % [page[0], _page + 1, ParametresJeu.PAGES.size()]
	$Titre.size = Vector2(size.x - 2 * (TAILLE_BOUTON + 40.0), 100)
	$Titre.position = Vector2(TAILLE_BOUTON + 40.0, 16)
	$Precedent.position = Vector2(24, 16)
	$Suivant.position = Vector2(size.x - TAILLE_BOUTON - 24, 16)
	$Retour.position = Vector2(24, size.y - $Retour.size.y - 24)
	$Remettre.position = Vector2(size.x - $Remettre.size.x - 24, size.y - $Remettre.size.y - 24)
	for ligne in $Lignes.get_children():
		ligne.queue_free()
	_boutons.clear()
	var colonnes := 2 if paysage else 1
	var largeur := (size.x - 48.0 - (colonnes - 1) * 32.0) / colonnes
	var reglages: Array = page[1]
	var par_colonne := ceili(reglages.size() / float(colonnes))
	var haut := 136.0 if paysage else 150.0
	for i in reglages.size():
		var ligne := Control.new()
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.position = Vector2(24.0 + (i / par_colonne) * (largeur + 32.0), haut + (i % par_colonne) * HAUTEUR_LIGNE)
		ligne.size = Vector2(largeur, HAUTEUR_LIGNE - 12.0)
		$Lignes.add_child(ligne)
		var r: Array = reglages[i]
		var moins = _bouton(ligne, "Non" if _interrupteur(r) else "-", ligne.size.x - (2 if not _interrupteur(r) else 1) * (TAILLE_BOUTON + 8.0), -1, r)
		var plus = null if _interrupteur(r) else _bouton(ligne, "+", ligne.size.x - TAILLE_BOUTON - 4.0, 1, r)
		if _interrupteur(r):
			_taille(moins, Vector2(TAILLE_BOUTON * 1.6, TAILLE_BOUTON))
			moins.position.x = ligne.size.x - moins.size.x - 4.0
		ligne.draw.connect(_dessiner_ligne.bind(ligne, r))
		_boutons.append([ligne, r, moins, plus])
	_actualiser()


func _interrupteur(r: Array) -> bool:
	return is_zero_approx(float(r[2]))


func _bouton(ligne: Control, texte: String, x: float, sens: int, r: Array) -> Control:
	var b := BOUTON.instantiate()
	b.texte = texte
	b.taille_texte = 48
	b.couleur = Palette.LAMPE
	b.appuye.connect(func() -> void:
		ParametresJeu.changer(r, sens)
		_actualiser())
	ligne.add_child(b)
	_taille(b, Vector2(TAILLE_BOUTON, TAILLE_BOUTON))
	b.position = Vector2(x, (ligne.size.y - TAILLE_BOUTON) / 2.0)
	return b


## Taille fixée après l'ajout (la scène du bouton a 140 x 140 par défaut).
func _taille(b: Control, taille: Vector2) -> void:
	b.custom_minimum_size = taille
	b.size = taille


## Boutons grisés aux limites, texte de l'interrupteur, valeurs redessinées.
func _actualiser() -> void:
	for entree in _boutons:
		var r: Array = entree[1]
		var v = ParametresJeu.valeur(r[0])
		if _interrupteur(r):
			entree[2].texte = "Oui" if v else "Non"
			entree[2].couleur = Palette.SORTIE if v else Palette.UI_BOUTON
			entree[2].queue_redraw()
		else:
			entree[2].actif = v > r[3]
			entree[3].actif = v < r[4]
		entree[0].queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	DecorEcran.fond(self, size)


## Cadre de la ligne, libellé, valeur (jaune si changée) et valeur d'origine en petit.
func _dessiner_ligne(ligne: Control, r: Array) -> void:
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.CONTOUR
	cadre.set_border_width_all(4)
	cadre.set_corner_radius_all(20)
	ligne.draw_style_box(cadre, Rect2(Vector2.ZERO, ligne.size))
	var police := ThemeDB.fallback_font
	var change := ParametresJeu.est_change(r[0])
	var place := ligne.size.x - (TAILLE_BOUTON * 1.6 + 30.0 if _interrupteur(r) else 2 * TAILLE_BOUTON + 30.0)
	ligne.draw_string(police, Vector2(18, 42), r[1], HORIZONTAL_ALIGNMENT_LEFT, place - 18.0, 26, Palette.UI_TEXTE)
	if _interrupteur(r):
		return
	var texte := _texte(ParametresJeu.valeur(r[0]))
	ligne.draw_string_outline(police, Vector2(18, 86), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, 6, Palette.CONTOUR)
	ligne.draw_string(police, Vector2(18, 86), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.LAMPE if change else Palette.UI_TEXTE)
	if change:
		var x := 30.0 + police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		ligne.draw_string(police, Vector2(x, 84), "(origine : %s)" % _texte(ParametresJeu.origine(r[0])),
			HORIZONTAL_ALIGNMENT_LEFT, place - x, 22, Palette.UI_BORD)


## 260 -> « 260 », 0.05 -> « 0,05 », 1.5 -> « 1,5 ».
func _texte(v: Variant) -> String:
	if v is int:
		return str(v)
	var t := ("%.2f" % v).rstrip("0").rstrip(".")
	return t.replace(".", ",")
