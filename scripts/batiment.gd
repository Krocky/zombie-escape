extends "res://scripts/mur.gd"
## Bâtiment du camp de la base (abri, feu, construction, tente) : un obstacle du décor (voir Mur) posé au sol
## sur son emprise, avec collision. Image V3 base_* découpée en bandes triées (Iso.habiller : ses coins au sol
## sur ceux de l'emprise, donc ses pieds dedans) ; sans image, dessin en code de secours (formes simples avec
## contour épais). Feu : flammes animées et lueur au sol ; projecteur : faisceau et phares. Le rescapé d'une tente
## est un personnage à part (RescapeBase) qui se promène ; devant() = sa place devant l'entrée.
## Il peut tomber du ciel (tomber) : chute, aplatissement et petit rebond, nuage de poussière, et il finit posé
## à sa place (la chute ne fait que décaler le dessin, jamais l'emprise).

## Nom du bâtiment : abri_1, abri_2, feu, barricade, atelier, lampe, jardin, tente_N (Partie.premiere_apparition).
@export var id := ""

## Chute du ciel : durée de la chute, du rebond, du nuage de poussière (s), hauteur de départ (pixels à l'écran)
const DUREE_CHUTE := 0.55
const DUREE_REBOND := 0.35
const DUREE_POUSSIERE := 0.8
const HAUTEUR_CHUTE := 900.0
## base_campfire : base des flammes (pixels de l'image), taille et opacité des flammes animées par-dessus
const FEU_IMAGE := Vector2(240, 178)
const FEU_FLAMMES := 0.55
const FEU_OPACITE := 0.5
## base_floodlight : centre des trois phares (pixels de l'image)
const PHARE_IMAGE := Vector2(110, 60)
## Place du rescapé devant sa tente (monde, depuis `position`)
const DEVANT_TENTE := Vector2(-60, 30)
## Une case du monde (200 x 200) fait cette largeur à l'écran : échelle des dessins de secours
const LARGEUR_CASE := 240.0

var _temps := 0.0
var _chute := -1.0              # instant (_temps) où la chute commence ; < 0 : posé
var _bandes := []               # [bande, décalage, échelle] de l'image découpée
var _corps: Node2D = null       # dessin de secours (sans image)
var _effets := Node2D.new()     # flammes, phares, poussière : par-dessus le bâtiment
var _pieds := Vector2.ZERO      # pieds du dessin à l'écran (milieu, vers l'avant de l'emprise)
var _e := 1.0                   # échelle des dessins de secours et des effets (1 = une case)


## Pieds du bâtiment dans le monde : ancre « pieds » de l'image (sinon le milieu de l'emprise).
func pieds() -> Vector2:
	if _bandes.is_empty():
		return emprise().get_center()
	return Iso.monde(Iso.point_image(image, emprise(), Images.v3_pieds(image), _miroir()))


## Un point de l'image (pixels de l'image) à l'écran, bâtiment posé ; sans image, le milieu de l'emprise.
func point_ecran(pixel: Vector2) -> Vector2:
	if _bandes.is_empty():
		return Iso.ecran(emprise().get_center())
	return Iso.point_image(image, emprise(), pixel, _miroir())


## Devant l'entrée de la tente (monde) : place de son rescapé.
func devant() -> Vector2:
	return position + DEVANT_TENTE


## Posé au sol (pas en train de tomber ni en attente de tomber).
func pose() -> bool:
	return _etat()["pose"] and _etat()["dy"] == 0.0


## Le bâtiment tombera du ciel dans `attente` secondes (caché jusque-là).
func tomber(attente: float) -> void:
	_chute = _temps + attente
	_appliquer_chute()


## Un bâtiment enlevé (l'abri remplacé par le grand abri) emporte son affichage.
func _exit_tree() -> void:
	for noeud in [_vue, _sol]:
		if is_instance_valid(noeud):
			noeud.queue_free()


func _miroir() -> bool:
	return Iso.miroir_pour(image, taille.x >= taille.y)


