extends CharacterBody2D
## Un rescapé sauvé qui vit dans la base (lot 4 c) : il se promène lentement sur le parking vers un point au hasard
## (libre, et en ligne droite sans obstacle : pas de recherche de chemin), s'arrête quelques secondes, repart.
## Quand le héros passe tout près, il s'arrête, se tourne vers lui et le remercie dans une bulle (au plus une fois
## toutes les RESCAPE_BASE_DELAI_MERCI s). aller_devant_tente() l'envoie devant sa tente et l'y garde (pour
## l'attaque de la base, étape h) ; liberer() le laisse repartir.
## La base lui donne la position du héros (connaitre_heros) et le cache tant que sa tente n'est pas posée (actif).
## Origine = aux pieds (coordonnées monde). Affichage isométrique dans le calque Vue, bulle sur l'enfant « Bulle »
## (sans ombre, par-dessus le décor). Il ne bloque personne (aucune couche physique), seul le décor l'arrête.

enum Etat { PAUSE, MARCHE, MERCI, TENTE }

const MASQUE_DECOR := 1
const ECHELLE := 0.5            # images V3 à 2x, comme le héros
const RAYON_LIBRE := 20.0       # un point de promenade est libre dans ce rayon (collision : 14)
const MARGE := 80.0             # les points de promenade restent à cette distance du bord du parking
const ESSAIS := 12              # points tirés au hasard avant d'attendre un peu
const DELAI_BLOQUE := 0.6       # secondes sans avancer : il s'arrête (promenade) ou réapparaît (tente)
const ARRIVEE := 6.0
const POP_BULLE := 0.15         # la bulle grossit en apparaissant (s)
const TAILLE_TEXTE := 26
const PHRASES := ["Merci de m'avoir sauvé !", "Sans toi, j'étais fichu !"]

## Images V3 / V4 du rescapé (elles regardent à droite), voir Partie.persos_base.
@export var perso := "survivor"
## Zone où il se promène (monde) et point devant sa tente : donnés par la base.
var parking := Rect2(0, 0, 2400, 1600)
var tente := Vector2.ZERO
## Faux tant que sa tente n'est pas posée (elle tombe du ciel) : caché et immobile.
var actif := true

var _etat := Etat.PAUSE
var _attente := 0.0             # temps restant de la pause ou de la bulle
var _cible := Vector2.ZERO
var _position_heros := Vector2(INF, INF)
var _depuis_merci := INF        # temps depuis le début de la dernière bulle
var _phrase := ""
var _temps := 0.0
var _bloque := 0.0
var _gauche := false            # sens du dessin à l'écran
var _vue := Node2D.new()        # dans le calque Vue du niveau
var _haut := -120.0             # haut de l'image (pour la bulle)

@onready var _bulle: Node2D = $Bulle   # enfant de _vue, sans ombre


func _ready() -> void:
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_bulle.material = sans_ombre
	_bulle.z_as_relative = false
	_bulle.z_index = 5           # par-dessus le décor et les personnages
	_bulle.draw.connect(_dessiner_bulle)
	remove_child(_bulle)
	_vue.add_child(_bulle)
	_vue.draw.connect(_dessiner)
	_pause()
	_suivre()


## Nœuds d'affichage, placés par la base.
func visuels() -> Dictionary:
	return {"vue": _vue}


func _exit_tree() -> void:
	if is_instance_valid(_vue):
		_vue.queue_free()


## Appelé par la base à chaque pas : position du héros (monde).
func connaitre_heros(position_heros: Vector2) -> void:
	_position_heros = position_heros


## Il va devant sa tente et y reste (jusqu'à liberer).
func aller_devant_tente() -> void:
	_etat = Etat.TENTE
	_bloque = 0.0


## Il reprend ses promenades.
func liberer() -> void:
	if _etat == Etat.TENTE:
		_pause()


