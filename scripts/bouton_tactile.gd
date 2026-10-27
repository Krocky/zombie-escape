extends Control
## Bouton tactile qui marche avec plusieurs doigts (le joystick peut rester appuyé).
## Rond si la taille est carrée, sinon pilule (Jouer, Partir, Retour à la base). Style « bouton de jeu » :
## socle sombre, dessus coloré qui s'enfonce quand on appuie, reflet, icône : image V3 (IMAGES_ICONES) ou dessin en code.
## recharge > 0 : jauge circulaire autour du bouton rond et icône grisée ; petit rebond quand il redevient disponible.

signal appuye

@export var texte := "Bouton":
	set(valeur):
		if texte != valeur:
			texte = valeur
			queue_redraw()
@export var couleur := Color.WHITE
## Taille du texte des boutons en pilule (les ronds gardent leur taille).
@export var taille_texte := 40
## Icône au-dessus du texte : "batte", "cacher", "sortir", "jouer", "heros", "reglages", "pause", "soigner", "guerir", "reparer" ou rien.
@export var icone := "":
	set(valeur):
		if icone != valeur:
			icone = valeur
			queue_redraw()

## Recharge restante (1 = coup juste donné, 0 = disponible).
@export var recharge := 0.0:
	set(valeur):
		valeur = clampf(valeur, 0.0, 1.0)
		if recharge != valeur:
			if valeur == 0.0 and recharge > 0.0:
				_rebond = 1.0
				create_tween().tween_property(self, "_rebond", 0.0, DUREE_REBOND)
			recharge = valeur
			queue_redraw()

const PROFONDEUR := 8.0   # épaisseur du bouton (le dessus s'enfonce de cette hauteur)
## Icônes en image V3 (images/v3), à TAILLE_IMAGE du diamètre du bouton rond. Sans image : dessin en code.
const IMAGES_ICONES := {"batte": "icon_hit", "cacher": "icon_hide"}
const TAILLE_IMAGE := 0.7
const DUREE_REBOND := 0.35
const ECART_ICONE := 18.0   # bouton en pilule : entre l'icône et le texte
## Un bouton inactif est grisé et ne réagit pas.
@export var actif := true:
	set(valeur):
		if actif != valeur:
			actif = valeur
			queue_redraw()

var _doigt := -1
var _rebond := 0.0:   # 1 -> 0 pendant le rebond
	set(valeur):
		_rebond = valeur
		queue_redraw()


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


## Vrai tant qu'un doigt le tient appuyé (bouton visible et actif) : Réparer agit tant qu'il est tenu.
func tenu() -> bool:
	return _doigt != -1 and actif and is_visible_in_tree()


## Oublie le doigt posé (le jeu se fige : son lever n'arrivera jamais jusqu'ici).
func relacher() -> void:
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
		var image: String = IMAGES_ICONES.get(icone, "")
		if recharge > 0.0:
			# Jauge circulaire autour du bouton (socle compris) : la partie remplie avance jusqu'au tour complet
			var milieu := centre + Vector2(0, PROFONDEUR / 2.0)
			var r_jauge := rayon + PROFONDEUR / 2.0 + 5.0
			draw_arc(milieu, r_jauge, 0.0, TAU, 48, Palette.CONTOUR, 11.0, true)
			draw_arc(milieu, r_jauge, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - recharge), 48, fond.lightened(0.2), 6.0, true)
		if image != "" and Images.v3_existe(image):
			var gris := recharge > 0.0 or not actif
			var texture := Images.v3_gris(image) if gris else Images.v3_texture(image)
			var t := texture.get_size()
			var e := rayon * 2.0 * TAILLE_IMAGE / maxf(t.x, t.y) * (1.0 + 0.22 * sin(_rebond * PI))
			var teinte := Color(1, 1, 1, 0.45) if not actif else (Color(0.8, 0.8, 0.85) if gris else Color.WHITE)
			draw_texture_rect(texture, Rect2(haut + Vector2(0, -8) - t * e / 2.0, t * e), false, teinte)
			_texte(haut + Vector2(0, rayon * 0.8), 20, couleur_texte, true)
		elif icone != "":
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
			# Icône puis texte, centrés ensemble, séparés de ECART_ICONE
			var r_icone := 24.0
			var largeur := ThemeDB.fallback_font.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_texte).x
			var gauche := -(2.0 * r_icone + ECART_ICONE + largeur) / 2.0
			_icone(milieu + Vector2(gauche + r_icone, 0), r_icone, couleur_texte)
			_texte(milieu + Vector2(gauche + 2.0 * r_icone + ECART_ICONE + largeur / 2.0, taille_texte * 0.35), taille_texte, couleur_texte)
		else:
			_texte(milieu + Vector2(0, taille_texte * 0.35), taille_texte, couleur_texte)


