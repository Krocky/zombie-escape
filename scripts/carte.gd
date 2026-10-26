extends Control
## Écran Carte : plan de la ville la nuit (image V3 bg_map, défilable au doigt quand elle dépasse l'écran),
## avec la base et les lieux (Partie.LIEUX) en vignettes V3 (map_*), reliés à la base par des pointillés animés.
## Au pied de chaque lieu disponible et dans sa fiche : son meilleur nombre d'étoiles (Partie.meilleures_etoiles), les autres grises.
## Toucher un lieu disponible ouvre sa fiche (nom, objectif, danger = zombies, rescapé, objets à trouver, « Y aller ») ;
## un lieu sans scène est grisé, marqué d'un cadenas et de « Bientôt », et ne réagit pas. « Retour » ramène à la base.
## Sans les images : ville dessinée en code (pâtés de maisons tirés avec une graine fixe) et petits bâtiments dessinés.

const GRAINE := 11
const RAYON_TOUCHE := 80.0      # zone de toucher autour d'un lieu (diamètre >= 100 px)
const TAILLE_ICONE := 46.0      # objets, dans la fiche
const HAUTEUR_ZOMBIE := 84.0    # zombies, dans la fiche
const LARGEUR_VIGNETTE := 160.0 # vignettes map_* (à l'échelle 1)
const CADENAS := 64.0           # hauteur de map_lock sur un lieu « Bientôt »
const ETOILE_CARTE := 28.0      # étoiles (meilleur score) au pied de la vignette, à l'échelle 1
const ETOILE_FICHE := 40.0      # étoiles sur la ligne du nom, dans la fiche
const SEUIL_GLISSE := 20.0      # au-delà (pixels parcourus), le doigt fait défiler la carte au lieu de toucher
const VITESSE_POINTILLES := 30.0   # pixels par seconde, de la base vers le lieu
## Vignette de chaque lieu (et de la base)
const VIGNETTES := {"base": "map_base", "supermarche": "map_market", "maison": "map_house", "pharmacie": "map_pharmacy"}
## Emplacements de la base et des lieux, en fraction de la carte ; « vue » = point de la carte au centre de l'écran
## à l'arrivée. En paysage puis en portrait. À l'arrivée, tous sont à l'écran et hors de la fiche.
const PLACES := {
	true: {"vue": Vector2(0.5, 0.5), "base": Vector2(0.179, 0.65), "supermarche": Vector2(0.336, 0.35),
		"maison": Vector2(0.486, 0.675), "pharmacie": Vector2(0.534, 0.31)},
	false: {"vue": Vector2(0.4, 0.5), "base": Vector2(0.294, 0.37), "supermarche": Vector2(0.469, 0.195),
		"maison": Vector2(0.452, 0.37), "pharmacie": Vector2(0.311, 0.2)},
}
## Fiche : à droite en paysage, en bas (au-dessus de Retour) en portrait ; même mise en page pour tous les lieux
const TAILLE_FICHE := {true: Vector2(456, 530), false: Vector2(680, 530)}

var _temps := 0.0
var _choisi := ""   # lieu dont la fiche est ouverte
var _decalage := Vector2.ZERO   # position du coin haut gauche de la carte à l'écran (défilement)
var _doigt := -1                # doigt posé sur la carte (-1 : aucun)
var _appui := Vector2.ZERO      # où il s'est posé
var _glisse := 0.0              # distance parcourue depuis


func _ready() -> void:
	$Titre.add_theme_color_override("font_color", Palette.LAMPE)
	$Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Retour.couleur = Palette.UI_BOUTON
	$Retour.appuye.connect(_retour)
	$Fiche/YAller.couleur = Palette.LAMPE
	$Fiche/YAller.icone = "jouer"
	$Fiche/YAller.appuye.connect(_y_aller)
	$Fiche.draw.connect(_dessiner_fiche)
	resized.connect(_placer)
	_placer()


## Fiche à sa place, carte recentrée sur sa vue d'arrivée (après un changement d'orientation aussi).
func _placer() -> void:
	var paysage := size.x > size.y
	var t: Vector2 = TAILLE_FICHE[paysage]
	$Fiche.size = t
	if paysage:
		$Fiche.position = Vector2(size.x - t.x - 24, maxf(120.0, (size.y - t.y) / 2.0))
	else:
		$Fiche.position = Vector2((size.x - t.x) / 2.0, size.y - t.y - 156)
	_decalage = _borner(size / 2.0 - PLACES[paysage]["vue"] * _taille_carte())


