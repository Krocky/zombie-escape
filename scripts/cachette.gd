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
	# Ombre au sol sous les personnages (voir Mur)
	var ombre := Node2D.new()
	ombre.z_index = -1
	ombre.draw.connect(func() -> void:
		Dessin.ombre(ombre, Rect2(-taille.x / 2.0 - 14, -taille.y - 8, taille.x + Dessin.biais(taille.y) + 36, taille.y + 30)))
	add_child(ombre)


func _process(delta: float) -> void:
	if _occupee:
		_temps += delta
		queue_redraw()


func _draw() -> void:
	var g := -taille.x / 2.0
	var d := taille.x / 2.0
	var coins := Dessin.dessus_boite(taille, hauteur)
	var centre_dessus := (coins[0] + coins[2]) / 2.0
	if style == Style.CARTON:
		Dessin.boite(self, taille, hauteur, Palette.CARTON, Palette.CARTON_FACE, Palette.CARTON_COTE)
		# Rabats : fente au milieu du dessus, scotch par-dessus et sur la face avant
		var avant := (coins[0] + coins[1]) / 2.0
		var arriere := (coins[2] + coins[3]) / 2.0
		var scotch := Palette.LAMPE_DOUCE * Color(1, 1, 1, 0.6)
		draw_line(avant, arriere, scotch, 12.0)
		draw_line(Vector2(0, -hauteur), Vector2(0, -hauteur + 22), scotch, 12.0)
		draw_line(avant, arriere, Palette.CONTOUR, 2.0)
		# Étiquette sur la face avant
		draw_rect(Rect2(g + 10, -26, 22, 14), Palette.CARTON_COTE)
		if _occupee:
			# Le rabat est entrouvert : on voit deux yeux qui regardent
			Dessin.rect(self, Rect2(centre_dessus.x - taille.x / 2.0 + 14, centre_dessus.y - 9, taille.x - 28, 18), Palette.CONTOUR, false)
			_yeux(centre_dessus)
	else:
		Dessin.boite(self, taille, hauteur, Palette.CONGELATEUR, Palette.CONGELATEUR_FACE, Palette.CONGELATEUR_COTE)
		# Grille d'aération et poignée sur la face avant
		for k in 4:
			draw_line(Vector2(d - 46, -14 - k * 6), Vector2(d - 14, -14 - k * 6), Palette.CONTOUR, 2.0)
		Dessin.rect(self, Rect2(g + 16, -hauteur + 8, 34, 7), Palette.UI_BORD)
		# Couvercle vitré en deux parties, avec un reflet
		var vitre := PackedVector2Array()
		for i in 4:
			vitre.append(coins[i].lerp(centre_dessus, 0.18))
		draw_colored_polygon(vitre, Palette.FENETRE * Color(1, 1, 1, 0.55))
		var haut_milieu := (vitre[2] + vitre[3]) / 2.0
		var bas_milieu := (vitre[0] + vitre[1]) / 2.0
		draw_line(bas_milieu, haut_milieu, Palette.CONTOUR, 4.0)
		draw_line(vitre[0].lerp(vitre[3], 0.85) + Vector2(10, 0), vitre[0].lerp(vitre[3], 0.15) + Vector2(24, 0), Color(1, 1, 1, 0.35), 3.0)
		if _occupee:
			_yeux(centre_dessus + Vector2(-taille.x / 4.0, 0))


func _yeux(centre: Vector2) -> void:
	# Le héros jette des coups d'œil à gauche et à droite
	var regard := sin(_temps * 1.5) * 2.0
	for dx in [-7.0, 7.0]:
		draw_circle(centre + Vector2(dx, 0), 5.0, Palette.UI_TEXTE)
		draw_circle(centre + Vector2(dx + regard, 0), 2.2, Palette.CONTOUR)