func _construire() -> void:
	var c := Iso.coins(emprise())
	_e = (c[2].x - c[0].x) / LARGEUR_CASE
	_pieds = Iso.ecran(emprise().get_center()).lerp(c[1], 0.5)
	if image != "" and Images.existe(image):
		_image_ecran = Iso.habiller(image, emprise(), _vue, _miroir())
		for bande in _vue.get_children():
			_bandes.append([bande, bande.offset, bande.scale])
	else:
		_corps = Node2D.new()
		_corps.position = _pieds
		_corps.draw.connect(_dessiner_secours)
		_vue.add_child(_corps)
	_effets.position = c[1] + Vector2(0, 1)   # trié juste devant le bâtiment
	_effets.draw.connect(_dessiner_effets)
	_vue.add_child(_effets)
	_sol.draw.connect(_dessiner_sol)


## Remplace l'image (même emprise) : nouvelles bandes, état de la chute gardé. Pour la tourelle qui tourne et la
## barricade qui s'abîme.
func _rehabiller(nom: String) -> void:
	for b in _bandes:
		b[0].queue_free()
	_bandes.clear()
	image = nom
	_image_ecran = Iso.habiller(image, emprise(), _vue, _miroir())
	for bande in _vue.get_children():
		if bande is Sprite2D and not bande.is_queued_for_deletion():
			_bandes.append([bande, bande.offset, bande.scale])
	_appliquer_chute()


func _process(delta: float) -> void:
	_temps += delta
	if _chute >= 0.0:
		_appliquer_chute()
	_effets.queue_redraw()
	_sol.queue_redraw()
	if _corps:
		_corps.queue_redraw()


## Où en est la chute : {"cache" (pas encore tombé), "pose" (au sol, rebond compris), "dy" (décalage vertical
## à l'écran), "ecrase" (aplatissement à l'impact), "poussiere" (0 -> 1 après l'impact, -1 sinon)}.
func _etat() -> Dictionary:
	var etat := {"cache": false, "pose": true, "dy": 0.0, "ecrase": 0.0, "poussiere": -1.0}
	if _chute < 0.0:
		return etat
	var t := _temps - _chute
	if t < 0.0:
		etat["cache"] = true
		etat["pose"] = false
	elif t < DUREE_CHUTE:
		etat["pose"] = false
		etat["dy"] = -HAUTEUR_CHUTE * (1.0 - pow(t / DUREE_CHUTE, 2.0))
	else:
		var u := t - DUREE_CHUTE
		if u < DUREE_REBOND:
			var v := u / DUREE_REBOND
			etat["ecrase"] = 0.14 * sin(minf(v * 3.0, 1.0) * PI)
			etat["dy"] = -18.0 * sin(clampf((v - 0.33) * 1.5, 0.0, 1.0) * PI)
		if u < DUREE_POUSSIERE:
			etat["poussiere"] = u / DUREE_POUSSIERE
	return etat


## Décale le dessin (pas l'emprise ni le tri) pendant la chute ; la chute finie, tout est remis en place.
func _appliquer_chute() -> void:
	var etat := _etat()
	if _temps - _chute > DUREE_CHUTE + DUREE_POUSSIERE + 0.1:
		_chute = -1.0
		etat = _etat()
	for b in _bandes:
		var bande: Sprite2D = b[0]
		bande.visible = not etat["cache"]
		bande.scale.y = b[2].y * (1.0 - etat["ecrase"])
		bande.offset.y = b[1].y + etat["dy"] / bande.scale.y
	if _corps:
		_corps.visible = not etat["cache"]


func _dessiner_sol() -> void:
	var etat := _etat()
	# Ombre qui grandit au sol pendant la chute
	if not etat["pose"] and not etat["cache"]:
		var p := 1.0 - absf(etat["dy"]) / HAUTEUR_CHUTE
		Dessin.ombre(_sol, Rect2(_pieds - Vector2(110, 22) * _e * p, Vector2(220, 44) * _e * p))
	if not etat["pose"]:
		return
	if id == "feu":
		var vacille := 1.0 + 0.05 * sin(_temps * 7.0) + 0.03 * sin(_temps * 13.0)
		for r: float in [330.0, 220.0, 130.0]:
			_ellipse_pleine(_sol, _pieds, Vector2(r, r * 0.45) * _e * vacille, Palette.FEU_LUEUR)
	elif id == "lampe" and not _bandes.is_empty():
		var e := _echelle_image() / 0.5
		var force := 0.16 + 0.02 * sin(_temps * 3.0)
		_ellipse_pleine(_sol, _pieds + Vector2(110, 30) * e, Vector2(150, 40) * e, Color(Palette.LAMPE_FAISCEAU, force))


