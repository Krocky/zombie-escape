extends CharacterBody2D
## Le héros : capuche, sac à dos, batte, lampe torche.
## Origine = aux pieds (coordonnées monde). Affichage isométrique dans le calque Vue : images V3 du héros
## choisi (Partie.perso() : immobile, marche, coup de batte, de dos vers le haut ; retournées pour la gauche), sinon sprites V2
## (4 directions en diagonale, 3 poses de marche), dessin en code si une image manque.

## La batte frappe : le niveau décide quels zombies sont touchés.
signal attaque(origine: Vector2, sens: Vector2)
signal pv_change(pv: int, pv_max: int)
signal mort
## Le héros fait du bruit (pas, coups) : le niveau prévient les zombies.
signal bruit(origine: Vector2, rayon: float)

const DUREE_COUP := 0.2
const DUREE_POSE_ATTAQUE := 0.3   # pose « attack » (images V3) pendant le coup
const ECHELLE := 0.5            # images à 2x : taille à l'écran
const CADENCE_MARCHE := 7.0     # poses par seconde
const DUREE_FONDU := 0.25       # entrée / sortie de cachette
const DUREE_SECOUSSE := 0.35    # tremblement de l'écran quand il est touché
## Poses (images regardant à droite, retournées pour la gauche) : immobile, puis cycle de marche.
const POSES := {
	"face": ["profil_1", ["profil_2", "profil_1", "profil_3", "profil_1"]],
	"dos": ["dos_droite_2", ["dos_droite_1", "dos_droite_2", "dos_droite_3", "dos_droite_2"]],
}

var _direction := Vector2.ZERO
var _temps := 0.0
var _pv_max := Partie.heros_pv()   # avec la barricade de la base
var _pv := _pv_max
var _touche := false   # a déjà perdu un cœur (même soigné ensuite)
var _recul := Vector2.ZERO
var _invulnerable := 0.0
var _recharge_attaque := 0.0
var _coup := 0.0   # temps restant de l'animation de coup de batte
var _pose_attaque := 0.0
var _perso := Partie.perso()   # skin choisi (images V3)
var _cache := false
var _temps_pas := 0.0
var _regard := Vector2.RIGHT   # direction du regard et de la lampe (monde, 8 directions)
var _vue := Node2D.new()       # dans le calque Vue du niveau
var _fondu := 1.0              # 1 = visible, 0 = dans la cachette (animation)
var _secousse := 0.0

@onready var _lampe: PointLight2D = $Lampe
@onready var _halo: PointLight2D = $Halo
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	pv_change.emit.call_deferred(_pv, _pv_max)
	_lampe.texture = _texture_faisceau()
	_lampe.color = Palette.LAMPE_FAISCEAU
	_halo.color = Palette.LAMPE_DOUCE
	_lampe.texture_scale = Partie.portee_lampe() * Iso.K / 256.0
	# La pointe du cône (bord gauche de l'image) doit être sur la main
	_lampe.offset = Vector2(128.0 * _lampe.texture_scale, 0)
	# Lumières et dessin suivent la position à l'écran ; la caméra aussi (hors du monde)
	for lumiere in [_halo, _lampe]:
		remove_child(lumiere)
		_vue.add_child(lumiere)
	_vue.draw.connect(_dessiner)
	_camera.top_level = true
	# Les sons des zombies se règlent sur la distance dans le monde, pas à l'écran
	var oreille := AudioListener2D.new()
	add_child(oreille)
	oreille.make_current()
	_suivre()


## Nœuds d'affichage, placés par le niveau.
func visuels() -> Dictionary:
	return {"vue": _vue}


## Faisceau de lampe torche en cône, dessiné pixel par pixel (pas d'image externe).
## La pointe du cône est au bord gauche de l'image, le faisceau part vers la droite.
## Calculé une seule fois (gardé pour les parties suivantes).
static var _faisceau: ImageTexture
static var _faisceau_angle := 0.0   # recalculé si l'angle change (écran Réglages)