## Taille de la carte à l'écran : bg_map agrandie pour couvrir tout l'écran (sinon l'écran).
func _taille_carte() -> Vector2:
	if not Images.v3_existe("bg_map"):
		return size
	var t := Images.v3_taille("bg_map")
	return t * maxf(size.x / t.x, size.y / t.y)


## Décalage gardé dans les limites : la carte couvre toujours l'écran.
func _borner(decalage: Vector2) -> Vector2:
	var t := _taille_carte()
	return Vector2(clampf(decalage.x, size.x - t.x, 0.0), clampf(decalage.y, size.y - t.y, 0.0))


## Centre d'un lieu (ou de la base) à l'écran.
func _place(id: String) -> Vector2:
	return _decalage + PLACES[size.x > size.y][id] * _taille_carte()


## Un doigt posé puis levé sans glisser touche la carte ; s'il glisse, il la fait défiler.
func _input(event: InputEvent) -> void:
	# Les boutons (enfants) passent avant et marquent le toucher comme tireté.
	if event is InputEventScreenTouch:
		if event.pressed:
			if _doigt != -1 or ($Fiche.visible and $Fiche.get_global_rect().has_point(event.position)):
				return
			_doigt = event.index
			_appui = event.position
			_glisse = 0.0
		elif event.index == _doigt:
			_doigt = -1
			if _glisse < SEUIL_GLISSE:
				_toucher(_appui)
	elif event is InputEventScreenDrag and event.index == _doigt:
		_glisse += event.relative.length()
		_decalage = _borner(_decalage + event.relative)


func _toucher(position_ecran: Vector2) -> void:
	for id in Partie.LIEUX:
		if _place(id).distance_to(position_ecran) <= RAYON_TOUCHE:
			if Partie.lieu_disponible(id):
				_ouvrir(id)
			return
	_ouvrir("")


## Ouvre la fiche d'un lieu ("" : la ferme).
func _ouvrir(id: String) -> void:
	_choisi = id
	$Fiche.visible = id != ""
	$Fiche.queue_redraw()


func _y_aller() -> void:
	if _choisi == "":
		return
	Partie.choisir_lieu(_choisi)
	get_tree().change_scene_to_file(Partie.scene_lieu())


## Geste « retour » d'Android : écran précédent (la base), comme « Retour ».
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_retour.call_deferred()   # pas pendant la diffusion de la notification


func _retour() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()


func _draw() -> void:
	var e := minf(size.x, size.y) / 720.0
	if Images.v3_existe("bg_map"):
		draw_texture_rect(Images.v3_texture("bg_map"), Rect2(_decalage, _taille_carte()), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.TERRE)
		_ville(e)
	# Chemins en pointillés depuis la base (qui avancent vers les lieux disponibles)
	for id in Partie.LIEUX:
		var dispo := Partie.lieu_disponible(id)
		_pointilles(_place("base"), _place(id), Palette.LAMPE if dispo else Color(Palette.UI_BORD, 0.6), e, dispo)
	_brume(e)
	_marque_base(_place("base"), e)
	for id in Partie.LIEUX:
		_marque_lieu(id, _place(id), e)
	# Haut assombri pour le titre, bas pour Retour
	var sombre := Color(Palette.FOND_NUIT, 0.85)
	var clair := Color(Palette.FOND_NUIT, 0.0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, 150), Vector2(0, 150)]),
		PackedColorArray([sombre, sombre, clair, clair]))
	draw_polygon(PackedVector2Array([Vector2(0, size.y - 160), Vector2(size.x, size.y - 160), size, Vector2(0, size.y)]),
		PackedColorArray([clair, clair, sombre, sombre]))


