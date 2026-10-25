extends Control
## Écran Base (pas un niveau jouable) : le camp la nuit, sur un parking en ruine (image V3 bg_base),
## l'inventaire (une icône par type d'objet avec son nombre), la jauge du remède, le bouton Partir,
## le bouton Héros (changer de héros ou de prénom) et le bouton Réglages (en haut à droite en paysage, en bas à droite en portrait).
## Les cartes de construction sont dans un tiroir, ouvert et fermé par le bouton « Construire », pour voir tout le camp.
## Quand la jauge vient d'être remplie, on passe d'abord par l'écran « Remède trouvé ! ».
## Bâtiments en images V3 (base_*), selon la sauvegarde : abri (base_shelter_2 dès 2 constructions), feu de camp (flammes
## animées par-dessus), barricade, atelier, projecteur (si construits), une tente par rescapé sauvé avec lui devant.
## Chaque bâtiment tombe du ciel la première fois qu'il apparaît (Partie.premiere_apparition, mémorisé).
## Image manquante : dessin en code de secours (formes simples avec contour épais).

const CARTE := preload("res://scenes/carte_construction.tscn")

const TAILLE_ICONE := 54.0
## Emplacements (fraction de l'écran, pieds au sol) en paysage puis en portrait.
## fond : point de bg_base gardé au recadrage (0 = bord gauche / haut, 1 = bord droit / bas) ;
## echelle : taille des images de bâtiments (multipliée par e) ; perso : taille du héros et des rescapés ;
## horizon : ligne d'horizon du dessin de secours (sans bg_base) ; tentes : une place par rescapé sauvé ;
## jardin : place prête pour une future construction (base_garden), pas encore affichée.
const PLACES := {
	true: {"fond": Vector2(0.5, 0.12), "echelle": 0.5, "perso": 0.56, "horizon": 0.56,
		"abri": Vector2(0.2, 0.66), "feu": Vector2(0.5, 0.7), "heros": Vector2(0.63, 0.75),
		"lampe": Vector2(0.05, 0.74), "atelier": Vector2(0.86, 0.6), "barricade": Vector2(0.8, 0.79),
		"tentes": [Vector2(0.36, 0.52), Vector2(0.64, 0.5), Vector2(0.5, 0.42), Vector2(0.24, 0.42)],
		"jardin": Vector2(0.94, 0.45)},
	false: {"fond": Vector2(0.78, 0.0), "echelle": 0.52, "perso": 0.58, "horizon": 0.55,
		"abri": Vector2(0.3, 0.58), "feu": Vector2(0.5, 0.74), "heros": Vector2(0.73, 0.78),
		"lampe": Vector2(0.07, 0.62), "atelier": Vector2(0.76, 0.6), "barricade": Vector2(0.24, 0.85),
		"tentes": [Vector2(0.2, 0.7), Vector2(0.88, 0.69), Vector2(0.55, 0.5), Vector2(0.62, 0.88)],
		"jardin": Vector2(0.85, 0.45)},
}
## Taille des cartes de construction : en ligne (paysage), en colonne (portrait, coût sur la ligne du nom)
const TAILLE_CARTE := {true: Vector2(400, 130), false: Vector2(680, 112)}
## Bouton du tiroir des constructions : en haut à gauche (paysage), à droite de la jauge (portrait)
const TAILLE_TIROIR := Vector2(260, 100)
## Haut du tiroir : sous l'inventaire (paysage), sous la jauge et le bouton (portrait)
const HAUT_TIROIR := {true: 240.0, false: 352.0}
const DUREE_TIROIR := 0.2
## Jauge du remède : en bas à droite (paysage), en haut à gauche du bouton Construire (portrait, largeur calculée)
const TAILLE_JAUGE := {true: Vector2(380, 106), false: Vector2(0, 100)}
## bg_base : lune (pixels de l'image), redessinée en code si le recadrage la coupe
const LUNE_FOND := Vector2(1805, 168)
const RAYON_LUNE_FOND := 60.0
## Chute du ciel : durée de la chute, du rebond, du nuage de poussière (s), écart entre deux bâtiments
const DUREE_CHUTE := 0.55
const DUREE_REBOND := 0.35
const DUREE_POUSSIERE := 0.8
const ECART_CHUTES := 0.35
const ATTENTE_CHUTES := 0.3
## Teinte des images V3 (un peu assombries par la nuit)
const TEINTE := Color(0.86, 0.84, 0.94)
## base_campfire : base des flammes (pixels de l'image), et taille des flammes animées (multipliée par l'échelle)
const FEU_IMAGE := Vector2(240, 178)
const FEU_FLAMMES := 0.55
## base_floodlight : centre des trois phares (pixels de l'image)
const PHARE_IMAGE := Vector2(110, 60)
## base_floodlight est très haut (1,4 x l'abri) : dessiné un peu plus petit pour tenir sous les boutons du haut
const ECHELLE_PROJECTEUR := 0.75

