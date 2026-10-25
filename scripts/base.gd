extends Control
## Écran Base (pas un niveau jouable) : l'abri en planches et le feu de camp, la nuit,
## l'inventaire (une icône par type d'objet avec son nombre), une carte par construction et le bouton Partir.
## Tout est dessiné en code, en formes simples avec contour épais. Les constructions faites apparaissent dans le décor.

const CARTE := preload("res://scenes/carte_construction.tscn")

const TAILLE_ICONE := 54.0
## Emplacements (fraction de l'écran) : horizon, abri, feu, héros, constructions ; en paysage puis en portrait
const PLACES := {
	true: {"horizon": 0.56, "abri": Vector2(0.19, 0.84), "feu": Vector2(0.5, 0.7), "heros": Vector2(0.65, 0.77),
		"atelier": Vector2(0.78, 0.74), "barricade": Vector2(0.92, 0.8)},
	false: {"horizon": 0.55, "abri": Vector2(0.5, 0.74), "feu": Vector2(0.36, 0.83), "heros": Vector2(0.8, 0.84),
		"atelier": Vector2(0.13, 0.77), "barricade": Vector2(0.86, 0.73)},
}
## Taille des cartes de construction : en ligne (paysage), en colonne (portrait, coût sur la ligne du nom)
const TAILLE_CARTE := {true: Vector2(400, 130), false: Vector2(680, 112)}

var _temps := 0.0
var _etoiles := PackedVector2Array()    # positions en fraction de l'écran
var _immeubles := PackedVector2Array()  # largeur, hauteur (fractions) des ruines à l'horizon


func _ready() -> void:
	$Haut/Titre.add_theme_color_override("font_color", Palette.LAMPE)
	$Haut/Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Haut/Inventaire.draw.connect(_dessiner_inventaire)
	$Partir.couleur = Palette.LAMPE
	$Partir.icone = "jouer"
	$Partir.appuye.connect(_partir)
	for construction in Partie.CONSTRUCTIONS:
		var carte := CARTE.instantiate()
		carte.construction = construction
		carte.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		carte.construire.connect(_construire)
		$Constructions.add_child(carte)
	resized.connect(_placer_cartes)
	_placer_cartes()
	# Ciel et ruines tirés une fois, avec une graine fixe
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	for i in 40:
		_etoiles.append(Vector2(hasard.randf(), hasard.randf() * 0.5))
	for i in 14:
		_immeubles.append(Vector2(hasard.randf_range(0.06, 0.12), hasard.randf_range(0.06, 0.18)))


## Cartes en ligne en paysage, en colonne en portrait.
func _placer_cartes() -> void:
	var paysage := size.x > size.y
	$Constructions.vertical = not paysage
	$Constructions.add_theme_constant_override("separation", 14 if paysage else 10)
	for carte in $Constructions.get_children():
		carte.custom_minimum_size = TAILLE_CARTE[paysage]


func _construire(construction: String) -> void:
	if not Partie.construire(construction):
		return
	for carte in $Constructions.get_children():
		carte.actualiser()
	$Haut/Inventaire.queue_redraw()


func _partir() -> void:
	get_tree().change_scene_to_file("res://scenes/niveau.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()


func _draw() -> void:
	var e := minf(size.x, size.y) / 720.0
	var places: Dictionary = PLACES[size.x > size.y]
	var horizon: float = size.y * places["horizon"]
	draw_rect(Rect2(Vector2.ZERO, size), Palette.FOND_NUIT)
	_ciel(horizon, e)
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Palette.TERRE)
	var feu: Vector2 = places["feu"] * size
	# Lumière chaude du feu sur le sol, qui vacille
	var vacille := 1.0 + 0.05 * sin(_temps * 7.0) + 0.03 * sin(_temps * 13.0)
	for r: float in [330.0, 220.0, 130.0]:
		_ellipse_pleine(feu, Vector2(r, r * 0.45) * e * vacille, Palette.FEU_LUEUR)
	if Partie.est_construit("barricade"):
		_barricade(places["barricade"] * size, e)
	_abri(places["abri"] * size, e)
	if Partie.est_construit("lampe"):
		_lampe(places["abri"] * size, e)
	if Partie.est_construit("atelier"):
		_atelier(places["atelier"] * size, e)
	_heros(places["heros"] * size, e, places["heros"].x > places["feu"].x)
	_feu(feu, e)
	# Haut assombri pour que le titre et l'inventaire ressortent
	var sombre := Color(Palette.FOND_NUIT, 0.85)
	var clair := Color(Palette.FOND_NUIT, 0.0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, 260), Vector2(0, 260)]),
		PackedColorArray([sombre, sombre, clair, clair]))


