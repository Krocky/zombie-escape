extends Control
class_name EcranParties
## Écran des parties sauvegardées (lot 4 d), deux modes :
## - « liste » (« Mes parties », depuis le titre ou le menu Partie de la base) : une ligne par partie (nom, héros,
##   rescapés, date) ; toucher une ligne charge la partie (celle en cours est d'abord sauvegardée) ; « Effacer » sur
##   chaque ligne, après « Effacer <nom> ? » (Oui / Non), grisé pour la partie en cours. La liste défile au doigt :
##   comme la carte, un doigt qui glisse fait défiler, un doigt levé sans glisser touche.
## - « nouvelle » (menu Partie de la base) : le nom (champ en haut, visible au-dessus du clavier), « Créer »,
##   puis « Êtes-vous sûr ? » (Oui : nouvelle partie vide, puis le choix du héros).
## Retour (et geste « retour » d'Android) : écran précédent sans rien changer.

## Mode et écran d'origine, donnés par ouvrir() avant de changer de scène.
static var mode := "liste"
static var depuis_base := false

const HAUTEUR_LIGNE := 140.0
const ECART_LIGNE := 16.0
const LARGEUR_MAX := 900.0
const TAILLE_EFFACER := Vector2(180, 100)
const SEUIL_GLISSE := 20.0
const PROFONDEUR := 8.0         # épaisseur du bouton Effacer dessiné (comme BoutonTactile)

var _ids := []                  # parties de la liste, dans l'ordre affiché
var _infos := {}                # id -> Partie.infos_partie(id)
var _defilement := 0.0          # pixels de liste cachés au-dessus
var _doigt := -1
var _appui := Vector2.ZERO
var _glisse := 0.0
var _a_effacer := ""            # partie dont on demande l'effacement ("" : confirmation de la nouvelle partie)


## Ouvre l'écran dans un mode (« liste » ou « nouvelle ») ; base : ouvert depuis la base (sinon depuis le titre).
static func ouvrir(arbre: SceneTree, nouveau_mode: String, base: bool) -> void:
	mode = nouveau_mode
	depuis_base = base
	arbre.change_scene_to_file("res://scenes/parties.tscn")


func _ready() -> void:
	for label in [$Titre, $Etiquette, $Confirmation/Question]:
		label.add_theme_color_override("font_color", Palette.LAMPE)
		label.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Etiquette.add_theme_color_override("font_color", Palette.UI_TEXTE)
	var champ: LineEdit = $Nom
	champ.max_length = Partie.NOM_PARTIE_MAX
	champ.placeholder_text = Partie.nom_libre()
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.LAMPE
	cadre.set_border_width_all(5)
	cadre.set_corner_radius_all(20)
	champ.add_theme_stylebox_override("normal", cadre)
	champ.add_theme_stylebox_override("focus", cadre)
	champ.add_theme_color_override("font_color", Palette.UI_TEXTE)
	champ.add_theme_color_override("font_placeholder_color", Palette.UI_BORD * Color(1, 1, 1, 0.6))
	champ.text_submitted.connect(func(_t: String) -> void: champ.release_focus())
	$Creer.couleur = Palette.LAMPE
	$Creer.appuye.connect(_demander_creation)
	$Retour.couleur = Palette.UI_BOUTON
	$Retour.appuye.connect(_retour)
	$Confirmation/Oui.couleur = Palette.SORTIE
	$Confirmation/Oui.appuye.connect(_oui)
	$Confirmation/Non.couleur = Palette.UI_BOUTON
	$Confirmation/Non.appuye.connect(_fermer_confirmation)
	$Confirmation.draw.connect(func() -> void: $Confirmation.draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.CONTOUR, 0.8)))
	$Liste.draw.connect(_dessiner_liste)
	var liste := mode == "liste"
	$Titre.text = "Mes parties" if liste else "Nouvelle partie"
	for noeud in [$Etiquette, $Nom, $Creer]:
		noeud.visible = not liste
	$Liste.visible = liste
	_lire_parties()
	resized.connect(_placer)
	_placer()


func _lire_parties() -> void:
	_ids = Partie.parties.map(func(e: Dictionary) -> String: return e["id"])
	_infos = {}
	for id in _ids:
		_infos[id] = Partie.infos_partie(id)


