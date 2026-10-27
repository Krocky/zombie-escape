class_name DecorEcran
## Fond illustré des écrans titre et fin : sol en dalles dans la nuit, le héros choisi et sa lampe,
## des zombies aux yeux qui brillent (ou la porte de sortie verte après une victoire).
## Les personnages sont sur les côtés en paysage, en bas en portrait, pour laisser le texte lisible.

enum Scene { TITRE, VICTOIRE, DEFAITE }

const SOMBRE := Color(0.42, 0.43, 0.56)   # les personnages hors de la lampe
## Pose V2 -> image V3 / V4 des zombies (immobiles, ils regardent à gauche)
const ZOMBIES_V3 := {"gros_face_2": "zombie_big_iddle", "maigre_profil_2": "zombie_thin_iddle"}


static func dessiner(ci: CanvasItem, taille: Vector2, temps: float, scene := Scene.TITRE) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, taille), Palette.FOND_NUIT)
	var e := minf(taille.x, taille.y) / 720.0
	var paysage := taille.x > taille.y
	var horizon := taille.y * (0.5 if paysage else 0.62)
	_sol(ci, taille, horizon, e)
	# Emplacements : héros, puis deux autres (zombies ou porte)
	var heros := Vector2(0.15, 0.94) if paysage else Vector2(0.24, 0.96)
	var autres := [Vector2(0.8, 0.9), Vector2(0.93, 0.96)] if paysage else [Vector2(0.62, 0.93), Vector2(0.86, 0.97)]
	var pieds := heros * taille
	if scene == Scene.VICTOIRE:
		_porte(ci, autres[0] * taille + Vector2(40, -10) * e, e, temps)
	if scene == Scene.DEFAITE:
		# La lampe est tombée par terre : son faisceau rase le sol
		_faisceau(ci, pieds + Vector2(70, -12) * e, Vector2.from_angle(0.04), taille.x * 0.45, e)
	else:
		_faisceau(ci, lampe_heros(Partie.perso(), pieds, e * 0.9), Vector2.from_angle(-0.12 + 0.1 * sin(temps * 0.8)), taille.x * 0.55, e)
	if scene != Scene.VICTOIRE:
		_zombie(ci, "gros_face_2", autres[0] * taille, e * 0.95, temps)
		_zombie(ci, "maigre_profil_2", autres[1] * taille, e * 0.95, temps + 1.7)
	Dessin.ombre(ci, Rect2(pieds - Vector2(50, 14) * e, Vector2(100, 28) * e))
	if scene == Scene.DEFAITE:
		dessiner_heros(ci, Partie.perso(), pieds, e * 0.9, false, SOMBRE, -PI / 2.0)
	else:
		dessiner_heros(ci, Partie.perso(), pieds, e * 0.9, false, Color.WHITE, 0.0)
	_voile(ci, taille)


## Fond seul (sol en dalles dans la nuit, haut assombri), sans personnages : écran de choix du héros.
static func fond(ci: CanvasItem, taille: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, taille), Palette.FOND_NUIT)
	_sol(ci, taille, taille.y * (0.5 if taille.x > taille.y else 0.62), minf(taille.x, taille.y) / 720.0)
	_voile(ci, taille)


## Dalles en losange, de plus en plus visibles vers le bas.
static func _sol(ci: CanvasItem, taille: Vector2, horizon: float, e: float) -> void:
	if not Images.existe("dalle"):
		return
	var r := Images.region("dalle")
	var largeur := 300.0 * e
	var k := largeur / r.size.x
	var demi := largeur * Iso.RAPPORT / 2.0
	var lignes := int((taille.y - horizon) / demi) + 3
	for j in range(-1, lignes):
		var y := horizon + j * demi
		var clarte := clampf(0.15 + 0.45 * (y - horizon) / maxf(taille.y - horizon, 1.0), 0.15, 0.6)
		var decalage := largeur / 2.0 if j % 2 != 0 else 0.0
		for i in range(-1, int(taille.x / largeur) + 2):
			var haut := Vector2(i * largeur + decalage, y)
			Images.dessiner(ci, "dalle", Rect2(haut - Vector2(largeur / 2.0, 0), r.size * k), false,
				Color(clarte, clarte * 1.02, clarte * 1.3))


## Le héros choisi debout (image V3 immobile, sinon V2), pieds sur « pieds », tourné de « angle ».
## Aussi utilisé par la base et l'écran de choix du héros.
static func dessiner_heros(ci: CanvasItem, perso: String, pieds: Vector2, echelle: float, miroir: bool, couleur: Color, angle := 0.0) -> void:
	var base := Transform2D(angle, pieds)
	ci.draw_set_transform_matrix(base)
	var nom := Images.v3_pose(perso, "idle")
	if nom != "":
		Images.v3_dessiner(ci, nom, Vector2.ZERO, echelle, miroir, couleur, base)
	elif Images.existe("profil_1"):
		Images.dessiner_pieds(ci, "profil_1", Vector2.ZERO, echelle, miroir, couleur, base)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Position de la lampe dans la main du héros debout (comme dans le jeu).
