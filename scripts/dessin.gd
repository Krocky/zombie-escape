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


# --- Vue 3/4 : boîtes avec dessus, face avant et côté droit ---

## Le dessus et le côté sont décalés vers la droite selon la profondeur (vue légèrement de biais).
const OBLIQUE := 0.35
const OBLIQUE_MAX := 24.0   # limite pour les obstacles très profonds (murs de côté)

static var _ombre: GradientTexture2D


## Décalage vers la droite du bord arrière d'une emprise de cette profondeur.
static func biais(profondeur: float) -> float:
	return minf(profondeur * OBLIQUE, OBLIQUE_MAX)


## Boîte vue en 3/4. Origine = milieu du bord bas avant (au sol), comme les obstacles.
## taille = emprise au sol, hauteur = hauteur de la face avant.
static func boite(ci: CanvasItem, taille: Vector2, hauteur: float, dessus: Color, face: Color, cote: Color) -> void:
	var g := -taille.x / 2.0
	var d := taille.x / 2.0
	var p := taille.y
	var e := biais(p)
	polygone(ci, PackedVector2Array([Vector2(d, 0), Vector2(d + e, -p), Vector2(d + e, -p - hauteur), Vector2(d, -hauteur)]), cote)
	polygone(ci, PackedVector2Array([Vector2(g, 0), Vector2(d, 0), Vector2(d, -hauteur), Vector2(g, -hauteur)]), face)
	polygone(ci, dessus_boite(taille, hauteur), dessus)
	# Arête avant du dessus éclaircie : donne du volume
	ci.draw_line(Vector2(g + 3, -hauteur - 2), Vector2(d - 2, -hauteur - 2), dessus.lightened(0.25), 2.0)


## Les 4 coins du dessus d'une boîte (avant gauche, avant droit, arrière droit, arrière gauche).
static func dessus_boite(taille: Vector2, hauteur: float) -> PackedVector2Array:
	var g := -taille.x / 2.0
	var d := taille.x / 2.0
	var e := biais(taille.y)
	return PackedVector2Array([Vector2(g, -hauteur), Vector2(d, -hauteur),
		Vector2(d + e, -hauteur - taille.y), Vector2(g + e, -hauteur - taille.y)])


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
