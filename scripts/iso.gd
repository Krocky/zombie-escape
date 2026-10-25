extends Node
## Vue isométrique. La physique, l'IA et les positions restent dans le plan du sol (coordonnées
## « monde », inchangées) ; seul l'affichage est projeté à l'écran, dans le calque `Vue` du niveau.
## Les losanges des images V2 sont en 1,7:1 (RAPPORT), pas en 2:1.

const K := 0.6                 # monde -> écran (largeur)
const RAPPORT := 0.588         # hauteur / largeur d'un losange au sol
const LARGEUR_BANDE := 24.0    # bandes verticales des objets du décor, triées chacune en profondeur


func ecran(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * K, (p.x + p.y) * K * RAPPORT)


func monde(e: Vector2) -> Vector2:
	var a := e.x / K
	var b := e.y / (K * RAPPORT)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## Direction à l'écran (joystick) -> direction dans le monde, de longueur 1.
func direction_monde(d: Vector2) -> Vector2:
	return monde(d).normalized()


## Direction dans le monde -> direction à l'écran, de longueur 1.
func direction_ecran(d: Vector2) -> Vector2:
	return ecran(d).normalized()


## Coins à l'écran d'une emprise au sol : gauche, avant (le plus bas), droit, arrière.
func coins(emprise: Rect2) -> PackedVector2Array:
	return PackedVector2Array([ecran(Vector2(emprise.position.x, emprise.end.y)), ecran(emprise.end),
		ecran(Vector2(emprise.end.x, emprise.position.y)), ecran(emprise.position)])


## Vrai si l'image doit être retournée pour être longue dans le sens voulu (x ou y du monde).
## Le sens de l'image est déduit de ses coins au sol (bord avant-gauche = sens x).
func miroir_pour(nom: String, long_en_x: bool) -> bool:
	var a := Images.ancres(nom)
	var image_en_x := (a[1].x - a[0].x) >= (a[2].x - a[1].x)
	return image_en_x != long_en_x


## Habille une emprise au sol avec l'image « nom », découpée en bandes verticales : chaque bande
## est triée selon le bord avant de l'emprise sous elle, pour que les personnages passent
## correctement devant ou derrière. Les coins gauche et droit de l'image (ancres) sont posés sur ceux
## de l'emprise à l'écran, son coin avant à la hauteur du coin avant. Les bandes sont ajoutées à `conteneur`.
## Renvoie le rectangle de l'image à l'écran.
func habiller(nom: String, emprise: Rect2, conteneur: Node2D, miroir := false, couleur := Color.WHITE) -> Rect2:
	var c := coins(emprise)
	var r := Images.region(nom)
	var place := placement(nom, emprise, miroir)
	var origine := place.position
	var e := place.size.x
	var largeur := r.size.x * e
	var n := maxi(int(ceil(largeur / LARGEUR_BANDE)), 1)
	for i in n:
		var x0 := origine.x + largeur * i / n
		var x1 := origine.x + largeur * (i + 1) / n
		var ix0 := (x0 - origine.x) / e
		var ix1 := minf((x1 - origine.x) / e + 1.0, r.size.x)   # +1 pixel : pas de jour entre les bandes
		var source := r.size.x - ix1 if miroir else ix0
		var xc := (x0 + x1) * 0.5
		var cle := bord_avant(c, xc)
		# Bande recadrée en hauteur sur ses pixels visibles : moins de pixels transparents à dessiner
		# et à éclairer (une bande de mur en biais est vide en haut et en bas)
		var vide := _vide_vertical(nom, Rect2(r.position.x + source, r.position.y, ix1 - ix0, r.size.y))
		var bande := Sprite2D.new()
		bande.texture = Images.texture(nom)
		bande.region_enabled = true
		bande.region_rect = Rect2(r.position.x + source, r.position.y + vide.x, ix1 - ix0, r.size.y - vide.x - vide.y)
		bande.flip_h = miroir
		bande.centered = false
		bande.scale = Vector2(e, e)
		bande.position = Vector2(xc, cle)
		bande.offset = Vector2((x0 - xc) / e, (origine.y - cle) / e + vide.x)
		bande.modulate = couleur
		conteneur.add_child(bande)
	return Rect2(origine, r.size * e)


## Placement de l'image « nom » sur l'emprise (voir habiller) : position = coin haut gauche de l'image
## à l'écran, size.x = échelle.
func placement(nom: String, emprise: Rect2, miroir := false) -> Rect2:
	var c := coins(emprise)
	var r := Images.region(nom)
	var a := Images.ancres(nom)
	var e := (c[2].x - c[0].x) / maxf(a[2].x - a[0].x, 1.0)
	var gauche := (r.size.x - a[2].x) if miroir else a[0].x
	return Rect2(Vector2(c[0].x - gauche * e, c[1].y - a[1].y * e), Vector2(e, e))