var _temps := 0.0
var _etoiles := PackedVector2Array()    # positions en fraction de l'écran
var _immeubles := PackedVector2Array()  # largeur, hauteur (fractions) des ruines à l'horizon
var _chutes := {}                       # id du bâtiment -> instant où il commence à tomber (_temps)
var _glissement: Tween                  # ouverture ou fermeture du tiroir en cours
var _tiroir := 0.0:                     # 0 = tiroir fermé, 1 = ouvert
	set(valeur):
		_tiroir = valeur
		_placer_tiroir()


func _ready() -> void:
	if Partie.annoncer_remede():
		get_tree().change_scene_to_file.call_deferred("res://scenes/remede.tscn")
	$Haut/Titre.add_theme_color_override("font_color", Palette.LAMPE)
	$Haut/Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Haut/Inventaire.draw.connect(_dessiner_inventaire)
	$Remede.draw.connect(_dessiner_remede)
	$Partir.couleur = Palette.LAMPE
	$Partir.icone = "jouer"
	$Partir.appuye.connect(_partir)
	$Heros.couleur = Palette.UI_BOUTON
	$Heros.icone = "heros"
	$Heros.appuye.connect(_changer_heros)
	$Reglages.couleur = Palette.UI_BOUTON
	$Reglages.icone = "reglages"
	$Reglages.appuye.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/parametres.tscn"))
	$Tiroir.appuye.connect(func() -> void: ouvrir_tiroir(not tiroir_ouvert()))
	$Haut/Titre.text = _titre()
	for construction in Partie.CONSTRUCTIONS:
		var carte := CARTE.instantiate()
		carte.construction = construction
		carte.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		carte.construire.connect(_construire)
		$Constructions.add_child(carte)
	resized.connect(_placer_cartes)
	_placer_cartes()
	_actualiser_tiroir()
	_preparer_chutes()
	# Ciel et ruines (dessin de secours) tirés une fois, avec une graine fixe
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	for i in 40:
		_etoiles.append(Vector2(hasard.randf(), hasard.randf() * 0.5))
	for i in 14:
		_immeubles.append(Vector2(hasard.randf_range(0.06, 0.12), hasard.randf_range(0.06, 0.18)))


## Bouton Construire en haut à gauche (paysage) ou à droite de la jauge (portrait), cartes en ligne en paysage,
## en colonne en portrait. Jauge du remède en bas à droite ou en haut à gauche.
func _placer_cartes() -> void:
	var paysage := size.x > size.y
	$Tiroir.custom_minimum_size = TAILLE_TIROIR
	$Tiroir.size = TAILLE_TIROIR
	$Tiroir.position = Vector2(24, 24) if paysage else Vector2(size.x - TAILLE_TIROIR.x - 24, 236)
	$Remede.size = TAILLE_JAUGE[true] if paysage else Vector2(size.x - TAILLE_TIROIR.x - 64, TAILLE_JAUGE[false].y)
	$Remede.position = Vector2(size.x - $Remede.size.x - 24, size.y - $Remede.size.y - 34) if paysage \
		else Vector2(24, 236)
	$Reglages.size = $Reglages.custom_minimum_size
	$Reglages.position = Vector2(size.x - $Reglages.size.x - 24, 24) if paysage \
		else Vector2(size.x - $Reglages.size.x - 24, size.y - $Reglages.size.y - 44)
	$Constructions.vertical = not paysage
	$Constructions.add_theme_constant_override("separation", 14 if paysage else 10)
	for carte in $Constructions.get_children():
		carte.custom_minimum_size = TAILLE_CARTE[paysage]
	$Constructions.size = Vector2.ZERO
	_placer_tiroir()


