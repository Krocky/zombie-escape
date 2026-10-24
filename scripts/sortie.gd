extends Node2D
## La sortie du supermarché : une porte dans le mur du fond, avec un panneau.
## Le niveau détecte quand le héros l'atteint. Origine = au sol, devant la porte.


func _ready() -> void:
	$Lumiere.color = Palette.SORTIE


func _draw() -> void:
	# Lumière verte au sol devant la porte
	Dessin.ellipse(self, Vector2(0, -6), Vector2(70, 20), Palette.SORTIE * Color(1, 1, 1, 0.25), false)
	# Porte dans la face avant du mur
	Dessin.rect(self, Rect2(-50, -115, 100, 110), Palette.CONTOUR)
	Dessin.rect(self, Rect2(-42, -107, 38, 102), Palette.FENETRE * Color(0.6, 0.6, 0.7, 1))
	Dessin.rect(self, Rect2(4, -107, 38, 102), Palette.FENETRE * Color(0.6, 0.6, 0.7, 1))
	# Panneau « SORTIE »
	Dessin.rect(self, Rect2(-58, -158, 116, 36), Palette.SORTIE)
	var police := ThemeDB.fallback_font
	var largeur := police.get_string_size("SORTIE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(police, Vector2(-largeur / 2.0, -131), "SORTIE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.CONTOUR)
