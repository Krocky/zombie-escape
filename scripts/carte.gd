extends Control
## Écran Carte : plan de la ville la nuit, vu du dessus, avec la base et les lieux (Partie.LIEUX).
## Toucher un lieu disponible ouvre sa fiche (nom, objectif, danger = zombies, rescapé, objets à trouver, « Y aller ») ;
## un lieu sans scène est grisé, marqué « Bientôt » et ne réagit pas. « Retour » ramène à la base.
## Tout est dessiné en code (pâtés de maisons tirés avec une graine fixe).

const GRAINE := 11
const RAYON_TOUCHE := 80.0      # zone de toucher autour d'un lieu (diamètre >= 100 px)
const TAILLE_ICONE := 46.0      # objets, dans la fiche
const HAUTEUR_ZOMBIE := 84.0    # zombies, dans la fiche
## Emplacements (fraction de l'écran) de la base et des lieux ; en paysage puis en portrait
const PLACES := {
	true: {"base": Vector2(0.13, 0.62), "supermarche": Vector2(0.36, 0.36), "maison": Vector2(0.5, 0.72)},
	false: {"base": Vector2(0.2, 0.47), "supermarche": Vector2(0.68, 0.24), "maison": Vector2(0.62, 0.45)},
}
## Fiche : à droite en paysage, en bas (au-dessus de Retour) en portrait
## (en paysage, l'objectif est sous le nom et la fiche plus haute ; en portrait il est à gauche de « Y aller »)
const TAILLE_FICHE := {true: Vector2(456, 512), false: Vector2(680, 440)}

var _temps := 0.0
var _choisi := ""   # lieu dont la fiche est ouverte


func _ready() -> void:
	$Titre.add_theme_color_override("font_color", Palette.LAMPE)
	$Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Retour.couleur = Palette.UI_BOUTON
	$Retour.appuye.connect(_retour)
	$Fiche/YAller.couleur = Palette.LAMPE
	$Fiche/YAller.icone = "jouer"
	$Fiche/YAller.appuye.connect(_y_aller)
	$Fiche.draw.connect(_dessiner_fiche)
	resized.connect(_placer_fiche)
	_placer_fiche()


func _placer_fiche() -> void:
	var paysage := size.x > size.y
	var t: Vector2 = TAILLE_FICHE[paysage]
	$Fiche.size = t
	if paysage:
		$Fiche.position = Vector2(size.x - t.x - 24, maxf(120.0, (size.y - t.y) / 2.0))
	else:
		$Fiche.position = Vector2((size.x - t.x) / 2.0, size.y - t.y - 156)


## Centre d'un lieu (ou de la base) à l'écran.
func _place(id: String) -> Vector2:
	return PLACES[size.x > size.y][id] * size


func _input(event: InputEvent) -> void:
	# Les boutons (enfants) passent avant et marquent le toucher comme traité.
	if not event is InputEventScreenTouch or not event.pressed:
		return
	if $Fiche.visible and $Fiche.get_global_rect().has_point(event.position):
		return
	for id in Partie.LIEUX:
		if _place(id).distance_to(event.position) <= RAYON_TOUCHE:
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


func _retour() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()


func _draw() -> void:
	var e := minf(size.x, size.y) / 720.0
	draw_rect(Rect2(Vector2.ZERO, size), Palette.TERRE)
	_ville(e)
	# Chemins en pointillés depuis la base
	for id in Partie.LIEUX:
		var couleur := Palette.LAMPE if Partie.lieu_disponible(id) else Color(Palette.UI_BORD, 0.5)
		_pointilles(_place("base"), _place(id), couleur, e)
	_brume(e)
	_marque_base(_place("base"), e)
	for id in Partie.LIEUX:
		_marque_lieu(id, _place(id), e)
	# Haut assombri pour le titre, bords assombris
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


func _pointilles(a: Vector2, b: Vector2, couleur: Color, e: float) -> void:
	var longueur := a.distance_to(b)
	var d := (b - a) / longueur
	var t := 50.0 * e
	while t < longueur - 50.0 * e:
		draw_line(a + d * t, a + d * minf(t + 14.0 * e, longueur), Palette.CONTOUR, 9.0 * e)
		draw_line(a + d * t, a + d * minf(t + 14.0 * e, longueur), couleur, 5.0 * e)
		t += 28.0 * e


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


## La base : petit abri à toit de tôle et feu de camp qui vacille.
func _marque_base(c: Vector2, e: float) -> void:
	draw_circle(c, (60.0 + 4.0 * sin(_temps * 6.0)) * e, Palette.FEU_LUEUR)
	Dessin.ombre(self, Rect2(c + Vector2(-56, -6) * e, Vector2(112, 26) * e))
	Dessin.rect(self, Rect2(c + Vector2(-46, -40) * e, Vector2(60, 40) * e), Palette.BOIS)
	Dessin.polygone(self, PackedVector2Array([c + Vector2(-54, -36) * e, c + Vector2(22, -50) * e,
		c + Vector2(22, -40) * e, c + Vector2(-54, -26) * e]), Palette.TOLE)
	var feu := c + Vector2(36, 4) * e
	var h := (30.0 + 5.0 * sin(_temps * 9.0)) * e
	Dessin.polygone(self, PackedVector2Array([feu + Vector2(-12, 0) * e, feu + Vector2(sin(_temps * 5.0) * 4.0 * e, -h),
		feu + Vector2(12, 0) * e]), Palette.FEU)
	draw_colored_polygon(PackedVector2Array([feu + Vector2(-5, 0) * e, feu + Vector2(0, -h * 0.5), feu + Vector2(5, 0) * e]), Palette.FEU_COEUR)
	_etiquette(c + Vector2(0, 40) * e, "Base", Palette.LAMPE, 24)


