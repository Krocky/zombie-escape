extends Control
## Écran de fin.
## Victoire (Mission réussie / Victoire) : ciel d'aube en dégradé dessiné en code, illustration V3 bg_victory_<skin>
## au centre (une vignette, pas un plein écran), titre en haut, 1 à 3 étoiles icon_star (Partie.etoiles : sorti,
## objectif rempli, rescapé sauvé ou aucun cœur perdu) qui rebondissent l'une après l'autre, objets rapportés (et bonus)
## qui volent un par un dans un sac, inventaire de la base en icônes, rescapé sauvé qui sautille.
## Défaite (Retour à la base) : bg_defeat_<skin> plein écran assombri (son panneau EXIT recouvert d'une étiquette
## SORTIE), message encourageant, objets gardés puis perdus (barrés).
## Sans l'image : fond illustré DecorEcran. Le bouton « Retour à la base » ramène à l'écran Base.

const TAILLE_ICONE := 54.0
const PAS_ICONE := 86.0        # entre deux icônes d'objets (une image peut faire 1,4 x sa hauteur de large)
const TAILLE_STOCK := 42.0     # icônes de l'inventaire de la base
const TITRES := {"mission": "Mission réussie !", "victoire": "Victoire !", "defaite": "Retour à la base"}
const RAISONS := ["Sorti", "Objectif", "Rescapé ou\nsans blessure"]
const DEBUT_ETOILES := 0.5      # s : première étoile
const ECART_ETOILES := 0.45     # s entre deux étoiles
const DUREE_REBOND := 0.5
const DEBUT_VOL := 0.8          # s : premier objet qui vole vers le sac
const ECART_VOL := 0.35
const DUREE_VOL := 0.6
## Panneau EXIT des images de défaite (pixels de l'image), recouvert d'une étiquette SORTIE
const PANNEAUX := {"bg_defeat_heros": Rect2(878, 62, 346, 176), "bg_defeat_heroine": Rect2(1195, 15, 295, 200)}

var _temps := 0.0
var _victoire := false
var _illustration := ""        # image V3 de fond ("" : DecorEcran)
var _objets := Control.new()   # icônes : objets rapportés, bonus (entourés), puis perdus (barrés)
var _stock := Control.new()    # icônes : inventaire de la base, avec le nombre
## Emplacements calculés par _placer (coordonnées de l'écran)
var _cadre := Rect2()          # illustration de victoire
var _etoiles := Vector2.ZERO   # centre de l'étoile du milieu
var _sac := Vector2.ZERO       # centre du sac


func _ready() -> void:
	var resultat := Partie.resultat
	_victoire = resultat["victoire"]
	var nom := ("bg_victory_" if _victoire else "bg_defeat_") + Partie.perso()
	_illustration = nom if Images.v3_existe(nom) else ""
	$Titre.text = TITRES["mission" if resultat["mission"] else "victoire" if _victoire else "defaite"]
	$Titre.add_theme_color_override("font_color", Palette.SORTIE if _victoire else Palette.LAMPE)
	$Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)

	var lignes := []
	var bravo := ("Bravo %s ! " % Partie.prenom) if Partie.prenom != "" else ""
	if _victoire:
		lignes.append(bravo + "Tu es %s %s !" % [Partie.accord("sorti", "sortie"), Partie.LIEUX[Partie.lieu]["du"]])
	else:
		lignes.append("Tu as été %s... tes amis t'ont %s à la base." % [Partie.accord("rattrapé", "rattrapée"), Partie.accord("ramené", "ramenée")])
		lignes.append("Pas grave%s : la prochaine fois sera la bonne !" % ((", " + Partie.prenom) if Partie.prenom != "" else ""))
	if resultat.get("rescape", false):
		lignes.append("Tu as sauvé un rescapé !")
	if resultat["mission"]:
		lignes.append("Objectif rempli ! Bonus : " + _liste(resultat["bonus"]))
	elif _victoire and Partie.total_objectif(Partie.lieu) > 0:
		lignes.append("Objectif pas rempli : " + Partie.texte_objectif(Partie.lieu))
	if not resultat.get("jardin", []).is_empty():
		lignes.append("Le jardin te donne : " + _liste(resultat["jardin"]))
	if resultat["fioles"] > 0:
		lignes.append("%s dans la jauge du remède : %d / %d" % ["Fiole versée" if resultat["fioles"] == 1 else "Fioles versées",
			Partie.remede, Reglages.REMEDE_FIOLES])
	$Resume.text = "\n".join(lignes)
	$Resume.add_theme_color_override("font_color", Palette.UI_TEXTE)
	$Resume.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Resume.add_theme_constant_override("outline_size", 8)

	$RetourBase.couleur = Palette.LAMPE
	$RetourBase.appuye.connect(_retour_base)
	for c: Control in [_objets, _stock]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		move_child(c, $RetourBase.get_index())
	_objets.draw.connect(_dessiner_objets)
	_stock.draw.connect(_dessiner_stock)
	resized.connect(_placer)
	_placer()


