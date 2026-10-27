extends "res://scripts/batiment.gd"
## Barricade de la base (lot 4 h2) : un bâtiment (Batiment : emprise, collision, chute du ciel) qui peut casser
## pendant la défense de la base. Elle a Reglages.BARRICADE_PV points de solidité ; un zombie bloqué contre elle la
## frappe (le niveau appelle abimer) : -1 point, éclats de bois, elle tremble, des fissures se dessinent par-dessus
## (une de plus par point perdu) et une barre de solidité apparaît au-dessus. À 0, elle s'effondre (nuage de
## poussière, elle s'affaisse) et ne bloque plus rien. Le bouton Réparer (le niveau appelle reparer) lui rend des
## points tant qu'elle n'est pas effondrée. La solidité n'est pas sauvegardée : chaque niveau (et la base) la
## retrouve entière.

## Éclats de bois et tremblement après un coup, effondrement (s)
const DUREE_ECLATS := 0.45
const DUREE_TREMBLEMENT := 0.2
const DUREE_EFFONDREMENT := 0.8
## Effondrée, elle garde cette part de sa hauteur (un tas de planches), assombrie
const RESTE := 0.28
const TEINTE_EFFONDREE := Color(0.6, 0.58, 0.66)
## Nuage de l'effondrement : sans ombre (visible la nuit), donc plus léger que celui de la chute du ciel
const OPACITE_POUSSIERE := 0.22
## Barre de solidité (pixels d'écran) : taille, écart au-dessus de l'image
const TAILLE_BARRE := Vector2(110, 16)
const ECART_BARRE := 18.0

var solidite := Reglages.BARRICADE_PV
var _eclats := 0.0              # temps restant des éclats de bois
var _effondrement := -1.0       # temps depuis l'effondrement (< 0 : debout)
var _infos := Node2D.new()      # barre de solidité, éclats et poussière : sans ombre, par-dessus le décor


func _ready() -> void:
	add_to_group("barricades")
	super()


## Solidité au plus (Reglages.BARRICADE_PV, au moins 1).
func solidite_max() -> int:
	return maxi(Reglages.BARRICADE_PV, 1)


## Elle bloque encore (pas effondrée).
func solide() -> bool:
	return solidite > 0


## Abîmée mais pas effondrée : elle se répare.
func abimee() -> bool:
	return solidite > 0 and solidite < solidite_max()


## Un zombie la frappe : un point de moins ; à 0, elle s'effondre.
func abimer() -> void:
	if not solide():
		return
	solidite -= 1
	_eclats = DUREE_ECLATS
	if solidite == 0:
		_effondrement = 0.0
		for enfant in get_children():
			if enfant is CollisionShape2D:
				enfant.set_deferred("disabled", true)


## Le héros la répare : un point de plus (pas si elle est effondrée ou déjà entière).
func reparer() -> void:
	if abimee():
		solidite += 1


func _construire() -> void:
	super()
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_infos.material = sans_ombre
	_infos.z_as_relative = false
	_infos.z_index = 5
	_infos.draw.connect(_dessiner_infos)
	_vue.add_child(_infos)


func _process(delta: float) -> void:
	super(delta)
	var tremblement := _eclats - (DUREE_ECLATS - DUREE_TREMBLEMENT)
	_eclats = maxf(_eclats - delta, 0.0)
	_vue.position.x = sin(_temps * 70.0) * 4.0 if tremblement > 0.0 else 0.0
	if _effondrement >= 0.0:
		_effondrement += delta
		_affaisser(minf(_effondrement / (DUREE_EFFONDREMENT * 0.5), 1.0))
	_infos.queue_redraw()


## Effondrement : le dessin s'écrase vers le sol (f de 0 à 1) jusqu'à RESTE de sa hauteur, et s'assombrit.
func _affaisser(f: float) -> void:
	var haut := lerpf(1.0, RESTE, f)
	for b in _bandes:
		b[0].scale.y = b[2].y * haut
		b[0].offset.y = b[1].y
		b[0].modulate = Color.WHITE.lerp(TEINTE_EFFONDREE, f)
	if _corps:
		_corps.scale.y = haut   # écrasé vers ses pieds
		_corps.modulate = Color.WHITE.lerp(TEINTE_EFFONDREE, f)


