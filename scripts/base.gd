extends "res://scripts/niveau.gd"
## La base : un grand parking où le héros marche, avec la même mécanique que les lieux (Niveau : vue isométrique,
## joystick, caméra qui suit, tri en profondeur, collisions), sans zombie et éclairé (pas de nuit noire, lampe
## éteinte, Reglages.BASE_CLARTE). Le camp (Batiment) : abri (base_shelter_2 dès 2 constructions), feu, constructions
## faites (barricade, atelier, projecteur, jardin), une tente par rescapé sauvé (au plus 4) avec lui devant ;
## chacun posé au sol sur sa place fixe (PLACES, TENTES), avec collision. Un bâtiment qui apparaît pour la première
## fois tombe du ciel (Partie.premiere_apparition, mémorisé) et finit posé à sa place.
## Interface (calque Interface) : titre, inventaire, jauge du remède, tiroir des constructions, boutons Héros et
## Réglages, et Start quand le héros est près de la voiture de survie : il ouvre la carte. Le héros arrive toujours
## à côté de la voiture. Quand la jauge vient d'être remplie, on passe d'abord par l'écran « Remède trouvé ! ».

const CARTE := preload("res://scenes/carte_construction.tscn")
const BATIMENT := preload("res://scenes/batiment.tscn")

const TAILLE_ICONE := 54.0
## Places fixes du camp (monde) : centre de l'emprise et taille (l'emprise prend ensuite les proportions de l'image).
const PLACES := {
	"abri": [Vector2(900, 560), Vector2(160, 205)],
	"feu": [Vector2(1200, 820), Vector2(200, 200)],
	"jardin": [Vector2(1250, 420), Vector2(200, 200)],
	"atelier": [Vector2(1600, 680), Vector2(200, 200)],
	"barricade": [Vector2(1560, 1120), Vector2(200, 200)],
	"lampe": [Vector2(870, 1060), Vector2(68, 68)],
}
## Tentes des rescapés, groupées dans le coin du fond à droite (centre de l'emprise), une par rescapé sauvé.
const TENTES := [Vector2(1900, 260), Vector2(2170, 260), Vector2(1900, 560), Vector2(2170, 560)]
const TAILLE_TENTE := Vector2(200, 200)
## Image V3 de chaque bâtiment (dessin de secours dans Batiment si elle manque).
const IMAGES := {"abri_1": "base_shelter_1", "abri_2": "base_shelter_2", "feu": "base_campfire",
	"barricade": "base_barricade", "atelier": "base_workshop", "lampe": "base_floodlight", "jardin": "base_garden",
	"tente": "base_tent"}
## Lignes blanches des places de parking (monde) : [début, fin, pas, de, à, le long de x ?]. Une ligne tous les
## « pas » entre début et fin ; elle va de « de » à « à » dans l'autre sens.
const LIGNES := [[160.0, 1600.0, 160.0, 40.0, 280.0, false], [1000.0, 2200.0, 160.0, 1320.0, 1560.0, false],
	[300.0, 940.0, 160.0, 40.0, 280.0, true]]
const LARGEUR_LIGNE := 8.0
## Chute du ciel : attente avant la première, écart entre deux bâtiments (s)
const ATTENTE_CHUTES := 0.3
const ECART_CHUTES := 0.35
## Taille des cartes de construction : grille de COLONNES_CARTES (paysage), en colonne (portrait, coût sur la ligne du nom)
const TAILLE_CARTE := {true: Vector2(400, 130), false: Vector2(680, 112)}
## Bouton du tiroir des constructions : en haut à gauche (paysage), à droite de la jauge (portrait)
const TAILLE_TIROIR := Vector2(260, 100)
## Haut du tiroir : sous l'inventaire (paysage), sous la jauge et le bouton (portrait)
const HAUT_TIROIR := {true: 240.0, false: 352.0}
## Cartes par ligne dans le tiroir : 5 cartes en 3 + 2 (paysage), une colonne (portrait)
const COLONNES_CARTES := {true: 3, false: 1}
const DUREE_TIROIR := 0.2
## Jauge du remède : en bas à droite (paysage), en haut à gauche du bouton Construire (portrait, largeur calculée)
const TAILLE_JAUGE := {true: Vector2(380, 106), false: Vector2(0, 100)}
## Boutons ronds Héros et Réglages ; bouton Start (remplace Partir)
const TAILLE_ROND := Vector2(120, 120)
const TAILLE_START := Vector2(360, 110)