func _liste(types: Array) -> String:
	if types.is_empty():
		return "aucun"
	var noms := []
	for type in types:
		noms.append(Partie.nom(type))
	return ", ".join(noms)


## Geste « retour » d'Android : comme le bouton « Retour à la base ».
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_retour_base.call_deferred()   # pas pendant la diffusion de la notification


func _retour_base() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


## Place titre, texte, icônes et bouton (paysage : en colonnes autour de l'illustration ; portrait : en pile).
func _placer() -> void:
	var paysage := size.x > size.y
	var bouton := Rect2(size.x / 2.0 - 240, size.y - 134, 480, 110)
	if not _victoire:
		# Défaite : tout dans un bloc, à gauche en paysage (le héros est au milieu de l'image), en bas en portrait
		var zone := Rect2(30, (size.y - 470) / 2.0, 520, 470) if paysage else Rect2(30, size.y - 470, size.x - 60, 450)
		_poser($Titre, Rect2(zone.position.x, zone.position.y, zone.size.x, 84), 60)
		_poser($Resume, Rect2(zone.position.x, zone.position.y + 88, zone.size.x, 150), 24)
		_objets.position = Vector2(zone.position.x, zone.position.y + 246)
		_objets.size = Vector2(zone.size.x, TAILLE_ICONE + 12)
		_stock.visible = false
		bouton.position = Vector2(zone.get_center().x - 240, zone.end.y - 110)
	elif paysage:
		_poser($Titre, Rect2(0, 12, size.x, 96), 72)
		var h := size.y - 120 - 170
		_cadre = _vignette(Vector2(size.x / 2.0, 120 + h / 2.0), h, size.x * 0.3)
		var gauche := Rect2(30, 120, _cadre.position.x - 60, size.y - 290)
		var droite := Rect2(_cadre.end.x + 30, 120, size.x - _cadre.end.x - 60, size.y - 290)
		_etoiles = Vector2(gauche.get_center().x, gauche.position.y + 70)
		_poser($Resume, Rect2(gauche.position.x, gauche.position.y + 192, gauche.size.x, 150), 22)
		_sac = Vector2(droite.get_center().x, droite.position.y + 70)
		_objets.position = Vector2(droite.position.x, droite.position.y + 150)
		_objets.size = Vector2(droite.size.x, 2 * PAS_ICONE)
		_stock.position = Vector2(droite.position.x, droite.position.y + 292)
		_stock.size = Vector2(droite.size.x, 140)
	else:
		_poser($Titre, Rect2(0, 12, size.x, 96), 64)
		_etoiles = Vector2(size.x / 2.0, 170)
		var bas := size.y - 134 - 90 - 160 - 150
		_cadre = _vignette(Vector2(size.x / 2.0, (290 + bas) / 2.0), bas - 290, size.x - 80)
		_poser($Resume, Rect2(40, bas + 4, size.x - 80, 150), 24)
		_sac = Vector2(110, bas + 230)
		_objets.position = Vector2(200, bas + 170)
		_objets.size = Vector2(size.x - 230, 2 * PAS_ICONE)
		_stock.position = Vector2(30, size.y - 134 - 96)
		_stock.size = Vector2(size.x - 60, 90)
	$RetourBase.position = bouton.position
	$RetourBase.size = bouton.size