## Le tiroir glisse depuis son bouton et s'efface en se fermant ; fermé, ses cartes ne captent plus les doigts.
func _placer_tiroir() -> void:
	if not is_node_ready():
		return
	var boite: Control = $Constructions
	var largeur := boite.get_combined_minimum_size().x
	boite.position = Vector2((size.x - largeur) / 2.0, HAUT_TIROIR[size.x > size.y] - 40.0 * (1.0 - _tiroir))
	boite.modulate.a = _tiroir
	boite.visible = _tiroir > 0.01
	queue_redraw()


## Ouvre ou ferme le tiroir des constructions.
func ouvrir_tiroir(ouvert: bool) -> void:
	if _glissement:
		_glissement.kill()
	_glissement = create_tween()
	_glissement.tween_property(self, "_tiroir", 1.0 if ouvert else 0.0, DUREE_TIROIR)
	$Tiroir.texte = "Fermer" if ouvert else "Construire"


func tiroir_ouvert() -> bool:
	return $Tiroir.texte == "Fermer"


## Bouton du tiroir en vert quand une construction est possible.
func _actualiser_tiroir() -> void:
	var possible := false
	for construction in Partie.CONSTRUCTIONS:
		possible = possible or Partie.peut_construire(construction)
	$Tiroir.couleur = Palette.SORTIE if possible else Palette.UI_BOUTON


## Construction faite : on ferme le tiroir pour voir le bâtiment tomber du ciel.
func _construire(construction: String) -> void:
	if not Partie.construire(construction):
		return
	for carte in $Constructions.get_children():
		carte.actualiser()
	$Haut/Inventaire.queue_redraw()
	_actualiser_tiroir()
	ouvrir_tiroir(false)
	_preparer_chutes(DUREE_TIROIR)


## Bâtiments qui apparaissent pour la première fois : ils tomberont du ciel l'un après l'autre.
func _preparer_chutes(attente := ATTENTE_CHUTES) -> void:
	var debut := _temps + attente
	for id in _batiments_visibles():
		if Partie.premiere_apparition(id):
			_chutes[id] = debut
			debut += ECART_CHUTES


## Ids des bâtiments du camp, selon la sauvegarde.
func _batiments_visibles() -> Array:
	var ids := ["abri_2" if Partie.constructions.size() >= 2 else "abri_1", "feu"]
	for construction in ["barricade", "atelier", "lampe"]:
		if Partie.est_construit(construction):
			ids.append(construction)
	# Jardin : future construction (pas encore dans Partie.CONSTRUCTIONS), donc jamais affiché pour l'instant
	if Partie.est_construit("jardin"):
		ids.append("jardin")
	for k in mini(Partie.rescapes, PLACES[true]["tentes"].size()):
		ids.append("tente_%d" % (k + 1))
	return ids


## « La base d'Eliott », « La base de Lou », ou « La base » sans prénom.
func _titre() -> String:
	var prenom := Partie.prenom
	if prenom == "":
		return "La base"
	var voyelle := prenom.left(1).to_lower() in ["a", "e", "i", "o", "u", "y", "h", "é", "è", "ê", "à", "â", "î", "ô", "û"]
	return "La base " + ("d'" if voyelle else "de ") + prenom


func _changer_heros() -> void:
	get_tree().change_scene_to_file("res://scenes/choix_heros.tscn")


