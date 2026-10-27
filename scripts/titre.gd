extends Control
## Écran titre : le nom du jeu, le bouton Jouer (reprend la partie en cours : vers la base ; avant son choix du
## héros, vers l'écran « Choisis ton héros ») et « Mes parties » (lot 4 d). Le geste « retour » d'Android n'y fait rien (quit_on_go_back désactivé).

var _temps := 0.0


func _ready() -> void:
	$Centre/Colonne/Titre.add_theme_color_override("font_color", Palette.LAMPE)
	$Centre/Colonne/Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Centre/Colonne/SousTitre.add_theme_color_override("font_color", Palette.UI_TEXTE)
	$Centre/Colonne/Jouer.couleur = Palette.LAMPE
	$Centre/Colonne/Jouer.icone = "jouer"
	$Centre/Colonne/Jouer.appuye.connect(_jouer)
	$Centre/Colonne/MesParties.couleur = Palette.UI_BOUTON
	$Centre/Colonne/MesParties.appuye.connect(func() -> void: EcranParties.ouvrir(get_tree(), "liste", false))


func _jouer() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn" if Partie.skin != "" else "res://scenes/choix_heros.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()


func _draw() -> void:
	DecorEcran.dessiner(self, size, _temps)