func _poser(label: Label, rect: Rect2, taille_police: int) -> void:
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", taille_police)


## Rectangle de l'illustration de victoire centré sur c, de hauteur h au plus (largeur au plus l), aux proportions de l'image.
func _vignette(c: Vector2, h: float, l: float) -> Rect2:
	var t := Images.v3_taille(_illustration) if _illustration != "" else Vector2(3, 4)
	var k := minf(h / t.y, l / t.x)
	return Rect2(c - t * k / 2.0, t * k)


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()
	_objets.queue_redraw()


func _draw() -> void:
	if _illustration == "":
		DecorEcran.dessiner(self, size, _temps, DecorEcran.Scene.VICTOIRE if _victoire else DecorEcran.Scene.DEFAITE)
		if _victoire and Partie.resultat.get("rescape", false):
			var paysage := size.x > size.y
			_rescape((Vector2(0.15, 0.94) if paysage else Vector2(0.24, 0.96)) * size + Vector2(-112, 2) * _e())
	elif _victoire:
		_aube()
		draw_texture_rect(Images.v3_texture(_illustration), _cadre, false)
		if Partie.resultat.get("rescape", false):
			_rescape(Vector2(_cadre.position.x + 10.0 * _e(), _cadre.end.y - 6.0 * _e()))
	else:
		_defaite()
	if _victoire:
		_dessiner_etoiles()
		_dessiner_sac()


func _e() -> float:
	return minf(size.x, size.y) / 720.0


## Ciel d'aube : dégradé vertical (nuit en haut, orange à l'horizon), dernières étoiles, lueur du soleil levant.
func _aube() -> void:
	var couleurs: Array = Palette.AUBE
	var n := couleurs.size()
	for i in n - 1:
		var y0 := size.y * i / (n - 1.0)
		var y1 := size.y * (i + 1) / (n - 1.0)
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)]),
			PackedColorArray([couleurs[i], couleurs[i], couleurs[i + 1], couleurs[i + 1]]))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 5
	for k in 40:
		var p := Vector2(hasard.randf() * size.x, hasard.randf() * size.y * 0.35)
		var a := (1.0 - p.y / (size.y * 0.35)) * (0.5 + 0.3 * sin(_temps * 2.0 + k))
		draw_circle(p, hasard.randf_range(1.0, 2.5) * _e(), Color(1, 1, 1, a))
	_lueur(_cadre.get_center() + Vector2(0, _cadre.size.y * 0.15), _cadre.size.x * 1.4, Palette.AUBE_SOLEIL)


## Lueur ronde qui s'efface vers l'extérieur (cercles empilés : plus fort au centre).
func _lueur(c: Vector2, rayon: float, couleur: Color) -> void:
	for k in 12:
		draw_circle(c, rayon * (1.0 - k / 12.0), Color(couleur, couleur.a / 6.0))


## Défaite : l'image recadrée pour remplir l'écran et assombrie, étiquette SORTIE sur le panneau,
## dégradé sombre sous le texte.
func _defaite() -> void:
	var t := Images.v3_taille(_illustration)
	var k := maxf(size.x / t.x, size.y / t.y)
	var origine := (size - t * k) * Vector2(0.5, 0.45)
	draw_texture_rect(Images.v3_texture(_illustration), Rect2(origine, t * k), false, Palette.DEFAITE_NUIT)
	if PANNEAUX.has(_illustration):
		var r: Rect2 = PANNEAUX[_illustration]
		_panneau(Rect2(origine + r.position * k, r.size * k))
	var sombre := Color(Palette.FOND_NUIT, 0.9)
	var clair := Color(Palette.FOND_NUIT, 0.0)
	if size.x > size.y:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(620, 0), Vector2(620, size.y), Vector2(0, size.y)]),
			PackedColorArray([sombre, clair, clair, sombre]))
	else:
		var y := size.y - 560
		draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(size.x, y), Vector2(size.x, size.y - 380), Vector2(0, size.y - 380)]),
			PackedColorArray([clair, clair, sombre, sombre]))
		draw_rect(Rect2(0, size.y - 380, size.x, 380), sombre)


