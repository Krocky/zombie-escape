extends CharacterBody2D
## Un rescapé à sauver (enfant en pyjama avec son chat, images V3 survivor_*). Caché dans un coin du lieu
## (pose hiding, petit « ? » visible dans le noir), il suit le héros dès que celui-ci le touche (pose follow),
## à RESCAPE_DISTANCE derrière lui. Il glisse le long des obstacles (pas de recherche de chemin) ; bloqué trop loin,
## il réapparaît juste derrière le héros. Un zombie qui le touche le renvoie se cacher à sa place (pas de dégâts).
## Le niveau lui donne la position du héros (connaitre_heros) et les contacts des zombies (effrayer).
## Origine = aux pieds (coordonnées monde). Affichage isométrique dans le calque Vue, « ? » / « ! » sur l'enfant
## « Icone » (sans ombre). Il ne bloque personne (aucune couche physique), seul le décor l'arrête.

## Il commence à suivre le héros, ou il ne le suit plus (effrayé) : le niveau met à jour le HUD.
signal suit_change(suit: bool)

enum Etat { CACHE, SUIT, ATTEND, RETOUR }

const MASQUE_DECOR := 1
const ECHELLE := 0.45           # images V3 à 2x ; un peu plus petit que le héros (c'est un enfant)
const PERSO := "survivor"       # images V3 (elles regardent à droite)
const DELAI_BLOQUE := 0.6       # secondes sans avancer avant de réapparaître près du héros (ou à sa cachette)
const VITESSE_RETOUR_FOIS := 1.2   # il court se cacher un peu plus vite

var _etat := Etat.CACHE
var _depart := Vector2.ZERO
var _position_heros := Vector2.ZERO
var _regard_heros := Vector2.RIGHT
var _heros_cache := false
var _temps := 0.0
var _bloque := 0.0
var _gauche := false           # sens du dessin à l'écran
var _vue := Node2D.new()       # dans le calque Vue du niveau
var _haut_icone := -110.0

@onready var _icone: Node2D = $Icone   # enfant de _vue, sans ombre


func _ready() -> void:
	_depart = global_position
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_icone.material = sans_ombre
	_icone.draw.connect(_dessiner_icone)
	remove_child(_icone)
	_vue.add_child(_icone)
	_vue.draw.connect(_dessiner)
	_suivre()


## Nœuds d'affichage, placés par le niveau.
func visuels() -> Dictionary:
	return {"vue": _vue}


func _exit_tree() -> void:
	if is_instance_valid(_vue):
		_vue.queue_free()


## Appelé par le niveau à chaque pas : position et regard (monde) du héros, caché ou non.
func connaitre_heros(position_heros: Vector2, regard: Vector2, cache: bool) -> void:
	_position_heros = position_heros
	if regard != Vector2.ZERO:
		_regard_heros = regard.normalized()
	_heros_cache = cache


func suit() -> bool:
	return _etat == Etat.SUIT or _etat == Etat.ATTEND


## Appelé par le niveau quand un zombie le touche : il retourne se cacher à sa place.
func effrayer() -> void:
	if _etat == Etat.CACHE or _etat == Etat.RETOUR:
		return
	_changer_etat(Etat.RETOUR)


func _changer_etat(nouvel_etat: Etat) -> void:
	var suivait := suit()
	_etat = nouvel_etat
	_bloque = 0.0
	if suit() != suivait:
		suit_change.emit(suit())


