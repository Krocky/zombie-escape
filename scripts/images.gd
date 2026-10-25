extends Node
## Images détourées des planches V2 (atlas générés par outils/decoupe_v2.py, liste dans data/atlas.gd).
## Les images V3 du décor (prop_, wall_, floor_ : images/v3) passent par les mêmes fonctions (existe, region,
## ancres...) : elles s'utilisent comme une image V2 (Iso.habiller).
## Si une image manque, existe() est faux : l'appelant garde son dessin en code (jamais de carré vide).

const ATLAS := preload("res://data/atlas.gd")

var _textures := {}   # famille -> Texture2D (un atlas par famille)
var _images := {}     # famille -> Image (pixels de l'atlas, lus à la demande)


func existe(nom: String) -> bool:
	if not ATLAS.REGIONS.has(nom):
		return v3_existe(nom)
	return texture(nom) != null


func texture(nom: String) -> Texture2D:
	if not ATLAS.REGIONS.has(nom):
		return v3_texture(nom)
	var famille: String = ATLAS.REGIONS[nom][0]
	if not _textures.has(famille):
		_textures[famille] = load("res://images/%s.png" % famille) if ResourceLoader.exists("res://images/%s.png" % famille) else null
	return _textures[famille]


## Pixels de l'atlas de « nom » (pour trouver ses parties transparentes), null si illisibles.
func image(nom: String) -> Image:
	if not ATLAS.REGIONS.has(nom):
		if not _images.has(nom):
			var img := v3_texture(nom).get_image()
			if img and img.is_compressed():
				img.decompress()
			_images[nom] = img
		return _images[nom]
	var famille: String = ATLAS.REGIONS[nom][0]
	if not _images.has(famille):
		var t := texture(nom)
		_images[famille] = t.get_image() if t else null
	return _images[famille]


func region(nom: String) -> Rect2:
	if not ATLAS.REGIONS.has(nom):
		return Rect2(Vector2.ZERO, v3_taille(nom))
	return ATLAS.REGIONS[nom][1]


## Décalage d'un calque (yeux) dans l'image du corps, en pixels de l'image.
func decalage(nom: String) -> Vector2:
	return ATLAS.REGIONS[nom][2]


## Coins au sol (gauche, avant, droit) puis pieds, en pixels de l'image.
func ancres(nom: String) -> PackedVector2Array:
	if not ATLAS.REGIONS.has(nom):
		return v3_ancres(nom)
	return PackedVector2Array(ATLAS.REGIONS[nom][3])


## Les fonctions de dessin acceptent `base` : la transformation de dessin en cours sur ci
## (draw_set_transform), rétablie après un dessin retourné.

## Dessine un personnage : ses pieds (ancre) posés sur « pieds », à l'échelle, retourné si miroir.
func dessiner_pieds(ci: CanvasItem, nom: String, pieds: Vector2, echelle: float, miroir := false, couleur := Color.WHITE, base := Transform2D.IDENTITY) -> void:
	var r := region(nom)
	var p := ancres(nom)[3]
	var x := (r.size.x - p.x) if miroir else p.x
	_dessiner(ci, nom, Rect2(pieds - Vector2(x, p.y) * echelle, r.size * echelle), miroir, couleur, base)


## Dessine le calque « nom_calque » (ex. yeux) aligné sur l'image « nom_corps » dessinée par dessiner_pieds.
func dessiner_calque(ci: CanvasItem, nom_corps: String, nom_calque: String, pieds: Vector2, echelle: float, miroir := false, couleur := Color.WHITE, base := Transform2D.IDENTITY) -> void:
	var corps := region(nom_corps)
	var calque := region(nom_calque)
	var p := ancres(nom_corps)[3]
	var x := (corps.size.x - p.x) if miroir else p.x
	var coin := pieds - Vector2(x, p.y) * echelle
	var d := decalage(nom_calque)
	if miroir:
		d.x = corps.size.x - d.x - calque.size.x
	_dessiner(ci, nom_calque, Rect2(coin + d * echelle, calque.size * echelle), miroir, couleur, base)