## Rectangle de son dessin à l'écran (image, sinon une palissade d'une case).
func _rect_ecran() -> Rect2:
	if _image_ecran.size != Vector2.ZERO:
		return _image_ecran
	return Rect2(_pieds - Vector2(120, 150) * _e, Vector2(240, 150) * _e)


## Fissures dessinées par-dessus la barricade : une de plus par point perdu (toujours aux mêmes places).
func _dessiner_effets() -> void:
	super()
	var perdus := solidite_max() - solidite
	if perdus <= 0 or not solide():
		return
	var r := _rect_ecran()
	_effets.draw_set_transform(-_effets.position)
	var hasard := RandomNumberGenerator.new()
	for k in perdus:
		hasard.seed = hash(id) + k * 7919
		var p := r.position + r.size * Vector2(hasard.randf_range(0.2, 0.8), hasard.randf_range(0.3, 0.75))
		var sens := Vector2.from_angle(hasard.randf_range(-2.4, -0.7))
		var fente := PackedVector2Array([p])
		for s in 4:
			p += (sens.rotated(hasard.randf_range(-0.6, 0.6))) * r.size.y * 0.11
			fente.append(p)
		_effets.draw_polyline(fente, Palette.CONTOUR, 8.0, true)
		_effets.draw_polyline(fente, Palette.BOIS_CLAIR.lightened(0.4), 3.0, true)   # bois clair dans la fente
	_effets.draw_set_transform(Vector2.ZERO)


## Barre de solidité (seulement abîmée), éclats de bois après un coup, poussière de l'effondrement.
func _dessiner_infos() -> void:
	var r := _rect_ecran()
	var milieu := Vector2(r.get_center().x, r.position.y + r.size.y * 0.55)
	if abimee():
		var barre := Rect2(Vector2(r.get_center().x - TAILLE_BARRE.x / 2.0, r.position.y - ECART_BARRE - TAILLE_BARRE.y), TAILLE_BARRE)
		var part := float(solidite) / solidite_max()
		var couleur: Color = Palette.SOLIDITE[0] if part > 0.5 else (Palette.SOLIDITE[1] if part > 0.25 else Palette.SOLIDITE[2])
		_infos.draw_rect(barre.grow(4), Palette.CONTOUR)
		_infos.draw_rect(barre, Palette.COEUR_VIDE)
		_infos.draw_rect(Rect2(barre.position, Vector2(barre.size.x * part, barre.size.y)), couleur)
		for k in range(1, solidite_max()):
			var x := barre.position.x + barre.size.x * k / solidite_max()
			_infos.draw_line(Vector2(x, barre.position.y), Vector2(x, barre.end.y), Palette.CONTOUR, 2.0)
	if _eclats > 0.0:
		var t := 1.0 - _eclats / DUREE_ECLATS
		var hasard := RandomNumberGenerator.new()
		hasard.seed = solidite * 31 + hash(id)
		for k in 7:
			var vitesse := Vector2(hasard.randf_range(-170, 170), hasard.randf_range(-260, -120))
			var p := milieu + vitesse * t * DUREE_ECLATS + Vector2(0, 600.0 * pow(t * DUREE_ECLATS, 2.0))
			var a := hasard.randf() * TAU + t * 9.0
			var demi := Vector2.from_angle(a) * hasard.randf_range(6.0, 11.0)
			var couleur := (Palette.BOIS_CLAIR if k % 2 == 0 else Palette.BOIS).lightened(0.25)
			_infos.draw_line(p - demi, p + demi, Color(Palette.CONTOUR, 1.0 - t), 7.0)
			_infos.draw_line(p - demi, p + demi, Color(couleur, 1.0 - t), 4.0)
	if _effondrement >= 0.0 and _effondrement < DUREE_EFFONDREMENT:
		_poussiere(_infos, _pieds, maxf(_e, 0.6) * 0.75, _effondrement / DUREE_EFFONDREMENT, OPACITE_POUSSIERE)
