extends StaticBody2D
## Une cachette (carton ou congélateur). Le héros s'y cache tout près.
## position = milieu du bord bas de l'emprise au sol.

enum Style { CARTON, CONGELATEUR }

@export var style := Style.CARTON
@export var taille := Vector2(110, 70)   # emprise au sol (collision)
@export var hauteur := 70.0              # hauteur de la face avant dessinée

var _occupee := false
var _temps := 0.0


## Distance entre un point et le bord de la cachette (0 si dedans).
func distance_a(point: Vector2) -> float:
	var emprise := Rect2(global_position + Vector2(-taille.x / 2.0, -taille.y), taille)
	var proche := point.clamp(emprise.position, emprise.end)
	return point.distance_to(proche)


func occuper(occupee: bool) -> void:
	_occupee = occupee
	queue_redraw()


func _ready() -> void:
	var forme := RectangleShape2D.new()
	forme.size = taille
	var collision := CollisionShape2D.new()
	collision.shape = forme
	collision.position = Vector2(0, -taille.y / 2.0)
	add_child(collision)


func _process(delta: float) -> void:
	if _occupee:
		_temps += delta
		queue_redraw()


func _draw() -> void:
	var gauche := -taille.x / 2.0
	var r_face := Rect2(gauche, -hauteur, taille.x, hauteur)
	var r_dessus := Rect2(gauche, -taille.y - hauteur, taille.x, taille.y)
	if style == Style.CARTON:
		Dessin.rect(self, r_face, Palette.CARTON_FACE)
		Dessin.rect(self, r_dessus, Palette.CARTON)
		# Scotch sur le dessus
		draw_rect(Rect2(-6, r_dessus.position.y + 2, 12, taille.y - 4), Palette.LAMPE_DOUCE * Color(1, 1, 1, 0.6))
		if _occupee:
			# Le rabat est entrouvert : on voit deux yeux qui regardent
			Dessin.rect(self, Rect2(gauche + 14, r_dessus.position.y - 6, taille.x - 28, 18), Palette.CONTOUR, false)
			_yeux(Vector2(0, r_dessus.position.y + 3))
	else:
		Dessin.rect(self, r_face, Palette.CONGELATEUR_FACE)
		Dessin.rect(self, r_dessus, Palette.CONGELATEUR)
		# Couvercle vitré en deux parties
		var vitre := r_dessus.grow(-8)
		draw_rect(vitre, Palette.FENETRE * Color(1, 1, 1, 0.5))
		draw_line(Vector2(0, vitre.position.y), Vector2(0, vitre.end.y), Palette.CONTOUR, 3.0)
		draw_line(vitre.position + Vector2(8, 4), vitre.position + Vector2(24, vitre.size.y - 4), Color(1, 1, 1, 0.35), 3.0)
		if _occupee:
			_yeux(vitre.get_center() + Vector2(-taille.x / 4.0, 0))


func _yeux(centre: Vector2) -> void:
	# Le héros jette des coups d'œil à gauche et à droite
	var regard := sin(_temps * 1.5) * 2.0
	for dx in [-7.0, 7.0]:
		draw_circle(centre + Vector2(dx, 0), 5.0, Palette.UI_TEXTE)
		draw_circle(centre + Vector2(dx + regard, 0), 2.2, Palette.CONTOUR)
