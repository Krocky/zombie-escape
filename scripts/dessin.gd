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