## Échelle de l'image à l'écran (taille de ses pixels).
func _echelle_image() -> float:
	return Iso.placement(image, emprise(), _miroir()).size.x


## Flammes, phares et poussière, en coordonnées de l'écran.
func _dessiner_effets() -> void:
	var etat := _etat()
	_effets.draw_set_transform(-_effets.position)
	if etat["pose"] and not _bandes.is_empty():
		if id == "feu":
			var centre := Iso.point_image(image, emprise(), FEU_IMAGE, _miroir())
			_flammes_et_etincelles(_effets, centre + Vector2(0, etat["dy"]), _echelle_image() * FEU_FLAMMES, FEU_OPACITE)
		elif id == "lampe":
			_phares(_effets, Iso.point_image(image, emprise(), Images.v3_pieds(image), _miroir()))
	if etat["poussiere"] >= 0.0:
		_poussiere(_effets, _pieds, maxf(_e, 0.6), etat["poussiere"])
	_effets.draw_set_transform(Vector2.ZERO)


## Nuage de poussière à l'impact : des bouffées qui s'écartent au ras du sol, grossissent et s'effacent.
func _poussiere(ci: CanvasItem, pieds_ecran: Vector2, e: float, t: float, opacite := 0.45) -> void:
	var alpha := opacite * (1.0 - t)
	for k in 10:
		var a := k * TAU / 10.0 + 0.4
		var d := Vector2(cos(a) * 150.0, sin(a) * 42.0) * e * (0.4 + 0.8 * sqrt(t))
		var r := (22.0 + 26.0 * t + 6.0 * (k % 3)) * e
		ci.draw_circle(pieds_ecran + d - Vector2(0, 20.0 * t * e), r, Color(Palette.PIERRE.lightened(0.3), alpha))


## Lumière des trois phares du projecteur, qui tombe sur le sol devant lui.
func _phares(ci: CanvasItem, pieds_ecran: Vector2) -> void:
	var tete := Iso.point_image(image, emprise(), PHARE_IMAGE, _miroir())
	var e := _echelle_image() / 0.5
	var force := 0.14 + 0.02 * sin(_temps * 3.0)
	ci.draw_colored_polygon(PackedVector2Array([tete + Vector2(-30, -10) * e, tete + Vector2(30, 10) * e,
		pieds_ecran + Vector2(260, 30) * e, pieds_ecran + Vector2(-40, 40) * e]), Color(Palette.LAMPE_FAISCEAU, force))
	for p: Vector2 in [Vector2(60, 35), Vector2(112, 52), Vector2(150, 95)]:
		var c := Iso.point_image(image, emprise(), p, _miroir())
		ci.draw_circle(c, 22.0 * e, Color(Palette.LAMPE, 0.22 + 0.04 * sin(_temps * 3.0)))
		ci.draw_circle(c, 10.0 * e, Color(Palette.LAMPE, 0.5))


## Dessin de secours (sans image), pieds en (0, 0), décalé et aplati pendant la chute.
func _dessiner_secours() -> void:
	var etat := _etat()
	_corps.draw_set_transform(Vector2(0, etat["dy"]), 0.0, Vector2(1.0 + etat["ecrase"], 1.0 - etat["ecrase"]))
	match id.get_slice("_", 0):
		"abri":
			_abri(_corps, Vector2.ZERO, _e)
		"feu":
			_feu(_corps, Vector2.ZERO, _e)
		"barricade":
			_barricade(_corps, Vector2.ZERO, _e)
		"atelier":
			_atelier(_corps, Vector2.ZERO, _e)
		"lampe":
			_lampe(_corps, Vector2.ZERO, _e)
		"tente", "infirmerie":
			_tente(_corps, Vector2.ZERO, _e)
		_:
			# Jardin : un bac de terre
			var c := Iso.coins(emprise())
			for i in c.size():
				c[i] -= _pieds
			Dessin.boite_iso(_corps, c, 30.0, Palette.TERRE, Palette.BOIS, Palette.BOIS_SOMBRE)
	_corps.draw_set_transform(Vector2.ZERO)


