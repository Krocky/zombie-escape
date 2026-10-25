extends Control
## Écran de fin : Mission réussie (objectif rempli, avec bonus), Victoire ou Retour à la base,
## objets rapportés ou perdus, fioles versées dans la jauge du remède, rescapé sauvé (survivor_happy près du héros),
## inventaire de la base.
## Le bouton « Retour à la base » ramène à l'écran Base.
## Fond illustré (DecorEcran) et icônes des objets (Dessin.icone_objet).

const TAILLE_ICONE := 54.0
const TITRES := {"mission": "Mission réussie !", "victoire": "Victoire !", "defaite": "Retour à la base"}

var _temps := 0.0
var _partie := Control.new()   # icônes : objets rapportés, bonus (entourés), puis perdus (barrés)
var _base := Control.new()     # icônes : inventaire de la base, avec le nombre


func _ready() -> void:
	var resultat := Partie.resultat
	var titre: Label = $Centre/Colonne/Titre
	titre.text = TITRES["mission" if resultat["mission"] else "victoire" if resultat["victoire"] else "defaite"]
	titre.add_theme_color_override("font_color", Palette.SORTIE if resultat["victoire"] else Palette.LAMPE)
	titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)

	var lignes := []
	var bravo := ("Bravo %s ! " % Partie.prenom) if Partie.prenom != "" else ""
	if resultat["victoire"]:
		lignes.append(bravo + "Tu es %s %s !" % [Partie.accord("sorti", "sortie"), Partie.LIEUX[Partie.lieu]["du"]])
	else:
		lignes.append("Tu as été %s... tes amis t'ont %s à la base." % [Partie.accord("rattrapé", "rattrapée"), Partie.accord("ramené", "ramenée")])
	if resultat.get("rescape", false):
		lignes.append("Tu as sauvé un rescapé !")
	if resultat["mission"]:
		lignes.append("Objectif rempli ! Bonus : " + _liste(resultat["bonus"]))
	elif Partie.total_objectif(Partie.lieu) > 0:
		lignes.append("Objectif pas rempli : " + Partie.texte_objectif(Partie.lieu))
	lignes.append("Objets rapportés : " + _liste(resultat["rapportes"]))
	if not resultat["victoire"]:
		lignes.append("Objets perdus en route : " + _liste(resultat["perdus"]))
	if resultat["fioles"] > 0:
		lignes.append("%s dans la jauge du remède : %d / %d" % ["Fiole versée" if resultat["fioles"] == 1 else "Fioles versées",
			Partie.remede, Reglages.REMEDE_FIOLES])
	$Centre/Colonne/Resume.text = "\n".join(lignes)
	$Centre/Colonne/Resume.add_theme_color_override("font_color", Palette.UI_TEXTE)

	var stock := []
	for type in Partie.NOMS:
		if Partie.inventaire.get(type, 0) > 0:
			stock.append("%s x%d" % [Partie.nom(type), Partie.inventaire[type]])
	$Centre/Colonne/Inventaire.text = "Inventaire de la base :\n" + (", ".join(stock) if stock else "vide")
	$Centre/Colonne/Inventaire.add_theme_color_override("font_color", Palette.UI_BORD)

	$Centre/Colonne/RetourBase.couleur = Palette.LAMPE
	$Centre/Colonne/RetourBase.appuye.connect(_retour_base)
	$Centre/Colonne/Resume.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Centre/Colonne/Resume.add_theme_constant_override("outline_size", 6)
	$Centre/Colonne/Inventaire.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Centre/Colonne/Inventaire.add_theme_constant_override("outline_size", 6)
	# Lignes d'icônes sous les textes
	for ligne in [[_partie, $Centre/Colonne/Resume], [_base, $Centre/Colonne/Inventaire]]:
		ligne[0].custom_minimum_size = Vector2(0, TAILLE_ICONE + 12)
		ligne[0].mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Centre/Colonne.add_child(ligne[0])
		$Centre/Colonne.move_child(ligne[0], ligne[1].get_index() + 1)
	_partie.draw.connect(_dessiner_partie)
	_base.draw.connect(_dessiner_base)


func _liste(types: Array) -> String:
	if types.is_empty():
		return "aucun"
	var noms := []
	for type in types:
		noms.append(Partie.nom(type))
	return ", ".join(noms)


func _retour_base() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()
	_partie.queue_redraw()


func _draw() -> void:
	var scene := DecorEcran.Scene.VICTOIRE if Partie.resultat["victoire"] else DecorEcran.Scene.DEFAITE
	DecorEcran.dessiner(self, size, _temps, scene)
	if Partie.resultat.get("rescape", false):
		_dessiner_rescape()


## Le rescapé sauvé, content, à côté du héros (à sa gauche : le faisceau part à droite).
func _dessiner_rescape() -> void:
	var nom := Images.v3_pose("survivor", "happy")
	if nom == "":
		return
	var e := minf(size.x, size.y) / 720.0
	var paysage := size.x > size.y
	var pieds := (Vector2(0.15, 0.94) if paysage else Vector2(0.24, 0.96)) * size + Vector2(-112, 2) * e
	var saut := absf(sin(_temps * 3.0)) * 8.0 * e
	Dessin.ombre(self, Rect2(pieds - Vector2(40, 11) * e, Vector2(80, 22) * e))
	Images.v3_dessiner(self, nom, pieds - Vector2(0, saut), e * 0.8)


## Objets rapportés (en couleur), bonus (sur un rond jaune), puis perdus (sombres, barrés d'une croix rouge), centrés.
func _dessiner_partie() -> void:
	var rapportes: Array = Partie.resultat["rapportes"]
	var bonus: Array = Partie.resultat["bonus"]
	var perdus: Array = Partie.resultat["perdus"]
	var types := rapportes + bonus + perdus
	var x0 := _partie.size.x / 2.0 - (types.size() - 1) * (TAILLE_ICONE + 14) / 2.0
	for i in types.size():
		var pieds := Vector2(x0 + i * (TAILLE_ICONE + 14), TAILLE_ICONE + 6)
		var perdu := i >= rapportes.size() + bonus.size()
		if i >= rapportes.size() and not perdu:
			_partie.draw_circle(pieds - Vector2(0, TAILLE_ICONE / 2.0), TAILLE_ICONE * 0.62, Color(Palette.LAMPE, 0.3 + 0.1 * sin(_temps * 4.0)))
		Dessin.icone_objet(_partie, types[i], pieds, TAILLE_ICONE, Color(0.65, 0.65, 0.75, 0.8) if perdu else Color.WHITE)
		if perdu:
			var c := pieds - Vector2(0, TAILLE_ICONE / 2.0)
			for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
				_partie.draw_line(c - d * 18.0, c + d * 18.0, Palette.COEUR, 6.0, true)


## Inventaire de la base : une icône par type, avec « x N ».
func _dessiner_base() -> void:
	var types := []
	for type in Partie.NOMS:
		if Partie.inventaire.get(type, 0) > 0:
			types.append(type)
	var pas := TAILLE_ICONE + 56
	var x0 := _base.size.x / 2.0 - (types.size() - 1) * pas / 2.0
	for i in types.size():
		Dessin.objet_compte(_base, types[i], Vector2(x0 + i * pas - 16, TAILLE_ICONE + 6), TAILLE_ICONE, Partie.inventaire[types[i]])
