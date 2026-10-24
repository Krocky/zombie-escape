extends Control
## Joystick virtuel flottant : toucher n'importe où dans cette zone (moitié gauche)
## place le joystick sous le doigt. Émet la direction (longueur 0 ou 1).

signal direction_changee(direction: Vector2)

const RAYON_BASE := 110.0
const RAYON_BOUTON := 50.0
const MARGE_REPOS := 190.0

var _doigt := -1
var _centre := Vector2.ZERO
var _bouton := Vector2.ZERO
var _direction := Vector2.ZERO


func _ready() -> void:
	resized.connect(_revenir_au_repos)
	_revenir_au_repos()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _doigt == -1 and get_global_rect().has_point(event.position):
			_doigt = event.index
			_centre = event.position - global_position
			_deplacer_bouton(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _doigt:
			_doigt = -1
			_revenir_au_repos()
	elif event is InputEventScreenDrag and event.index == _doigt:
		_deplacer_bouton(event.position)
		get_viewport().set_input_as_handled()


func _deplacer_bouton(position_ecran: Vector2) -> void:
	var decalage := (position_ecran - global_position - _centre).limit_length(RAYON_BASE)
	_bouton = _centre + decalage
	var nouvelle := Vector2.ZERO
	if decalage.length() > RAYON_BASE * Reglages.JOYSTICK_ZONE_MORTE:
		nouvelle = decalage.normalized()
	_emettre(nouvelle)
	queue_redraw()


func _revenir_au_repos() -> void:
	_centre = Vector2(MARGE_REPOS, size.y - MARGE_REPOS)
	_bouton = _centre
	_emettre(Vector2.ZERO)
	queue_redraw()


func _emettre(direction: Vector2) -> void:
	if direction != _direction:
		_direction = direction
		direction_changee.emit(direction)


func _draw() -> void:
	var actif := _doigt != -1
	var opacite := 1.0 if actif else 0.6
	draw_circle(_centre, RAYON_BASE, Palette.UI_FOND * Color(1, 1, 1, opacite))
	draw_arc(_centre, RAYON_BASE, 0, TAU, 48, Palette.UI_BORD * Color(1, 1, 1, opacite), 4.0, true)
	draw_circle(_bouton, RAYON_BOUTON, Palette.UI_BORD * Color(1, 1, 1, opacite))
	draw_arc(_bouton, RAYON_BOUTON, 0, TAU, 32, Palette.CONTOUR, 4.0, true)