## Pâtés de maisons vus du dessus, séparés par des rues ; deux avenues avec leur ligne blanche ;
## un parc ; une place dégagée sous chaque lieu.
func _ville(e: float) -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = GRAINE
	var pas := 150.0 * e
	var rue := 30.0 * e
	var places := [_place("base")]
	for id in Partie.LIEUX:
		places.append(_place(id))
	var colonnes := int(size.x / pas) + 2
	var lignes := int(size.y / pas) + 2
	for j in lignes:
		for i in colonnes:
			var bloc := Rect2(Vector2(i, j) * pas + Vector2(-pas * 0.3, -pas * 0.2) + Vector2(rue, rue) / 2.0, Vector2(pas - rue, pas - rue))
			var tirage := hasard.randf()
			var libre := false
			for p: Vector2 in places:
				if bloc.grow(55.0 * e).has_point(p):
					libre = true
			if libre:
				# Place dégagée (trottoir)
				Dessin.rect(self, bloc, Palette.PIERRE.darkened(0.45))
			elif tirage < 0.1:
				_parc(bloc, hasard, e)
			else:
				_immeubles(bloc, hasard, e)
	# Avenues
	for k in 2:
		var y := (1.8 + k * 2.0) * pas   # sur une rue entre deux rangées de pâtés
		var a := Vector2(0, y)
		var b := Vector2(size.x, y)
		draw_line(a, b, Palette.CONTOUR, rue * 1.6)
		draw_line(a, b, Palette.TERRE.lightened(0.05), rue * 1.3)
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, y), Vector2(x + 18.0 * e, y), Color(Palette.UI_TEXTE, 0.25), 3.0 * e)
			x += 40.0 * e


## Un pâté : 1 à 4 toits plats, avec un rebord clair, parfois un climatiseur ou un toit effondré.
func _immeubles(bloc: Rect2, hasard: RandomNumberGenerator, e: float) -> void:
	var coupe := hasard.randi() % 3
	var morceaux := [bloc]
	if coupe == 1:
		var x := bloc.size.x * hasard.randf_range(0.35, 0.65)
		morceaux = [Rect2(bloc.position, Vector2(x, bloc.size.y)), Rect2(bloc.position + Vector2(x, 0), Vector2(bloc.size.x - x, bloc.size.y))]
	elif coupe == 2:
		var y := bloc.size.y * hasard.randf_range(0.35, 0.65)
		morceaux = [Rect2(bloc.position, Vector2(bloc.size.x, y)), Rect2(bloc.position + Vector2(0, y), Vector2(bloc.size.x, bloc.size.y - y))]
	for toit: Rect2 in morceaux:
		var teinte := hasard.randf_range(-0.08, 0.12)
		var couleur := Palette.MUR.lightened(teinte) if teinte > 0 else Palette.MUR.darkened(-teinte)
		Dessin.rect(self, toit, couleur)
		var bord := toit.grow(-7.0 * e)
		draw_rect(bord, Color(Palette.UI_BORD, 0.12), false, 3.0 * e)
		var detail := hasard.randf()
		if detail < 0.3:
			# Climatiseur
			var c := Rect2(bord.position + bord.size * Vector2(hasard.randf_range(0.2, 0.6), hasard.randf_range(0.2, 0.6)), Vector2(18, 14) * e)
			Dessin.rect(self, c, Palette.TOLE)
		elif detail < 0.45:
			# Toit effondré : trou sombre et gravats
			var centre := bord.get_center()
			Dessin.ellipse(self, centre, Vector2(bord.size.x * 0.25, bord.size.y * 0.2), Palette.MUR_COTE)
			for k in 3:
				draw_circle(centre + Vector2(hasard.randf_range(-1, 1), hasard.randf_range(-1, 1)) * 14.0 * e, 4.0 * e, Palette.PIERRE)
		elif detail < 0.6:
			# Fenêtre de toit éclairée par la lune
			draw_rect(Rect2(bord.position + Vector2(8, 8) * e, Vector2(16, 10) * e), Palette.FENETRE.darkened(0.5))


## Parc : herbe sombre et arbres ronds vus du dessus.
func _parc(bloc: Rect2, hasard: RandomNumberGenerator, e: float) -> void:
	Dessin.rect(self, bloc, Palette.ZOMBIE_PEAU_OMBRE.darkened(0.62))
	for k in 5:
		var p := bloc.position + bloc.size * Vector2(hasard.randf_range(0.2, 0.8), hasard.randf_range(0.2, 0.8))
		var r := hasard.randf_range(12.0, 20.0) * e
		Dessin.cercle(self, p, r, Palette.ZOMBIE_PEAU_OMBRE.darkened(0.42))
		draw_circle(p - Vector2(r, r) * 0.3, r * 0.4, Palette.ZOMBIE_PEAU_OMBRE.darkened(0.25))