## Centre à l'écran du calque « nom_calque » placé comme par dessiner_calque.
func centre_calque(nom_corps: String, nom_calque: String, pieds: Vector2, echelle: float, miroir := false) -> Vector2:
	var calque := region(nom_calque)
	var p := ancres(nom_corps)[3]
	var d := decalage(nom_calque) + calque.size / 2.0
	if miroir:
		return pieds + Vector2(p.x - d.x, d.y - p.y) * echelle
	return pieds + (d - p) * echelle


## Dessine l'image entière dans le rectangle cible.
func dessiner(ci: CanvasItem, nom: String, cible: Rect2, miroir := false, couleur := Color.WHITE, base := Transform2D.IDENTITY) -> void:
	_dessiner(ci, nom, cible, miroir, couleur, base)


func _dessiner(ci: CanvasItem, nom: String, cible: Rect2, miroir: bool, couleur: Color, base: Transform2D) -> void:
	if not miroir:
		ci.draw_texture_rect_region(texture(nom), cible, region(nom), couleur)
		return
	# Retourné : symétrie autour du milieu du rectangle cible
	var centre := cible.position.x + cible.size.x / 2.0
	ci.draw_set_transform_matrix(base * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(2.0 * centre, 0)))
	ci.draw_texture_rect_region(texture(nom), cible, region(nom), couleur)
	ci.draw_set_transform_matrix(base)


# --- Images V3 (une image par fichier, tools/process_assets.py) ---
## Poses d'un personnage V3 : images/v3/<perso>_<pose>.png, ancre aux pieds dans images/v3/manifest.json.
## Les images regardent vers la droite (héros) ou vers la gauche (zombie coureur, voir V3_GAUCHE).

const DOSSIER_V3 := "res://images/v3/"
const V3_GAUCHE := ["zombie_runner"]
## Noms de pose acceptés pour l'immobile (la source s'appelle « iddle »)
const POSES_IMMOBILE := ["idle", "iddle"]

## Emprise au sol des images V3 du décor, mesurée à l'œil sur les images : [x du coin gauche, coin avant,
## x du coin droit] (pixels de l'image). Les coins du manifest suivent souvent l'ombre ou le socle effacé.
## Les y des coins gauche et droit sont recalculés avec la pente du jeu (Iso.RAPPORT).
const EMPRISES_V3 := {
	"prop_sofa_2c": [30.0, Vector2(194, 600), 660.0],
	"prop_bed_2c": [5.0, Vector2(234, 652), 700.0],
	"prop_kitchen_table_2c": [30.0, Vector2(252, 580), 570.0],
	"prop_fridge": [2.0, Vector2(82, 334), 208.0],
	"prop_bookshelf": [44.0, Vector2(145, 670), 395.0],
	"prop_shelf_wood": [30.0, Vector2(145, 594), 446.0],
	"prop_wardrobe": [25.0, Vector2(142, 672), 455.0],
	"prop_bathtub_2c": [25.0, Vector2(360, 1330), 930.0],
	"prop_shelf_food_2c": [9.0, Vector2(112, 690), 519.0],
	"prop_freezer": [2.0, Vector2(112, 336), 336.0],
	"prop_checkout_2c": [100.0, Vector2(260, 632), 672.0],
	"prop_cart": [30.0, Vector2(170, 410), 440.0],
	"prop_pallet": [2.0, Vector2(145, 324), 315.0],
	"prop_neon": [0.0, Vector2(128, 340), 252.0],
}
## Fenêtre peinte sur les pans de mur V3 (« <mur>_fenetre », voir v3_fenetre) : le long du pan (0 à 1)
## et en hauteur au-dessus du bas du pan (pixels de l'image).
const FENETRE_LONG := Vector2(0.24, 0.76)
const FENETRE_HAUT := Vector2(150.0, 330.0)
const FENETRE_CADRE := 9.0

var _v3 = null           # nom -> infos du manifest (null tant qu'il n'est pas lu)
var _v3_textures := {}   # nom -> Texture2D
var _v3_lampes := {}     # nom -> position de la lampe (pixels de l'image)
var _v3_yeux := {}       # nom -> Rect2 des yeux jaunes (pixels de l'image), vide s'il n'y en a pas
var _v3_variantes := {}  # "nom|variante" -> Texture2D recolorée (grisée, étiquette teintée)


func _manifest_v3() -> Dictionary:
	if _v3 == null:
		_v3 = {}
		var texte := FileAccess.get_file_as_string(DOSSIER_V3 + "manifest.json")
		var donnees = JSON.parse_string(texte) if texte != "" else null
		if donnees is Dictionary and donnees.get("images") is Dictionary:
			_v3 = donnees["images"]
	return _v3