## Point de l'image « nom » (pixels de l'image non retournée) à l'écran, quand elle habille cette emprise.
func point_image(nom: String, emprise: Rect2, point: Vector2, miroir := false) -> Vector2:
	var place := placement(nom, emprise, miroir)
	if miroir:
		point.x = Images.region(nom).size.x - point.x
	return place.position + point * place.size.x


## Emprise au sol aux proportions de l'image « nom » : même grand côté que `taille` (dans le même sens),
## petit côté recalculé. Si `taille` est bien plus longue que l'image, elle est découpée en `n` morceaux
## (rayons) : le petit côté suit alors la longueur d'un morceau. Renvoie [taille, n].
func taille_image(nom: String, taille: Vector2) -> Array:
	var a := Images.ancres(nom)
	var cotes := Vector2(a[1].x - a[0].x, a[2].x - a[1].x)   # côtés de l'image : x, y du monde (non retournée)
	var rapport := minf(cotes.x, cotes.y) / maxf(maxf(cotes.x, cotes.y), 1.0)
	var longueur := maxf(taille.x, taille.y)
	var court := minf(taille.x, taille.y)
	var n := maxi(roundi(longueur * rapport / maxf(court, 1.0)), 1)
	court = longueur / n * rapport
	return [Vector2(longueur, court) if taille.x >= taille.y else Vector2(court, longueur), n]


## Grand meuble devant le héros : il devient transparent tant que le héros est derrière lui et caché
## par son image. `image` = rectangle de l'image à l'écran, `c` = coins de son emprise, `pieds` = pieds
## du héros à l'écran (Vector2.INF : pas de héros à montrer). Renvoie l'opacité visée.
const TRANSPARENCE := 0.45
const HAUTEUR_HEROS := 110.0   # hauteur du héros à l'écran, à peu près


func opacite_devant(image: Rect2, c: PackedVector2Array, pieds: Vector2) -> float:
	if pieds == Vector2.INF or pieds.x < c[0].x - 10.0 or pieds.x > c[2].x + 10.0:
		return 1.0
	if pieds.y >= bord_avant(c, pieds.x):
		return 1.0   # devant : rien ne le cache
	var corps := Rect2(pieds.x - 22.0, pieds.y - HAUTEUR_HEROS, 44.0, HAUTEUR_HEROS - 30.0)
	return TRANSPARENCE if image.intersects(corps) else 1.0


var _vides := {}   # bande de l'atlas -> lignes transparentes (haut, bas), calculé une fois


## Lignes entièrement transparentes en haut (x) et en bas (y) d'une bande de l'atlas.
## Une ligne de marge est gardée de chaque côté (filtrage).
func _vide_vertical(nom: String, bande: Rect2) -> Vector2:
	var zone := Rect2i(Vector2i(bande.position.floor()), Vector2i.ZERO)
	zone.end = Vector2i(bande.end.ceil())
	if _vides.has(zone):
		return _vides[zone]
	var vide := Vector2.ZERO
	var image := Images.image(nom)
	if image:
		var utile := image.get_region(zone).get_used_rect()
		if utile.size.y > 0:
			vide = Vector2(maxi(utile.position.y - 1, 0), maxi(zone.size.y - utile.end.y - 1, 0))
	_vides[zone] = vide
	return vide


## Hauteur à l'écran du bord avant d'une emprise (coins), à l'abscisse x.
func bord_avant(c: PackedVector2Array, x: float) -> float:
	x = clampf(x, c[0].x, c[2].x)
	if x <= c[1].x:
		return lerpf(c[0].y, c[1].y, (x - c[0].x) / maxf(c[1].x - c[0].x, 0.001))
	return lerpf(c[1].y, c[2].y, (x - c[1].x) / maxf(c[2].x - c[1].x, 0.001))


## Hauteur à l'écran, en pixels, de l'image « nom » quand elle habille cette emprise.
func hauteur_image(nom: String, emprise: Rect2) -> float:
	return Images.region(nom).size.y * placement(nom, emprise).size.x


## Ombre douce au sol sous une emprise (dessinée sur ci, en coordonnées écran).
func ombre(ci: CanvasItem, emprise: Rect2, force := 1.0) -> void:
	var c := coins(emprise)
	var haut := c[3].y
	Dessin.ombre(ci, Rect2(c[0].x - 14, haut - 6, c[2].x - c[0].x + 28, c[1].y - haut + 22), force)