func _ellipse_pleine(centre: Vector2, rayons: Vector2, couleur: Color) -> void:
	draw_set_transform(centre, 0.0, Vector2(1.0, rayons.y / rayons.x))
	draw_circle(Vector2.ZERO, rayons.x, couleur)
	draw_set_transform(Vector2.ZERO)


## Étoiles qui scintillent, lune, et ruines de la ville à l'horizon.
func _ciel(horizon: float, e: float) -> void:
	for i in _etoiles.size():
		var p := _etoiles[i] * Vector2(size.x, horizon)
		var a := 0.35 + 0.3 * sin(_temps * 1.5 + i * 1.7)
		draw_circle(p, 2.0 * e, Color(Palette.UI_TEXTE, a))
	var lune := Vector2(size.x * 0.88, size.y * (0.13 if size.x > size.y else 0.06))
	draw_circle(lune, 70.0 * e, Color(Palette.LUNE, 0.12))
	Dessin.cercle(self, lune, 34.0 * e, Palette.LUNE)
	draw_circle(lune + Vector2(-10, -6) * e, 7.0 * e, Palette.LUNE.darkened(0.15))
	draw_circle(lune + Vector2(9, 10) * e, 5.0 * e, Palette.LUNE.darkened(0.15))
	var x := -20.0 * e
	var i := 0
	while x < size.x:
		var t := _immeubles[i % _immeubles.size()]
		var r := Rect2(x, horizon - t.y * size.y, t.x * size.x, t.y * size.y + 2.0)
		Dessin.rect(self, r, Palette.MUR)
		# Quelques fenêtres éteintes, une sur trois éclairée par la lune
		for k in int(r.size.y / (34.0 * e)):
			var f := Rect2(r.position + Vector2(r.size.x * 0.3, 14.0 * e + k * 34.0 * e), Vector2(12, 14) * e)
			draw_rect(f, Palette.FENETRE.darkened(0.55) if (i + k) % 3 == 0 else Palette.MUR_COTE)
		x += r.size.x + 6.0 * e
		i += 1


## Abri en planches avec un toit de tôle, une couverture devant l'entrée, une caisse et un carton à côté.
func _abri(pieds: Vector2, e: float) -> void:
	var l := 320.0 * e
	var h := 170.0 * e
	Dessin.ombre(self, Rect2(pieds - Vector2(l * 0.62, 26 * e), Vector2(l * 1.24, 52 * e)))
	# Mur de planches verticales, de hauteurs un peu inégales
	var n := 7
	for k in n:
		var x0 := pieds.x - l / 2.0 + k * l / n
		var haut := pieds.y - h - (k % 3) * 6.0 * e
		var planche := PackedVector2Array([Vector2(x0, haut), Vector2(x0 + l / n, haut + 4.0 * e),
			Vector2(x0 + l / n, pieds.y), Vector2(x0, pieds.y)])
		Dessin.polygone(self, planche, Palette.BOIS if k % 2 == 0 else Palette.BOIS_CLAIR)
		draw_circle(Vector2(x0 + l / n / 2.0, haut + 18.0 * e), 3.0 * e, Palette.CONTOUR)
	# Planche en travers (renfort)
	draw_line(pieds + Vector2(-l * 0.48, -h * 0.25), pieds + Vector2(-l * 0.2, -h * 0.85), Palette.CONTOUR, 18.0 * e)
	draw_line(pieds + Vector2(-l * 0.48, -h * 0.25), pieds + Vector2(-l * 0.2, -h * 0.85), Palette.BOIS_SOMBRE, 11.0 * e)
	# Entrée sombre, à moitié fermée par une couverture
	var porte := Rect2(pieds + Vector2(-10 * e, -h * 0.72), Vector2(96 * e, h * 0.72))
	Dessin.rect(self, porte, Palette.CONTOUR)
	Dessin.polygone(self, PackedVector2Array([porte.position, porte.position + Vector2(porte.size.x * 0.6, 0),
		porte.position + Vector2(porte.size.x * 0.4, porte.size.y), porte.position + Vector2(0, porte.size.y)]), Palette.UI_BOUTON)
	# Toit de tôle en pente, avec ses ondulations
	var g := pieds + Vector2(-l / 2.0 - 34 * e, -h + 14 * e)
	var d := pieds + Vector2(l / 2.0 + 38 * e, -h - 38 * e)
	var epaisseur := Vector2(0, 26 * e)
	Dessin.polygone(self, PackedVector2Array([g, d, d + epaisseur, g + epaisseur]), Palette.TOLE)
	for k in range(1, 9):
		var a := g.lerp(d, k / 9.0)
		draw_line(a + Vector2(0, 4 * e), a + epaisseur - Vector2(0, 4 * e), Palette.TOLE.darkened(0.3), 3.0 * e)
	# Caisse et carton posés contre l'abri (images V2, assombries par la nuit)
	_image_au_sol("caisse", pieds + Vector2(-l * 0.58, 6 * e), 95.0 * e)
	_image_au_sol("carton", pieds + Vector2(l * 0.55, 10 * e), 70.0 * e)


