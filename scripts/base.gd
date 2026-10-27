extends "res://scripts/niveau.gd"
## La base : un grand parking où le héros marche, avec la même mécanique que les lieux (Niveau : vue isométrique,
## joystick, caméra qui suit, tri en profondeur, collisions), sans zombie et éclairé (pas de nuit noire, lampe
## éteinte, Reglages.BASE_CLARTE). Le camp (Batiment) : abri (base_shelter_2 dès 2 constructions), feu, constructions
## faites (barricades, atelier, projecteur, jardin), une tente par rescapé sauvé (au plus 10) ;
## chacun posé au sol avec collision : abri, feu et tentes sur leur place fixe (PLACES, TENTES), les constructions
## là où le joueur les a posées (Partie.poses_camp). Un bâtiment qui apparaît pour la première fois tombe du ciel
## (Partie.premiere_apparition, mémorisé) et finit posé à sa place.
## Placement libre : « Construire » sur une carte ouvre le mode placement (fantôme vert si la place est libre, rouge
## sinon ; toucher le sol le déplace, glisser fait défiler la vue ; Poser paie et construit, Annuler ne coûte rien).
## Chaque rescapé d'une tente est un personnage (RescapeBase) qui se promène sur le parking et remercie le héros ;
## il apparaît quand sa tente est posée.
## Potager (jardin construit) : un fruit (Fruit) y pousse toutes les Reglages.FRUIT_DELAI secondes, en vrai temps ;
## le héros le cueille en arrivant au bord du potager, il sera mangé à l'arrivée dans le prochain lieu.
## Interface (calque Interface) : titre, inventaire, jauge du remède, tiroir des constructions, boutons Héros et
## Réglages, et Start quand le héros est près de la voiture de survie : il ouvre la carte. Le héros arrive toujours
## à côté de la voiture. Quand la jauge vient d'être remplie, on passe d'abord par l'écran « Remède trouvé ! ».

const CARTE := preload("res://scenes/carte_construction.tscn")
const BATIMENT := preload("res://scenes/batiment.tscn")
const RESCAPE := preload("res://scenes/rescape_base.tscn")
const FRUIT := preload("res://scenes/fruit.tscn")

const TAILLE_ICONE := 54.0
## Places fixes du camp (monde) : centre de l'emprise et taille (l'emprise prend ensuite les proportions de l'image).
const PLACES := {
	"abri": [Vector2(900, 560), Vector2(160, 205)],
	"feu": [Vector2(1200, 820), Vector2(200, 200)],
}
## Taille des constructions posées par le joueur (place d'origine : Partie.PLACES_DEPART)
const TAILLES := {"barricade": Vector2(200, 200), "atelier": Vector2(200, 200), "lampe": Vector2(68, 68),
	"jardin": Vector2(200, 200)}
## Tentes des rescapés, groupées dans le coin de droite (centre de l'emprise), une par rescapé sauvé : 2 colonnes
## de 5, de l'arrière vers l'avant (au-delà de 10 rescapés, pas de tente ni de personnage de plus).
const TENTES := [Vector2(1900, 240), Vector2(2170, 240), Vector2(1900, 490), Vector2(2170, 490), Vector2(1900, 740),
	Vector2(2170, 740), Vector2(1900, 990), Vector2(2170, 990), Vector2(1900, 1240), Vector2(2170, 1240)]
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
## Mode placement : boutons Poser et Annuler, distance du fantôme devant le héros (monde, en plus de sa demi-taille),
## glissement au-delà duquel le doigt fait défiler la vue au lieu de déplacer le fantôme (pixels)
const TAILLE_POSER := Vector2(280, 110)
const DEVANT_HEROS := 60.0
const SEUIL_GLISSE := 20.0
## Couleurs du fantôme : place libre, place refusée
const FANTOME_LIBRE := Color(0.55, 1.0, 0.55, 0.75)
const FANTOME_REFUSE := Color(1.0, 0.4, 0.4, 0.75)
## Le parking (dans les murets), la marge autour du héros, la case de la grille du chemin héros -> voiture (monde)
const MARGE_PARKING := 40.0
const RAYON_HEROS := 18.0
const CASE_CHEMIN := 25.0
## Place gardée libre autour de l'arrivée du héros (à côté de la voiture), monde
const ARRIVEE := Vector2(140, 140)
## Fruit du potager : point de base_garden où la pomme est posée (terre entre les plants, pixels de l'image) ;
## distance au bord du potager pour lire quand pousse le prochain (monde) ; texte « Fruit cueilli » pendant (s)
const POMME_IMAGE := Vector2(250, 232)
const PRES_POTAGER := 160.0
const DUREE_MESSAGE_FRUIT := 3.0
## Raisons d'un refus (fantôme rouge)
const RAISONS := {"parking": "Hors du parking", "obstacle": "Il y a déjà quelque chose ici", "heros": "Trop près du héros",
	"chemin": "Le héros serait enfermé"}

