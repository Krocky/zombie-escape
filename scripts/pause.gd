extends CanvasLayer
## Menu de pause d'un lieu (bouton Pause du HUD ou geste « retour » d'Android) : fond assombri,
## « Reprendre » et « Retour à la base ». Il tourne pendant que le jeu est figé (process_mode = toujours).
## Le niveau met le jeu en pause (get_tree().paused) et décide de la suite.

signal reprendre
signal retour_base


func _ready() -> void:
	$Fond.color = Color(Palette.CONTOUR, 0.7)
	$Centre/Colonne/Titre.add_theme_color_override("font_color", Palette.LAMPE)
	$Centre/Colonne/Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Centre/Colonne/Perte.add_theme_color_override("font_color", Palette.UI_TEXTE)
	$Centre/Colonne/Perte.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Centre/Colonne/Reprendre.couleur = Palette.LAMPE
	$Centre/Colonne/Reprendre.icone = "jouer"
	$Centre/Colonne/Reprendre.appuye.connect(reprendre.emit)
	$Centre/Colonne/RetourBase.couleur = Palette.UI_BOUTON
	$Centre/Colonne/RetourBase.appuye.connect(retour_base.emit)


## Pendant la pause, aucun doigt ne passe au jeu en dessous (sauf sur les deux boutons, qui le prennent avant).
func _input(event: InputEvent) -> void:
	if visible and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		get_viewport().set_input_as_handled()


func ouvrir(ouvert: bool) -> void:
	visible = ouvert