## Barricade : palissade de pieux taillés en pointe, tenus par deux planches en travers.
func _barricade(pieds: Vector2, e: float) -> void:
	var l := 200.0 * e
	Dessin.ombre(self, Rect2(pieds - Vector2(l * 0.6, 18 * e), Vector2(l * 1.2, 36 * e)))
	var n := 6
	for k in n:
		var x0 := pieds.x - l / 2.0 + k * l / n
		var haut := pieds.y - (110.0 + (k % 2) * 16.0) * e
		var pointe := haut - 22.0 * e
		Dessin.polygone(self, PackedVector2Array([Vector2(x0 + 3 * e, haut), Vector2(x0 + l / n / 2.0, pointe),
			Vector2(x0 + l / n - 3 * e, haut), Vector2(x0 + l / n - 3 * e, pieds.y), Vector2(x0 + 3 * e, pieds.y)]),
			Palette.BOIS if k % 2 == 0 else Palette.BOIS_CLAIR)
	for y: float in [-80.0, -30.0]:
		var a := pieds + Vector2(-l * 0.55, y * e)
		var b := pieds + Vector2(l * 0.55, (y - 10.0) * e)
		draw_line(a, b, Palette.CONTOUR, 18.0 * e)
		draw_line(a, b, Palette.BOIS_SOMBRE, 11.0 * e)


## Lampe renforcée : un projecteur sur un poteau au coin du toit de l'abri, qui éclaire le sol devant.
func _lampe(abri: Vector2, e: float) -> void:
	var bas := abri + Vector2(212 * e, 0)
	var tete := bas + Vector2(0, -225 * e)
	# Lumière au sol, qui vacille un peu
	var force := 0.16 + 0.02 * sin(_temps * 3.0)
	draw_colored_polygon(PackedVector2Array([tete + Vector2(-10, 10) * e, tete + Vector2(18, 10) * e,
		bas + Vector2(150, 30) * e, bas + Vector2(-60, 30) * e]), Color(Palette.LAMPE_FAISCEAU, force))
	_ellipse_pleine(bas + Vector2(45, 28) * e, Vector2(115, 26) * e, Color(Palette.LAMPE_FAISCEAU, force))
	draw_line(bas, tete, Palette.CONTOUR, 14.0 * e)
	draw_line(bas, tete, Palette.TOLE.darkened(0.2), 7.0 * e)
	var corps := PackedVector2Array([tete + Vector2(-22, -16) * e, tete + Vector2(22, -10) * e,
		tete + Vector2(26, 14) * e, tete + Vector2(-18, 14) * e])
	Dessin.polygone(self, corps, Palette.TOLE)
	draw_circle(tete + Vector2(4, 6) * e, 26.0 * e, Color(Palette.LAMPE, 0.25))
	Dessin.ellipse(self, tete + Vector2(4, 12) * e, Vector2(18, 7) * e, Palette.LAMPE)


## Atelier : établi en bois avec un étau, un marteau et une scie posés dessus.
func _atelier(pieds: Vector2, e: float) -> void:
	var l := 150.0 * e
	var h := 70.0 * e
	Dessin.ombre(self, Rect2(pieds - Vector2(l * 0.62, 16 * e), Vector2(l * 1.24, 32 * e)))
	for x: float in [-0.42, 0.36]:
		Dessin.rect(self, Rect2(pieds + Vector2(l * x, -h), Vector2(14 * e, h)), Palette.BOIS_SOMBRE)
	Dessin.rect(self, Rect2(pieds + Vector2(-l * 0.42, -h * 0.4), Vector2(l * 0.84, 10 * e)), Palette.BOIS_SOMBRE)
	var plateau := Rect2(pieds + Vector2(-l / 2.0, -h - 18 * e), Vector2(l, 18 * e))
	Dessin.rect(self, plateau, Palette.BOIS_CLAIR)
	# Étau à gauche
	Dessin.rect(self, Rect2(plateau.position + Vector2(6, -22) * e, Vector2(26, 22) * e), Palette.PIERRE)
	draw_line(plateau.position + Vector2(0, -12) * e, plateau.position + Vector2(38, -12) * e, Palette.CONTOUR, 5.0 * e)
	# Marteau
	var m := plateau.position + Vector2(l * 0.45, 0)
	draw_line(m, m + Vector2(34, -30) * e, Palette.CONTOUR, 9.0 * e)
	draw_line(m, m + Vector2(34, -30) * e, Palette.BATTE, 5.0 * e)
	Dessin.polygone(self, PackedVector2Array([m + Vector2(22, -42) * e, m + Vector2(46, -22) * e,
		m + Vector2(40, -16) * e, m + Vector2(16, -36) * e]), Palette.PIERRE)
	# Scie accrochée au bord du plateau
	var s := plateau.position + Vector2(l * 0.7, plateau.size.y)
	Dessin.polygone(self, PackedVector2Array([s, s + Vector2(30, 0) * e, s + Vector2(30, 34) * e]), Palette.UI_BORD)
	Dessin.rect(self, Rect2(s + Vector2(-12, -2) * e, Vector2(14, 12) * e), Palette.BOIS_SOMBRE)