var _pret := false
var _batiments := {}                    # id -> Batiment
var _arrivee := Vector2.ZERO            # où le héros arrive (gardé libre)
var _placement := ""                    # construction en cours de placement ("" : pas de placement)
var _fantome: StaticBody2D = null       # bâtiment fantôme (sans collision)
var _centre_fantome := Vector2.ZERO     # centre demandé de son emprise (monde)
var _raison := ""                       # pourquoi la place est refusée ("" : libre), clé de RAISONS
var _zone := Node2D.new()               # emprise du fantôme au sol, verte ou rouge (calque Reperes)
var _doigt := -1                        # doigt posé sur le sol pendant le placement
var _glisse := 0.0                      # chemin parcouru par ce doigt (pixels)
var _rescapes := {}                     # id de la tente -> RescapeBase
var _fruit: Node2D = FRUIT.instantiate()   # fruit du potager (caché sans jardin)
var _message_fruit := 0.0               # temps restant du texte « Fruit cueilli »
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
	_arrivee = _heros.position
	# Les débris du sol évitent toutes les places du camp (même celles pas encore construites ; places d'origine
	# des constructions : le sol reste le même qu'à l'étape a)
	var places_fixes: Array = PLACES.values() + TENTES.map(func(p: Vector2) -> Array: return [p, TAILLE_TENTE])
	for nom in TAILLES:
		places_fixes.append([Partie.PLACES_DEPART[nom], TAILLES[nom]])
	for place in places_fixes:
		var r := Rect2(place[0] - place[1] / 2.0, place[1])
		for p in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
			_places_objets.append(p)
	var camp := _camp()
	for id in camp:
		_ajouter_batiment(id, camp[id])
	$Monde.add_child(_fruit)
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
	var poser: Control = _ui.get_node("Poser")
	poser.couleur = Palette.SORTIE
	poser.appuye.connect(poser_construction)
	_ui.get_node("Annuler").couleur = Palette.UI_BOUTON
	_ui.get_node("Annuler").appuye.connect(annuler_placement)
	var consigne: Label = _ui.get_node("Consigne")
	consigne.add_theme_color_override("font_color", Palette.LAMPE)
	consigne.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	_zone.draw.connect(_dessiner_zone)
	$Reperes.add_child(_zone)
	_montrer_placement(false)
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
	_ui.get_node("Start").visible = _placement == "" and $Monde/Voiture.distance_a(_heros.global_position) <= Reglages.VOITURE_PORTEE
	# Les rescapés : chacun apparaît une fois sa tente posée
	for id in _rescapes:
		_rescapes[id].actif = _batiments[id].pose()
		_rescapes[id].connaitre_heros(_heros.global_position)
	_actualiser_fruit(delta)