func _ellipse_pleine(ci: CanvasItem, centre: Vector2, rayons: Vector2, couleur: Color) -> void:
	ci.draw_set_transform(centre, 0.0, Vector2(1.0, rayons.y / rayons.x))
	ci.draw_circle(Vector2.ZERO, rayons.x, couleur)
	ci.draw_set_transform(Vector2.ZERO)


## Secours (sans image) : abri en planches avec un toit de tôle, une couverture devant l'entrée, une caisse et un carton à côté.
func _abri(ci: CanvasItem, pieds: Vector2, e: float) -> void:
	var l := 320.0 * e
	var h := 170.0 * e
	Dessin.ombre(ci, Rect2(pieds - Vector2(l * 0.62, 26 * e), Vector2(l * 1.24, 52 * e)))
	# Mur de planches verticales, de hauteurs un peu inégales
	var n := 7
	for k in n:
		var x0 := pieds.x - l / 2.0 + k * l / n
		var haut := pieds.y - h - (k % 3) * 6.0 * e
		var planche := PackedVector2Array([Vector2(x0, haut), Vector2(x0 + l / n, haut + 4.0 * e),
			Vector2(x0 + l / n, pieds.y), Vector2(x0, pieds.y)])
		Dessin.polygone(ci, planche, Palette.BOIS if k % 2 == 0 else Palette.BOIS_CLAIR)
		ci.draw_circle(Vector2(x0 + l / n / 2.0, haut + 18.0 * e), 3.0 * e, Palette.CONTOUR)
	# Planche en travers (renfort)
	ci.draw_line(pieds + Vector2(-l * 0.48, -h * 0.25), pieds + Vector2(-l * 0.2, -h * 0.85), Palette.CONTOUR, 18.0 * e)
	ci.draw_line(pieds + Vector2(-l * 0.48, -h * 0.25), pieds + Vector2(-l * 0.2, -h * 0.85), Palette.BOIS_SOMBRE, 11.0 * e)
	# Entrée sombre, à moitié fermée par une couverture
	var porte := Rect2(pieds + Vector2(-10 * e, -h * 0.72), Vector2(96 * e, h * 0.72))
	Dessin.rect(ci, porte, Palette.CONTOUR)
	Dessin.polygone(ci, PackedVector2Array([porte.position, porte.position + Vector2(porte.size.x * 0.6, 0),
		porte.position + Vector2(porte.size.x * 0.4, porte.size.y), porte.position + Vector2(0, porte.size.y)]), Palette.UI_BOUTON)
	# Toit de tôle en pente, avec ses ondulations
	var g := pieds + Vector2(-l / 2.0 - 34 * e, -h + 14 * e)
	var d := pieds + Vector2(l / 2.0 + 38 * e, -h - 38 * e)
	var epaisseur := Vector2(0, 26 * e)
	Dessin.polygone(ci, PackedVector2Array([g, d, d + epaisseur, g + epaisseur]), Palette.TOLE)
	for k in range(1, 9):
		var a := g.lerp(d, k / 9.0)
		ci.draw_line(a + Vector2(0, 4 * e), a + epaisseur - Vector2(0, 4 * e), Palette.TOLE.darkened(0.3), 3.0 * e)
	# Caisse et carton posés contre l'abri (images V2, assombries par la nuit)
	_image_au_sol(ci, "caisse", pieds + Vector2(-l * 0.58, 6 * e), 95.0 * e)
	_image_au_sol(ci, "carton", pieds + Vector2(l * 0.55, 10 * e), 70.0 * e)


## Secours : barricade, palissade de pieux taillés en pointe, tenus par deux planches en travers.
func _barricade(ci: CanvasItem, pieds: Vector2, e: float) -> void:
	var l := 200.0 * e
	Dessin.ombre(ci, Rect2(pieds - Vector2(l * 0.6, 18 * e), Vector2(l * 1.2, 36 * e)))
	var n := 6
	for k in n:
		var x0 := pieds.x - l / 2.0 + k * l / n
		var haut := pieds.y - (110.0 + (k % 2) * 16.0) * e
		var pointe := haut - 22.0 * e
		Dessin.polygone(ci, PackedVector2Array([Vector2(x0 + 3 * e, haut), Vector2(x0 + l / n / 2.0, pointe),
			Vector2(x0 + l / n - 3 * e, haut), Vector2(x0 + l / n - 3 * e, pieds.y), Vector2(x0 + 3 * e, pieds.y)]),
			Palette.BOIS if k % 2 == 0 else Palette.BOIS_CLAIR)
	for y: float in [-80.0, -30.0]:
		var a := pieds + Vector2(-l * 0.55, y * e)
		var b := pieds + Vector2(l * 0.55, (y - 10.0) * e)
		ci.draw_line(a, b, Palette.CONTOUR, 18.0 * e)
		ci.draw_line(a, b, Palette.BOIS_SOMBRE, 11.0 * e)