func v3_existe(nom: String) -> bool:
	return (_manifest_v3().has(nom) or _v3_textures.has(nom)) and v3_texture(nom) != null


func v3_texture(nom: String) -> Texture2D:
	if not _v3_textures.has(nom):
		var chemin := DOSSIER_V3 + nom + ".png"
		var texture: Texture2D = load(chemin) if ResourceLoader.exists(chemin) else null
		if texture and Palette.CLARTE_V3.has(nom):
			# Image trop claire pour la nuit : assombrie une fois (Palette.CLARTE_V3)
			var img := texture.get_image()
			if img.is_compressed():
				img.decompress()
			img.adjust_bcs(Palette.CLARTE_V3[nom], 1.0, 1.0)
			texture = ImageTexture.create_from_image(img)
		_v3_textures[nom] = texture
	return _v3_textures[nom]


## Pose « pose » du personnage, ou "" si l'image n'existe pas.
func v3_pose(perso: String, pose: String) -> String:
	var noms := POSES_IMMOBILE if pose in POSES_IMMOBILE else [pose]
	for p in noms:
		if v3_existe(perso + "_" + p):
			return perso + "_" + p
	return ""


## Poses de marche du personnage (walk_a / walk_b, ou run_a / run_b), vide s'il n'y en a pas.
func v3_marche(perso: String) -> Array:
	for paire in [["walk_a", "walk_b"], ["run_a", "run_b"]]:
		var a := v3_pose(perso, paire[0])
		var b := v3_pose(perso, paire[1])
		if a != "" and b != "":
			return [a, b]
	return []


func v3_taille(nom: String) -> Vector2:
	return v3_texture(nom).get_size()


## Coins au sol (gauche, avant, droit) puis pieds d'une image V3 du décor (voir ancres).
func v3_ancres(nom: String) -> PackedVector2Array:
	nom = nom.trim_suffix("_fenetre")
	if EMPRISES_V3.has(nom):
		var e: Array = EMPRISES_V3[nom]
		var avant: Vector2 = e[1]
		return PackedVector2Array([Vector2(e[0], avant.y - (avant.x - e[0]) * Iso.RAPPORT), avant,
			Vector2(e[2], avant.y - (e[2] - avant.x) * Iso.RAPPORT), avant])
	var c: Dictionary = _manifest_v3()[nom].get("coins_sol", {})
	var t := v3_taille(nom)
	var coins := PackedVector2Array()
	for coin in [["gauche", Vector2(0, t.y)], ["avant", Vector2(t.x / 2.0, t.y)], ["droit", t]]:
		var p: Array = c.get(coin[0], [])
		coins.append(Vector2(p[0], p[1]) if p.size() >= 2 else coin[1])
	coins.append(coins[1])
	return coins


## Pan de mur V3 avec une fenêtre éclairée par la lune, peinte une fois sur une copie de l'image
## (le pan reste une seule image, découpée et triée comme les autres). Renvoie son nom (« <mur>_fenetre »).
func v3_fenetre(mur: String) -> String:
	var nom := mur + "_fenetre"
	if _v3_textures.has(nom):
		return nom
	var img: Image = v3_texture(mur).get_image().duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	# Bas du grand côté du pan : du coin avant au coin droit (image non retournée)
	var c := v3_ancres(mur)
	var a := c[1]
	var d := c[2]
	var x0 := int(a.x + (d.x - a.x) * FENETRE_LONG.x)
	var x1 := int(a.x + (d.x - a.x) * FENETRE_LONG.y)
	var cadre_u := FENETRE_CADRE / (d.x - a.x)
	for x in range(x0, x1 + 1):
		var u := (x - a.x) / (d.x - a.x)
		var bas := a.y + (d.y - a.y) * u
		for y in range(int(bas - FENETRE_HAUT.y), int(bas - FENETRE_HAUT.x) + 1):
			if y < 0 or y >= img.get_height():
				continue
			var h := bas - y
			var bord_u := minf(u - FENETRE_LONG.x, FENETRE_LONG.y - u)
			var bord_h := minf(h - FENETRE_HAUT.x, FENETRE_HAUT.y - h)
			var milieu_u := absf(u - (FENETRE_LONG.x + FENETRE_LONG.y) / 2.0)
			var milieu_h := absf(h - (FENETRE_HAUT.x + FENETRE_HAUT.y) / 2.0)
			var couleur: Color
			if bord_u < cadre_u * 0.4 or bord_h < FENETRE_CADRE * 0.4:
				couleur = Palette.CONTOUR
			elif bord_u < cadre_u or bord_h < FENETRE_CADRE or milieu_u < cadre_u * 0.35 or milieu_h < FENETRE_CADRE * 0.35:
				couleur = Palette.FENETRE_CADRE
			else:
				# Vitre : plus claire en haut, un reflet en biais
				couleur = Palette.FENETRE.lerp(Palette.FENETRE_REFLET, clampf((h - FENETRE_HAUT.x) / (FENETRE_HAUT.y - FENETRE_HAUT.x), 0.0, 1.0) * 0.5)
				if absf(fmod(h * 0.6 + (x - x0) * 1.0, 70.0) - 35.0) < 4.0:
					couleur = couleur.lerp(Palette.FENETRE_REFLET, 0.6)
			img.set_pixel(x, y, couleur)
	_v3_textures[nom] = ImageTexture.create_from_image(img)
	return nom