func _image_au_sol(nom: String, pieds: Vector2, hauteur: float) -> void:
	if not Images.existe(nom):
		return
	Images.dessiner_pieds(self, nom, pieds, hauteur / Images.region(nom).size.y, false, Color(0.62, 0.58, 0.72))


## Le héros debout près du feu, tourné vers lui, éclairé d'un côté.
func _heros(pieds: Vector2, e: float, miroir: bool) -> void:
	Dessin.ombre(self, Rect2(pieds - Vector2(50, 14) * e, Vector2(100, 28) * e))
	if Images.existe("profil_1"):
		Images.dessiner_pieds(self, "profil_1", pieds, e * 0.9, miroir, Color(1.0, 0.9, 0.8))


## Feu de camp : pierres en cercle, bûches croisées, trois flammes qui dansent et des étincelles.
func _feu(centre: Vector2, e: float) -> void:
	var pierres := []
	for k in 8:
		var a := k * TAU / 8.0
		pierres.append(centre + Vector2(cos(a) * 62.0, sin(a) * 22.0) * e)
	for p: Vector2 in pierres:
		if p.y <= centre.y:
			Dessin.ellipse(self, p, Vector2(17, 11) * e, Palette.PIERRE)
	for sens: float in [-1.0, 1.0]:
		var a := centre + Vector2(-44 * sens, 8) * e
		var b := centre + Vector2(44 * sens, -14) * e
		draw_line(a, b, Palette.CONTOUR, 22.0 * e)
		draw_line(a, b, Palette.BOIS_SOMBRE, 14.0 * e)
	for k in 3:
		var dx := (k - 1) * 22.0 * e
		var haut := (95.0 - absf(k - 1) * 30.0 + 14.0 * sin(_temps * 9.0 + k * 2.1)) * e
		var penche := 10.0 * sin(_temps * 5.0 + k) * e
		_flamme(centre + Vector2(dx, -4 * e), 24.0 * e, haut, penche, Palette.FEU)
		_flamme(centre + Vector2(dx, -4 * e), 12.0 * e, haut * 0.55, penche * 0.6, Palette.FEU_COEUR, false)
	for k in 5:
		var vie := fmod(_temps * 0.7 + k * 0.23, 1.0)
		var p := centre + Vector2(sin(k * 3.7 + _temps * 2.0) * 30.0, -60.0 - vie * 140.0) * e
		draw_circle(p, (1.0 - vie) * 4.0 * e, Color(Palette.FEU_COEUR, 1.0 - vie))
	for p: Vector2 in pierres:
		if p.y > centre.y:
			Dessin.ellipse(self, p, Vector2(17, 11) * e, Palette.PIERRE)


func _flamme(base: Vector2, demi: float, haut: float, penche: float, couleur: Color, contour := true) -> void:
	Dessin.polygone(self, PackedVector2Array([base + Vector2(-demi, 0), base + Vector2(-demi * 0.6, -haut * 0.5),
		base + Vector2(penche, -haut), base + Vector2(demi * 0.6, -haut * 0.5), base + Vector2(demi, 0)]), couleur, contour)


## Cadre de l'inventaire : les 5 types d'objets, chacun avec son nombre (grisé s'il n'y en a pas).
func _dessiner_inventaire() -> void:
	var zone: Control = $Haut/Inventaire
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.CONTOUR
	cadre.set_border_width_all(5)
	cadre.set_corner_radius_all(24)
	zone.draw_style_box(cadre, Rect2(Vector2.ZERO, zone.size))
	var types := Partie.NOMS.keys()
	var pas := zone.size.x / types.size()
	for i in types.size():
		var pieds := Vector2(pas * (i + 0.5) - 18, zone.size.y / 2.0 + TAILLE_ICONE / 2.0)
		Dessin.objet_compte(zone, types[i], pieds, TAILLE_ICONE, Partie.inventaire.get(types[i], 0))
