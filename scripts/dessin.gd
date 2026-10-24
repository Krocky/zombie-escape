class_name Dessin
## Petites fonctions pour dessiner des formes en aplat avec un contour épais.

const EPAISSEUR := 4.0


static func polygone(ci: CanvasItem, points: PackedVector2Array, couleur: Color, contour := true) -> void:
	ci.draw_colored_polygon(points, couleur)
	if contour:
		var ferme := points.duplicate()
		ferme.append(points[0])
		ci.draw_polyline(ferme, Palette.CONTOUR, EPAISSEUR, true)


static func rect(ci: CanvasItem, r: Rect2, couleur: Color, contour := true) -> void:
	polygone(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), couleur, contour)


static func ellipse(ci: CanvasItem, centre: Vector2, rayons: Vector2, couleur: Color, contour := true) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		points.append(centre + Vector2(cos(a) * rayons.x, sin(a) * rayons.y))
	polygone(ci, points, couleur, contour)


static func cercle(ci: CanvasItem, centre: Vector2, rayon: float, couleur: Color, contour := true) -> void:
	ellipse(ci, centre, Vector2(rayon, rayon), couleur, contour)


# --- Dessin de secours en isométrique (quand une image V2 manque) ---

static var _ombre: GradientTexture2D


## Boîte isométrique : coins au sol à l'écran (gauche, avant, droit, arrière, voir Iso.coins),
## hauteur en pixels d'écran. Faces gauche et droite, puis dessus.
static func boite_iso(ci: CanvasItem, c: PackedVector2Array, hauteur: float, dessus: Color, face: Color, cote: Color) -> void:
	var h := Vector2(0, -hauteur)
	polygone(ci, PackedVector2Array([c[0], c[1], c[1] + h, c[0] + h]), face)
	polygone(ci, PackedVector2Array([c[1], c[2], c[2] + h, c[1] + h]), cote)
	polygone(ci, PackedVector2Array([c[0] + h, c[1] + h, c[2] + h, c[3] + h]), dessus)


## Ombre douce posée au sol, dans le rectangle donné (une seule texture, sans contour).
static func ombre(ci: CanvasItem, r: Rect2, force := 1.0) -> void:
	if _ombre == null:
		var degrade := Gradient.new()
		degrade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		degrade.colors = PackedColorArray([Palette.OMBRE, Palette.OMBRE, Color(Palette.OMBRE, 0.0)])
		_ombre = GradientTexture2D.new()
		_ombre.gradient = degrade
		_ombre.width = 64
		_ombre.height = 64
		_ombre.fill = GradientTexture2D.FILL_RADIAL
		_ombre.fill_from = Vector2(0.5, 0.5)
		_ombre.fill_to = Vector2(1.0, 0.5)
	ci.draw_texture_rect(_ombre, r, false, Color(1, 1, 1, force))