func _partir() -> void:
	get_tree().change_scene_to_file("res://scenes/carte.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()


func _draw() -> void:
	var e := minf(size.x, size.y) / 720.0
	var places: Dictionary = PLACES[size.x > size.y]
	_fond(places, e)
	# Lumières au sol : feu qui vacille, projecteur (une fois posés)
	var feu: Vector2 = places["feu"] * size
	if _etat_chute("feu")["pose"]:
		var vacille := 1.0 + 0.05 * sin(_temps * 7.0) + 0.03 * sin(_temps * 13.0)
		for r: float in [330.0, 220.0, 130.0]:
			_ellipse_pleine(feu, Vector2(r, r * 0.45) * e * vacille, Palette.FEU_LUEUR)
	if Partie.est_construit("lampe") and _etat_chute("lampe")["pose"]:
		var force := 0.16 + 0.02 * sin(_temps * 3.0)
		_ellipse_pleine(places["lampe"] * size + Vector2(110, 30) * e, Vector2(150, 40) * e, Color(Palette.LAMPE_FAISCEAU, force))
	# Bâtiments, héros et rescapés, de l'arrière vers l'avant
	var elements := _elements(places, e)
	elements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pieds"].y < b["pieds"].y)
	for element in elements:
		_dessiner_element(element, e)
	# Haut assombri pour que le titre et l'inventaire ressortent
	var sombre := Color(Palette.FOND_NUIT, 0.7)
	var clair := Color(Palette.FOND_NUIT, 0.0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, 240), Vector2(0, 240)]),
		PackedColorArray([sombre, sombre, clair, clair]))
	# Fond du tiroir ouvert, sous les cartes
	if $Constructions.visible:
		var cadre := StyleBoxFlat.new()
		cadre.bg_color = Color(Palette.FOND_NUIT, 0.75 * _tiroir)
		cadre.set_corner_radius_all(28)
		draw_style_box(cadre, $Constructions.get_rect().grow(16))


## Fond bg_base recadré pour remplir l'écran (lune redessinée si le recadrage la coupe), sinon ciel, ruines et sol en code.
func _fond(places: Dictionary, e: float) -> void:
	if not Images.v3_existe("bg_base"):
		var horizon: float = size.y * places["horizon"]
		draw_rect(Rect2(Vector2.ZERO, size), Palette.FOND_NUIT)
		_ciel(horizon, e)
		draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Palette.TERRE)
		return
	var t := Images.v3_taille("bg_base")
	var k := maxf(size.x / t.x, size.y / t.y)
	var source := Rect2((t - size / k) * places["fond"], size / k)
	draw_texture_rect_region(Images.v3_texture("bg_base"), Rect2(Vector2.ZERO, size), source)
	if not source.grow(-RAYON_LUNE_FOND).has_point(LUNE_FOND):
		_lune(Vector2(size.x * 0.88, size.y * (0.13 if size.x > size.y else 0.06)), e)