func v3_pieds(nom: String) -> Vector2:
	var a: Array = _manifest_v3()[nom].get("ancre_pieds", [])
	if a.size() < 2:
		return Vector2(v3_taille(nom).x / 2.0, v3_taille(nom).y)
	return Vector2(a[0], a[1])


## Version grisée d'une image V3 (bouton en attente ou inactif), calculée une seule fois.
func v3_gris(nom: String) -> Texture2D:
	return _v3_variante(nom, "gris", func(c: Color) -> Color:
		var l := c.get_luminance()
		return Color(l, l, l, c.a))


## Image V3 dont les pixels rouges vifs (étiquette de la clef) prennent la teinte de « couleur »,
## en gardant leurs ombres et reflets. Calculée une seule fois par couleur.
func v3_teinte(nom: String, couleur: Color) -> Texture2D:
	return _v3_variante(nom, couleur.to_html(), func(c: Color) -> Color:
		if c.a < 0.05 or c.s < 0.45 or c.v < 0.25 or (c.h > 0.05 and c.h < 0.95):
			return c
		return Color.from_hsv(couleur.h, minf(1.0, c.s * couleur.s / 0.75), minf(1.0, c.v * couleur.v), c.a))


func _v3_variante(nom: String, variante: String, recolorer: Callable) -> Texture2D:
	var cle := nom + "|" + variante
	if not _v3_variantes.has(cle):
		var image := v3_texture(nom).get_image()
		if image == null:
			_v3_variantes[cle] = v3_texture(nom)
			return _v3_variantes[cle]
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				image.set_pixel(x, y, recolorer.call(image.get_pixel(x, y)))
		_v3_variantes[cle] = ImageTexture.create_from_image(image)
	return _v3_variantes[cle]


## Lampe torche : le pixel visible le plus à droite (le plus à gauche si « gauche », poses de dos),
## à hauteur de main (entre 35 et 65 % de la hauteur).
func v3_lampe(nom: String, gauche := false) -> Vector2:
	var cle := nom + (":gauche" if gauche else "")
	if not _v3_lampes.has(cle):
		var image := v3_texture(nom).get_image()
		var t := v3_taille(nom)
		var lampe := Vector2(0.0 if gauche else t.x, t.y * 0.5)
		if image:
			if image.is_compressed():
				image.decompress()
			var trouve := false
			var colonnes: Array = range(int(t.x)) if gauche else range(int(t.x) - 1, -1, -1)
			for x in colonnes:
				for y in range(int(t.y * 0.35), int(t.y * 0.65)):
					if image.get_pixel(x, y).a > 0.5:
						lampe = Vector2(x, y)
						trouve = true
						break
				if trouve:
					break
		_v3_lampes[cle] = lampe
	return _v3_lampes[cle]