## Titre en haut, Retour en bas à gauche ; liste entre les deux, ou nom + Créer sous le titre.
func _placer() -> void:
	var paysage := size.x > size.y
	$Retour.size = Vector2(260, 104)
	$Creer.size = Vector2(360, 110)
	for nom in ["Confirmation/Oui", "Confirmation/Non"]:
		get_node(nom).size = Vector2(240, 110)
	for bouton in [$Retour, $Creer, $Confirmation/Oui, $Confirmation/Non]:
		bouton.custom_minimum_size = bouton.size   # la scène impose 140 x 140
	$Retour.position = Vector2(24, size.y - $Retour.size.y - (24.0 if paysage else 60.0))
	var haut := 120.0
	$Liste.position = Vector2(24, haut)
	$Liste.size = Vector2(size.x - 48, $Retour.position.y - 20.0 - haut)
	var y_nom := 130.0 if paysage else 170.0
	var largeur_ligne: float = $Etiquette.size.x + 20.0 + $Nom.size.x
	$Etiquette.position = Vector2((size.x - largeur_ligne) / 2.0, y_nom)
	$Nom.position = Vector2($Etiquette.position.x + $Etiquette.size.x + 20.0, y_nom)
	$Creer.position = Vector2((size.x - $Creer.size.x) / 2.0, y_nom + 130.0)
	var question: Label = $Confirmation/Question
	question.size = Vector2(minf(size.x - 48, 900), 120)
	question.position = Vector2((size.x - question.size.x) / 2.0, size.y / 2.0 - 150.0)
	$Confirmation/Non.position = Vector2(size.x / 2.0 - 20.0 - 240.0, size.y / 2.0 + 10.0)
	$Confirmation/Oui.position = Vector2(size.x / 2.0 + 20.0, size.y / 2.0 + 10.0)
	_borner()
	queue_redraw()


# --- Liste ---

func _largeur_ligne() -> float:
	return minf($Liste.size.x, LARGEUR_MAX)


## Rectangle d'une ligne, dans la liste (défilement compris).
func ligne(k: int) -> Rect2:
	var largeur := _largeur_ligne()
	return Rect2(($Liste.size.x - largeur) / 2.0, k * (HAUTEUR_LIGNE + ECART_LIGNE) - _defilement, largeur, HAUTEUR_LIGNE)


## Bouton « Effacer » d'une ligne, dans la liste.
func bouton_effacer(k: int) -> Rect2:
	var r := ligne(k)
	return Rect2(r.end.x - TAILLE_EFFACER.x - 20.0, r.position.y + (r.size.y - TAILLE_EFFACER.y) / 2.0, TAILLE_EFFACER.x, TAILLE_EFFACER.y)


## Position à l'écran du milieu d'une ligne, ou de son bouton Effacer (tests).
func centre_ligne(id: String, effacer := false) -> Vector2:
	var k := _ids.find(id)
	return $Liste.global_position + (bouton_effacer(k) if effacer else ligne(k)).get_center()


func _borner() -> void:
	var contenu := _ids.size() * (HAUTEUR_LIGNE + ECART_LIGNE) - ECART_LIGNE
	_defilement = clampf(_defilement, 0.0, maxf(0.0, contenu - $Liste.size.y))
	$Liste.queue_redraw()


## Un doigt posé puis levé sans glisser touche une ligne ; s'il glisse, il fait défiler la liste.
func _input(event: InputEvent) -> void:
	if mode != "liste" or $Confirmation.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _doigt != -1 or not $Liste.get_global_rect().has_point(event.position):
				return
			_doigt = event.index
			_appui = event.position
			_glisse = 0.0
		elif event.index == _doigt:
			_doigt = -1
			if _glisse < SEUIL_GLISSE:
				_toucher(_appui - $Liste.global_position)
	elif event is InputEventScreenDrag and event.index == _doigt:
		_glisse += event.relative.length()
		if _glisse >= SEUIL_GLISSE:
			_defilement -= event.relative.y
			_borner()


func _toucher(p: Vector2) -> void:
	for k in _ids.size():
		var id: String = _ids[k]
		if bouton_effacer(k).has_point(p):
			if id != Partie.en_cours:
				_a_effacer = id
				_ouvrir_confirmation("Effacer %s ?" % _infos[id]["nom"])
			return
		if ligne(k).has_point(p):
			_charger(id)
			return


## Charge la partie touchée (celle en cours est sauvegardée), puis la base, ou le choix du héros s'il n'est pas fait.
func _charger(id: String) -> void:
	Partie.charger_partie(id)
	get_tree().change_scene_to_file.call_deferred("res://scenes/base.tscn" if Partie.skin != "" else "res://scenes/choix_heros.tscn")   # pas pendant la diffusion du toucher