## Fruit du potager : la pomme est sur le potager posé quand le fruit est prêt ; le héros la cueille en arrivant
## au bord (Reglages.OBJET_PORTEE, comme un objet), s'il n'a pas déjà un fruit en réserve. Près du potager, un
## petit texte dit dans combien de temps pousse le prochain.
func _actualiser_fruit(delta: float) -> void:
	_message_fruit = maxf(_message_fruit - delta, 0.0)
	var potager: StaticBody2D = _batiments.get("jardin")
	var texte := ""
	_fruit.pret = false
	if potager and potager.pose() and _placement == "":
		var e: Rect2 = potager.emprise()
		_fruit.position = e.end   # coin avant : la pomme passe devant le potager
		_fruit.sommet = potager.point_ecran(POMME_IMAGE) if Images.existe(potager.image) else Iso.ecran(e.get_center()) + Vector2(0, -60)
		var pieds: Vector2 = _heros.global_position
		var distance := pieds.distance_to(pieds.clamp(e.position, e.end))
		if Partie.fruit_pret():
			_fruit.pret = true
			if distance <= Reglages.OBJET_PORTEE and Partie.cueillir_fruit():
				_fruit.cueillir()
				_message_fruit = DUREE_MESSAGE_FRUIT
			elif distance <= PRES_POTAGER and Partie.fruit:
				texte = "Tu as déjà un fruit pour le prochain lieu"
		elif distance <= PRES_POTAGER:
			texte = "Prochain fruit dans " + texte_duree(Partie.secondes_avant_fruit())
		if _message_fruit > 0.0:
			texte = "Fruit cueilli : plus rapide au prochain niveau !"
	_fruit.texte = texte


## « 2 h 14 » (heures et minutes, minutes arrondies au-dessus), « 5 min » sous une heure.
static func texte_duree(secondes: float) -> String:
	var minutes := ceili(secondes / 60.0)
	if minutes < 60:
		return "%d min" % maxi(minutes, 1)
	return "%d h %02d" % [minutes / 60, minutes % 60]


## Envoie tous les rescapés devant leur tente et les y garde (attaque de la base, étape h), ou les libère.
func rescapes_aux_tentes(oui: bool) -> void:
	for rescape in _rescapes.values():
		if oui:
			rescape.aller_devant_tente()
		else:
			rescape.liberer()


## Pas de zombie à prévenir ni d'ondes de bruit dans la base.
func _sur_bruit(_origine: Vector2, _rayon: float) -> void:
	pass


## Le fruit cueilli se garde pour le prochain lieu (il n'est pas mangé dans la base).
func _manger_fruit() -> void:
	pass


## Pas d'objectif dans la base.
func _afficher_objectif() -> void:
	$HUD.afficher_objectif("", 0, 0)


## Geste « retour » d'Android : annule le placement en cours, sinon écran précédent (le titre), comme avant.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _placement != "":
			annuler_placement.call_deferred()
		else:
			get_tree().change_scene_to_file.call_deferred("res://scenes/titre.tscn")   # pas pendant la diffusion de la notification


func _changer_heros() -> void:
	get_tree().change_scene_to_file("res://scenes/choix_heros.tscn")


## Bouton Start de la voiture de survie : la carte.
func _partir() -> void:
	get_tree().change_scene_to_file("res://scenes/carte.tscn")


# --- Camp ---

## Ids des bâtiments du camp, selon la sauvegarde.
func _batiments_visibles() -> Array:
	return _camp().keys()


## Bâtiments du camp, selon la sauvegarde : id -> [image, centre de l'emprise, taille, rescapé devant].
## Ids : abri_1 / abri_2, feu, barricade, barricade_2..., atelier, lampe, jardin, tente_1... (l'infirmerie n'a pas
## d'image : rien de plus dans le camp).
func _camp() -> Dictionary:
	var camp := {}
	var abri := "abri_2" if Partie.constructions.size() >= 2 else "abri_1"
	camp[abri] = [IMAGES[abri], PLACES["abri"][0], PLACES["abri"][1], ""]
	camp["feu"] = [IMAGES["feu"], PLACES["feu"][0], PLACES["feu"][1], ""]
	var nombres := {}
	for pose in Partie.poses_camp():
		var nom: String = pose[0]
		nombres[nom] = nombres.get(nom, 0) + 1
		var id := nom if nombres[nom] == 1 else "%s_%d" % [nom, nombres[nom]]
		camp[id] = [IMAGES[nom], pose[1], TAILLES[nom], ""]
	var persos := Partie.persos_base()
	for k in mini(Partie.rescapes, TENTES.size()):
		camp["tente_%d" % (k + 1)] = [IMAGES["tente"], TENTES[k], TAILLE_TENTE, persos[k] if k < persos.size() else "survivor"]
	return camp