## Secours : lampe renforcée, un projecteur sur un poteau qui éclaire le sol devant.
func _lampe(ci: CanvasItem, bas: Vector2, e: float) -> void:
	var tete := bas + Vector2(0, -225 * e)
	# Lumière au sol, qui vacille un peu
	var force := 0.16 + 0.02 * sin(_temps * 3.0)
	ci.draw_colored_polygon(PackedVector2Array([tete + Vector2(-10, 10) * e, tete + Vector2(18, 10) * e,
		bas + Vector2(150, 30) * e, bas + Vector2(-60, 30) * e]), Color(Palette.LAMPE_FAISCEAU, force))
	_ellipse_pleine(ci, bas + Vector2(45, 28) * e, Vector2(115, 26) * e, Color(Palette.LAMPE_FAISCEAU, force))
	ci.draw_line(bas, tete, Palette.CONTOUR, 14.0 * e)
	ci.draw_line(bas, tete, Palette.TOLE.darkened(0.2), 7.0 * e)
	var corps := PackedVector2Array([tete + Vector2(-22, -16) * e, tete + Vector2(22, -10) * e,
		tete + Vector2(26, 14) * e, tete + Vector2(-18, 14) * e])
	Dessin.polygone(ci, corps, Palette.TOLE)
	ci.draw_circle(tete + Vector2(4, 6) * e, 26.0 * e, Color(Palette.LAMPE, 0.25))
	Dessin.ellipse(ci, tete + Vector2(4, 12) * e, Vector2(18, 7) * e, Palette.LAMPE)


## Secours : atelier, établi en bois avec un étau, un marteau et une scie posés dessus.
func _atelier(ci: CanvasItem, pieds: Vector2, e: float) -> void:
	var l := 150.0 * e
	var h := 70.0 * e
	Dessin.ombre(ci, Rect2(pieds - Vector2(l * 0.62, 16 * e), Vector2(l * 1.24, 32 * e)))
	for x: float in [-0.42, 0.36]:
		Dessin.rect(ci, Rect2(pieds + Vector2(l * x, -h), Vector2(14 * e, h)), Palette.BOIS_SOMBRE)
	Dessin.rect(ci, Rect2(pieds + Vector2(-l * 0.42, -h * 0.4), Vector2(l * 0.84, 10 * e)), Palette.BOIS_SOMBRE)
	var plateau := Rect2(pieds + Vector2(-l / 2.0, -h - 18 * e), Vector2(l, 18 * e))
	Dessin.rect(ci, plateau, Palette.BOIS_CLAIR)
	# Étau à gauche
	Dessin.rect(ci, Rect2(plateau.position + Vector2(6, -22) * e, Vector2(26, 22) * e), Palette.PIERRE)
	ci.draw_line(plateau.position + Vector2(0, -12) * e, plateau.position + Vector2(38, -12) * e, Palette.CONTOUR, 5.0 * e)
	# Marteau
	var m := plateau.position + Vector2(l * 0.45, 0)
	ci.draw_line(m, m + Vector2(34, -30) * e, Palette.CONTOUR, 9.0 * e)
	ci.draw_line(m, m + Vector2(34, -30) * e, Palette.BATTE, 5.0 * e)
	Dessin.polygone(ci, PackedVector2Array([m + Vector2(22, -42) * e, m + Vector2(46, -22) * e,
		m + Vector2(40, -16) * e, m + Vector2(16, -36) * e]), Palette.PIERRE)
	# Scie accrochée au bord du plateau
	var s := plateau.position + Vector2(l * 0.7, plateau.size.y)
	Dessin.polygone(ci, PackedVector2Array([s, s + Vector2(30, 0) * e, s + Vector2(30, 34) * e]), Palette.UI_BORD)
	Dessin.rect(ci, Rect2(s + Vector2(-12, -2) * e, Vector2(14, 12) * e), Palette.BOIS_SOMBRE)