var _pret := false
var _batiments := {}                    # id -> Batiment
var _glissement: Tween                  # ouverture ou fermeture du tiroir en cours
var _tiroir := 0.0:                     # 0 = tiroir fermé, 1 = ouvert
	set(valeur):
		_tiroir = valeur
		_placer_tiroir()

@onready var _ui := $Interface


func _ready() -> void:
	var remede := Partie.annoncer_remede()
	if remede:
		get_tree().change_scene_to_file.call_deferred("res://scenes/remede.tscn")
	# Les débris du sol évitent toutes les places du camp (même celles pas encore construites)
	for place in PLACES.values() + TENTES.map(func(p: Vector2) -> Array: return [p, TAILLE_TENTE]):
		var r := Rect2(place[0] - place[1] / 2.0, place[1])
		for p in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
			_places_objets.append(p)
	for id in _batiments_visibles():
		_ajouter_batiment(id)
	super()
	$Nuit.color = Palette.BASE_LUMIERE * Color(Reglages.BASE_CLARTE, Reglages.BASE_CLARTE, Reglages.BASE_CLARTE, 1.0)
	for calque in [$BrumeSol, $Brouillard, $Vignette]:
		calque.visible = false
	_heros.allumer_lampe(false)
	$HUD.mode_base()
	_preparer_interface()
	if remede:
		return   # les chutes se verront au retour sur la base (sinon elles seraient marquées vues pour rien)
	_preparer_chutes(ATTENTE_CHUTES)
	_pret = true


## Interface de la base : titre, inventaire, jauge, tiroir et cartes, boutons.
func _preparer_interface() -> void:
	var titre: Label = _ui.get_node("Haut/Titre")
	titre.add_theme_color_override("font_color", Palette.LAMPE)
	titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	titre.text = _titre()
	_ui.get_node("Haut").draw.connect(_dessiner_haut)
	_ui.get_node("Haut/Inventaire").draw.connect(_dessiner_inventaire)
	_ui.get_node("Remede").draw.connect(_dessiner_remede)
	_ui.get_node("Constructions").draw.connect(_dessiner_fond_tiroir)
	var start: Control = _ui.get_node("Start")
	start.couleur = Palette.LAMPE
	start.icone = "jouer"
	start.visible = false
	start.appuye.connect(_partir)
	_ui.get_node("Heros").couleur = Palette.UI_BOUTON
	_ui.get_node("Heros").icone = "heros"
	_ui.get_node("Heros").appuye.connect(_changer_heros)
	_ui.get_node("Reglages").couleur = Palette.UI_BOUTON
	_ui.get_node("Reglages").icone = "reglages"
	_ui.get_node("Reglages").appuye.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/parametres.tscn"))
	_ui.get_node("Tiroir").appuye.connect(func() -> void: ouvrir_tiroir(not tiroir_ouvert()))
	for construction in Partie.CONSTRUCTIONS:
		var carte := CARTE.instantiate()
		carte.construction = construction
		carte.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		carte.construire.connect(_construire)
		_ui.get_node("Constructions").add_child(carte)
	get_viewport().size_changed.connect(_placer_interface)
	_placer_interface()
	_actualiser_tiroir()


func _physics_process(delta: float) -> void:
	if not _pret:
		return
	# Un grand bâtiment devant le héros devient transparent : on le voit toujours
	var pieds := Iso.ecran(_heros.global_position)
	for meuble in _meubles:
		if is_instance_valid(meuble):
			meuble.voir_a_travers(pieds, delta)
	_ui.get_node("Start").visible = $Monde/Voiture.distance_a(_heros.global_position) <= Reglages.VOITURE_PORTEE


## Pas de zombie à prévenir ni d'ondes de bruit dans la base.
func _sur_bruit(_origine: Vector2, _rayon: float) -> void:
	pass