## Bâtiment posé sur son emprise (centre, taille avant d'en prendre les proportions de l'image), dans le monde.
func _creer_batiment(id: String, image: String, centre: Vector2, taille_batiment: Vector2) -> StaticBody2D:
	var batiment := BATIMENT.instantiate()
	batiment.id = id
	batiment.image = image
	batiment.taille = taille_batiment
	batiment.position = centre + Vector2(0, taille_batiment.y / 2.0)   # milieu du bord bas de l'emprise
	return batiment


## Pose un bâtiment à sa place (dans le monde ; une fois la base prête, son affichage est ajouté ici).
## infos : [image, centre, taille, rescapé] (voir _camp) ; une tente amène son rescapé (RescapeBase).
func _ajouter_batiment(id: String, infos: Array) -> void:
	var batiment := _creer_batiment(id, infos[0], infos[1], infos[2])
	$Monde.add_child(batiment)
	_batiments[id] = batiment
	if _pret:
		var visuels: Dictionary = batiment.visuels()
		$SolEffets.add_child(visuels["sol"])
		$Vue.add_child(visuels["vue"])
		_meubles.append(batiment)
	if infos[3] != "":
		_ajouter_rescape(id, batiment, infos[3])


## Le rescapé d'une tente (perso : Partie.persos_base, dans l'ordre des tentes), devant elle.
func _ajouter_rescape(id: String, tente: Node2D, perso: String) -> void:
	var rescape := RESCAPE.instantiate()
	rescape.perso = perso
	rescape.parking = Rect2(Vector2.ZERO, taille)
	rescape.tente = tente.devant()
	rescape.position = rescape.tente
	rescape.actif = false
	$Monde.add_child(rescape)
	_rescapes[id] = rescape
	if _pret:
		$Vue.add_child(rescape.visuels()["vue"])


## Bâtiments qui apparaissent pour la première fois : ils tomberont du ciel l'un après l'autre.
func _preparer_chutes(attente: float) -> void:
	for id in _batiments_visibles():
		if Partie.premiere_apparition(id):
			_batiments[id].tomber(attente)
			attente += ECART_CHUTES


## Après une construction : l'abri grandit, la nouvelle construction apparaît aussitôt à sa place (et tombe du ciel).
func _actualiser_camp(attente: float) -> void:
	var camp := _camp()
	for id in _batiments.keys():
		if not camp.has(id):
			_meubles.erase(_batiments[id])
			_batiments[id].queue_free()
			_batiments.erase(id)
			if _rescapes.has(id):
				_rescapes[id].queue_free()
				_rescapes.erase(id)
	for id in camp:
		if not _batiments.has(id):
			_ajouter_batiment(id, camp[id])
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
	for nom in ["Poser", "Annuler"]:
		var bouton: Control = _ui.get_node(nom)
		bouton.custom_minimum_size = TAILLE_POSER
		bouton.size = TAILLE_POSER
		bouton.position = Vector2(ecran.x / 2.0 + (15.0 if nom == "Poser" else -15.0 - TAILLE_POSER.x), ecran.y - TAILLE_POSER.y - 40)
	var consigne: Label = _ui.get_node("Consigne")
	consigne.size = Vector2(ecran.x - 48, 60)
	consigne.position = Vector2(24, ecran.y - TAILLE_POSER.y - 120)
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


