extends Control
## Les cœurs du héros, en haut à gauche. Un cœur perdu « éclate » ; le dernier cœur bat.

const ECART := 58.0
const DUREE_PERTE := 0.45

var _pv := 0
var _pv_max := 0
var _temps := 0.0
var _perte := 0.0        # temps restant de l'animation du cœur perdu
var _coeur_perdu := -1


func afficher(pv: int, pv_max: int) -> void:
	if pv < _pv:
		_coeur_perdu = pv
		_perte = DUREE_PERTE
	_pv = pv
	_pv_max = pv_max
	queue_redraw()


func _process(delta: float) -> void:
	_temps += delta
	_perte = maxf(_perte - delta, 0.0)
	if _perte > 0.0 or _pv == 1:
		queue_redraw()


func _draw() -> void:
	for i in _pv_max:
		var c := Vector2(32 + i * ECART, 32)
		if i < _pv:
			var battement := 1.0
			if _pv == 1:
				battement = 1.0 + 0.12 * maxf(sin(_temps * 7.0), 0.0)   # dernier cœur : il bat
			_coeur(c, 1.0 * battement, Palette.COEUR, true)
		else:
			_coeur(c, 1.0, Palette.COEUR_VIDE, false)
			if i == _coeur_perdu and _perte > 0.0:
				# Le cœur perdu grossit et s'efface
				var avance := 1.0 - _perte / DUREE_PERTE
				_coeur(c, 1.0 + avance * 0.8, Palette.COEUR * Color(1, 1, 1, 1.0 - avance), true)


func _coeur(c: Vector2, echelle: float, couleur: Color, plein: bool) -> void:
	var points := PackedVector2Array()
	for k in 32:
		var t := TAU * k / 32.0
		# Courbe de cœur classique, mise à l'échelle
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		points.append(c + Vector2(x, y) * 1.45 * echelle)
	Dessin.polygone(self, points, couleur)
	if plein and couleur.a > 0.5:
		# Reflet en haut à gauche
		draw_circle(c + Vector2(-9, -8) * echelle, 4.5 * echelle, Color(1, 1, 1, 0.55 * couleur.a))