## Pas d'objectif dans la base.
func _afficher_objectif() -> void:
	$HUD.afficher_objectif("", 0, 0)


## Geste « retour » d'Android : écran précédent (le titre), comme avant.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file.call_deferred("res://scenes/titre.tscn")   # pas pendant la diffusion de la notification


func _changer_heros() -> void:
	get_tree().change_scene_to_file("res://scenes/choix_heros.tscn")


## Bouton Start de la voiture de survie : la carte.
func _partir() -> void:
	get_tree().change_scene_to_file("res://scenes/carte.tscn")


# --- Camp ---

## Ids des bâtiments du camp, selon la sauvegarde.
func _batiments_visibles() -> Array:
	var ids := ["abri_2" if Partie.constructions.size() >= 2 else "abri_1", "feu"]
	# L'infirmerie n'a pas d'image : rien de plus dans le camp
	for construction in ["barricade", "atelier", "lampe", "jardin"]:
		if Partie.est_construit(construction):
			ids.append(construction)
	for k in mini(Partie.rescapes, TENTES.size()):
		ids.append("tente_%d" % (k + 1))
	return ids


## Pose un bâtiment à sa place (dans le monde ; une fois la base prête, son affichage est ajouté ici).
func _ajouter_batiment(id: String) -> void:
	var batiment := BATIMENT.instantiate()
	batiment.id = id
	var place: Array
	if id.begins_with("tente_"):
		var k := int(id.get_slice("_", 1)) - 1
		place = [TENTES[k], TAILLE_TENTE]
		var persos := Partie.persos_base()
		batiment.rescape = persos[k] if k < persos.size() else "survivor"
		batiment.image = IMAGES["tente"]
	else:
		place = PLACES[id.get_slice("_", 0)]
		batiment.image = IMAGES[id]
	batiment.taille = place[1]
	batiment.position = place[0] + Vector2(0, place[1].y / 2.0)   # milieu du bord bas de l'emprise
	$Monde.add_child(batiment)
	_batiments[id] = batiment
	if _pret:
		var visuels: Dictionary = batiment.visuels()
		$SolEffets.add_child(visuels["sol"])
		$Vue.add_child(visuels["vue"])
		_meubles.append(batiment)


## Bâtiments qui apparaissent pour la première fois : ils tomberont du ciel l'un après l'autre.
func _preparer_chutes(attente: float) -> void:
	for id in _batiments_visibles():
		if Partie.premiere_apparition(id):
			_batiments[id].tomber(attente)
			attente += ECART_CHUTES


## Après une construction : l'abri grandit, la nouvelle construction apparaît aussitôt à sa place (et tombe du ciel).
func _actualiser_camp(attente: float) -> void:
	var ids := _batiments_visibles()
	for id in _batiments.keys():
		if not id in ids:
			_meubles.erase(_batiments[id])
			_batiments[id].queue_free()
			_batiments.erase(id)
	for id in ids:
		if not _batiments.has(id):
			_ajouter_batiment(id)
	_preparer_chutes(attente)


# --- Interface ---

## « La base d'Eliott », « La base de Lou », ou « La base » sans prénom.
func _titre() -> String:
	var prenom := Partie.prenom
	if prenom == "":
		return "La base"
	var voyelle := prenom.left(1).to_lower() in ["a", "e", "i", "o", "u", "y", "h", "é", "è", "ê", "à", "â", "î", "ô", "û"]
	return "La base " + ("d'" if voyelle else "de ") + prenom