## « Construire » sur une carte : le tiroir se ferme ; une construction avec un bâtiment passe par le placement
## (rien n'est payé avant « Poser »), les autres (infirmerie) sont faites aussitôt.
func _construire(construction: String) -> void:
	if not Partie.peut_construire(construction):
		return
	ouvrir_tiroir(false)
	if TAILLES.has(construction):
		commencer_placement(construction)
	elif Partie.construire(construction):
		_apres_construction(DUREE_TIROIR)


## Construction payée : cartes, inventaire et bouton du tiroir à jour, elle apparaît (et tombe du ciel).
func _apres_construction(attente: float) -> void:
	for carte in _ui.get_node("Constructions").get_children():
		carte.actualiser()
	_ui.get_node("Haut/Inventaire").queue_redraw()
	_actualiser_tiroir()
	_actualiser_camp(attente)


# --- Placement libre des constructions ---

## Mode placement : le fantôme apparaît devant le héros (ou à la place libre la plus proche), le joystick est
## coupé (le héros s'arrête) ; Poser et Annuler remplacent les autres boutons.
func commencer_placement(construction: String) -> void:
	_placement = construction
	$HUD.relacher()
	_heros.definir_direction(Vector2.ZERO)
	_montrer_placement(true)
	var devant: Vector2 = _heros.global_position + _heros.regard() * (RAYON_HEROS + DEVANT_HEROS + TAILLES[construction].length() / 2.0)
	placer_fantome(_place_libre_pres(devant))


## Poser : paie, sauvegarde la position, le bâtiment tombe du ciel à cet endroit. Rien si la place est refusée.
func poser_construction() -> void:
	if _placement == "" or _raison != "":
		return
	var construction := _placement
	var centre := _centre_fantome
	_finir_placement()
	if Partie.construire(construction, centre):
		_apres_construction(0.0)


## Annuler : rien n'est payé ni construit.
func annuler_placement() -> void:
	if _placement != "":
		_finir_placement()


func en_placement() -> bool:
	return _placement != ""


## Pourquoi la place du fantôme est refusée ("" : libre ; sinon clé de RAISONS).
func raison_refus() -> String:
	return _raison


func _finir_placement() -> void:
	_placement = ""
	_doigt = -1
	_enlever_fantome()
	_heros.decalage_camera = Vector2.ZERO
	_montrer_placement(false)


## Pendant le placement : Poser, Annuler et la consigne ; sinon tiroir, jauge, Héros, Réglages (Start selon la
## voiture) et joystick.
func _montrer_placement(placement: bool) -> void:
	for nom in ["Poser", "Annuler", "Consigne"]:
		_ui.get_node(nom).visible = placement
	for nom in ["Tiroir", "Remede", "Heros", "Reglages"]:
		_ui.get_node(nom).visible = not placement
	if placement:
		_ui.get_node("Start").visible = false
	$HUD.get_node("Joystick").visible = not placement
	$HUD.get_node("Joystick").set_process_input(not placement)
	_zone.visible = placement


## Place le fantôme de la construction en cours, centré sur `centre` (monde), vert si la place est libre.
func placer_fantome(centre: Vector2) -> void:
	_enlever_fantome()
	centre = centre.round()
	_centre_fantome = centre
	_fantome = _creer_batiment(_placement, IMAGES[_placement], centre, TAILLES[_placement])
	_fantome.collision_layer = 0   # un fantôme ne bloque personne
	_fantome.collision_mask = 0
	$Monde.add_child(_fantome)
	var visuels: Dictionary = _fantome.visuels()
	$Vue.add_child(visuels["vue"])
	_raison = _verifier_place(_fantome.emprise())
	visuels["vue"].modulate = FANTOME_LIBRE if _raison == "" else FANTOME_REFUSE
	visuels["sol"].visible = false   # pas d'ombre ni de lueur sous un fantôme
	$SolEffets.add_child(visuels["sol"])
	_ui.get_node("Poser").actif = _raison == ""
	_ui.get_node("Consigne").text = "Touche le sol pour choisir la place" if _raison == "" else RAISONS[_raison]
	_zone.queue_redraw()