## Chemin en pointillés légèrement courbé de a vers b ; « anime » : les traits avancent vers b.
func _pointilles(a: Vector2, b: Vector2, couleur: Color, e: float, anime: bool) -> void:
	var courbe := PackedVector2Array()
	var milieu := (a + b) / 2.0 + (b - a).orthogonal() * 0.12
	for k in 33:
		var t := k / 32.0
		courbe.append(a.lerp(milieu, t).lerp(milieu.lerp(b, t), t))
	var pas := 28.0 * e
	var tiret := 14.0 * e
	var d := 60.0 * e + (fmod(_temps * VITESSE_POINTILLES * e, pas) if anime else 0.0)
	var longueur := 0.0
	for k in 32:
		longueur += courbe[k].distance_to(courbe[k + 1])
	while d + tiret < longueur - 70.0 * e:
		var p := _point_courbe(courbe, d)
		var q := _point_courbe(courbe, d + tiret)
		draw_line(p, q, Palette.CONTOUR, 9.0 * e)
		draw_line(p, q, couleur, 5.0 * e)
		d += pas


## Point à la distance d le long d'une ligne brisée.
func _point_courbe(courbe: PackedVector2Array, d: float) -> Vector2:
	for k in courbe.size() - 1:
		var l := courbe[k].distance_to(courbe[k + 1])
		if d <= l:
			return courbe[k].lerp(courbe[k + 1], d / l)
		d -= l
	return courbe[courbe.size() - 1]


## Nappes de brume qui dérivent lentement au-dessus de la ville.
func _brume(e: float) -> void:
	for k in 7:
		var x := fmod(k * 0.31 + _temps * 0.008 * (1 + k % 3), 1.4) - 0.2
		var p := Vector2(x * size.x, size.y * (0.15 + 0.12 * k))
		var r := (180.0 + 40.0 * (k % 3)) * e
		draw_set_transform(p, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, r, Color(Palette.BRUME_CLAIRE, 0.07))
		draw_set_transform(Vector2.ZERO)


## Étiquette sous une marque : texte dans une pilule sombre.
func _etiquette(centre: Vector2, texte: String, couleur: Color, taille: int) -> void:
	var police := ThemeDB.fallback_font
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.CONTOUR
	cadre.set_border_width_all(4)
	cadre.set_corner_radius_all(int(taille * 0.7))
	draw_style_box(cadre, Rect2(centre - Vector2(largeur / 2.0 + 14, taille * 0.75), Vector2(largeur + 28, taille * 1.5)))
	draw_string(police, centre + Vector2(-largeur / 2.0, taille * 0.36), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)


## Vignette V3 d'un lieu (ou de la base), centrée sur c ; faux si l'image manque.
func _vignette(id: String, c: Vector2, e: float, teinte: Color) -> bool:
	var nom: String = VIGNETTES.get(id, "")
	if not Images.v3_existe(nom):
		return false
	var t := Images.v3_taille(nom)
	var taille := t * LARGEUR_VIGNETTE * e / t.x
	draw_texture_rect(Images.v3_texture(nom), Rect2(c - taille / 2.0, taille), false, teinte)
	return true


## La base : vignette map_base (sinon petit abri à toit de tôle et feu de camp qui vacille), lueur du feu.
func _marque_base(c: Vector2, e: float) -> void:
	draw_circle(c, (70.0 + 4.0 * sin(_temps * 6.0)) * e, Palette.FEU_LUEUR)
	if not _vignette("base", c, e, Color.WHITE):
		Dessin.ombre(self, Rect2(c + Vector2(-56, -6) * e, Vector2(112, 26) * e))
		Dessin.rect(self, Rect2(c + Vector2(-46, -40) * e, Vector2(60, 40) * e), Palette.BOIS)
		Dessin.polygone(self, PackedVector2Array([c + Vector2(-54, -36) * e, c + Vector2(22, -50) * e,
			c + Vector2(22, -40) * e, c + Vector2(-54, -26) * e]), Palette.TOLE)
		var feu := c + Vector2(36, 4) * e
		var h := (30.0 + 5.0 * sin(_temps * 9.0)) * e
		Dessin.polygone(self, PackedVector2Array([feu + Vector2(-12, 0) * e, feu + Vector2(sin(_temps * 5.0) * 4.0 * e, -h),
			feu + Vector2(12, 0) * e]), Palette.FEU)
		draw_colored_polygon(PackedVector2Array([feu + Vector2(-5, 0) * e, feu + Vector2(0, -h * 0.5), feu + Vector2(5, 0) * e]), Palette.FEU_COEUR)
	_etiquette(c + Vector2(0, 78) * e, "Base", Palette.LAMPE, 24)


