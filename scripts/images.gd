extends Node
## Images détourées des planches V2 (atlas générés par outils/decoupe_v2.py, liste dans data/atlas.gd).
## Si une image manque, existe() est faux : l'appelant garde son dessin en code (jamais de carré vide).

const ATLAS := preload("res://data/atlas.gd")

var _textures := {}   # famille -> Texture2D (un atlas par famille)


func existe(nom: String) -> bool:
	return ATLAS.REGIONS.has(nom) and texture(nom) != null


func texture(nom: String) -> Texture2D:
	var famille: String = ATLAS.REGIONS[nom][0]
	if not _textures.has(famille):
		_textures[famille] = load("res://images/%s.png" % famille) if ResourceLoader.exists("res://images/%s.png" % famille) else null
	return _textures[famille]


func region(nom: String) -> Rect2:
	return ATLAS.REGIONS[nom][1]


## Décalage d'un calque (yeux) dans l'image du corps, en pixels de l'image.
func decalage(nom: String) -> Vector2:
	return ATLAS.REGIONS[nom][2]


## Coins au sol (gauche, avant, droit) puis pieds, en pixels de l'image.
func ancres(nom: String) -> PackedVector2Array:
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
