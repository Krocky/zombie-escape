extends "res://scripts/batiment.gd"
## Tourelle de la base (lot 4 g) : un bâtiment (Batiment : emprise, collision, chute du ciel) qui tire tout seul.
## Le niveau lui donne les zombies à chaque pas (viser) : chargée et posée, elle vise le plus proche à moins de
## Reglages.TOURELLE_PORTEE, tourne vers lui et tire toutes les Reglages.TOURELLE_CADENCE secondes (une balle) ;
## elle émet `tir`, le niveau fait les dégâts. Petit éclair au bout du canon et trace jaune jusqu'à la cible.
## Nombre de balles au-dessus d'elle (gris à 0), sans ombre et par-dessus le décor.
## Sans image : trépied, boîtier et canon dessinés en code. Avec l'image base_turret (trépied + boîtier, SANS
## canon), le canon reste dessiné en code par-dessus pour pouvoir tourner.

## Elle tire sur `cible` (une balle de moins).
signal tir(cible: Node2D)

## Échelle du dessin en code (1 = petite tourelle de 80 pixels de haut)
const E := 1.35
## Canon (pixels d'écran, depuis les pieds) : pivot, longueur, vitesse de rotation (radians par seconde)
const PIVOT := Vector2(0, -60) * E
const LONGUEUR_CANON := 46.0 * E
const VITESSE_ROTATION := 9.0
## Écart d'angle sous lequel elle peut tirer (radians), durée de l'éclair et de la trace (s)
const ANGLE_TIR := 0.3
const DUREE_TIR := 0.15
## Hauteur visée sur la cible (pixels d'écran au-dessus de ses pieds), du nombre de balles au-dessus des pieds
const HAUT_CIBLE := 55.0
const HAUT_BALLES := 125.0

## Balles dans la tourelle (Partie.balles_tourelles), donné par la base ; le nombre saute quand il augmente.
var balles := 0:
	set(valeur):
		if valeur > balles:
			_saut = 1.0
		balles = valeur
## Faux pour le fantôme du placement : pas de nombre de balles.
var montrer_balles := true

var _angle := 0.0               # direction du canon dans le monde (vers l'avant droit de l'écran au départ)
var _attente := 0.0             # temps avant le prochain tir possible
var _tir := 0.0                 # temps restant de l'éclair et de la trace
var _cible_ecran := Vector2.ZERO
var _saut := 0.0                # 1 -> 0 : le nombre de balles saute après une recharge
var _infos := Node2D.new()      # nombre de balles, éclair, trace : sans ombre, par-dessus tout


func _construire() -> void:
	super()
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_infos.material = sans_ombre
	_infos.z_as_relative = false
	_infos.z_index = 5
	_infos.position = _pieds
	_infos.draw.connect(_dessiner_infos)
	_vue.add_child(_infos)


func _process(delta: float) -> void:
	super(delta)
	_tir = maxf(_tir - delta, 0.0)
	_saut = maxf(_saut - delta * 3.0, 0.0)
	_infos.queue_redraw()


## Centre de l'emprise (monde) : d'où elle vise et tire.
func centre() -> Vector2:
	return emprise().get_center()


## Appelé par le niveau à chaque pas avec les zombies (groupe « zombies »). Rien sans balle, sans zombie à portée
## ou pendant sa chute du ciel.
func viser(zombies: Array, delta: float) -> void:
	_attente = maxf(_attente - delta, 0.0)
	if balles <= 0 or not pose():
		return
	var cible: Node2D = null
	var meilleure := Reglages.TOURELLE_PORTEE
	for zombie: Node2D in zombies:
		var d := centre().distance_to(zombie.global_position)
		if d <= meilleure:
			meilleure = d
			cible = zombie
	if cible == null:
		return
	var vise := centre().direction_to(cible.global_position).angle()
	_angle = rotate_toward(_angle, vise, VITESSE_ROTATION * delta)
	if _attente > 0.0 or absf(angle_difference(_angle, vise)) > ANGLE_TIR:
		return
	balles -= 1
	_attente = Reglages.TOURELLE_CADENCE
	_tir = DUREE_TIR
	_cible_ecran = Iso.ecran(cible.global_position) - Vector2(0, HAUT_CIBLE)
	tir.emit(cible)


## Bout du canon à l'écran, depuis le pivot (raccourci par la perspective quand il vise vers le fond).
func _bout_canon() -> Vector2:
	return PIVOT + Iso.ecran(Vector2.from_angle(_angle)) / Iso.K * LONGUEUR_CANON