## Un lieu : son bâtiment dessiné en petit, une étiquette ; grisé et « Bientôt » s'il n'est pas encore là.
## Le lieu dont la fiche est ouverte a un anneau qui pulse.
func _marque_lieu(id: String, c: Vector2, e: float) -> void:
	var dispo := Partie.lieu_disponible(id)
	var gris := Color(0.45, 0.45, 0.55)
	if id == _choisi:
		var pulse := 0.5 + 0.5 * sin(_temps * 5.0)
		draw_arc(c + Vector2(0, -20) * e, (74.0 + 6.0 * pulse) * e, 0.0, TAU, 40, Palette.CONTOUR, 10.0 * e, true)
		draw_arc(c + Vector2(0, -20) * e, (74.0 + 6.0 * pulse) * e, 0.0, TAU, 40, Palette.LAMPE, 5.0 * e, true)
	elif dispo:
		# Lueur qui invite à toucher
		draw_circle(c + Vector2(0, -20) * e, (64.0 + 6.0 * sin(_temps * 2.5)) * e, Color(Palette.LAMPE, 0.12))
	Dessin.ombre(self, Rect2(c + Vector2(-70, -8) * e, Vector2(140, 30) * e))
	match id:
		"supermarche":
			_supermarche(c, e, Color.WHITE if dispo else gris)
		"maison":
			_maison(c, e, Color.WHITE if dispo else gris)
	var nom: String = Partie.LIEUX[id]["nom"]
	_etiquette(c + Vector2(0, 36) * e, nom, Palette.LAMPE if dispo else Palette.UI_BORD, 24)
	if not dispo:
		_etiquette(c + Vector2(0, 76) * e, "Bientôt", Palette.UI_TEXTE, 18)


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


## Fiche du lieu choisi : nom, objectif (sur une ou deux lignes), danger (un zombie dessiné par zombie), objets à trouver.
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
	var nom: String = Partie.LIEUX[_choisi]["nom"]
	fiche.draw_string_outline(police, Vector2(x, 60), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, 8, Palette.CONTOUR)
	fiche.draw_string(police, Vector2(x, 60), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Palette.LAMPE)
	# Objectif sur deux lignes (« Objectif : » en jaune, puis le texte) : à gauche de « Y aller » s'il y tient,
	# sinon sous le nom (le reste de la fiche descend)
	var objectif := Partie.texte_objectif(_choisi)
	var place_bas: float = fiche.size.x - $Fiche/YAller.size.x - 3 * x
	var en_bas := police.get_string_size(objectif, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x <= place_bas
	var y_objectif := fiche.size.y - 80.0 if en_bas else 102.0
	fiche.draw_string(police, Vector2(x, y_objectif), "Objectif :", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.LAMPE)
	fiche.draw_string(police, Vector2(x, y_objectif + 32), objectif, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.UI_TEXTE)
	var dy := 0.0 if en_bas else 72.0
	var infos := Partie.infos_lieu(_choisi)
	var zombies: Array = infos["zombies"]
	var objets: Array = infos["objets"]
	# Danger
	var danger := "Danger : %d zombie%s" % [zombies.size(), "s" if zombies.size() > 1 else ""]
	fiche.draw_string(police, Vector2(x, 106 + dy), danger, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.COEUR)
	for i in zombies.size():
		var pieds := Vector2(x + 40 + i * 76, 202 + dy)
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
	# Rescapé : à droite des zombies (sous la ligne Danger), caché (à sauver) ou content (déjà sauvé)
	if infos["rescapes"] > 0:
		var sauve := Partie.rescape_sauve(_choisi)
		var ligne := "Rescapé sauvé" if sauve else "Rescapé : %d" % infos["rescapes"]
		fiche.draw_string_outline(police, Vector2(x, 140 + dy), ligne, HORIZONTAL_ALIGNMENT_RIGHT, fiche.size.x - 2 * x, 22, 6, Palette.CONTOUR)
		fiche.draw_string(police, Vector2(x, 140 + dy), ligne, HORIZONTAL_ALIGNMENT_RIGHT, fiche.size.x - 2 * x, 22,
			Palette.SORTIE if sauve else Palette.LAMPE)
		var image := Images.v3_pose("survivor", "happy" if sauve else "hiding")
		if image != "":
			var pieds := Vector2(fiche.size.x - x - 60, 210 + dy)
			Dessin.ombre(fiche, Rect2(pieds - Vector2(26, 7), Vector2(52, 14)))
			Images.v3_dessiner(fiche, image, pieds, 58.0 / Images.v3_taille(image).y)
	# Objets à trouver
	var texte := "Objets à trouver : %d" % objets.size()
	fiche.draw_string(police, Vector2(x, 248 + dy), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.UI_TEXTE)
	var pas := minf(82.0, (fiche.size.x - 2 * x) / maxf(objets.size(), 1.0))
	for i in objets.size():
		Dessin.icone_objet(fiche, objets[i], Vector2(x + 26 + i * pas, 306 + dy), TAILLE_ICONE)
