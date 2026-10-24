extends CharacterBody2D
## Le héros : capuche, sac à dos, batte, lampe torche.
## Origine = aux pieds (tri par Y).

var _direction := Vector2.ZERO
var _regarde_gauche := false
var _temps := 0.0


## Appelé par le niveau quand le joystick bouge.
func definir_direction(direction: Vector2) -> void:
	_direction = direction


func regler_limites_camera(limites: Rect2) -> void:
	var camera: Camera2D = $Camera2D
	camera.limit_left = int(limites.position.x)
	camera.limit_top = int(limites.position.y)
	camera.limit_right = int(limites.end.x)
	camera.limit_bottom = int(limites.end.y)
	camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	velocity = _direction * Reglages.HEROS_VITESSE
	move_and_slide()
	if absf(_direction.x) > 0.1:
		_regarde_gauche = _direction.x < 0.0
	if _direction != Vector2.ZERO:
		_temps += delta
	else:
		_temps = 0.0
	queue_redraw()


func _draw() -> void:
	var s := -1.0 if _regarde_gauche else 1.0  # sens du regard
	var pas := sin(_temps * 14.0) * 4.0         # balancement des jambes
	var rebond := absf(sin(_temps * 14.0)) * 2.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.25, 1.25))

	# Ombre au sol
	Dessin.ellipse(self, Vector2(0, 0), Vector2(22, 7), Palette.OMBRE, false)
	# Jambes
	Dessin.rect(self, Rect2(-11 + pas * 0.5, -26, 9, 24), Palette.HEROS_JEAN)
	Dessin.rect(self, Rect2(2 - pas * 0.5, -26, 9, 24), Palette.HEROS_JEAN)
	# Sac à dos (côté opposé au regard)
	Dessin.rect(self, Rect2(-s * 22 - 8, -60 - rebond, 16, 26), Palette.HEROS_SAC)
	# Batte dans la main arrière
	draw_line(Vector2(-s * 10, -34 - rebond), Vector2(-s * 30, -6), Palette.CONTOUR, 9.0)
	draw_line(Vector2(-s * 10, -34 - rebond), Vector2(-s * 30, -6), Palette.BATTE, 5.0)
	# Corps (veste)
	Dessin.polygone(self, PackedVector2Array([
		Vector2(-16, -62 - rebond), Vector2(16, -62 - rebond),
		Vector2(18, -24), Vector2(-18, -24)]), Palette.HEROS_VESTE)
	# Bras avant + lampe torche
	draw_line(Vector2(s * 12, -54 - rebond), Vector2(s * 26, -40 - rebond), Palette.CONTOUR, 10.0)
	draw_line(Vector2(s * 12, -54 - rebond), Vector2(s * 26, -40 - rebond), Palette.HEROS_VESTE, 6.0)
	Dessin.rect(self, Rect2(s * 26 - 5, -46 - rebond, 10, 10), Palette.LAMPE)
	# Tête : capuche puis visage tourné vers le regard
	Dessin.cercle(self, Vector2(0, -74 - rebond), 17, Palette.HEROS_VESTE)
	Dessin.cercle(self, Vector2(s * 5, -73 - rebond), 11, Palette.HEROS_PEAU)
	draw_rect(Rect2(s * 5 - 9, -84 - rebond, 18, 5), Palette.HEROS_CHEVEUX)
	draw_circle(Vector2(s * 10, -74 - rebond), 2.0, Palette.CONTOUR)