## Un lieu : sa vignette (sinon son bâtiment dessiné en petit), une étiquette ; grisé, avec un cadenas et « Bientôt »
## s'il n'est pas encore là. Le lieu dont la fiche est ouverte a un anneau qui pulse.
func _marque_lieu(id: String, c: Vector2, e: float) -> void:
	var dispo := Partie.lieu_disponible(id)
	var teinte := Color.WHITE if dispo else Color(0.5, 0.5, 0.6)
	if id == _choisi:
		var pulse := 0.5 + 0.5 * sin(_temps * 5.0)
		draw_arc(c, (84.0 + 6.0 * pulse) * e, 0.0, TAU, 40, Palette.CONTOUR, 10.0 * e, true)
		draw_arc(c, (84.0 + 6.0 * pulse) * e, 0.0, TAU, 40, Palette.LAMPE, 5.0 * e, true)
	elif dispo:
		# Lueur qui invite à toucher
		draw_circle(c, (74.0 + 6.0 * sin(_temps * 2.5)) * e, Color(Palette.LAMPE, 0.12))
	if not _vignette(id, c, e, teinte):
		var pieds := c + Vector2(0, 30) * e
		Dessin.ombre(self, Rect2(pieds + Vector2(-70, -8) * e, Vector2(140, 30) * e))
		match id:
			"supermarche":
				_supermarche(pieds, e, teinte)
			"maison":
				_maison(pieds, e, teinte)
			"pharmacie":
				_pharmacie(pieds, e, teinte)
	# Meilleur score posé au pied de la vignette, juste au-dessus du nom (en portrait, un autre lieu est juste dessous)
	if dispo:
		_etoiles(self, c + Vector2(0, 45) * e, ETOILE_CARTE * e, Partie.meilleures_etoiles(id))
	var nom: String = Partie.LIEUX[id]["nom"]
	_etiquette(c + Vector2(0, 78) * e, nom, Palette.LAMPE if dispo else Palette.UI_BORD, 24)
	if not dispo:
		if Images.v3_existe("map_lock"):
			var t := Images.v3_taille("map_lock")
			var taille := t * CADENAS * e / t.y
			draw_texture_rect(Images.v3_texture("map_lock"), Rect2(c + Vector2(0, -8) * e - taille / 2.0, taille), false)
		_etiquette(c + Vector2(0, 116) * e, "Bientôt", Palette.UI_TEXTE, 18)


## Trois étoiles icon_star côte à côte centrées sur c : les « gagnees » premières en couleur, les autres grises
## (sans l'image : étoiles dessinées en code).
func _etoiles(cible: CanvasItem, c: Vector2, taille: float, gagnees: int) -> void:
	for i in 3:
		var centre := c + Vector2((i - 1) * taille * 1.1, 0)
		if Images.v3_existe("icon_star"):
			var texture := Images.v3_texture("icon_star") if i < gagnees else Images.v3_gris("icon_star")
			var t := texture.get_size()
			var k := taille / maxf(t.x, t.y)
			cible.draw_texture_rect(texture, Rect2(centre - t * k / 2.0, t * k), false)
		else:
			var points := PackedVector2Array()
			for j in 10:
				points.append(centre + Vector2.from_angle(-PI / 2.0 + j * PI / 5.0) * taille * (0.5 if j % 2 == 0 else 0.22))
			Dessin.polygone(cible, points, Palette.LAMPE if i < gagnees else Palette.UI_FOND)