## Texte centré horizontalement sur p (p = ligne de base). « contour » : texte clair cerclé de sombre, lisible sur une image.
func _texte(p: Vector2, taille: int, couleur_texte: Color, contour := false) -> void:
	var police := ThemeDB.fallback_font
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	if contour:
		draw_string_outline(police, p - Vector2(largeur / 2.0, 0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 7, Palette.CONTOUR)
		if actif:
			couleur_texte = Palette.UI_TEXTE
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
		"heros":
			# Buste : tête et épaules
			Dessin.polygone(self, PackedVector2Array([c + Vector2(-r * 0.85, r * 0.9), c + Vector2(-r * 0.6, r * 0.25),
				c + Vector2(r * 0.6, r * 0.25), c + Vector2(r * 0.85, r * 0.9)]), Palette.HEROS_VESTE)
			Dessin.cercle(self, c + Vector2(0, -r * 0.3), r * 0.45, Palette.HEROS_PEAU)
		"reglages":
			# Roue dentée
			for k in 8:
				var a := k * TAU / 8.0
				draw_line(c + Vector2.from_angle(a) * r * 0.5, c + Vector2.from_angle(a) * r * 0.95, encre, r * 0.32)
			draw_circle(c, r * 0.68, encre)
			draw_circle(c, r * 0.28, Palette.UI_BOUTON)
		"pause":
			# Deux barres verticales
			for dx: float in [-r * 0.42, r * 0.42]:
				Dessin.rect(self, Rect2(c + Vector2(dx - r * 0.22, -r * 0.75), Vector2(r * 0.44, r * 1.5)), encre)
		"soigner":
			# Cœur barré d'un bandage en travers
			var coeur := PackedVector2Array()
			for k in 24:
				var t := TAU * k / 24.0
				coeur.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * r / 15.0)
			Dessin.polygone(self, coeur, Palette.COEUR)
			var sens := Vector2.from_angle(-PI / 4.0)
			var large := sens.orthogonal() * r * 0.24
			var bout := sens * r * 0.95
			Dessin.polygone(self, PackedVector2Array([c - bout - large, c + bout - large, c + bout + large, c - bout + large]), Palette.UI_TEXTE)
			draw_circle(c, r * 0.07, Palette.COEUR.darkened(0.3))
		"guerir":
			# Fiole de remède, avec trois petites bulles vertes qui s'en échappent
			Dessin.icone_objet(self, "fiole", c + Vector2(0, r * 0.95), r * 1.9, Color.WHITE if actif else Color(0.6, 0.6, 0.65, 0.6))
			draw_set_transform(Vector2.ZERO)
			for k in 3:
				draw_circle(c + Vector2(r * (0.55 + 0.2 * k), -r * (0.5 + 0.3 * k)), r * (0.16 - 0.03 * k), Palette.GUERISON if actif else encre)
		"reparer":
			# Clé à molette en diagonale : manche, tête ronde ouverte (mâchoire), trou au bout du manche
			var metal := Palette.FERRAILLE.lightened(0.25) if actif else encre
			draw_set_transform(c, -PI / 4.0, Vector2.ONE)
			draw_line(Vector2(-r * 0.95, 0), Vector2(r * 0.3, 0), Palette.CONTOUR, r * 0.5, true)
			draw_line(Vector2(-r * 0.95, 0), Vector2(r * 0.3, 0), metal, r * 0.3, true)
			Dessin.cercle(self, Vector2(r * 0.5, 0), r * 0.48, metal)
			draw_rect(Rect2(r * 0.42, -r * 0.17, r * 0.7, r * 0.34), couleur if actif else Palette.UI_FOND)
			draw_circle(Vector2(-r * 0.78, 0), r * 0.09, Palette.CONTOUR)
			draw_set_transform(Vector2.ZERO)
		"jouer":
			Dessin.polygone(self, PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.8), c + Vector2(r * 0.8, 0),
				c + Vector2(-r * 0.6, r * 0.8)]), encre)