## Dessin de secours (sans image), pieds en (0, 0) : trépied, boîtier kaki, bande de balles et canon.
func _dessiner_secours() -> void:
	var etat := _etat()
	_corps.draw_set_transform(Vector2(0, etat["dy"]), 0.0, Vector2(1.0 + etat["ecrase"], 1.0 - etat["ecrase"]) * E)
	Dessin.ombre(_corps, Rect2(-46, -12, 92, 24))
	var moyeu := Vector2(0, -40)
	# Pied arrière, puis les deux pieds avant
	for pied: Vector2 in [Vector2(6, -14), Vector2(-34, 6), Vector2(34, 6)]:
		_corps.draw_line(moyeu, pied, Palette.CONTOUR, 11.0)
		_corps.draw_line(moyeu, pied, Palette.TOLE, 5.0)
	var vers_le_fond := _bout_canon().y < PIVOT.y
	if vers_le_fond:
		_canon(_corps, Vector2.ZERO, 1.0 / E)
	# Boîtier kaki en volume (dessus plus clair), bande sombre, rivets
	Dessin.polygone(_corps, PackedVector2Array([Vector2(-25, -76), Vector2(-15, -84), Vector2(35, -84), Vector2(25, -76)]),
		Palette.BALLES_BOITE.lightened(0.25))
	Dessin.polygone(_corps, PackedVector2Array([Vector2(25, -76), Vector2(35, -84), Vector2(35, -48), Vector2(25, -40)]),
		Palette.BALLES_BOITE.darkened(0.25))
	Dessin.rect(_corps, Rect2(-25, -76, 50, 36), Palette.BALLES_BOITE)
	_corps.draw_rect(Rect2(-23, -53, 46, 6), Palette.BALLES_BOITE.darkened(0.3))
	for x: float in [-18.0, 18.0]:
		_corps.draw_circle(Vector2(x, -70), 2.5, Palette.CONTOUR)
	# Bande de cartouches qui pend sur le côté
	for k in 4:
		Dessin.rect(_corps, Rect2(-30 - k * 2, -48 + k * 7, 8, 6), Palette.BALLES_CUIVRE, false)
	Dessin.cercle(_corps, PIVOT / E, 9.0, Palette.TOLE)
	if not vers_le_fond:
		_canon(_corps, Vector2.ZERO, 1.0 / E)
	_corps.draw_set_transform(Vector2.ZERO)


## Avec l'image : seul le canon est dessiné en code, par-dessus.
func _dessiner_effets() -> void:
	super()
	if not _bandes.is_empty() and pose():
		_effets.draw_set_transform(_pieds - _effets.position)
		_canon(_effets, Vector2.ZERO)
		_effets.draw_set_transform(Vector2.ZERO)


## Canon : tube sombre à contour épais, bouche cerclée de métal. k : échelle du repère de dessin (1 / E dans le
## dessin de secours, déjà agrandi de E).
func _canon(ci: CanvasItem, pieds: Vector2, k := 1.0) -> void:
	var a := pieds + PIVOT * k
	var b := pieds + _bout_canon() * k
	ci.draw_line(a, b, Palette.CONTOUR, 17.0 * k * E)
	ci.draw_line(a, b, Palette.PNEU.lightened(0.15), 9.0 * k * E)
	ci.draw_circle(b, 7.5 * k * E, Palette.CONTOUR)
	ci.draw_circle(b, 4.0 * k * E, Palette.TOLE)


## Nombre de balles (gris à 0) et, juste après un tir, éclair au bout du canon et trace jusqu'à la cible.
func _dessiner_infos() -> void:
	if not pose():
		return
	if _tir > 0.0:
		var f := minf(_tir / DUREE_TIR, 1.0)
		var bout := _bout_canon()
		_infos.draw_line(bout, _cible_ecran - _pieds, Color(Palette.LAMPE, 0.8 * f), 4.0, true)
		var r := 16.0 * f + 6.0
		_infos.draw_colored_polygon(PackedVector2Array([bout + Vector2(0, -r), bout + Vector2(r * 0.3, -r * 0.3),
			bout + Vector2(r, 0), bout + Vector2(r * 0.3, r * 0.3), bout + Vector2(0, r), bout + Vector2(-r * 0.3, r * 0.3),
			bout + Vector2(-r, 0), bout + Vector2(-r * 0.3, -r * 0.3)]), Color(Palette.FEU_COEUR, f))
		_infos.draw_circle(_cible_ecran - _pieds, 9.0 * f, Color(Palette.LAMPE, f))
	if not montrer_balles:
		return
	var police := ThemeDB.fallback_font
	var taille := int(30 * (1.0 + 0.4 * _saut))
	var texte := str(balles)
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var p := Vector2(-largeur / 2.0 + 10.0, -HAUT_BALLES)
	var couleur := Palette.LAMPE if balles > 0 else Palette.UI_BORD
	# Petite cartouche devant le nombre
	Dessin.rect(_infos, Rect2(p.x - 22, p.y - 22, 10, 18), Palette.BALLES_CUIVRE if balles > 0 else Palette.UI_BORD)
	_infos.draw_string_outline(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 7, Palette.CONTOUR)
	_infos.draw_string(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