## Éléments du camp à dessiner : {"id", "pieds", "image" (V3, "" = dessin de secours), "echelle", "miroir",
## "secours" (Callable(pieds)), "apres" (Callable(pieds, echelle) dessiné par-dessus), "attend" (id dont la chute doit être finie)}.
func _elements(places: Dictionary, e: float) -> Array:
	var s: float = places["echelle"] * e
	var liste := []
	var abri := "abri_2" if Partie.constructions.size() >= 2 else "abri_1"
	var image_abri := "base_shelter_2" if abri == "abri_2" and Images.v3_existe("base_shelter_2") else "base_shelter_1"
	liste.append(_batiment(abri, places["abri"] * size, image_abri, s, _abri.bind(e)))
	liste.append(_batiment("feu", places["feu"] * size, "base_campfire", s, _feu.bind(e), _flammes))
	if Partie.est_construit("barricade"):
		liste.append(_batiment("barricade", places["barricade"] * size, "base_barricade", s, _barricade.bind(e)))
	if Partie.est_construit("atelier"):
		liste.append(_batiment("atelier", places["atelier"] * size, "base_workshop", s, _atelier.bind(e)))
	if Partie.est_construit("lampe"):
		liste.append(_batiment("lampe", places["lampe"] * size, "base_floodlight", s * ECHELLE_PROJECTEUR, _lampe.bind(e), _phares))
	if Partie.est_construit("jardin"):
		liste.append(_batiment("jardin", places["jardin"] * size, "base_garden", s, func(_p: Vector2) -> void: pass))
	var tentes: Array = places["tentes"]
	for k in mini(Partie.rescapes, tentes.size()):
		var id := "tente_%d" % (k + 1)
		var pieds: Vector2 = tentes[k] * size
		liste.append(_batiment(id, pieds, "base_tent", s, _tente.bind(e)))
		# Le rescapé, content, devant l'entrée de sa tente (côté gauche de l'image)
		var rescape := _batiment("rescape_%d" % (k + 1), pieds + Vector2(-70, 14) * e, "survivor_happy", places["perso"] * e,
			func(_p: Vector2) -> void: pass)
		rescape["attend"] = id
		liste.append(rescape)
	var heros: Vector2 = places["heros"] * size
	liste.append({"id": "heros", "pieds": heros, "image": "", "attend": "",
		"secours": _heros.bind(e * places["perso"], places["heros"].x > places["feu"].x)})
	return liste


func _batiment(id: String, pieds: Vector2, image: String, echelle: float, secours: Callable, apres := Callable()) -> Dictionary:
	return {"id": id, "pieds": pieds, "image": image if Images.v3_existe(image) else "", "echelle": echelle,
		"secours": secours, "apres": apres, "attend": ""}


## Où en est la chute d'un bâtiment : {"cache" (pas encore tombé), "pose" (au sol, rebond compris),
## "dy" (décalage vertical), "ecrase" (aplatissement à l'impact), "poussiere" (0 -> 1 après l'impact, -1 sinon)}.
func _etat_chute(id: String) -> Dictionary:
	var etat := {"cache": false, "pose": true, "dy": 0.0, "ecrase": 0.0, "poussiere": -1.0}
	if not _chutes.has(id):
		return etat
	var t: float = _temps - _chutes[id]
	if t < 0.0:
		etat["cache"] = true
		etat["pose"] = false
	elif t < DUREE_CHUTE:
		etat["pose"] = false
		etat["dy"] = -size.y * 1.1 * (1.0 - pow(t / DUREE_CHUTE, 2.0))
	else:
		var u := t - DUREE_CHUTE
		if u < DUREE_REBOND:
			var v := u / DUREE_REBOND
			etat["ecrase"] = 0.14 * sin(minf(v * 3.0, 1.0) * PI)
			etat["dy"] = -18.0 * sin(clampf((v - 0.33) * 1.5, 0.0, 1.0) * PI)
		if u < DUREE_POUSSIERE:
			etat["poussiere"] = u / DUREE_POUSSIERE
		elif u > DUREE_POUSSIERE + 0.1:
			_chutes.erase(id)
	return etat


func _dessiner_element(element: Dictionary, e: float) -> void:
	if element["attend"] != "" and not _etat_chute(element["attend"])["pose"]:
		return
	var etat := _etat_chute(element["id"])
	if etat["cache"]:
		return
	var pieds: Vector2 = element["pieds"]
	# Ombre qui grandit au sol pendant la chute
	if not etat["pose"] and etat["dy"] < 0.0:
		var p := 1.0 - absf(etat["dy"]) / (size.y * 1.1)
		Dessin.ombre(self, Rect2(pieds - Vector2(110, 22) * e * p, Vector2(220, 44) * e * p))
	var ici := pieds + Vector2(0, etat["dy"])
	if element["image"] != "":
		var base := Transform2D(0.0, Vector2(1.0 + etat["ecrase"], 1.0 - etat["ecrase"]), 0.0, ici)
		draw_set_transform_matrix(base)
		Images.v3_dessiner(self, element["image"], Vector2.ZERO, element["echelle"], false, TEINTE, base)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if element.get("apres", Callable()).is_valid() and etat["pose"]:
			element["apres"].call(ici, element["echelle"])
	else:
		element["secours"].call(ici)
	if etat["poussiere"] >= 0.0:
		_poussiere(pieds, e, etat["poussiere"])