## Arrivé et gardé devant sa tente.
func devant_tente() -> bool:
	return _etat == Etat.TENTE and global_position.distance_to(tente) <= ARRIVEE


func marche() -> bool:
	return _etat == Etat.MARCHE or (_etat == Etat.TENTE and not devant_tente())


## Phrase de la bulle affichée, "" sans bulle.
func remercie() -> String:
	return _phrase if _etat == Etat.MERCI else ""


func _pause() -> void:
	_etat = Etat.PAUSE
	_attente = randf_range(Reglages.RESCAPE_BASE_PAUSE_MIN, maxf(Reglages.RESCAPE_BASE_PAUSE_MIN, Reglages.RESCAPE_BASE_PAUSE_MAX))


## Prochaine promenade : un point libre du parking, joignable en ligne droite ; sinon il attend encore un peu.
func _partir() -> void:
	if not _libre(global_position):
		global_position = tente   # une construction vient d'être posée sur lui
	var zone := parking.grow(-MARGE)
	for essai in ESSAIS:
		var p := Vector2(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y, zone.end.y))
		if p.distance_to(global_position) > 100.0 and _libre(p) and _chemin_libre(p):
			_cible = p
			_etat = Etat.MARCHE
			_bloque = 0.0
			return
	_pause()


func _forme() -> PhysicsShapeQueryParameters2D:
	var cercle := CircleShape2D.new()
	cercle.radius = RAYON_LIBRE
	var requete := PhysicsShapeQueryParameters2D.new()
	requete.shape = cercle
	requete.collision_mask = MASQUE_DECOR
	return requete


func _libre(p: Vector2) -> bool:
	var requete := _forme()
	requete.transform = Transform2D(0.0, p + Vector2(0, -8))
	return get_world_2d().direct_space_state.intersect_shape(requete, 1).is_empty()


func _chemin_libre(p: Vector2) -> bool:
	var requete := _forme()
	requete.transform = Transform2D(0.0, global_position + Vector2(0, -8))
	requete.motion = p - global_position
	return get_world_2d().direct_space_state.cast_motion(requete)[0] >= 1.0


func _physics_process(delta: float) -> void:
	_depuis_merci += delta
	_vue.visible = actif
	if not actif:
		return
	var cible := global_position
	var vitesse := 0.0
	match _etat:
		Etat.PAUSE:
			_attente -= delta
			if _attente <= 0.0:
				_partir()
		Etat.MARCHE:
			if global_position.distance_to(_cible) <= ARRIVEE:
				_pause()
			else:
				cible = _cible
				vitesse = Reglages.RESCAPE_BASE_VITESSE
		Etat.MERCI:
			_attente -= delta
			var ecran := Iso.ecran(_position_heros) - Iso.ecran(global_position)
			if absf(ecran.x) > 4.0:
				_gauche = ecran.x < 0.0
			if _attente <= 0.0:
				_pause()
		Etat.TENTE:
			cible = tente
			vitesse = Reglages.RESCAPE_VITESSE   # il se dépêche
	if (_etat == Etat.PAUSE or _etat == Etat.MARCHE) and _depuis_merci >= Reglages.RESCAPE_BASE_DELAI_MERCI \
			and global_position.distance_to(_position_heros) <= Reglages.RESCAPE_BASE_PORTEE_MERCI:
		_remercier()
		vitesse = 0.0
	var direction := global_position.direction_to(cible) if global_position.distance_to(cible) > ARRIVEE else Vector2.ZERO
	velocity = direction * vitesse
	move_and_slide()
	if vitesse > 0.0 and direction != Vector2.ZERO:
		var ecran := Iso.direction_ecran(direction)
		if absf(ecran.x) > 0.1:
			_gauche = ecran.x < 0.0
		_temps += delta
		# Bloqué (une construction vient de tomber sur son chemin...) : il s'arrête, ou réapparaît devant sa tente
		if get_real_velocity().dot(direction) < vitesse * 0.4:
			_bloque += delta
		else:
			_bloque = 0.0
		if _bloque >= DELAI_BLOQUE:
			_bloque = 0.0
			if _etat == Etat.TENTE:
				global_position = tente
			else:
				_pause()
	else:
		_temps = 0.0
		_bloque = 0.0
	_suivre()