## Étiquette « SORTIE » lumineuse (pas assombrie) posée sur le panneau EXIT de l'image.
func _panneau(r: Rect2) -> void:
	_lueur(r.get_center(), r.size.x * 0.9, Color(Palette.SORTIE, 0.25 + 0.06 * sin(_temps * 2.2)))
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.SORTIE_PANNEAU
	cadre.border_color = Palette.CONTOUR
	cadre.set_border_width_all(maxi(3, int(r.size.y * 0.06)))
	cadre.set_corner_radius_all(int(r.size.y * 0.12))
	draw_style_box(cadre, r)
	var police := ThemeDB.fallback_font
	var taille := int(r.size.y * 0.5)
	var largeur := police.get_string_size("SORTIE", HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	if largeur > r.size.x * 0.84:
		taille = int(taille * r.size.x * 0.84 / largeur)
		largeur = police.get_string_size("SORTIE", HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	draw_string(police, r.get_center() + Vector2(-largeur / 2.0, taille * 0.36), "SORTIE", HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Palette.SORTIE)


## Le rescapé sauvé, content, qui sautille (pieds sur « pieds »).
func _rescape(pieds: Vector2) -> void:
	var nom := Images.v3_pose("survivor", "happy")
	if nom == "":
		return
	var e := _e()
	var saut := absf(sin(_temps * 3.0)) * 8.0 * e
	Dessin.ombre(self, Rect2(pieds - Vector2(40, 11) * e, Vector2(80, 22) * e))
	Images.v3_dessiner(self, nom, pieds - Vector2(0, saut), e * 0.8)


## Trois étoiles : les gagnées arrivent l'une après l'autre avec un rebond, les autres restent grises.
func _dessiner_etoiles() -> void:
	var e := _e()
	var gagnees := Partie.etoiles()
	var police := ThemeDB.fallback_font
	for i in 3:
		var c := _etoiles + Vector2((i - 1) * 110.0, -12.0 if i == 1 else 0.0) * e
		var taille := (96.0 if i == 1 else 80.0) * e
		_etoile(c, taille, Palette.ETOILE_VIDE, true)
		var t := _temps - DEBUT_ETOILES - i * ECART_ETOILES
		if i < gagnees and t > 0.0:
			var k := clampf(t / DUREE_REBOND, 0.0, 1.0)
			var echelle := (1.0 - pow(1.0 - k, 3.0)) * (1.0 + 0.4 * sin(k * PI))
			_etoile(c - Vector2(0, sin(k * PI) * 30.0 * e), taille * echelle, Color.WHITE, false)
		for j in RAISONS[i].split("\n").size():
			var ligne: String = RAISONS[i].split("\n")[j]
			var p := c + Vector2(-60 * e, taille * 0.5 + (22 + j * 20) * e)
			draw_string_outline(police, p, ligne, HORIZONTAL_ALIGNMENT_CENTER, 120 * e, int(17 * e), 5, Palette.CONTOUR)
			draw_string(police, p, ligne, HORIZONTAL_ALIGNMENT_CENTER, 120 * e, int(17 * e),
				Palette.LAMPE if i < gagnees else Palette.UI_BORD)


## Une étoile icon_star centrée sur c (grisée si « vide »), sinon dessinée en code.
func _etoile(c: Vector2, taille: float, couleur: Color, vide: bool) -> void:
	if Images.v3_existe("icon_star"):
		var texture := Images.v3_gris("icon_star") if vide else Images.v3_texture("icon_star")
		var t := texture.get_size()
		var k := taille / maxf(t.x, t.y)
		draw_texture_rect(texture, Rect2(c - t * k / 2.0, t * k), false, couleur)
		return
	var points := PackedVector2Array()
	for k in 10:
		points.append(c + Vector2.from_angle(-PI / 2.0 + k * PI / 5.0) * taille * (0.5 if k % 2 == 0 else 0.22))
	Dessin.polygone(self, points, Palette.UI_FOND if vide else Palette.LAMPE)


## Nombre d'objets (rapportés puis bonus) déjà tombés dans le sac.
func _arrives() -> int:
	return clampi(floori((_temps - DEBUT_VOL - DUREE_VOL) / ECART_VOL) + 1, 0, _volants().size())


func _volants() -> Array:
	return Partie.resultat["rapportes"] + Partie.resultat["bonus"]


## Sac en toile dessiné en code (il se tasse quand un objet tombe dedans) et objets en vol, de l'illustration au sac.
func _dessiner_sac() -> void:
	var e := _e()
	var volants := _volants()
	# Tassement après la dernière arrivée
	var depuis := 1.0
	for i in volants.size():
		var t := _temps - DEBUT_VOL - i * ECART_VOL - DUREE_VOL
		if t >= 0.0:
			depuis = minf(depuis, t)
	var tasse := 1.0 - 0.15 * maxf(0.0, 1.0 - depuis / 0.25)
	var c := _sac
	var l := 62.0 * e
	var h := 70.0 * e * tasse
	var fond := c + Vector2(0, 60.0 * e)
	Dessin.ombre(self, Rect2(fond - Vector2(l * 1.1, 10 * e), Vector2(l * 2.2, 20 * e)))
	# Corps : moitié basse d'une ellipse (de gauche à droite par le bas), flancs qui remontent jusqu'au col noué,
	# puis la toile froncée au-dessus du nœud, ouverte (bouche sombre)
	var ventre := fond - Vector2(0, h * 0.7)
	var col := ventre - Vector2(0, h * 0.95)
	var corps := PackedVector2Array()
	for k in 17:
		var a := PI - PI * k / 16.0
		corps.append(ventre + Vector2(cos(a) * l, sin(a) * h * 0.7))
	for v: Vector2 in [Vector2(0.95, -0.35), Vector2(0.72, -0.7), Vector2(0.34, -0.95)]:
		corps.append(ventre + Vector2(v.x * l, v.y * h))
	for v: Vector2 in [Vector2(-0.34, -0.95), Vector2(-0.72, -0.7), Vector2(-0.95, -0.35)]:
		corps.append(ventre + Vector2(v.x * l, v.y * h))
	Dessin.polygone(self, corps, Palette.SAC)
	draw_colored_polygon(PackedVector2Array([ventre + Vector2(l * 0.35, h * 0.6), ventre + Vector2(l * 0.88, h * 0.15),
		ventre + Vector2(l * 0.8, -h * 0.45), ventre + Vector2(l * 0.5, -h * 0.2)]), Palette.SAC_OMBRE)
	var bouche := col - Vector2(0, h * 0.42)
	Dessin.polygone(self, PackedVector2Array([col + Vector2(-l * 0.3, 0), bouche + Vector2(-l * 0.62, 0),
		bouche + Vector2(l * 0.62, 0), col + Vector2(l * 0.3, 0)]), Palette.SAC)
	Dessin.ellipse(self, bouche, Vector2(l * 0.62, 11.0 * e), Palette.SAC_OMBRE.darkened(0.55))
	draw_line(col + Vector2(-l * 0.4, 0), col + Vector2(l * 0.4, 0), Palette.CONTOUR, 11.0 * e)
	draw_line(col + Vector2(-l * 0.38, 0), col + Vector2(l * 0.38, 0), Palette.SAC_CORDE, 6.0 * e)
	Dessin.cercle(self, col + Vector2(l * 0.1, 0), 7.0 * e, Palette.SAC_CORDE)
	# Objets en vol : en arc, depuis l'illustration jusque dans la bouche du sac
	var depart := _cadre.get_center() if _illustration != "" else size / 2.0
	for i in volants.size():
		var t := (_temps - DEBUT_VOL - i * ECART_VOL) / DUREE_VOL
		if t <= 0.0 or t >= 1.0:
			continue
		var p := depart.lerp(bouche, t) - Vector2(0, sin(t * PI) * 160.0 * e)
		Dessin.icone_objet(self, volants[i], p + Vector2(0, TAILLE_ICONE / 2.0), TAILLE_ICONE * (1.0 - 0.4 * t))


## Victoire : objets dans le sac (bonus sur un rond jaune), apparus au fil des arrivées, en grille.
## Défaite : objets gardés, puis perdus (sombres, barrés d'une croix rouge), centrés.
func _dessiner_objets() -> void:
	var types: Array = _volants() if _victoire else Partie.resultat["rapportes"] + Partie.resultat["perdus"]
	var nombre := _arrives() if _victoire else types.size()
	var pas := PAS_ICONE
	var par_ligne := maxi(1, int(_objets.size.x / pas))
	var rapportes: Array = Partie.resultat["rapportes"]
	var a_gauche := _victoire and size.x < size.y   # portrait : les objets se rangent à droite du sac, depuis lui
	for i in nombre:
		var ligne := i / par_ligne
		var dans_ligne := mini(types.size() - ligne * par_ligne, par_ligne)
		var x0 := pas / 2.0 if a_gauche else _objets.size.x / 2.0 - (dans_ligne - 1) * pas / 2.0
		var pieds := Vector2(x0 + (i % par_ligne) * pas, TAILLE_ICONE + 6 + ligne * (TAILLE_ICONE + 14))
		var perdu := not _victoire and i >= rapportes.size()
		if _victoire and i >= rapportes.size():
			_objets.draw_circle(pieds - Vector2(0, TAILLE_ICONE / 2.0), TAILLE_ICONE * 0.62, Color(Palette.LAMPE, 0.3 + 0.1 * sin(_temps * 4.0)))
		Dessin.icone_objet(_objets, types[i], pieds, TAILLE_ICONE, Color(0.65, 0.65, 0.75, 0.8) if perdu else Color.WHITE)
		if perdu:
			var c := pieds - Vector2(0, TAILLE_ICONE / 2.0)
			for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
				_objets.draw_line(c - d * 18.0, c + d * 18.0, Palette.COEUR, 6.0, true)


## Inventaire de la base : une icône par type, avec « xN », en grille centrée.
func _dessiner_stock() -> void:
	var types := []
	for type in Partie.NOMS:
		if Partie.inventaire.get(type, 0) > 0:
			types.append(type)
	if types.is_empty():
		return
	var police := ThemeDB.fallback_font
	_stock.draw_string_outline(police, Vector2(0, 22), "À la base :", HORIZONTAL_ALIGNMENT_CENTER, _stock.size.x, 20, 6, Palette.CONTOUR)
	_stock.draw_string(police, Vector2(0, 22), "À la base :", HORIZONTAL_ALIGNMENT_CENTER, _stock.size.x, 20, Palette.UI_BORD)
	var pas := TAILLE_STOCK + 64
	var par_ligne := maxi(1, int(_stock.size.x / pas))
	for i in types.size():
		var ligne := i / par_ligne
		var dans_ligne := mini(types.size() - ligne * par_ligne, par_ligne)
		var x0 := _stock.size.x / 2.0 - (dans_ligne - 1) * pas / 2.0
		Dessin.objet_compte(_stock, types[i], Vector2(x0 + (i % par_ligne) * pas - 14, 34 + TAILLE_STOCK + ligne * (TAILLE_STOCK + 14)),
			TAILLE_STOCK, Partie.inventaire[types[i]])