## Nuage de poussière à l'impact : des bouffées qui s'écartent au ras du sol, grossissent et s'effacent.
func _poussiere(pieds: Vector2, e: float, t: float) -> void:
	var alpha := 0.45 * (1.0 - t)
	for k in 10:
		var a := k * TAU / 10.0 + 0.4
		var d := Vector2(cos(a) * 150.0, sin(a) * 42.0) * e * (0.4 + 0.8 * sqrt(t))
		var r := (22.0 + 26.0 * t + 6.0 * (k % 3)) * e
		draw_circle(pieds + d - Vector2(0, 20.0 * t * e), r, Color(Palette.PIERRE.lightened(0.3), alpha))


## Flammes animées par-dessus le feu de l'image base_campfire.
func _flammes(pieds: Vector2, echelle: float) -> void:
	var centre := Images.v3_point("base_campfire", FEU_IMAGE, pieds, echelle)
	_flammes_et_etincelles(centre, echelle * FEU_FLAMMES)


## Lumière des trois phares du projecteur, qui tombe sur le sol devant lui.
func _phares(pieds: Vector2, echelle: float) -> void:
	var tete := Images.v3_point("base_floodlight", PHARE_IMAGE, pieds, echelle)
	var e := echelle / 0.5
	var force := 0.14 + 0.02 * sin(_temps * 3.0)
	draw_colored_polygon(PackedVector2Array([tete + Vector2(-30, -10) * e, tete + Vector2(30, 10) * e,
		pieds + Vector2(260, 30) * e, pieds + Vector2(-40, 40) * e]), Color(Palette.LAMPE_FAISCEAU, force))
	for p: Vector2 in [Vector2(60, 35), Vector2(112, 52), Vector2(150, 95)]:
		var c := Images.v3_point("base_floodlight", p, pieds, echelle)
		draw_circle(c, 22.0 * e, Color(Palette.LAMPE, 0.22 + 0.04 * sin(_temps * 3.0)))
		draw_circle(c, 10.0 * e, Color(Palette.LAMPE, 0.5))


func _ellipse_pleine(centre: Vector2, rayons: Vector2, couleur: Color) -> void:
	draw_set_transform(centre, 0.0, Vector2(1.0, rayons.y / rayons.x))
	draw_circle(Vector2.ZERO, rayons.x, couleur)
	draw_set_transform(Vector2.ZERO)


## Dessin de secours (sans bg_base) : étoiles qui scintillent, lune, et ruines de la ville à l'horizon.
func _ciel(horizon: float, e: float) -> void:
	for i in _etoiles.size():
		var p := _etoiles[i] * Vector2(size.x, horizon)
		var a := 0.35 + 0.3 * sin(_temps * 1.5 + i * 1.7)
		draw_circle(p, 2.0 * e, Color(Palette.UI_TEXTE, a))
	_lune(Vector2(size.x * 0.88, size.y * (0.13 if size.x > size.y else 0.06)), e)
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


func _lune(lune: Vector2, e: float) -> void:
	draw_circle(lune, 70.0 * e, Color(Palette.LUNE, 0.12))
	Dessin.cercle(self, lune, 34.0 * e, Palette.LUNE)
	draw_circle(lune + Vector2(-10, -6) * e, 7.0 * e, Palette.LUNE.darkened(0.15))
	draw_circle(lune + Vector2(9, 10) * e, 5.0 * e, Palette.LUNE.darkened(0.15))


## Secours (sans image) : abri en planches avec un toit de tôle, une couverture devant l'entrée, une caisse et un carton à côté.
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


## Secours : barricade, palissade de pieux taillés en pointe, tenus par deux planches en travers.
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