## Paysage : Construire en haut à gauche, Héros et Réglages en haut à droite, jauge en bas à droite, Start en bas
## au milieu ; cartes en ligne. Portrait : jauge et Construire sous l'inventaire, Héros et Réglages au-dessus de
## Start en bas à droite (la moitié gauche reste au joystick) ; cartes en colonne.
func _placer_interface() -> void:
	var ecran := get_viewport().get_visible_rect().size
	var paysage := ecran.x > ecran.y
	var tiroir: Control = _ui.get_node("Tiroir")
	var remede: Control = _ui.get_node("Remede")
	tiroir.custom_minimum_size = TAILLE_TIROIR
	tiroir.size = TAILLE_TIROIR
	tiroir.position = Vector2(24, 24) if paysage else Vector2(ecran.x - TAILLE_TIROIR.x - 24, 236)
	remede.size = TAILLE_JAUGE[true] if paysage else Vector2(ecran.x - TAILLE_TIROIR.x - 64, TAILLE_JAUGE[false].y)
	remede.position = Vector2(ecran.x - remede.size.x - 24, ecran.y - remede.size.y - 34) if paysage else Vector2(24, 236)
	for nom in ["Heros", "Reglages", "Start"]:
		var bouton: Control = _ui.get_node(nom)
		bouton.custom_minimum_size = TAILLE_START if nom == "Start" else TAILLE_ROND   # la scène impose 140 x 140
		bouton.size = bouton.custom_minimum_size
	var bas := ecran.y - TAILLE_ROND.y - TAILLE_START.y - 60.0   # haut des boutons ronds en portrait
	_ui.get_node("Reglages").position = Vector2(ecran.x - TAILLE_ROND.x - 24, 24 if paysage else bas)
	_ui.get_node("Heros").position = Vector2(ecran.x - 2.0 * TAILLE_ROND.x - 44, 24 if paysage else bas)
	_ui.get_node("Start").position = Vector2((ecran.x - TAILLE_START.x) / 2.0, ecran.y - TAILLE_START.y - 40) if paysage \
		else Vector2(ecran.x - TAILLE_START.x - 24, ecran.y - TAILLE_START.y - 40)
	var cartes: GridContainer = _ui.get_node("Constructions")
	cartes.columns = COLONNES_CARTES[paysage]
	cartes.add_theme_constant_override("h_separation", 14)
	cartes.add_theme_constant_override("v_separation", 14 if paysage else 10)
	for carte in cartes.get_children():
		carte.custom_minimum_size = TAILLE_CARTE[paysage]
	cartes.size = Vector2.ZERO
	_placer_tiroir()


## Le tiroir glisse depuis son bouton et s'efface en se fermant ; fermé, ses cartes ne captent plus les doigts.
func _placer_tiroir() -> void:
	if not is_node_ready() or not has_node("Interface"):
		return
	var ecran := get_viewport().get_visible_rect().size
	var boite: Control = $Interface/Constructions
	var largeur := boite.get_combined_minimum_size().x
	boite.position = Vector2((ecran.x - largeur) / 2.0, HAUT_TIROIR[ecran.x > ecran.y] - 40.0 * (1.0 - _tiroir))
	boite.modulate.a = _tiroir
	boite.visible = _tiroir > 0.01
	boite.queue_redraw()


## Ouvre ou ferme le tiroir des constructions.
func ouvrir_tiroir(ouvert: bool) -> void:
	if _glissement:
		_glissement.kill()
	_glissement = create_tween()
	_glissement.tween_property(self, "_tiroir", 1.0 if ouvert else 0.0, DUREE_TIROIR)
	_ui.get_node("Tiroir").texte = "Fermer" if ouvert else "Construire"


func tiroir_ouvert() -> bool:
	return _ui.get_node("Tiroir").texte == "Fermer"


## Bouton du tiroir en vert quand une construction est possible.
func _actualiser_tiroir() -> void:
	var possible := false
	for construction in Partie.CONSTRUCTIONS:
		possible = possible or Partie.peut_construire(construction)
	_ui.get_node("Tiroir").couleur = Palette.SORTIE if possible else Palette.UI_BOUTON


## Construction faite : on ferme le tiroir pour la voir tomber du ciel à sa place.
func _construire(construction: String) -> void:
	if not Partie.construire(construction):
		return
	for carte in _ui.get_node("Constructions").get_children():
		carte.actualiser()
	_ui.get_node("Haut/Inventaire").queue_redraw()
	_actualiser_tiroir()
	ouvrir_tiroir(false)
	_actualiser_camp(DUREE_TIROIR)


## Haut de l'écran assombri pour que le titre et l'inventaire ressortent.
func _dessiner_haut() -> void:
	var haut: Control = _ui.get_node("Haut")
	var sombre := Color(Palette.FOND_NUIT, 0.7)
	var clair := Color(Palette.FOND_NUIT, 0.0)
	var y0 := -haut.position.y
	haut.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(haut.size.x, y0), Vector2(haut.size.x, y0 + 240),
		Vector2(0, y0 + 240)]), PackedColorArray([sombre, sombre, clair, clair]))


