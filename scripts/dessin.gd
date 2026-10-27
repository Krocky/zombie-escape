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


# --- Icônes des objets (niveau, HUD, écran de fin) ---

## Image V2 de chaque type d'objet.
const IMAGES_OBJETS := {"conserve": "conserve", "eau": "eau", "bandage": "trousse", "piles": "piles"}
## Image V3 (images/v3) de la fiole et de la clef. Sans image : dessin en code.
const IMAGES_V3_OBJETS := {"fiole": "item_vial", "clef": "item_key"}


## Icône d'un objet, posée sur « pieds » (milieu du bas), haute de « hauteur » pixels
## (une image plus large que haute, la clef, est limitée à 1,4 x hauteur de large).
## teinte : étiquette de la clef, clé de Palette.CLEF ("rouge" par défaut).
static func icone_objet(ci: CanvasItem, type: String, pieds: Vector2, hauteur: float, couleur := Color.WHITE, teinte := "rouge") -> void:
	var etiquette: Color = Palette.CLEF.get(teinte, Palette.CLEF["rouge"])
	var nom_v3: String = IMAGES_V3_OBJETS.get(type, "")
	if nom_v3 != "" and Images.v3_existe(nom_v3):
		var texture := Images.v3_teinte(nom_v3, etiquette) if type == "clef" else Images.v3_texture(nom_v3)
		var t := texture.get_size()
		var e := minf(hauteur / t.y, hauteur * 1.4 / t.x)
		ci.draw_texture_rect(texture, Rect2(pieds - Vector2(t.x * e / 2.0, t.y * e), t * e), false, couleur)
		return
	var nom: String = IMAGES_OBJETS.get(type, "")
	if nom != "" and Images.existe(nom):
		Images.dessiner_pieds(ci, nom, pieds, hauteur / Images.region(nom).size.y, false, couleur)
		return
	# Dessin en code (image manquante), à l'échelle de la hauteur voulue
	var e := hauteur / 40.0
	ci.draw_set_transform(pieds + Vector2(0, -20.0 * e), 0.0, Vector2(e, e))
	match type:
		"conserve":
			rect(ci, Rect2(-11, -14, 22, 28), Palette.UI_BORD * couleur)
			ci.draw_rect(Rect2(-11, -6, 22, 12), Palette.COEUR * couleur)
		"eau":
			rect(ci, Rect2(-9, -10, 18, 28), Palette.FENETRE * couleur)
			rect(ci, Rect2(-5, -17, 10, 7), Palette.UI_TEXTE * couleur)
		"bandage":
			rect(ci, Rect2(-15, -11, 30, 22), Palette.UI_TEXTE * couleur)
			ci.draw_rect(Rect2(-3, -8, 6, 16), Palette.COEUR * couleur)
			ci.draw_rect(Rect2(-8, -3, 16, 6), Palette.COEUR * couleur)
		"piles":
			for dx: float in [-7.0, 7.0]:
				rect(ci, Rect2(dx - 5, -13, 10, 26), Palette.LAMPE * couleur)
				ci.draw_rect(Rect2(dx - 5, 3, 10, 10), Palette.CONTOUR)
		"balles":
			# Boîte de balles de tourelle : caisse kaki à poignée, trois cartouches dorées qui dépassent
			for dx: float in [-9.0, 0.0, 9.0]:
				rect(ci, Rect2(dx - 3.5, -18, 7, 12), Palette.BALLES_CUIVRE * couleur)
				ci.draw_circle(Vector2(dx, -18), 3.5, Palette.BALLES_CUIVRE * couleur)
			rect(ci, Rect2(-17, -9, 34, 25), Palette.BALLES_BOITE * couleur)
			ci.draw_rect(Rect2(-13, -2, 26, 8), Palette.BALLES_ETIQUETTE * couleur)
			ci.draw_rect(Rect2(-17, 10, 34, 3), Palette.CONTOUR)
		"clef":
			# Anneau, tige à deux dents, étiquette colorée
			ci.draw_line(Vector2(-6, 6), Vector2(20, 6), Palette.CONTOUR, 8.0)
			ci.draw_line(Vector2(-6, 6), Vector2(20, 6), Palette.LAMPE * couleur, 4.0)
			for dx: float in [12.0, 18.0]:
				rect(ci, Rect2(dx - 2, 6, 4, 6), Palette.LAMPE * couleur)
			cercle(ci, Vector2(-12, 6), 8.0, Palette.LAMPE * couleur)
			ci.draw_circle(Vector2(-12, 6), 3.0, Palette.CONTOUR)
			rect(ci, Rect2(-24, -16, 14, 12), etiquette * couleur)
		_:
			# Fiole de remède : ballon vert, bouchon, reflet
			cercle(ci, Vector2(0, 6), 13.0, Palette.ZOMBIE_PEAU.lightened(0.3) * couleur)
			rect(ci, Rect2(-5, -17, 10, 12), Palette.UI_TEXTE * couleur)
			ci.draw_circle(Vector2(-4, 2), 3.5, Color(1, 1, 1, 0.7 * couleur.a))
	ci.draw_set_transform(Vector2.ZERO)


## Icône d'un objet suivie de « xN » (inventaire de la base). Un objet absent (0) est grisé.
static func objet_compte(ci: CanvasItem, type: String, pieds: Vector2, hauteur: float, nombre: int) -> void:
	var gris := Color(0.55, 0.55, 0.65, 0.6)
	icone_objet(ci, type, pieds, hauteur, Color.WHITE if nombre > 0 else gris)
	var police := ThemeDB.fallback_font
	var texte := "x%d" % nombre
	var p := pieds + Vector2(hauteur * 0.48, -6)
	ci.draw_string_outline(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Palette.CONTOUR)
	ci.draw_string(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.LAMPE if nombre > 0 else Palette.UI_BORD)