func _enlever_fantome() -> void:
	if _fantome:
		_fantome.queue_free()   # emporte son affichage (Batiment._exit_tree)
		_fantome = null


## Pendant le placement : un doigt posé puis levé sans glisser déplace le fantôme à cet endroit du sol ;
## s'il glisse, il fait défiler la vue. Les boutons (Poser, Annuler) passent avant.
func _input(event: InputEvent) -> void:
	if _placement == "":
		return
	if event is InputEventScreenTouch:
		if event.pressed and _doigt == -1:
			_doigt = event.index
			_glisse = 0.0
		elif not event.pressed and event.index == _doigt:
			_doigt = -1
			if _glisse < SEUIL_GLISSE:
				placer_fantome(Iso.monde(get_canvas_transform().affine_inverse() * event.position))
	elif event is InputEventScreenDrag and event.index == _doigt:
		_glisse += event.relative.length()
		if _glisse >= SEUIL_GLISSE:
			_faire_defiler(-event.relative)


## Fait défiler la vue (décalage de la caméra du héros), sans sortir des limites de la caméra.
func _faire_defiler(deplacement: Vector2) -> void:
	var camera: Camera2D = _heros.get_node("Camera2D")
	var moitie := get_viewport().get_visible_rect().size / 2.0
	var mini_ := Vector2(camera.limit_left, camera.limit_top) + moitie
	var maxi_ := Vector2(camera.limit_right, camera.limit_bottom) - moitie
	var vise: Vector2 = _heros.vise_camera()
	var cible: Vector2 = vise + _heros.decalage_camera + deplacement
	cible = Vector2(clampf(cible.x, mini_.x, maxf(mini_.x, maxi_.x)), clampf(cible.y, mini_.y, maxf(mini_.y, maxi_.y)))
	_heros.decalage_camera = cible - vise


## Emprise du fantôme au sol, verte ou rouge.
func _dessiner_zone() -> void:
	if _fantome == null:
		return
	var c := Iso.coins(_fantome.emprise())
	var libre := _raison == ""
	var couleur := Palette.SORTIE if libre else Palette.COEUR
	var losange := PackedVector2Array([c[0], c[1], c[2], c[3]])
	_zone.draw_colored_polygon(losange, Color(couleur, 0.3))
	losange.append(c[0])
	_zone.draw_polyline(losange, couleur, 4.0, true)


## Obstacles du parking (bâtiments, voitures, blocs, murets) : leurs emprises, sans le fantôme.
func _obstacles() -> Array:
	var liste := []
	for noeud in $Monde.get_children():
		if noeud is StaticBody2D and noeud != _fantome and noeud.has_method("emprise") and not noeud.is_queued_for_deletion():
			liste.append(noeud.emprise())
	return liste


## Places gardées libres même vides : abri (grand abri compris), feu, toutes les tentes, arrivée du héros.
func _reservees() -> Array:
	var liste := []
	for place in PLACES.values():
		liste.append(Rect2(place[0] - place[1] / 2.0, place[1]))
	for tente in TENTES:
		liste.append(Rect2(tente - TAILLE_TENTE / 2.0, TAILLE_TENTE))
	liste.append(Rect2(_arrivee - ARRIVEE / 2.0, ARRIVEE))
	return liste


## "" si une construction peut être posée sur cette emprise, sinon la raison du refus (clé de RAISONS).
func _verifier_place(emprise: Rect2) -> String:
	var parking := Rect2(Vector2.ONE * MARGE_PARKING, taille - Vector2.ONE * 2.0 * MARGE_PARKING)
	if not parking.encloses(emprise):
		return "parking"
	for autre: Rect2 in _obstacles() + _reservees():
		if autre.intersects(emprise):
			return "obstacle"
	if emprise.grow(RAYON_HEROS).has_point(_heros.global_position):
		return "heros"
	if not chemin_vers_voiture(emprise):
		return "chemin"
	return ""