## Fond du tiroir ouvert, sous les cartes.
func _dessiner_fond_tiroir() -> void:
	var boite: Control = _ui.get_node("Constructions")
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Color(Palette.FOND_NUIT, 0.75)
	cadre.set_corner_radius_all(28)
	boite.draw_style_box(cadre, Rect2(Vector2.ZERO, boite.size).grow(16))


## Cadre de l'inventaire : les 5 types d'objets, chacun avec son nombre (grisé s'il n'y en a pas).
func _dessiner_inventaire() -> void:
	var zone: Control = _ui.get_node("Haut/Inventaire")
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
	var zone: Control = _ui.get_node("Remede")
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


# --- Sol : asphalte et lignes des places, dessinés en code (blocs du Niveau) ---

## Une case d'asphalte par case du monde (taches et fissures tirées avec la graine), puis les lignes des places
## (dessinées après tout l'asphalte, avec les débris).
func _tirer_sol() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	for j in int(taille.y / CASE):
		for i in int(taille.x / CASE):
			var bloc := Vector2i(i, j) / BLOC
			if not _dalles.has(bloc):
				_dalles[bloc] = []
			_dalles[bloc].append(["asphalte", Rect2(Vector2(i, j) * CASE, Vector2(CASE, CASE)), rng.randi()])
	for rangee in LIGNES:
		var k: float = rangee[0]
		while k <= rangee[1]:
			var ligne := Rect2(k - LARGEUR_LIGNE / 2.0, rangee[3], LARGEUR_LIGNE, rangee[4] - rangee[3])
			if rangee[5]:
				ligne = Rect2(rangee[3], k - LARGEUR_LIGNE / 2.0, rangee[4] - rangee[3], LARGEUR_LIGNE)
			var bloc := Vector2i(ligne.get_center() / CASE) / BLOC
			if not _debris.has(bloc):
				_debris[bloc] = []
			_debris[bloc].append(["ligne", ligne, 0])
			k += rangee[2]
	_tirer_debris(rng)


func _dessiner_sol(noeud: Node2D, morceaux: Array) -> void:
	var autres := []
	for morceau in morceaux:
		match morceau[0]:
			"asphalte":
				_dessiner_asphalte(noeud, morceau[1], morceau[2])
			"ligne":
				var c := Iso.coins(morceau[1])
				noeud.draw_colored_polygon(PackedVector2Array([c[0], c[1], c[2], c[3]]), Palette.LIGNE_PARKING)
			_:
				autres.append(morceau)
	super(noeud, autres)


## Case d'asphalte : losange, quelques taches plus sombres et parfois une fissure.
func _dessiner_asphalte(noeud: Node2D, case: Rect2, graine_case: int) -> void:
	var c := Iso.coins(case)
	noeud.draw_colored_polygon(PackedVector2Array([c[3], c[2], c[1], c[0]]), Palette.ASPHALTE)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine_case
	for k in rng.randi() % 3:
		var centre := case.position + Vector2(rng.randf_range(50, CASE - 50), rng.randf_range(50, CASE - 50))
		var rayon := rng.randf_range(18, 45)
		var tache := PackedVector2Array()
		for a in 12:
			tache.append(Iso.ecran(centre + Vector2.from_angle(TAU * a / 12.0) * rayon * Vector2(1.0, rng.randf_range(0.7, 1.0))))
		noeud.draw_colored_polygon(tache, Palette.ASPHALTE_TACHE)
	if rng.randf() < 0.35:
		var p := case.position + Vector2(rng.randf_range(20, CASE - 20), rng.randf_range(20, CASE - 20))
		var fissure := PackedVector2Array([Iso.ecran(p)])
		for k in 3:
			p = (p + Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50))).clamp(case.position + Vector2(10, 10), case.end - Vector2(10, 10))
			fissure.append(Iso.ecran(p))
		noeud.draw_polyline(fissure, Palette.ASPHALTE_FISSURE, 2.5, true)