func _dessiner_liste() -> void:
	var zone: Control = $Liste
	for k in _ids.size():
		var r := ligne(k)
		if r.end.y < 0.0 or r.position.y > zone.size.y:
			continue
		var id: String = _ids[k]
		var infos: Dictionary = _infos[id]
		var en_cours := id == Partie.en_cours
		var cadre := StyleBoxFlat.new()
		cadre.bg_color = Palette.UI_CADRE
		cadre.border_color = Palette.LAMPE if en_cours else Palette.CONTOUR
		cadre.set_border_width_all(7 if en_cours else 5)
		cadre.set_corner_radius_all(26)
		zone.draw_style_box(cadre, r)
		# Le héros de la partie (petit, debout), ou un « ? » s'il n'est pas encore choisi
		var pieds := r.position + Vector2(60, r.size.y - 18)
		var skin: String = infos["skin"]
		if Partie.SKINS.has(skin) and Images.v3_existe(Images.v3_pose(skin, "idle")):
			var nom_image := Images.v3_pose(skin, "idle")
			Images.v3_dessiner(zone, nom_image, pieds, (r.size.y - 30.0) / Images.v3_taille(nom_image).y)
		else:
			_texte(zone, "?", pieds + Vector2(-14, -36), 56, Palette.UI_BORD)
		var x := r.position.x + 120.0
		var largeur_texte := bouton_effacer(k).position.x - x - 12.0
		_texte(zone, infos["nom"], Vector2(x, r.position.y + 46), 38, Palette.LAMPE, largeur_texte)
		var heros: String = infos["prenom"] if infos["prenom"] != "" else (Partie.SKINS.get(skin, "?"))
		_texte(zone, "Héros : %s   Rescapés : %d" % [heros, infos["rescapes"]], Vector2(x, r.position.y + 86), 26,
			Palette.UI_TEXTE, largeur_texte)
		var date: String = Partie.texte_date(infos["date"])
		_texte(zone, ("En cours   " if en_cours else "") + date, Vector2(x, r.position.y + 120), 24,
			Palette.SORTIE if en_cours else Palette.UI_BORD, largeur_texte)
		_dessiner_effacer(zone, bouton_effacer(k), not en_cours)


## Bouton « Effacer » dessiné (comme une pilule de BoutonTactile), grisé pour la partie en cours.
func _dessiner_effacer(zone: Control, r: Rect2, actif: bool) -> void:
	var fond := Palette.DEGATS if actif else Palette.UI_FOND
	fond.a = 1.0 if actif else fond.a
	var socle := StyleBoxFlat.new()
	socle.bg_color = fond.darkened(0.45)
	socle.border_color = Palette.CONTOUR
	socle.set_border_width_all(5)
	socle.set_corner_radius_all(int((r.size.y - PROFONDEUR) / 2.0))
	zone.draw_style_box(socle, Rect2(r.position + Vector2(0, PROFONDEUR), r.size - Vector2(0, PROFONDEUR)))
	var dessus := socle.duplicate()
	dessus.bg_color = fond
	zone.draw_style_box(dessus, Rect2(r.position, r.size - Vector2(0, PROFONDEUR)))
	var couleur := Palette.UI_TEXTE if actif else Palette.UI_BORD * Color(1, 1, 1, 0.6)
	var police := ThemeDB.fallback_font
	var largeur := police.get_string_size("Effacer", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	_texte(zone, "Effacer", Vector2(r.get_center().x - largeur / 2.0, r.get_center().y + 7), 32, couleur)


## Texte cerclé de sombre (p = début de la ligne de base) ; s'il dépasse « largeur », il rapetisse (jusqu'à 18),
## puis il est coupé.
func _texte(zone: Control, texte: String, p: Vector2, taille: int, couleur: Color, largeur := -1.0) -> void:
	var police := ThemeDB.fallback_font
	while largeur > 0.0 and taille > 18 and police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > largeur:
		taille -= 1
	zone.draw_string_outline(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, largeur, taille, 7, Palette.CONTOUR,
		TextServer.JUSTIFICATION_NONE)
	zone.draw_string(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, largeur, taille, couleur, TextServer.JUSTIFICATION_NONE)


# --- Confirmation (Oui / Non) ---

func _demander_creation() -> void:
	$Nom.release_focus()
	_a_effacer = ""
	var nom: String = $Nom.text.strip_edges()
	_ouvrir_confirmation("Créer « %s » ?\nÊtes-vous sûr ?" % (nom if nom != "" else Partie.nom_libre()))


## Les boutons tactiles captent les doigts partout : ceux de l'écran sont cachés pendant la question.
func _ouvrir_confirmation(question: String) -> void:
	$Confirmation/Question.text = question
	$Confirmation.visible = true
	_doigt = -1
	for bouton in [$Retour, $Creer]:
		bouton.visible = false
	$Nom.visible = false


func _fermer_confirmation() -> void:
	$Confirmation.visible = false
	$Retour.visible = true
	$Creer.visible = mode == "nouvelle"
	$Nom.visible = mode == "nouvelle"


func confirmation_ouverte() -> bool:
	return $Confirmation.visible


func _oui() -> void:
	if _a_effacer != "":
		Partie.effacer_partie(_a_effacer)
		_a_effacer = ""
		_fermer_confirmation()
		_lire_parties()
		_borner()
		return
	Partie.nouvelle_partie($Nom.text)
	get_tree().change_scene_to_file("res://scenes/choix_heros.tscn")


## Geste « retour » d'Android : ferme la question, sinon écran précédent (rien n'est changé).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if $Confirmation.visible:
			_fermer_confirmation.call_deferred()
		else:
			_retour.call_deferred()   # pas pendant la diffusion de la notification


func _retour() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn" if depuis_base else "res://scenes/titre.tscn")


func _draw() -> void:
	DecorEcran.fond(self, size)
