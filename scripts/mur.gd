extends StaticBody2D
## Obstacle du décor : mur, étagère, caisse...
## position = milieu du bord bas de l'emprise au sol.

enum Style { MUR, ETAGERE, CAISSE }

@export var taille := Vector2(200, 60)   # emprise au sol (collision)
@export var hauteur := 60.0              # hauteur de la face avant dessinée
@export var style := Style.MUR


func _ready() -> void:
	var forme := RectangleShape2D.new()
	forme.size = taille
	var collision := CollisionShape2D.new()
	collision.shape = forme
	collision.position = Vector2(0, -taille.y / 2.0)
	add_child(collision)


func _draw() -> void:
	var dessus := Palette.MUR
	var face := Palette.MUR_FACE
	match style:
		Style.ETAGERE:
			dessus = Palette.ETAGERE
			face = Palette.ETAGERE_FACE
		Style.CAISSE:
			dessus = Palette.CAISSE_BOIS
			face = Palette.CAISSE_BOIS_FACE
	var gauche := -taille.x / 2.0
	# Face avant (verticale), puis dessus décalé vers le haut de la hauteur
	var r_face := Rect2(gauche, -hauteur, taille.x, hauteur)
	var r_dessus := Rect2(gauche, -taille.y - hauteur, taille.x, taille.y)
	Dessin.rect(self, r_face, face)
	Dessin.rect(self, r_dessus, dessus)
	match style:
		Style.ETAGERE:
			# Planches de l'étagère
			var y := -hauteur + hauteur / 3.0
			while y < -4.0:
				draw_line(Vector2(gauche + 6, y), Vector2(-gauche - 6, y), Palette.CONTOUR, 3.0)
				y += hauteur / 3.0
		Style.CAISSE:
			# Lattes de bois
			for i in range(1, 4):
				var x := gauche + taille.x * i / 4.0
				draw_line(Vector2(x, -hauteur + 4), Vector2(x, -4), Palette.CONTOUR, 2.0)
