extends Control
## Écran titre : le nom du jeu et le bouton Jouer (vers la base).

var _temps := 0.0


func _ready() -> void:
	$Centre/Colonne/Titre.add_theme_color_override("font_color", Palette.LAMPE)
	$Centre/Colonne/Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Centre/Colonne/SousTitre.add_theme_color_override("font_color", Palette.UI_TEXTE)
	$Centre/Colonne/Jouer.couleur = Palette.LAMPE
	$Centre/Colonne/Jouer.icone = "jouer"
	$Centre/Colonne/Jouer.appuye.connect(_jouer)


func _jouer() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()


func _draw() -> void:
	DecorEcran.dessiner(self, size, _temps)