## Yeux jaunes (zombie) : rectangle des pixels jaunes vifs dans le tiers haut de l'image.
func v3_yeux(nom: String) -> Rect2:
	if not _v3_yeux.has(nom):
		var zone := Rect2()
		var image := v3_texture(nom).get_image()
		if image:
			if image.is_compressed():
				image.decompress()
			var t := v3_taille(nom)
			var premier := true
			for y in int(t.y * 0.35):
				for x in int(t.x):
					var c := image.get_pixel(x, y)
					if c.a > 0.8 and c.r > 0.8 and c.g > 0.75 and c.b < 0.45:
						if premier:
							zone = Rect2(x, y, 1, 1)
							premier = false
						else:
							zone = zone.expand(Vector2(x + 1, y + 1)).expand(Vector2(x, y))
		_v3_yeux[nom] = zone
	return _v3_yeux[nom]


## Coin haut gauche de l'image (à l'échelle) pour que ses pieds soient sur « pieds ».
func _v3_coin(nom: String, pieds: Vector2, echelle: float, miroir: bool) -> Vector2:
	var p := v3_pieds(nom)
	var x := (v3_taille(nom).x - p.x) if miroir else p.x
	return pieds - Vector2(x, p.y) * echelle


## Dessine une pose V3, pieds sur « pieds ». Si « zone » est donnée (pixels de l'image), seule cette partie est dessinée.
func v3_dessiner(ci: CanvasItem, nom: String, pieds: Vector2, echelle: float, miroir := false, couleur := Color.WHITE, base := Transform2D.IDENTITY, zone := Rect2()) -> void:
	var t := v3_taille(nom)
	if zone.size == Vector2.ZERO:
		zone = Rect2(Vector2.ZERO, t)
	var coin := _v3_coin(nom, pieds, echelle, miroir)
	var cible := Rect2(coin + zone.position * echelle, zone.size * echelle)
	if miroir:
		cible.position.x = coin.x + (t.x - zone.end.x) * echelle
		var centre := cible.position.x + cible.size.x / 2.0
		ci.draw_set_transform_matrix(base * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(2.0 * centre, 0)))
	ci.draw_texture_rect_region(v3_texture(nom), cible, zone, couleur)
	if miroir:
		ci.draw_set_transform_matrix(base)


## Point de l'image (pixels) à l'écran, pour une pose dessinée par v3_dessiner.
func v3_point(nom: String, point: Vector2, pieds: Vector2, echelle: float, miroir := false) -> Vector2:
	var p := point - v3_pieds(nom)
	if miroir:
		p.x = -p.x
	return pieds + p * echelle


## Animation d'un personnage V3 : poses de marche alternées si elles existent, sinon la pose immobile
## qui rebondit et se penche un peu ; pose « attack » pendant un coup.
const CADENCE_V3 := 6.0         # poses de marche par seconde
const REBOND_V3 := 7.0          # hauteur du rebond (pixels à l'écran), sans poses de marche
const INCLINAISON_V3 := 0.07    # inclinaison du rebond (radians, ~4°)


## « dos » : il regarde vers le haut de l'écran ; poses <perso>_back_* (immobile, walk_a / walk_b) si elles
## existent toutes, sinon les poses habituelles. Le coup garde la pose de profil.
## {"nom": pose à dessiner ("" si le personnage n'a pas d'image V3), "decalage": Vector2, "angle": float,
##  "dos": bool (pose de dos : lampe dans la main gauche de l'image)}
func v3_animation(perso: String, temps: float, marche: bool, attaque := false, cadence := CADENCE_V3, dos := false) -> Dictionary:
	var anim := {"nom": v3_pose(perso, "idle"), "decalage": Vector2.ZERO, "angle": 0.0, "dos": false}
	if attaque and v3_pose(perso, "attack") != "":
		anim["nom"] = v3_pose(perso, "attack")
		return anim
	if dos and v3_pose(perso + "_back", "idle") != "" and v3_marche(perso + "_back").size() == 2:
		anim["dos"] = true
		anim["nom"] = v3_marche(perso + "_back")[int(temps * cadence) % 2] if marche else v3_pose(perso + "_back", "idle")
		return anim
	if not marche or anim["nom"] == "":
		return anim
	var cycle := v3_marche(perso)
	if cycle.size() == 2:
		anim["nom"] = cycle[int(temps * cadence) % 2]
	else:
		var phase := temps * cadence * PI / 2.0
		anim["decalage"] = Vector2(0, -absf(sin(phase)) * REBOND_V3)
		anim["angle"] = sin(phase) * INCLINAISON_V3
	return anim