func _texture_faisceau() -> ImageTexture:
	if _faisceau and _faisceau_angle == Reglages.LAMPE_ANGLE:
		return _faisceau
	_faisceau_angle = Reglages.LAMPE_ANGLE
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
				# Bord du cône net, s'éteint doucement au bout du faisceau
				var bord := clampf((demi_angle - angle) / (demi_angle * 0.15), 0.0, 1.0)
				var coeur := 1.0 - angle / demi_angle   # plus fort au milieu du faisceau
				force = (1.0 - pow(d, 2.5)) * bord * (0.65 + 0.35 * coeur)
			image.set_pixel(x, y, Color(1, 1, 1, force))
	_faisceau = ImageTexture.create_from_image(image)
	return _faisceau


## Appelé par le niveau : couleur du faisceau propre au lieu (Palette.AMBIANCES).
func couleur_lampe(couleur: Color) -> void:
	_lampe.color = couleur


## Appelé par le niveau : lampe torche et halo allumés (lieux) ou éteints (base éclairée).
func allumer_lampe(allumee: bool) -> void:
	_lampe.enabled = allumee
	_halo.enabled = allumee


## Direction du regard dans le monde (le rescapé se place derrière).
func regard() -> Vector2:
	return _regard


## Vrai tant que le héros n'a perdu aucun cœur (un soin ne le rend pas intact).
func intact() -> bool:
	return not _touche


## Blessé (au moins un cœur perdu) et encore debout : il peut être soigné.
func blesse() -> bool:
	return _pv > 0 and _pv < _pv_max


## Appelé par le niveau (bouton Soigner) : rend des cœurs, sans dépasser le maximum.
func soigner(coeurs: int) -> void:
	if not blesse():
		return
	_pv = mini(_pv + coeurs, _pv_max)
	pv_change.emit(_pv, _pv_max)


## Délai avant le prochain coup, en fraction de Reglages.ATTAQUE_DELAI (0 = prêt à frapper).
func recharge() -> float:
	return _recharge_attaque / Reglages.ATTAQUE_DELAI if Reglages.ATTAQUE_DELAI > 0.0 else 0.0


## Appelé par le niveau quand le joystick bouge.
func definir_direction(direction: Vector2) -> void:
	_direction = direction


## Appelé par le niveau quand on appuie sur Frapper.
func attaquer() -> void:
	if _pv <= 0 or _cache or _recharge_attaque > 0.0:
		return
	_recharge_attaque = Reglages.ATTAQUE_DELAI
	_coup = DUREE_COUP
	_pose_attaque = DUREE_POSE_ATTAQUE
	attaque.emit(global_position, _regard)
	bruit.emit(global_position, Reglages.BRUIT_ATTAQUE)


## Appelé par le niveau : le héros entre dans une cachette (invisible, immobile, silencieux).
func se_cacher() -> void:
	_cache = true
	_recul = Vector2.ZERO    # un coup reçu juste avant ne le fait pas glisser hors de la cachette
	_lampe.enabled = false   # lampe éteinte dans la cachette
	collision_layer = 0
	_vue.queue_redraw()


func sortir_cachette() -> void:
	_cache = false
	_lampe.enabled = true
	collision_layer = 2


## Appelé par le niveau quand un zombie touche le héros.
func recevoir_degats(degats: int, depuis: Vector2) -> void:
	if _pv <= 0 or _cache or _invulnerable > 0.0:
		return
	_pv = maxi(_pv - degats, 0)
	_touche = true
	_invulnerable = Reglages.HEROS_INVULNERABLE
	_recul = depuis.direction_to(global_position) * Reglages.HEROS_RECUL
	pv_change.emit(_pv, _pv_max)
	_secousse = DUREE_SECOUSSE
	if _pv == 0:
		_direction = Vector2.ZERO
		mort.emit()