## Supermarché : grand bâtiment plat, vitrine, enseigne « SUPER » et un caddie.
func _supermarche(c: Vector2, e: float, teinte: Color) -> void:
	Dessin.rect(self, Rect2(c + Vector2(-62, -62) * e, Vector2(124, 62) * e), Palette.MUR.lightened(0.15) * teinte)
	Dessin.rect(self, Rect2(c + Vector2(-66, -70) * e, Vector2(132, 12) * e), Palette.TOLE * teinte)
	# Vitrine et porte
	for k in 4:
		draw_rect(Rect2(c + Vector2(-54 + k * 28, -44) * e, Vector2(20, 22) * e), Palette.FENETRE.darkened(0.45) * teinte)
	Dessin.rect(self, Rect2(c + Vector2(-12, -26) * e, Vector2(24, 26) * e), Palette.SORTIE.darkened(0.35) * teinte)
	# Enseigne
	Dessin.rect(self, Rect2(c + Vector2(-40, -94) * e, Vector2(80, 26) * e), Palette.COEUR * teinte)
	var police := ThemeDB.fallback_font
	var t := int(20 * e)
	var l := police.get_string_size("SUPER", HORIZONTAL_ALIGNMENT_LEFT, -1, t).x
	draw_string(police, c + Vector2(-l / 2.0, -74 * e), "SUPER", HORIZONTAL_ALIGNMENT_LEFT, -1, t, Palette.UI_TEXTE * teinte)
	# Caddie renversé devant
	var k := c + Vector2(48, 8) * e
	draw_rect(Rect2(k + Vector2(-12, -14) * e, Vector2(22, 12) * e), Palette.UI_BORD * teinte, false, 3.0 * e)
	draw_circle(k + Vector2(-8, 2) * e, 3.0 * e, Palette.CONTOUR)
	draw_circle(k + Vector2(6, 2) * e, 3.0 * e, Palette.CONTOUR)


## Maison : petite maison au toit pointu, fenêtre éclairée, porte.
func _maison(c: Vector2, e: float, teinte: Color) -> void:
	Dessin.rect(self, Rect2(c + Vector2(-42, -54) * e, Vector2(84, 54) * e), Palette.BOIS_CLAIR * teinte)
	Dessin.polygone(self, PackedVector2Array([c + Vector2(-54, -50) * e, c + Vector2(0, -96) * e, c + Vector2(54, -50) * e]),
		Palette.COEUR_VIDE.lightened(0.15) * teinte)
	Dessin.rect(self, Rect2(c + Vector2(22, -92) * e, Vector2(12, 22) * e), Palette.PIERRE * teinte)
	Dessin.rect(self, Rect2(c + Vector2(-30, -40) * e, Vector2(22, 20) * e), Palette.FENETRE.darkened(0.3) * teinte)
	Dessin.rect(self, Rect2(c + Vector2(8, -34) * e, Vector2(20, 34) * e), Palette.BOIS_SOMBRE * teinte)


## Pharmacie : bâtiment plat avec une croix verte (dessin de secours de map_pharmacy).
func _pharmacie(c: Vector2, e: float, teinte: Color) -> void:
	Dessin.rect(self, Rect2(c + Vector2(-56, -58) * e, Vector2(112, 58) * e), Palette.MUR.lightened(0.15) * teinte)
	Dessin.rect(self, Rect2(c + Vector2(-12, -30) * e, Vector2(24, 30) * e), Palette.FENETRE.darkened(0.4) * teinte)
	Dessin.rect(self, Rect2(c + Vector2(-8, -92) * e, Vector2(16, 40) * e), Palette.SORTIE * teinte)
	Dessin.rect(self, Rect2(c + Vector2(-20, -80) * e, Vector2(40, 16) * e), Palette.SORTIE * teinte)


