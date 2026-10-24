extends CharacterBody2D
## Le héros : capuche, sac à dos, batte, lampe torche.
## Origine = aux pieds (tri par Y).

## La batte frappe : le niveau décide quels zombies sont touchés.
signal attaque(origine: Vector2, sens: Vector2)
signal pv_change(pv: int, pv_max: int)
signal mort
## Le héros fait du bruit (pas, coups) : le niveau prévient les zombies.
signal bruit(origine: Vector2, rayon: float)

const DUREE_COUP := 0.2

var _direction := Vector2.ZERO
var _regarde_gauche := false
var _temps := 0.0
var _pv := Reglages.HEROS_PV
var _recul := Vector2.ZERO
var _invulnerable := 0.0
var _recharge_attaque := 0.0
var _coup := 0.0   # temps restant de l'animation de coup de batte
var _cache := false
var _temps_pas := 0.0
var _regard := Vector2.RIGHT   # direction de la lampe torche (8 directions)


func _ready() -> void:
	pv_change.emit.call_deferred(_pv, Reglages.HEROS_PV)
	$Lampe.texture = _texture_faisceau()
	$Lampe.color = Palette.LAMPE_FAISCEAU
	$Halo.color = Palette.LAMPE_DOUCE
	$Lampe.texture_scale = Reglages.LAMPE_PORTEE / 256.0
	# La pointe du cône (bord gauche de l'image) doit être sur la main
	$Lampe.offset = Vector2(128.0 * $Lampe.texture_scale, 0)


## Faisceau de lampe torche en cône, dessiné pixel par pixel (pas d'image externe).
## La pointe du cône est au bord gauche de l'image, le faisceau part vers la droite.
func _texture_faisceau() -> ImageTexture:
	var taille := 256
	var image := Image.create(taille, taille, false, Image.FORMAT_LA8)
	var demi_angle := deg_to_rad(Reglages.LAMPE_ANGLE / 2.0)
	for y in taille:
		for x in taille:
			var p := Vector2(x, y - taille / 2.0)
			var d := p.length() / taille
			var angle := absf(p.angle())
			var force := 0.0
			if d <= 1.0 and angle <= demi_angle:
				# Plus doux sur les bords du cône et au bout du faisceau
				force = (1.0 - pow(d, 2.0)) * clampf((demi_angle - angle) / (demi_angle * 0.4), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, force))
	return ImageTexture.create_from_image(image)


## Appelé par le niveau quand le joystick bouge.
func definir_direction(direction: Vector2) -> void:
	_direction = direction


## Appelé par le niveau quand on appuie sur Frapper.
func attaquer() -> void:
	if _pv <= 0 or _cache or _recharge_attaque > 0.0:
		return
	_recharge_attaque = Reglages.ATTAQUE_DELAI
	_coup = DUREE_COUP
	attaque.emit(global_position, Vector2(-1 if _regarde_gauche else 1, 0))
	bruit.emit(global_position, Reglages.BRUIT_ATTAQUE)


## Appelé par le niveau : le héros entre dans une cachette (invisible, immobile, silencieux).
func se_cacher() -> void:
	_cache = true
	$Lampe.enabled = false   # lampe éteinte dans la cachette
	collision_layer = 0
	queue_redraw()


func sortir_cachette() -> void:
	_cache = false
	$Lampe.enabled = true
	collision_layer = 2


## Appelé par le niveau quand un zombie touche le héros.
func recevoir_degats(degats: int, depuis: Vector2) -> void:
	if _pv <= 0 or _cache or _invulnerable > 0.0:
		return
	_pv = maxi(_pv - degats, 0)
	_invulnerable = Reglages.HEROS_INVULNERABLE
	_recul = depuis.direction_to(global_position) * Reglages.HEROS_RECUL
	pv_change.emit(_pv, Reglages.HEROS_PV)
	if _pv == 0:
		_direction = Vector2.ZERO
		mort.emit()


func regler_limites_camera(limites: Rect2) -> void:
	var camera: Camera2D = $Camera2D
	camera.limit_left = int(limites.position.x)
	camera.limit_top = int(limites.position.y)
	camera.limit_right = int(limites.end.x)
	camera.limit_bottom = int(limites.end.y)
	camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_recharge_attaque = maxf(_recharge_attaque - delta, 0.0)
	_coup = maxf(_coup - delta, 0.0)
	var direction := _direction if _pv > 0 and not _cache else Vector2.ZERO
	# Bruit des pas, à intervalles réguliers quand il marche
	_temps_pas -= delta
	if direction != Vector2.ZERO and _temps_pas <= 0.0:
		_temps_pas = 0.4
		bruit.emit(global_position, Reglages.BRUIT_PAS)
	velocity = direction * Reglages.HEROS_VITESSE + _recul
	_recul = _recul.move_toward(Vector2.ZERO, 2000.0 * delta)
	move_and_slide()
	if absf(direction.x) > 0.1:
		_regarde_gauche = direction.x < 0.0
	if direction != Vector2.ZERO:
		_regard = direction
	# La lampe suit la direction du héros, depuis sa main
	$Lampe.rotation = lerp_angle($Lampe.rotation, _regard.angle(), minf(12.0 * delta, 1.0))
	$Lampe.position = Vector2(-30 if _regarde_gauche else 30, -50)
	if direction != Vector2.ZERO:
		_temps += delta
	else:
		_temps = 0.0
	queue_redraw()


func _draw() -> void:
	if _cache:
		return   # dans la cachette : la cachette dessine ses yeux
	var s := -1.0 if _regarde_gauche else 1.0  # sens du regard
	var pas := sin(_temps * 14.0) * 4.0         # balancement des jambes
	var rebond := absf(sin(_temps * 14.0)) * 2.0
	if _pv <= 0:
		# K.O. : couché par terre
		draw_set_transform(Vector2(0, -10), -s * PI / 2.0, Vector2(1.25, 1.25))
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.25, 1.25))
	# Clignote quand il vient d'être touché
	modulate.a = 0.35 if _invulnerable > 0.0 and int(_invulnerable * 12.0) % 2 == 0 else 1.0

	# Ombre au sol
	Dessin.ombre(self, Rect2(-28, -9, 56, 18))
	# Jambes
	Dessin.rect(self, Rect2(-11 + pas * 0.5, -26, 9, 24), Palette.HEROS_JEAN)
	Dessin.rect(self, Rect2(2 - pas * 0.5, -26, 9, 24), Palette.HEROS_JEAN)
	# Sac à dos (côté opposé au regard)
	Dessin.rect(self, Rect2(-s * 22 - 8, -60 - rebond, 16, 26), Palette.HEROS_SAC)
	# Batte dans la main arrière (au repos)
	if _coup == 0.0:
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
	# Coup de batte : la batte balaie devant le héros
	if _coup > 0.0:
		var avance := 1.0 - _coup / DUREE_COUP
		var angle := lerpf(-PI * 0.6, PI * 0.25, avance)
		var main := Vector2(s * 14, -46)
		var bout := main + Vector2(s * cos(angle), sin(angle)) * 46.0
		draw_arc(main, 46.0, -PI * 0.6 if s > 0 else PI * 1.6, angle if s > 0 else PI - angle, 12, Palette.LAMPE * Color(1, 1, 1, 0.5), 6.0)
		draw_line(main, bout, Palette.CONTOUR, 11.0)
		draw_line(main, bout, Palette.BATTE, 7.0)