## limites : rectangle à l'écran (vue isométrique).
func regler_limites_camera(limites: Rect2) -> void:
	var camera := _camera
	camera.limit_left = int(limites.position.x)
	camera.limit_top = int(limites.position.y)
	camera.limit_right = int(limites.end.x)
	camera.limit_bottom = int(limites.end.y)
	camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_recharge_attaque = maxf(_recharge_attaque - delta, 0.0)
	_coup = maxf(_coup - delta, 0.0)
	_pose_attaque = maxf(_pose_attaque - delta, 0.0)
	_secousse = maxf(_secousse - delta, 0.0)
	_fondu = move_toward(_fondu, 0.0 if _cache else 1.0, delta / DUREE_FONDU)
	var direction := _direction if _pv > 0 and not _cache else Vector2.ZERO
	# Bruit des pas, à intervalles réguliers quand il marche
	_temps_pas -= delta
	if direction != Vector2.ZERO and _temps_pas <= 0.0:
		_temps_pas = 0.4
		bruit.emit(global_position, Reglages.BRUIT_PAS)
	velocity = direction * Reglages.HEROS_VITESSE + _recul
	_recul = _recul.move_toward(Vector2.ZERO, 2000.0 * delta)
	move_and_slide()
	if direction != Vector2.ZERO:
		_regard = direction
		_temps += delta
	else:
		_temps = 0.0
	_suivre()


## Le dessin, les lumières et la caméra suivent la position projetée à l'écran.
func _suivre() -> void:
	_vue.position = Iso.ecran(global_position)
	var regard := Iso.direction_ecran(_regard)
	# La caméra regarde un peu en avant, du côté où il va
	_camera.global_position = _vue.position + Vector2(0, -50) + regard * Reglages.CAMERA_AVANCE
	# Tremblement quand il est touché (décalage de la caméra, de plus en plus faible)
	var force := 12.0 * _secousse / DUREE_SECOUSSE
	_camera.offset = Vector2(randf_range(-force, force), randf_range(-force, force)) if _secousse > 0.0 else Vector2.ZERO
	var nom := _pose()
	var main := Vector2(regard.x * 30.0, -60.0)
	var anim := _anim_v3()
	if anim["nom"] != "":
		# Images V3 : la lampe est le pixel le plus à droite à hauteur de main (le plus à gauche de dos)
		var v3: String = anim["nom"]
		main = Images.v3_point(v3, Images.v3_lampe(v3, anim["dos"]), anim["decalage"], ECHELLE, regard.x < 0.0)
	elif Images.existe(nom):
		# La lampe est le point le plus à droite de l'image (ancre droite)
		var a := Images.ancres(nom)
		main = (a[2] - a[3]) * ECHELLE
		if regard.x < 0.0:
			main.x = -main.x
	_lampe.position = main
	_lampe.rotation = lerp_angle(_lampe.rotation, regard.angle(), minf(12.0 * get_physics_process_delta_time(), 1.0))
	_vue.queue_redraw()


## Pose V3 du héros choisi (nom "" s'il n'a pas d'images V3) ; de dos s'il regarde vers le haut de l'écran.
func _anim_v3() -> Dictionary:
	var dos := Iso.direction_ecran(_regard).y < -0.1
	return Images.v3_animation(_perso, _temps, _temps > 0.0, _pose_attaque > 0.0, Images.CADENCE_V3, dos)


## Nom de l'image V2 à afficher selon la direction (face ou dos) et la marche.
func _pose() -> String:
	var poses: Array = POSES["dos" if Iso.direction_ecran(_regard).y < -0.1 else "face"]
	if _temps == 0.0:
		return poses[0]
	var cycle: Array = poses[1]
	return cycle[int(_temps * CADENCE_MARCHE) % cycle.size()]