static func lampe_heros(perso: String, pieds: Vector2, echelle: float) -> Vector2:
	var nom := Images.v3_pose(perso, "idle")
	if nom != "":
		return Images.v3_point(nom, Images.v3_lampe(nom), pieds, echelle)
	if not Images.existe("profil_1"):
		return pieds + Vector2(90, -130) * echelle
	var a := Images.ancres("profil_1")
	return pieds + (a[2] - a[3]) * echelle


## Cône de lumière jaune qui part de la lampe, en dégradé.
static func _faisceau(ci: CanvasItem, main: Vector2, direction: Vector2, longueur: float, e: float) -> void:
	var cote := direction.orthogonal() * longueur * 0.32
	var bout := main + direction * longueur
	ci.draw_polygon(PackedVector2Array([main + direction.orthogonal() * 6.0 * e, bout + cote, bout - cote, main - direction.orthogonal() * 6.0 * e]),
		PackedColorArray([Palette.LAMPE * Color(1, 1, 1, 0.55), Color(Palette.LAMPE, 0.0), Color(Palette.LAMPE, 0.0), Palette.LAMPE * Color(1, 1, 1, 0.55)]))


static func _personnage(ci: CanvasItem, nom: String, pieds: Vector2, e: float, miroir: bool, couleur: Color, angle: float) -> void:
	Dessin.ombre(ci, Rect2(pieds - Vector2(50, 14) * e, Vector2(100, 28) * e))
	if not Images.existe(nom):
		return
	var base := Transform2D(angle, pieds)
	ci.draw_set_transform_matrix(base)
	Images.dessiner_pieds(ci, nom, Vector2.ZERO, e * 0.9, miroir, couleur, base)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Zombie dans l'ombre, mais ses yeux brillent (et clignent de temps en temps) : image V3 / V4 immobile qui regarde à
## gauche vers le héros (ZOMBIES_V3), sinon la pose V2 « nom ».
static func _zombie(ci: CanvasItem, nom: String, pieds: Vector2, e: float, temps: float) -> void:
	var v3: String = ZOMBIES_V3.get(nom, "")
	if Images.v3_existe(v3):
		Dessin.ombre(ci, Rect2(pieds - Vector2(50, 14) * e, Vector2(100, 28) * e))
		Images.v3_dessiner(ci, v3, pieds, e * 0.9, false, SOMBRE)
		if fmod(temps, 4.0) < 0.15:
			return
		var zone := Images.v3_yeux(v3)
		if zone.size == Vector2.ZERO:
			return
		ci.draw_circle(Images.v3_point(v3, zone.get_center(), pieds, e * 0.9), 13.0 * e, Palette.ZOMBIE_YEUX_LUEUR)
		Images.v3_dessiner(ci, v3, pieds, e * 0.9, false, Color.WHITE, Transform2D.IDENTITY, zone)
		return
	_personnage(ci, nom, pieds, e, true, SOMBRE, 0.0)
	if not Images.existe(nom + "_yeux") or fmod(temps, 4.0) < 0.15:
		return
	var centre := Images.centre_calque(nom, nom + "_yeux", pieds, e * 0.9, true)
	ci.draw_circle(centre, 22.0 * e, Palette.ZOMBIE_YEUX_LUEUR)
	Images.dessiner_calque(ci, nom, nom + "_yeux", pieds, e * 0.9, true)


## Porte de sortie ouverte, avec sa lueur verte qui respire.
static func _porte(ci: CanvasItem, pieds: Vector2, e: float, temps: float) -> void:
	ci.draw_circle(pieds + Vector2(0, -120) * e, 190.0 * e, Palette.SORTIE * Color(1, 1, 1, 0.12 + 0.05 * sin(temps * 2.2)))
	if Images.existe("porte_ouverte"):
		var r := Images.region("porte_ouverte")
		var k := 300.0 * e / r.size.y
		Images.dessiner(ci, "porte_ouverte", Rect2(pieds - Vector2(r.size.x * k / 2.0, r.size.y * k), r.size * k))


## Bords assombris (haut et bas) pour que le texte et les boutons ressortent.
static func _voile(ci: CanvasItem, taille: Vector2) -> void:
	var sombre := Color(Palette.FOND_NUIT, 0.9)
	var clair := Color(Palette.FOND_NUIT, 0.0)
	var h := taille.y * 0.3
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(taille.x, 0), Vector2(taille.x, h), Vector2(0, h)]),
		PackedColorArray([sombre, sombre, clair, clair]))