func _physics_process(delta: float) -> void:
	var cible := global_position
	var vitesse := 0.0
	var distance_heros := global_position.distance_to(_position_heros)
	match _etat:
		Etat.CACHE:
			if not _heros_cache and distance_heros <= Reglages.RESCAPE_PORTEE:
				_changer_etat(Etat.SUIT)
		Etat.SUIT:
			if _heros_cache:
				_changer_etat(Etat.ATTEND)
			elif distance_heros > Reglages.RESCAPE_DISTANCE:
				cible = _position_heros
				vitesse = Reglages.RESCAPE_VITESSE
		Etat.ATTEND:
			# Le héros est dans une cachette : il s'accroupit et attend
			if not _heros_cache:
				_changer_etat(Etat.SUIT)
		Etat.RETOUR:
			cible = _depart
			vitesse = Reglages.RESCAPE_VITESSE * VITESSE_RETOUR_FOIS
			if global_position.distance_to(_depart) < 10.0:
				_changer_etat(Etat.CACHE)
	var direction := global_position.direction_to(cible) if global_position.distance_to(cible) > 4.0 else Vector2.ZERO
	velocity = direction * vitesse
	move_and_slide()
	if direction != Vector2.ZERO:
		var ecran := Iso.direction_ecran(direction)
		if absf(ecran.x) > 0.1:
			_gauche = ecran.x < 0.0
		_temps += delta
		# Bloqué (contre un mur, ou il glisse dans le mauvais sens) : au bout d'un moment, il réapparaît
		if get_real_velocity().dot(direction) < vitesse * 0.4:
			_bloque += delta
		else:
			_bloque = 0.0
		if _bloque >= DELAI_BLOQUE:
			if _etat == Etat.RETOUR:
				_teleporter(_depart)
			elif distance_heros > Reglages.RESCAPE_DISTANCE_MAX:
				_teleporter(_derriere_heros())
	else:
		_temps = 0.0
		_bloque = 0.0
	_suivre()


## Juste derrière le héros (à l'opposé de son regard, hors du faisceau), sans entrer dans un mur.
func _derriere_heros() -> Vector2:
	var point := _position_heros - _regard_heros * Reglages.RESCAPE_DISTANCE
	var rayon := PhysicsRayQueryParameters2D.create(_position_heros, point, MASQUE_DECOR, [get_rid()])
	var touche := get_world_2d().direct_space_state.intersect_ray(rayon)
	if not touche.is_empty():
		point = touche["position"] + touche["normal"] * 20.0
	return point


func _teleporter(point: Vector2) -> void:
	global_position = point
	velocity = Vector2.ZERO
	_bloque = 0.0


## Le dessin suit la position projetée à l'écran.
func _suivre() -> void:
	_vue.position = Iso.ecran(global_position)
	_vue.queue_redraw()
	_icone.queue_redraw()


## Pose V3 à dessiner : hiding (caché, ou il attend), sinon follow qui rebondit (Images.v3_animation).
func _pose() -> Dictionary:
	if _etat == Etat.CACHE or _etat == Etat.ATTEND:
		return {"nom": Images.v3_pose(PERSO, "hiding"), "decalage": Vector2.ZERO, "angle": 0.0}
	var anim := Images.v3_animation(PERSO, _temps, _temps > 0.0)
	anim["nom"] = Images.v3_pose(PERSO, "follow")
	return anim


func _dessiner() -> void:
	var v := _vue
	Dessin.ombre(v, Rect2(-24, -9, 48, 18))
	var anim := _pose()
	var nom: String = anim["nom"]
	if nom == "":
		# Secours : petit personnage en pyjama
		Dessin.ellipse(v, Vector2(0, -40), Vector2(16, 26), Palette.UI_TEXTE)
		Dessin.cercle(v, Vector2(0, -78), 13, Palette.HEROS_PEAU)
		_haut_icone = -110.0
		return
	var base := Transform2D(anim["angle"], anim["decalage"])
	v.draw_set_transform_matrix(base)
	Images.v3_dessiner(v, nom, Vector2.ZERO, ECHELLE, _gauche, Color.WHITE, base)
	v.draw_set_transform(Vector2.ZERO)
	_haut_icone = -Images.v3_taille(nom).y * ECHELLE - 14.0


## « ? » au-dessus de lui quand il est caché (pour le repérer à la lampe), « ! » quand il a peur.
func _dessiner_icone() -> void:
	var texte := "?" if _etat == Etat.CACHE else "!" if _etat == Etat.RETOUR else ""
	if texte == "":
		return
	var police := ThemeDB.fallback_font
	var p := Vector2(-8, _haut_icone + 4.0 + sin(Time.get_ticks_msec() / 300.0) * 3.0)
	var couleur := Palette.LUNE.lightened(0.5) if _etat == Etat.CACHE else Palette.UI_TEXTE
	_icone.draw_string_outline(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Palette.CONTOUR)
	_icone.draw_string(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, couleur)