## Le héros peut-il encore aller jusqu'à la voiture (bouton Start) si `en_plus` est construit ? Grille grossière
## du parking (CASE_CHEMIN) : une case est bloquée si un héros en son centre toucherait un obstacle.
func chemin_vers_voiture(en_plus := Rect2()) -> bool:
	var n := Vector2i((taille / CASE_CHEMIN).ceil())
	var bloquees := PackedByteArray()
	bloquees.resize(n.x * n.y)
	var obstacles := _obstacles()
	if en_plus.has_area():
		obstacles.append(en_plus)
	for r: Rect2 in obstacles:
		var g := r.grow(RAYON_HEROS)
		var debut := Vector2i(((g.position / CASE_CHEMIN) - Vector2(0.5, 0.5)).ceil()).clamp(Vector2i.ZERO, n - Vector2i.ONE)
		var fin := Vector2i(((g.end / CASE_CHEMIN) - Vector2(0.5, 0.5)).floor()).clamp(Vector2i.ZERO, n - Vector2i.ONE)
		for j in range(debut.y, fin.y + 1):
			for i in range(debut.x, fin.x + 1):
				bloquees[j * n.x + i] = 1
	# Départ : la case libre la plus proche du héros
	var depart := -1
	var proche := INF
	var case_heros := Vector2i(_heros.global_position / CASE_CHEMIN)
	for j in range(case_heros.y - 3, case_heros.y + 4):
		for i in range(case_heros.x - 3, case_heros.x + 4):
			if i >= 0 and j >= 0 and i < n.x and j < n.y and bloquees[j * n.x + i] == 0:
				var d := (Vector2(i, j) + Vector2(0.5, 0.5)).distance_to(_heros.global_position / CASE_CHEMIN)
				if d < proche:
					proche = d
					depart = j * n.x + i
	if depart == -1:
		return false
	var voiture = $Monde/Voiture
	var vues := PackedByteArray()
	vues.resize(n.x * n.y)
	vues[depart] = 1
	var file := [depart]
	while not file.is_empty():
		var k: int = file.pop_back()
		var centre := (Vector2(k % n.x, k / n.x) + Vector2(0.5, 0.5)) * CASE_CHEMIN
		if voiture.distance_a(centre) <= Reglages.VOITURE_PORTEE:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = Vector2i(k % n.x, k / n.x) + d
			if v.x >= 0 and v.y >= 0 and v.x < n.x and v.y < n.y and vues[v.y * n.x + v.x] == 0 and bloquees[v.y * n.x + v.x] == 0:
				vues[v.y * n.x + v.x] = 1
				file.append(v.y * n.x + v.x)
	return false


## La place libre la plus proche de `centre` (des cercles de plus en plus grands autour du héros, en commençant
## devant lui) ; `centre` s'il n'y en a aucune (le fantôme sera rouge).
func _place_libre_pres(centre: Vector2) -> Vector2:
	var taille_fantome: Vector2 = TAILLES[_placement]
	if Images.existe(IMAGES[_placement]):
		taille_fantome = Iso.taille_image(IMAGES[_placement], taille_fantome)[0]
	var ecart: Vector2 = centre - _heros.global_position
	for rayon in [ecart.length(), ecart.length() + 100.0, ecart.length() + 200.0, ecart.length() + 350.0, ecart.length() + 500.0]:
		for k in 16:
			var angle: float = ecart.angle() + ceili(k / 2.0) * (1 if k % 2 == 0 else -1) * TAU / 16.0
			var essai: Vector2 = _heros.global_position + Vector2.from_angle(angle) * rayon
			# Même emprise que celle du bâtiment posé là (_creer_batiment, puis proportions de l'image)
			var bas: float = essai.y + TAILLES[_placement].y / 2.0
			if _verifier_place(Rect2(essai.x - taille_fantome.x / 2.0, bas - taille_fantome.y, taille_fantome.x, taille_fantome.y)) == "":
				return essai
	return centre


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