## Il s'arrête et dit merci (phrase au hasard, différente de la précédente si possible).
func _remercier() -> void:
	var phrases := PHRASES.duplicate()
	if Partie.prenom != "":
		phrases.append("Merci %s !" % Partie.prenom)
	if phrases.size() > 1:
		phrases.erase(_phrase)
	_phrase = phrases[randi() % phrases.size()]
	_etat = Etat.MERCI
	_attente = Reglages.RESCAPE_BASE_DUREE_MERCI
	_depuis_merci = 0.0


## Le dessin suit la position projetée à l'écran.
func _suivre() -> void:
	_vue.position = Iso.ecran(global_position)
	_vue.queue_redraw()
	_bulle.queue_redraw()


## Pose V3 : follow qui rebondit en marchant (Images.v3_animation), happy à l'arrêt.
func _pose() -> Dictionary:
	if not marche():
		return {"nom": Images.v3_pose(perso, "happy"), "decalage": Vector2.ZERO, "angle": 0.0}
	var anim := Images.v3_animation(perso, _temps, true)
	anim["nom"] = Images.v3_pose(perso, "follow")
	return anim


func _dessiner() -> void:
	var v := _vue
	Dessin.ombre(v, Rect2(-26, -9, 52, 18))
	var anim := _pose()
	var nom: String = anim["nom"]
	if nom == "":
		# Secours : petit personnage dessiné
		Dessin.ellipse(v, Vector2(0, -40), Vector2(16, 26), Palette.UI_TEXTE)
		Dessin.cercle(v, Vector2(0, -78), 13, Palette.HEROS_PEAU)
		_haut = -100.0
		return
	var base := Transform2D(anim["angle"], anim["decalage"])
	v.draw_set_transform_matrix(base)
	Images.v3_dessiner(v, nom, Vector2.ZERO, ECHELLE, _gauche, Color.WHITE, base)
	v.draw_set_transform(Vector2.ZERO)
	_haut = -Images.v3_taille(nom).y * ECHELLE


## Bulle claire au contour épais avec une pointe vers sa tête ; elle grossit un instant en apparaissant.
func _dessiner_bulle() -> void:
	if _etat != Etat.MERCI:
		return
	var police := ThemeDB.fallback_font
	var texte_taille := police.get_string_size(_phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_TEXTE)
	var taille := texte_taille + Vector2(36, 24)
	var echelle := clampf(_depuis_merci / POP_BULLE, 0.0, 1.0) * 0.4 + 0.6
	var pointe := Vector2(0, _haut - 6.0)
	_bulle.draw_set_transform(pointe, 0.0, Vector2(echelle, echelle))
	var cadre := Rect2(Vector2(-taille.x / 2.0, -taille.y - 18.0), taille)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Palette.UI_TEXTE
	fond.border_color = Palette.CONTOUR
	fond.set_border_width_all(4)
	fond.set_corner_radius_all(18)
	var triangle := PackedVector2Array([Vector2(-12, -22), Vector2(12, -22), Vector2(0, 0)])
	_bulle.draw_colored_polygon(triangle, Palette.CONTOUR)
	_bulle.draw_style_box(fond, cadre)
	_bulle.draw_colored_polygon(PackedVector2Array([Vector2(-7, -23), Vector2(7, -23), Vector2(0, -7)]), Palette.UI_TEXTE)
	var p := Vector2(cadre.position.x + 18, cadre.position.y + 12 + police.get_ascent(TAILLE_TEXTE))
	_bulle.draw_string(police, p, _phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_TEXTE, Palette.CONTOUR)
	_bulle.draw_set_transform(Vector2.ZERO)
