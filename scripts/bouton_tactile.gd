extends Control
## Bouton tactile qui marche avec plusieurs doigts (le joystick peut rester appuyé).
## Rond si la taille est carrée, sinon pilule (Jouer, Partir, Retour à la base). Style « bouton de jeu » :
## socle sombre, dessus coloré qui s'enfonce quand on appuie, reflet, icône dessinée en code.

signal appuye

@export var texte := "Bouton":
	set(valeur):
		if texte != valeur:
			texte = valeur
			queue_redraw()
@export var couleur := Color.WHITE
## Taille du texte des boutons en pilule (les ronds gardent leur taille).
@export var taille_texte := 40
## Icône au-dessus du texte : "batte", "cacher", "sortir", "jouer" ou rien.
@export var icone := "":
	set(valeur):
		if icone != valeur:
			icone = valeur
			queue_redraw()

const PROFONDEUR := 8.0   # épaisseur du bouton (le dessus s'enfonce de cette hauteur)
## Un bouton inactif est grisé et ne réagit pas.
@export var actif := true:
	set(valeur):
		if actif != valeur:
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
	var appuye := _doigt != -1 and actif
	var fond := couleur if actif else Palette.UI_FOND
	var enfonce := PROFONDEUR if appuye else 0.0
	var couleur_texte := Palette.CONTOUR if fond.get_luminance() > 0.45 else Palette.UI_TEXTE
	if not actif:
		couleur_texte = Palette.UI_BORD * Color(1, 1, 1, 0.6)
	if _rond():
		var rayon := size.x / 2.0 - 4.0
		var centre := Vector2(size.x / 2.0, size.y / 2.0 - PROFONDEUR / 2.0)
		# Socle (ombre du bouton), puis dessus
		draw_circle(centre + Vector2(0, PROFONDEUR), rayon, Palette.CONTOUR)
		draw_circle(centre + Vector2(0, PROFONDEUR), rayon - 4.0, fond.darkened(0.45))
		var haut := centre + Vector2(0, enfonce)
		draw_circle(haut, rayon, Palette.CONTOUR)
		draw_circle(haut, rayon - 5.0, fond)
		# Reflet en haut à gauche
		draw_arc(haut, rayon - 13.0, PI * 1.05, PI * 1.45, 12, fond.lightened(0.45) * Color(1, 1, 1, 0.8), 6.0, true)
		if icone != "":
			_icone(haut + Vector2(0, -12), rayon * 0.42, couleur_texte)
			_texte(haut + Vector2(0, rayon * 0.5), 20, couleur_texte)
		else:
			_texte(haut + Vector2(0, 9), 26, couleur_texte)
	else:
		var rayon := int((size.y - PROFONDEUR) / 2.0)
		var socle := StyleBoxFlat.new()
		socle.bg_color = fond.darkened(0.45)
		socle.border_color = Palette.CONTOUR
		socle.set_border_width_all(5)
		socle.set_corner_radius_all(rayon)
		draw_style_box(socle, Rect2(0, PROFONDEUR, size.x, size.y - PROFONDEUR))
		var dessus := socle.duplicate()
		dessus.bg_color = fond
		draw_style_box(dessus, Rect2(0, enfonce, size.x, size.y - PROFONDEUR))
		var reflet := Rect2(rayon * 0.6, enfonce + 12, size.x - rayon * 1.2, 8)
		draw_rect(reflet, fond.lightened(0.45) * Color(1, 1, 1, 0.5))
		var milieu := Vector2(size.x / 2.0, enfonce + (size.y - PROFONDEUR) / 2.0)
		if icone != "":
			_icone(milieu + Vector2(-size.x * 0.28, 0), 24.0, couleur_texte)
			_texte(milieu + Vector2(size.x * 0.06, taille_texte * 0.35), taille_texte, couleur_texte)
		else:
			_texte(milieu + Vector2(0, taille_texte * 0.35), taille_texte, couleur_texte)


## Texte centré horizontalement sur p (p = ligne de base).
func _texte(p: Vector2, taille: int, couleur_texte: Color) -> void:
	var police := ThemeDB.fallback_font
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	draw_string(police, p - Vector2(largeur / 2.0, 0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur_texte)


## Icônes dessinées en code, dans un carré de demi-côté r autour de c.
func _icone(c: Vector2, r: float, encre: Color) -> void:
	match icone:
		"batte":
			# Batte en diagonale, poignée en bas à gauche, et deux traits de vitesse
			var bas := c + Vector2(-r * 0.8, r * 0.8)
			var haut := c + Vector2(r * 0.7, -r * 0.7)
			draw_line(bas, haut, Palette.CONTOUR, r * 0.5, true)
			draw_line(bas.lerp(haut, 0.35), haut, Palette.BATTE, r * 0.34, true)
			draw_line(bas, bas.lerp(haut, 0.35), Palette.BATTE.darkened(0.35), r * 0.2, true)
			draw_circle(bas, r * 0.16, Palette.CONTOUR)
			for k in 2:
				var d := Vector2(r * (0.15 + 0.3 * k), -r * (0.9 - 0.2 * k))
				draw_arc(c + d, r * 0.5, -PI * 0.1, PI * 0.3, 6, encre, 3.0, true)
		"cacher", "sortir":
			# Carton vu de face, deux yeux qui dépassent (cacher) ou flèche vers le haut (sortir)
			var boite := Rect2(c + Vector2(-r * 0.85, -r * 0.2), Vector2(r * 1.7, r * 1.1))
			Dessin.rect(self, boite, Palette.CARTON)
			draw_line(boite.position + Vector2(r * 0.85, 0), boite.position + Vector2(r * 0.85, r * 0.45), Palette.LAMPE_DOUCE, 5.0)
			if icone == "cacher":
				for dx: float in [-r * 0.3, r * 0.3]:
					draw_circle(c + Vector2(dx, -r * 0.42), r * 0.2, Palette.UI_TEXTE)
					draw_circle(c + Vector2(dx + r * 0.06, -r * 0.42), r * 0.09, Palette.CONTOUR)
			else:
				Dessin.polygone(self, PackedVector2Array([c + Vector2(0, -r * 1.05), c + Vector2(r * 0.5, -r * 0.45),
					c + Vector2(-r * 0.5, -r * 0.45)]), Palette.SORTIE)
		"jouer":
			Dessin.polygone(self, PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.8), c + Vector2(r * 0.8, 0),
				c + Vector2(-r * 0.6, r * 0.8)]), encre)