func _dessiner() -> void:
	if _fondu <= 0.0:
		return   # dans la cachette : la cachette dessine ses yeux
	var v := _vue
	var s := -1.0 if Iso.direction_ecran(_regard).x < 0.0 else 1.0  # sens du regard à l'écran
	# Clignote quand il vient d'être touché ; s'efface en entrant dans une cachette
	v.modulate.a = (0.35 if _invulnerable > 0.0 and int(_invulnerable * 12.0) % 2 == 0 else 1.0) * _fondu
	Dessin.ombre(v, Rect2(-30, -10, 60, 20))
	var base := Transform2D.IDENTITY
	if _pv <= 0:
		# K.O. : couché par terre
		base = Transform2D(-s * PI / 2.0, Vector2(0, -12))
	v.draw_set_transform_matrix(base)
	var nom := _pose()
	var anim := _anim_v3()
	if anim["nom"] != "":
		# Rebond et inclinaison autour des pieds (sans poses de marche)
		var pose := base * Transform2D(anim["angle"], anim["decalage"])
		v.draw_set_transform_matrix(pose)
		Images.v3_dessiner(v, anim["nom"], Vector2.ZERO, ECHELLE, s < 0.0, Color.WHITE, pose)
	elif Images.existe(nom):
		Images.dessiner_pieds(v, nom, Vector2.ZERO, ECHELLE, s < 0.0, Color.WHITE, base)
	else:
		_dessiner_secours(s)
	v.draw_set_transform(Vector2.ZERO)
	# Coup de batte : un arc lumineux balaie devant le héros
	if _coup > 0.0:
		var avance := 1.0 - _coup / DUREE_COUP
		var centre := Vector2(0, -50)
		var angle := Iso.direction_ecran(_regard).angle()
		v.draw_arc(centre, 58.0, angle - 1.2, angle - 1.2 + 2.4 * avance, 16, Palette.LAMPE * Color(1, 1, 1, 0.7), 8.0)


## Dessin en code (si les images manquent).
func _dessiner_secours(s: float) -> void:
	var v := _vue
	var pas := sin(_temps * 14.0) * 4.0         # balancement des jambes
	var rebond := absf(sin(_temps * 14.0)) * 2.0
	v.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.25, 1.25))
	if _pv <= 0:
		v.draw_set_transform(Vector2(0, -10), -s * PI / 2.0, Vector2(1.25, 1.25))
	# Jambes
	Dessin.rect(v, Rect2(-11 + pas * 0.5, -26, 9, 24), Palette.HEROS_JEAN)
	Dessin.rect(v, Rect2(2 - pas * 0.5, -26, 9, 24), Palette.HEROS_JEAN)
	# Sac à dos (côté opposé au regard)
	Dessin.rect(v, Rect2(-s * 22 - 8, -60 - rebond, 16, 26), Palette.HEROS_SAC)
	# Batte dans la main arrière
	v.draw_line(Vector2(-s * 10, -34 - rebond), Vector2(-s * 30, -6), Palette.CONTOUR, 9.0)
	v.draw_line(Vector2(-s * 10, -34 - rebond), Vector2(-s * 30, -6), Palette.BATTE, 5.0)
	# Corps (veste)
	Dessin.polygone(v, PackedVector2Array([
		Vector2(-16, -62 - rebond), Vector2(16, -62 - rebond),
		Vector2(18, -24), Vector2(-18, -24)]), Palette.HEROS_VESTE)
	# Bras avant + lampe torche
	v.draw_line(Vector2(s * 12, -54 - rebond), Vector2(s * 26, -40 - rebond), Palette.CONTOUR, 10.0)
	v.draw_line(Vector2(s * 12, -54 - rebond), Vector2(s * 26, -40 - rebond), Palette.HEROS_VESTE, 6.0)
	Dessin.rect(v, Rect2(s * 26 - 5, -46 - rebond, 10, 10), Palette.LAMPE)
	# Tête : capuche puis visage tourné vers le regard
	Dessin.cercle(v, Vector2(0, -74 - rebond), 17, Palette.HEROS_VESTE)
	Dessin.cercle(v, Vector2(s * 5, -73 - rebond), 11, Palette.HEROS_PEAU)
	v.draw_rect(Rect2(s * 5 - 9, -84 - rebond, 18, 5), Palette.HEROS_CHEVEUX)
	v.draw_circle(Vector2(s * 10, -74 - rebond), 2.0, Palette.CONTOUR)