## Secours : tente, une toile en triangle avec son ouverture sombre.
func _tente(ci: CanvasItem, pieds: Vector2, e: float) -> void:
	var l := 180.0 * e
	var h := 120.0 * e
	Dessin.ombre(ci, Rect2(pieds - Vector2(l * 0.6, 18 * e), Vector2(l * 1.2, 36 * e)))
	Dessin.polygone(ci, PackedVector2Array([pieds + Vector2(-l / 2.0, 0), pieds + Vector2(0, -h), pieds + Vector2(l / 2.0, 0)]),
		Palette.TOLE.darkened(0.2))
	Dessin.polygone(ci, PackedVector2Array([pieds + Vector2(-l * 0.18, 0), pieds + Vector2(0, -h * 0.6), pieds + Vector2(l * 0.18, 0)]),
		Palette.CONTOUR)


func _image_au_sol(ci: CanvasItem, nom: String, pieds: Vector2, hauteur: float) -> void:
	if not Images.existe(nom):
		return
	Images.dessiner_pieds(ci, nom, pieds, hauteur / Images.region(nom).size.y, false, Color(0.62, 0.58, 0.72))


## Secours : feu de camp, pierres en cercle, bûches croisées, trois flammes qui dansent et des étincelles.
func _feu(ci: CanvasItem, centre: Vector2, e: float) -> void:
	var pierres := []
	for k in 8:
		var a := k * TAU / 8.0
		pierres.append(centre + Vector2(cos(a) * 62.0, sin(a) * 22.0) * e)
	for p: Vector2 in pierres:
		if p.y <= centre.y:
			Dessin.ellipse(ci, p, Vector2(17, 11) * e, Palette.PIERRE)
	for sens: float in [-1.0, 1.0]:
		var a := centre + Vector2(-44 * sens, 8) * e
		var b := centre + Vector2(44 * sens, -14) * e
		ci.draw_line(a, b, Palette.CONTOUR, 22.0 * e)
		ci.draw_line(a, b, Palette.BOIS_SOMBRE, 14.0 * e)
	_flammes_et_etincelles(ci, centre, e)
	for p: Vector2 in pierres:
		if p.y > centre.y:
			Dessin.ellipse(ci, p, Vector2(17, 11) * e, Palette.PIERRE)


## Trois flammes qui dansent et des étincelles qui montent (feu de secours, ou par-dessus base_campfire).
## opacite < 1 : flammes transparentes et sans contour (sur l'image).
func _flammes_et_etincelles(ci: CanvasItem, centre: Vector2, e: float, opacite := 1.0) -> void:
	var contour := opacite >= 1.0
	for k in 3:
		var dx := (k - 1) * 22.0 * e
		var haut := (95.0 - absf(k - 1) * 30.0 + 14.0 * sin(_temps * 9.0 + k * 2.1)) * e
		var penche := 10.0 * sin(_temps * 5.0 + k) * e
		_flamme(ci, centre + Vector2(dx, -4 * e), 24.0 * e, haut, penche, Color(Palette.FEU, opacite), contour)
		_flamme(ci, centre + Vector2(dx, -4 * e), 12.0 * e, haut * 0.55, penche * 0.6, Color(Palette.FEU_COEUR, opacite), false)
	for k in 5:
		var vie := fmod(_temps * 0.7 + k * 0.23, 1.0)
		var p := centre + Vector2(sin(k * 3.7 + _temps * 2.0) * 30.0, -60.0 - vie * 140.0) * e
		ci.draw_circle(p, (1.0 - vie) * 4.0 * e, Color(Palette.FEU_COEUR, 1.0 - vie))


func _flamme(ci: CanvasItem, base: Vector2, demi: float, haut: float, penche: float, couleur: Color, contour := true) -> void:
	Dessin.polygone(ci, PackedVector2Array([base + Vector2(-demi, 0), base + Vector2(-demi * 0.6, -haut * 0.5),
		base + Vector2(penche, -haut), base + Vector2(demi * 0.6, -haut * 0.5), base + Vector2(demi, 0)]), couleur, contour)