## Fiche du lieu choisi, même mise en page pour tous : nom, objectif (deux lignes), danger (un zombie dessiné par zombie),
## rescapé (à droite, sous Danger), objets à trouver ; « Y aller » en bas à droite.
func _dessiner_fiche() -> void:
	if _choisi == "":
		return
	var fiche: Control = $Fiche
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.LAMPE
	cadre.set_border_width_all(5)
	cadre.set_corner_radius_all(24)
	fiche.draw_style_box(cadre, Rect2(Vector2.ZERO, fiche.size))
	var police := ThemeDB.fallback_font
	var x := 24.0
	var largeur := fiche.size.x - 2 * x
	var nom: String = Partie.LIEUX[_choisi]["nom"]
	# Nom réduit s'il toucherait les étoiles (paysage : fiche étroite)
	var taille_nom := 44
	while taille_nom > 28 and police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_nom).x > largeur - ETOILE_FICHE * 3.4 - 12:
		taille_nom -= 2
	fiche.draw_string_outline(police, Vector2(x, 60), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_nom, 8, Palette.CONTOUR)
	fiche.draw_string(police, Vector2(x, 60), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_nom, Palette.LAMPE)
	_etoiles(fiche, Vector2(fiche.size.x - x - ETOILE_FICHE * 1.6, 44), ETOILE_FICHE, Partie.meilleures_etoiles(_choisi))
	# Objectif sur deux lignes : « Objectif : » en jaune, puis le texte
	var objectif := Partie.texte_objectif(_choisi) if Partie.total_objectif(_choisi) > 0 else "explorer le lieu"
	fiche.draw_string(police, Vector2(x, 102), "Objectif :", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.LAMPE)
	fiche.draw_string(police, Vector2(x, 134), objectif, HORIZONTAL_ALIGNMENT_LEFT, largeur, 26, Palette.UI_TEXTE)
	fiche.draw_line(Vector2(x, 154), Vector2(fiche.size.x - x, 154), Color(Palette.UI_BORD, 0.3), 2.0)
	var infos := Partie.infos_lieu(_choisi)
	var zombies: Array = infos["zombies"]
	var objets: Array = infos["objets"]
	# Danger
	var danger := "Danger : %d zombie%s" % [zombies.size(), "s" if zombies.size() > 1 else ""]
	fiche.draw_string(police, Vector2(x, 192), danger, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.COEUR)
	for i in zombies.size():
		var pieds := Vector2(x + 40 + i * 76, 290)
		var image := "gros_face_2" if zombies[i] == 0 else "maigre_profil_2"
		Dessin.ombre(fiche, Rect2(pieds - Vector2(30, 8), Vector2(60, 16)))
		var coureur := Images.v3_pose("zombie_runner", "idle") if zombies[i] == 2 else ""
		if coureur != "":
			Images.v3_dessiner(fiche, coureur, pieds, HAUTEUR_ZOMBIE / Images.v3_taille(coureur).y)
		elif Images.existe(image):
			var echelle := HAUTEUR_ZOMBIE / Images.region(image).size.y
			Images.dessiner_pieds(fiche, image, pieds, echelle)
			if Images.existe(image + "_yeux"):
				Images.dessiner_calque(fiche, image, image + "_yeux", pieds, echelle)
		else:
			Dessin.cercle(fiche, pieds - Vector2(0, 30), 24.0, Palette.ZOMBIE_PEAU)
	# Rescapé : à droite des zombies (sous la ligne Danger), caché (à sauver), content (déjà sauvé) ou aucun
	var sauve := Partie.rescape_sauve(_choisi)
	var ligne := "Rescapé sauvé" if sauve else "Rescapé : %d" % infos["rescapes"] if infos["rescapes"] > 0 else "Pas de rescapé"
	var couleur := Palette.SORTIE if sauve else Palette.LAMPE if infos["rescapes"] > 0 else Palette.UI_BORD
	fiche.draw_string_outline(police, Vector2(x, 226), ligne, HORIZONTAL_ALIGNMENT_RIGHT, largeur, 22, 6, Palette.CONTOUR)
	fiche.draw_string(police, Vector2(x, 226), ligne, HORIZONTAL_ALIGNMENT_RIGHT, largeur, 22, couleur)
	var image := Images.v3_pose(Partie.perso_rescape(_choisi), "happy" if sauve else "hiding") if infos["rescapes"] > 0 else ""
	if image != "":
		var pieds := Vector2(fiche.size.x - x - 60, 294)
		Dessin.ombre(fiche, Rect2(pieds - Vector2(26, 7), Vector2(52, 14)))
		Images.v3_dessiner(fiche, image, pieds, 58.0 / Images.v3_taille(image).y)
	# Objets à trouver
	var texte := "Objets à trouver : %d" % objets.size()
	fiche.draw_string(police, Vector2(x, 336), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.UI_TEXTE)
	var pas := minf(82.0, largeur / maxf(objets.size(), 1.0))
	for i in objets.size():
		Dessin.icone_objet(fiche, objets[i], Vector2(x + 26 + i * pas, 394), TAILLE_ICONE)
