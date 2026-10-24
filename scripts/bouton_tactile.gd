extends Control
## Bouton tactile qui marche avec plusieurs doigts (le joystick peut rester appuyé).
## Rond si la taille est carrée, sinon rectangle arrondi (Jouer, Rejouer).

signal appuye

@export var texte := "Bouton":
	set(valeur):
		texte = valeur
		queue_redraw()
@export var couleur := Color.WHITE
## Un bouton inactif est grisé et ne réagit pas.
@export var actif := true:
	set(valeur):
		actif = valeur
		queue_redraw()

var _doigt := -1


func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return
	if event.pressed and _doigt == -1 and _touche(event.position):
		_doigt = event.index
		get_viewport().set_input_as_handled()
		if actif:
			appuye.emit()
		queue_redraw()
	elif not event.pressed and event.index == _doigt:
		_doigt = -1
		queue_redraw()


func _rond() -> bool:
	return absf(size.x - size.y) < 1.0


func _touche(position_ecran: Vector2) -> bool:
	var rect := get_global_rect()
	if not is_visible_in_tree():
		return false
	if _rond():
		return rect.get_center().distance_to(position_ecran) <= rect.size.x / 2.0
	return rect.has_point(position_ecran)


func _draw() -> void:
	var centre := size / 2.0
	var fond := couleur if actif else Palette.UI_FOND
	if _doigt != -1 and actif:
		fond = fond.lightened(0.3)
	var taille_police := 26
	if _rond():
		var rayon := size.x / 2.0 - 3.0
		draw_circle(centre, rayon, fond * Color(1, 1, 1, 0.85))
		draw_arc(centre, rayon, 0, TAU, 48, Palette.CONTOUR, 5.0, true)
	else:
		var boite := StyleBoxFlat.new()
		boite.bg_color = fond
		boite.border_color = Palette.CONTOUR
		boite.set_border_width_all(5)
		boite.set_corner_radius_all(int(size.y / 2.0))
		draw_style_box(boite, Rect2(Vector2.ZERO, size))
		taille_police = 40
	var police := ThemeDB.fallback_font
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_police).x
	var couleur_texte := Palette.CONTOUR if actif else Palette.UI_BORD
	draw_string(police, centre + Vector2(-largeur / 2.0, taille_police * 0.35), texte,
		HORIZONTAL_ALIGNMENT_LEFT, -1, taille_police, couleur_texte)
