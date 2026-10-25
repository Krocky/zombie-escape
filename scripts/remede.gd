extends Control
## Écran « Remède trouvé ! » (fin du lot 2) : montré une seule fois, quand la jauge du remède est pleine.
## Une grande fiole qui brille ; « Continuer » ramène à la base, et on peut continuer à jouer.

var _temps := 0.0


func _ready() -> void:
	var titre: Label = $Centre/Colonne/Titre
	titre.add_theme_color_override("font_color", Palette.SORTIE)
	titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	var texte: Label = $Centre/Colonne/Texte
	texte.text = "Avec %d fioles, tu as fabriqué le remède !\nLes rescapés vont pouvoir guérir.\nTu peux continuer à explorer la ville." % Reglages.REMEDE_FIOLES
	texte.add_theme_color_override("font_color", Palette.UI_TEXTE)
	texte.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Centre/Colonne/Fiole.draw.connect(_dessiner_fiole)
	$Centre/Colonne/Continuer.couleur = Palette.LAMPE
	$Centre/Colonne/Continuer.icone = "jouer"
	$Centre/Colonne/Continuer.appuye.connect(_continuer)


## Geste « retour » d'Android : comme « Continuer » (vers la base).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_continuer.call_deferred()   # pas pendant la diffusion de la notification


func _continuer() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()
	$Centre/Colonne/Fiole.queue_redraw()


func _draw() -> void:
	DecorEcran.dessiner(self, size, _temps, DecorEcran.Scene.VICTOIRE)


## La fiole, sur une lueur verte qui respire, avec des étincelles qui tournent autour.
func _dessiner_fiole() -> void:
	var zone: Control = $Centre/Colonne/Fiole
	var centre := Vector2(zone.size.x / 2.0, zone.size.y / 2.0)
	var respire := 1.0 + 0.08 * sin(_temps * 2.5)
	for r: float in [95.0, 70.0, 48.0]:
		zone.draw_circle(centre, r * respire, Color(Palette.SORTIE, 0.12))
	Dessin.icone_objet(zone, "fiole", centre + Vector2(0, 70), 140.0)
	for k in 6:
		var a := _temps * 1.2 + k * TAU / 6.0
		var p := centre + Vector2(cos(a) * 110.0, sin(a) * 60.0)
		var t := 5.0 + 3.0 * sin(_temps * 5.0 + k)
		zone.draw_line(p - Vector2(t, 0), p + Vector2(t, 0), Palette.LAMPE, 3.0)
		zone.draw_line(p - Vector2(0, t), p + Vector2(0, t), Palette.LAMPE, 3.0)