## Secours : lampe renforcée, un projecteur sur un poteau qui éclaire le sol devant.
func _lampe(bas: Vector2, e: float) -> void:
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


## Secours : atelier, établi en bois avec un étau, un marteau et une scie posés dessus.
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


## Secours : tente, une toile en triangle avec son ouverture sombre.
func _tente(pieds: Vector2, e: float) -> void:
	var l := 180.0 * e
	var h := 120.0 * e
	Dessin.ombre(self, Rect2(pieds - Vector2(l * 0.6, 18 * e), Vector2(l * 1.2, 36 * e)))
	Dessin.polygone(self, PackedVector2Array([pieds + Vector2(-l / 2.0, 0), pieds + Vector2(0, -h), pieds + Vector2(l / 2.0, 0)]),
		Palette.TOLE.darkened(0.2))
	Dessin.polygone(self, PackedVector2Array([pieds + Vector2(-l * 0.18, 0), pieds + Vector2(0, -h * 0.6), pieds + Vector2(l * 0.18, 0)]),
		Palette.CONTOUR)


func _image_au_sol(nom: String, pieds: Vector2, hauteur: float) -> void:
	if not Images.existe(nom):
		return
	Images.dessiner_pieds(self, nom, pieds, hauteur / Images.region(nom).size.y, false, Color(0.62, 0.58, 0.72))


## Le héros choisi debout près du feu, tourné vers lui, éclairé d'un côté.
func _heros(pieds: Vector2, echelle: float, miroir: bool) -> void:
	Dessin.ombre(self, Rect2(pieds - Vector2(55, 15) * echelle, Vector2(110, 30) * echelle))
	DecorEcran.dessiner_heros(self, Partie.perso(), pieds, echelle, miroir, Color(1.0, 0.9, 0.8))


## Secours : feu de camp, pierres en cercle, bûches croisées, trois flammes qui dansent et des étincelles.
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
	_flammes_et_etincelles(centre, e)
	for p: Vector2 in pierres:
		if p.y > centre.y:
			Dessin.ellipse(self, p, Vector2(17, 11) * e, Palette.PIERRE)


## Trois flammes qui dansent et des étincelles qui montent (feu de secours, ou par-dessus base_campfire).
func _flammes_et_etincelles(centre: Vector2, e: float) -> void:
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


## Jauge du remède : une fiole, « Remède N / 3 » et une barre en cases qui se remplit de vert.
func _dessiner_remede() -> void:
	var zone: Control = $Remede
	var plein := Partie.remede_trouve()
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.SORTIE if plein else Palette.CONTOUR
	cadre.set_border_width_all(5)
	cadre.set_corner_radius_all(24)
	zone.draw_style_box(cadre, Rect2(Vector2.ZERO, zone.size))
	var h := zone.size.y
	Dessin.icone_objet(zone, "fiole", Vector2(h * 0.5, h * 0.84), h * 0.62)
	var police := ThemeDB.fallback_font
	var texte := "Remède trouvé !" if plein else "Remède : %d / %d" % [Partie.remede, Reglages.REMEDE_FIOLES]
	var p := Vector2(h * 0.95, h * 0.4)
	zone.draw_string_outline(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6, Palette.CONTOUR)
	zone.draw_string(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.SORTIE if plein else Palette.LAMPE)
	# Barre : une case par fiole
	var barre := Rect2(p.x, h * 0.54, zone.size.x - p.x - 22, h * 0.28)
	var n := Reglages.REMEDE_FIOLES
	var pas := barre.size.x / n
	for k in n:
		var case := Rect2(barre.position + Vector2(k * pas + 3, 0), Vector2(pas - 6, barre.size.y))
		var couleur := Palette.ZOMBIE_PEAU.lightened(0.3) if k < Partie.remede else Palette.UI_FOND
		Dessin.rect(zone, case, couleur)
		if k < Partie.remede:
			zone.draw_rect(Rect2(case.position + Vector2(4, 4), Vector2(case.size.x - 8, 4)), Color(1, 1, 1, 0.5))
