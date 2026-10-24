extends Control
## Les cœurs du héros, en haut à gauche.

var _pv := 0
var _pv_max := 0


func afficher(pv: int, pv_max: int) -> void:
	_pv = pv
	_pv_max = pv_max
	queue_redraw()


func _draw() -> void:
	for i in _pv_max:
		var c := Vector2(30 + i * 56, 30)
		var plein := i < _pv
		_coeur(c, Palette.COEUR if plein else Palette.UI_FOND)


func _coeur(c: Vector2, couleur: Color) -> void:
	var points := PackedVector2Array()
	for k in 32:
		var t := TAU * k / 32.0
		# Courbe de cœur classique, mise à l'échelle
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		points.append(c + Vector2(x, y) * 1.4)
	Dessin.polygone(self, points, couleur)
