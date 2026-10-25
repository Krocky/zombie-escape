extends CharacterBody2D
## Un zombie : il patrouille, voit le héros dans son cône de vue, entend le bruit,
## poursuit, cherche là où il l'a perdu, puis retourne patrouiller.
## Le niveau lui donne la position du héros (connaitre_heros) et les bruits (entendre).
## Origine = aux pieds (coordonnées monde). Affichage isométrique : sprites V2 dans le calque Vue,
## yeux sur l'enfant « Yeux » (non assombri par la nuit), cône de vue sur le calque du sol.
## Le zombie COUREUR (images V3) ne repère le héros que dans son cône (ni bruit, ni contact de dos) :
## il charge très vite, puis s'arrête ESSOUFFLE (immobile, inoffensif) avant de pouvoir recharger.

## Le zombie touche le héros : le niveau transmet les dégâts.
signal touche_heros(degats: int, depuis: Vector2)

enum Type { LENT, RAPIDE, COUREUR }
enum Etat { PATROUILLE, POURSUITE, CHERCHE, RETOUR, ESSOUFFLE }

const MASQUE_DECOR := 1   # couche physique des murs et cachettes (bloquent la vue)
const SON_CRI_GROS := preload("res://sons/zombie_gros.mp3")
const SON_CRI_MAIGRE := preload("res://sons/zombie_maigre.mp3")
const SONS_COUP := [preload("res://sons/taper1.mp3"), preload("res://sons/taper2.mp3"), preload("res://sons/taper3.mp3")]
const ECHELLE := 0.5            # images à 2x : taille à l'écran
const CADENCE_MARCHE := 5.0     # poses par seconde (en patrouille ; deux fois plus en poursuite)
const PERSO_COUREUR := "zombie_runner"   # images V3 du coureur (elles regardent à gauche)
## Poses : immobile, puis cycle de marche. « gauche » : les images regardent à gauche.
const POSES := {
	Type.LENT: {"face": ["gros_face_2", ["gros_face_2", "gros_face_4", "gros_face_5", "gros_face_4"]],
		"dos": ["gros_dos_2", ["gros_dos_1", "gros_dos_2", "gros_dos_4", "gros_dos_2"]], "gauche": false},
	Type.RAPIDE: {"face": ["maigre_profil_2", ["maigre_profil_1", "maigre_profil_2", "maigre_profil_3", "maigre_profil_2"]],
		"dos": ["maigre_dos_2", ["maigre_dos_1", "maigre_dos_2", "maigre_dos_3", "maigre_dos_2"]], "gauche": true},
}
## Le coureur sans images V3 : dessiné comme le maigre
const POSES_SECOURS_COUREUR := Type.RAPIDE

@export var type := Type.LENT
## Point de patrouille, relatif à la position de départ : il fait l'aller-retour.
@export var patrouille := Vector2(300, 0)

var _etat := Etat.PATROUILLE
var _depart := Vector2.ZERO
var _vers_bout := true
var _position_heros := Vector2.ZERO
var _heros_detectable := false
var _point_recherche := Vector2.ZERO   # là où il a vu ou entendu le héros pour la dernière fois
var _temps_sans_voir := 0.0
var _temps_recherche := 0.0
var _regard := Vector2.RIGHT           # direction du regard (cône de vue)
var _temps := 0.0
var _pv := 1
var _recul := Vector2.ZERO
var _etourdi := 0.0
var _delai_coup := 0.0
var _flash := 0.0
var _battu := false        # vrai pour toujours dès qu'il n'a plus de PV
var _disparition := 0.0   # temps restant de l'animation où il bascule et s'efface
var _delai_cri := 0.0     # évite qu'il crie en boucle
var _charge := 0.0        # coureur : temps depuis le début de la charge
var _souffle := 0.0       # coureur : temps restant essoufflé
# Yeux du dessin de secours (calculés pendant le dessin du corps)
var _yeux_centre := Vector2.ZERO
var _yeux_sens := 1.0
var _corps_rotation := 0.0
var _corps_echelle := Vector2.ONE
var _vue := Node2D.new()   # dans le calque Vue du niveau
var _haut_icone := -120.0  # au-dessus de la tête : « ! », « ? », étoiles
var _impact := 0.0         # temps restant de la gerbe d'étincelles du coup de batte
const DUREE_IMPACT := 0.3

@onready var _cone: Node2D = $Cone   # placé par le niveau dans le calque du sol
@onready var _yeux: Node2D = $Yeux   # enfant de _vue


## detectable = faux quand le héros est caché ou K.O.
func connaitre_heros(position_heros: Vector2, detectable: bool) -> void:
	_position_heros = position_heros
	_heros_detectable = detectable


## Un bruit a été fait en « origine » ; il porte jusqu'à « rayon ».
func entendre(origine: Vector2, rayon: float) -> void:
	if _battu or _etat == Etat.POURSUITE or type == Type.COUREUR:
		return   # le coureur n'entend rien
	if global_position.distance_to(origine) <= rayon:
		_point_recherche = origine
		_changer_etat(Etat.CHERCHE)


func _ready() -> void:
	_depart = global_position
	_pv = [Reglages.ZOMBIE_LENT_PV, Reglages.ZOMBIE_RAPIDE_PV, Reglages.ZOMBIE_COUREUR_PV][type]
	if patrouille != Vector2.ZERO:
		_regard = patrouille.normalized()
	$Cri.stream = SON_CRI_GROS if type == Type.LENT else SON_CRI_MAIGRE   # le coureur crie comme le maigre
	$Cri.volume_db = Reglages.SONS_VOLUME
	$Coup.volume_db = Reglages.SONS_VOLUME
	# Le cône est dessiné au sol (calque du sol), les yeux par-dessus le corps, sans ombre
	_cone.draw.connect(_dessiner_cone)
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_yeux.material = sans_ombre
	_yeux.draw.connect(_dessiner_yeux)
	remove_child(_yeux)
	_vue.add_child(_yeux)
	_vue.draw.connect(_dessiner)
	_vue.position = Iso.ecran(global_position)


## Nœuds d'affichage, placés par le niveau.
func visuels() -> Dictionary:
	remove_child(_cone)
	return {"vue": _vue, "sol": _cone}


func _exit_tree() -> void:
	for noeud in [_vue, _cone]:
		if is_instance_valid(noeud):
			noeud.queue_free()


## Appelé par le niveau quand la batte du héros le touche.
func recevoir_coup(degats: int, depuis: Vector2) -> void:
	if _battu:
		return
	_pv -= degats
	$Coup.stream = SONS_COUP.pick_random()
	$Coup.play()
	_recul = depuis.direction_to(global_position) * Reglages.ZOMBIE_RECUL
	_etourdi = Reglages.ZOMBIE_ETOURDI
	_flash = 0.15
	_impact = DUREE_IMPACT
	_point_recherche = depuis
	_regard = global_position.direction_to(depuis)
	_changer_etat(Etat.POURSUITE)
	if _pv <= 0:
		# Battu : il tombe et disparaît en fumée (pas de gore)
		_battu = true
		_disparition = 0.6
		remove_from_group("zombies")
		$CollisionShape2D.set_deferred("disabled", true)


func _degats() -> int:
	return [Reglages.ZOMBIE_LENT_DEGATS, Reglages.ZOMBIE_RAPIDE_DEGATS, Reglages.ZOMBIE_COUREUR_DEGATS][type]


func _vitesse() -> float:
	var poursuite := _etat == Etat.POURSUITE or _etat == Etat.CHERCHE
	if type == Type.COUREUR:
		# Il ne fonce qu'en charge ; il cherche et rentre à petite vitesse
		if _etat == Etat.ESSOUFFLE:
			return 0.0
		if _etat == Etat.POURSUITE:
			return Reglages.ZOMBIE_LENT_VITESSE * Reglages.ZOMBIE_COUREUR_VITESSE_FOIS
		return Reglages.ZOMBIE_COUREUR_VITESSE_PATROUILLE
	if type == Type.LENT:
		return Reglages.ZOMBIE_LENT_VITESSE if poursuite else Reglages.ZOMBIE_LENT_VITESSE_PATROUILLE
	return Reglages.ZOMBIE_RAPIDE_VITESSE if poursuite else Reglages.ZOMBIE_RAPIDE_VITESSE_PATROUILLE


func _portee_vue() -> float:
	return Reglages.ZOMBIE_VUE_DISTANCE_POURSUITE if _etat == Etat.POURSUITE else Reglages.ZOMBIE_VUE_DISTANCE


## Le zombie voit-il le héros ? Dans le cône, assez près, et pas caché derrière un mur.
func _voit_heros() -> bool:
	if not _heros_detectable:
		return false
	var vers_heros := _position_heros - global_position
	var distance := vers_heros.length()
	if distance > _portee_vue():
		return false
	# Tout près, il te sent même de dos (sauf le coureur : seulement dans son cône)
	var dans_cone := (distance < Reglages.ZOMBIE_PORTEE_CONTACT * 1.5 and type != Type.COUREUR) \
		or rad_to_deg(absf(_regard.angle_to(vers_heros))) <= Reglages.ZOMBIE_VUE_ANGLE / 2.0
	if not dans_cone:
		return false
	var rayon := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -8), _position_heros + Vector2(0, -8), MASQUE_DECOR, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(rayon).is_empty()


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_impact = maxf(_impact - delta, 0.0)
	if _battu:
		_disparition = maxf(_disparition - delta, 0.0)
		_suivre()
		_cone.visible = false
		# Il ne bouge plus jamais ; on attend la fin du son de coup avant de l'enlever
		if _disparition == 0.0 and not $Coup.playing:
			queue_free()
		return
	_etourdi = maxf(_etourdi - delta, 0.0)
	_delai_coup = maxf(_delai_coup - delta, 0.0)
	_delai_cri = maxf(_delai_cri - delta, 0.0)

	var voit := _voit_heros()
	if voit:
		_point_recherche = _position_heros
		if _etat != Etat.POURSUITE and _etat != Etat.ESSOUFFLE:
			_changer_etat(Etat.POURSUITE)
			# Il t'a vu : il pousse son cri
			if _delai_cri == 0.0:
				_delai_cri = Reglages.ZOMBIE_DELAI_CRI
				$Cri.play()

	var cible := global_position
	match _etat:
		Etat.PATROUILLE:
			cible = _depart + patrouille if _vers_bout else _depart
			if global_position.distance_to(cible) < 10.0:
				_vers_bout = not _vers_bout
		Etat.POURSUITE:
			# Il fonce vers le héros, ou vers l'endroit où il l'a vu pour la dernière fois
			cible = _point_recherche
			_temps_sans_voir = 0.0 if voit else _temps_sans_voir + delta
			_charge += delta
			if not voit and (_temps_sans_voir > Reglages.ZOMBIE_DELAI_ABANDON or global_position.distance_to(cible) < 10.0):
				_changer_etat(Etat.ESSOUFFLE if type == Type.COUREUR else Etat.CHERCHE)
			elif type == Type.COUREUR and _charge >= Reglages.ZOMBIE_COUREUR_DUREE_CHARGE:
				_changer_etat(Etat.ESSOUFFLE)
		Etat.ESSOUFFLE:
			# Coureur à bout de souffle : il ne bouge plus, puis recharge s'il te voit encore
			_souffle = maxf(_souffle - delta, 0.0)
			if _souffle == 0.0:
				_changer_etat(Etat.POURSUITE if voit else Etat.CHERCHE)
		Etat.CHERCHE:
			# Il va voir, puis regarde autour de lui un moment
			cible = _point_recherche
			if global_position.distance_to(cible) < 10.0 or get_slide_collision_count() > 0 and velocity.length() < 5.0:
				cible = global_position
				_temps_recherche += delta
				_regard = _regard.rotated(sin(_temps_recherche * 2.0) * 2.5 * delta)
			if _temps_recherche > Reglages.ZOMBIE_DELAI_RECHERCHE:
				_changer_etat(Etat.RETOUR)
		Etat.RETOUR:
			cible = _depart
			if global_position.distance_to(_depart) < 10.0:
				_changer_etat(Etat.PATROUILLE)

	if voit and global_position.distance_to(_position_heros) < Reglages.ZOMBIE_PORTEE_CONTACT \
			and _delai_coup == 0.0 and _etourdi == 0.0 and _etat != Etat.ESSOUFFLE:
		_delai_coup = Reglages.ZOMBIE_DELAI_DEGATS
		touche_heros.emit(_degats(), global_position)
		if type == Type.COUREUR:
			_changer_etat(Etat.ESSOUFFLE)   # sa charge s'arrête sur toi

	var direction := global_position.direction_to(cible) if global_position.distance_to(cible) > 4.0 else Vector2.ZERO
	if _etourdi > 0.0:
		direction = Vector2.ZERO
	velocity = direction * _vitesse() + _recul
	_recul = _recul.move_toward(Vector2.ZERO, 2000.0 * delta)
	move_and_slide()
	if direction != Vector2.ZERO:
		_regard = _regard.slerp(direction, minf(8.0 * delta, 1.0)).normalized()
	_temps += delta * (2.0 if _etat == Etat.POURSUITE else 1.0)
	_suivre()
	_cone.queue_redraw()


func _changer_etat(nouvel_etat: Etat) -> void:
	if nouvel_etat == Etat.POURSUITE and _etat != Etat.POURSUITE:
		_charge = 0.0
	if nouvel_etat == Etat.ESSOUFFLE:
		_souffle = Reglages.ZOMBIE_COUREUR_ESSOUFFLE
	_etat = nouvel_etat
	_temps_sans_voir = 0.0
	_temps_recherche = 0.0


## Le dessin suit la position projetée à l'écran.
func _suivre() -> void:
	_vue.position = Iso.ecran(global_position)
	_vue.queue_redraw()
	_yeux.queue_redraw()


## Nom de l'image à afficher (face ou dos, marche) et retournement.
## Coureur : [pose V3, miroir, true, transformation du rebond] (images V3, un seul profil qui regarde à gauche).
func _pose() -> Array:
	var regard := Iso.direction_ecran(_regard)
	if type == Type.COUREUR:
		var anim := Images.v3_animation(PERSO_COUREUR, _temps, velocity.length() > 5.0 and not _battu, false, CADENCE_MARCHE)
		if anim["nom"] != "":
			return [anim["nom"], regard.x > 0.0, true, Transform2D(anim["angle"], anim["decalage"])]
	var poses: Dictionary = POSES[POSES_SECOURS_COUREUR if type == Type.COUREUR else type]
	var liste: Array = poses["dos" if regard.y < -0.1 else "face"]
	var nom: String = liste[0]
	if velocity.length() > 5.0 and not _battu:
		var cycle: Array = liste[1]
		nom = cycle[int(_temps * CADENCE_MARCHE) % cycle.size()]
	var miroir: bool = (regard.x > 0.0) if poses["gauche"] else (regard.x < 0.0)
	return [nom, miroir, false, Transform2D.IDENTITY]


func _dessiner() -> void:
	var v := _vue
	var s := -1.0 if Iso.direction_ecran(_regard).x < 0.0 else 1.0
	v.modulate = Color(2.0, 2.0, 2.0) if _flash > 0.0 else Color.WHITE  # éclair quand il est frappé
	_corps_rotation = 0.0
	if _battu:
		# Il bascule en arrière et s'efface
		var avance := 1.0 - _disparition / 0.6
		v.modulate.a = 1.0 - avance
		_corps_rotation = -s * avance * PI / 2.0
	var rayon_ombre := 34.0 if type == Type.LENT else 24.0
	Dessin.ombre(v, Rect2(-rayon_ombre, -10, rayon_ombre * 2.0, 20))
	var pose := _pose()
	var haut := -120.0
	if pose[2]:
		var base: Transform2D = Transform2D(_corps_rotation, Vector2.ZERO) * pose[3]
		v.draw_set_transform_matrix(base)
		Images.v3_dessiner(v, pose[0], Vector2.ZERO, ECHELLE, pose[1], Color.WHITE, base)
		haut = -Images.v3_taille(pose[0]).y * ECHELLE - 8.0
	elif Images.existe(pose[0]):
		var base := Transform2D(_corps_rotation, Vector2.ZERO)
		v.draw_set_transform_matrix(base)
		Images.dessiner_pieds(v, pose[0], Vector2.ZERO, ECHELLE, pose[1], Color.WHITE, base)
		haut = -Images.region(pose[0]).size.y * ECHELLE - 8.0
	else:
		_dessiner_secours(s)
	v.draw_set_transform(Vector2.ZERO)
	_haut_icone = haut


## Dessin en code (si les images manquent).
func _dessiner_secours(s: float) -> void:
	var pas := sin(_temps * 8.0) * 4.0
	var tangue := sin(_temps * 4.0) * 2.0
	_corps_echelle = Vector2(1.25, 1.25)
	if _battu:
		_corps_echelle *= 1.0 - (1.0 - _disparition / 0.6) * 0.3
	_vue.draw_set_transform(Vector2.ZERO, _corps_rotation, _corps_echelle)
	if type == Type.LENT:
		_dessiner_gros(s, pas, tangue)
	else:
		_dessiner_maigre(s, pas, tangue)


func _dessiner_gros(s: float, pas: float, tangue: float) -> void:
	var v := _vue
	# Jambes courtes
	Dessin.rect(v, Rect2(-16 + pas * 0.5, -22, 13, 20), Palette.ZOMBIE_PANTALON)
	Dessin.rect(v, Rect2(3 - pas * 0.5, -22, 13, 20), Palette.ZOMBIE_PANTALON)
	# Gros ventre en t-shirt
	Dessin.ellipse(v, Vector2(tangue, -46), Vector2(28, 28), Palette.ZOMBIE_TSHIRT)
	# Bras qui pendent
	Dessin.ellipse(v, Vector2(-s * 26 + tangue, -40), Vector2(8, 16), Palette.ZOMBIE_PEAU_OMBRE)
	Dessin.ellipse(v, Vector2(s * 28 + tangue, -42), Vector2(8, 16), Palette.ZOMBIE_PEAU)
	# Tête
	var t := Vector2(s * 4 + tangue, -84)
	Dessin.ellipse(v, t, Vector2(17, 16), Palette.ZOMBIE_PEAU)
	_dessiner_visage(t, s)


func _dessiner_maigre(s: float, pas: float, tangue: float) -> void:
	var v := _vue
	# Jambes fines
	Dessin.rect(v, Rect2(-9 + pas, -34, 7, 32), Palette.ZOMBIE_PANTALON)
	Dessin.rect(v, Rect2(2 - pas, -34, 7, 32), Palette.ZOMBIE_PANTALON)
	# Corps maigre, penché en avant
	Dessin.polygone(v, PackedVector2Array([
		Vector2(-9 + s * 4, -70), Vector2(9 + s * 4, -70), Vector2(9, -32), Vector2(-9, -32)]), Palette.ZOMBIE_TSHIRT)
	# Bras tendus vers l'avant
	v.draw_line(Vector2(s * 6, -64), Vector2(s * 34, -56 + tangue), Palette.CONTOUR, 9.0)
	v.draw_line(Vector2(s * 6, -64), Vector2(s * 34, -56 + tangue), Palette.ZOMBIE_PEAU, 5.0)
	# Tête
	var t := Vector2(s * 8, -82 + tangue)
	Dessin.ellipse(v, t, Vector2(12, 13), Palette.ZOMBIE_PEAU)
	_dessiner_visage(t, s)


func _dessiner_visage(t: Vector2, s: float) -> void:
	# Bouche ouverte ; les grands yeux jaunes sont dessinés par l'enfant « Yeux »
	Dessin.ellipse(_vue, t + Vector2(s * 3, 7), Vector2(4, 3), Palette.CONTOUR, false)
	_yeux_centre = t + Vector2(s * 3, -3)
	_yeux_sens = s


## Gerbe d'étincelles et rayons blancs au point d'impact de la batte.
func _dessiner_impact() -> void:
	if _impact <= 0.0:
		return
	_yeux.draw_set_transform(Vector2.ZERO)
	var avance := 1.0 - _impact / DUREE_IMPACT
	var centre := Vector2(0, _haut_icone * 0.55)
	var nombre := 4 if Qualite.basse else 8
	for i in nombre:
		var direction := Vector2.from_angle(TAU * i / float(nombre) + 0.4)
		var debut := centre + direction * (10.0 + 40.0 * avance)
		_yeux.draw_line(debut, debut + direction * 16.0 * (1.0 - avance), Palette.LAMPE * Color(1, 1, 1, 1.0 - avance), 4.0)
	_yeux.draw_circle(centre, 18.0 * (1.0 - avance), Color(1, 1, 1, 0.6 * (1.0 - avance)))


## « ! », « ? » ou étoiles au-dessus de la tête : sur le calque sans ombre, lisibles dans le noir.
func _dessiner_icone() -> void:
	_yeux.draw_set_transform(Vector2.ZERO)
	if _etourdi > 0.0:
		_dessiner_etoiles(Vector2(0, _haut_icone))
	elif _etat == Etat.ESSOUFFLE:
		_dessiner_essouffle(Vector2(0, _haut_icone))
	elif _etat == Etat.POURSUITE:
		_dessiner_alerte(Vector2(0, _haut_icone))
	elif _etat == Etat.CHERCHE:
		_dessiner_question(Vector2(0, _haut_icone))


## Grands yeux jaunes qui brillent dans le noir (matériau sans ombre) : calque d'yeux de l'image,
## ou yeux dessinés en code.
func _dessiner_yeux() -> void:
	_dessiner_impact()
	if _battu:
		return
	_dessiner_icone()
	var pose := _pose()
	if pose[2]:
		# Image V3 : on redessine seulement ses yeux jaunes, sans ombre, avec leur lueur
		var zone := Images.v3_yeux(pose[0])
		if zone.size == Vector2.ZERO:
			return
		var base_v3: Transform2D = Transform2D(_corps_rotation, Vector2.ZERO) * pose[3]
		_yeux.draw_set_transform_matrix(base_v3)
		var centre := Images.v3_point(pose[0], zone.get_center(), Vector2.ZERO, ECHELLE, pose[1])
		_yeux.draw_circle(centre, 16.0, Palette.ZOMBIE_YEUX_LUEUR)
		_yeux.draw_circle(centre, 9.0, Palette.ZOMBIE_YEUX_LUEUR)
		Images.v3_dessiner(_yeux, pose[0], Vector2.ZERO, ECHELLE, pose[1], Color.WHITE, base_v3, zone)
		return
	var nom_yeux: String = pose[0] + "_yeux"
	if Images.existe(pose[0]):
		if not Images.existe(nom_yeux):
			return   # vu de dos : pas d'yeux
		var base := Transform2D(_corps_rotation, Vector2.ZERO)
		_yeux.draw_set_transform_matrix(base)
		var centre := Images.centre_calque(pose[0], nom_yeux, Vector2.ZERO, ECHELLE, pose[1])
		_yeux.draw_circle(centre, 16.0, Palette.ZOMBIE_YEUX_LUEUR)
		_yeux.draw_circle(centre, 9.0, Palette.ZOMBIE_YEUX_LUEUR)
		Images.dessiner_calque(_yeux, pose[0], nom_yeux, Vector2.ZERO, ECHELLE, pose[1], Color.WHITE, base)
		return
	_yeux.draw_set_transform(Vector2.ZERO, _corps_rotation, _corps_echelle)
	_yeux.draw_circle(_yeux_centre, 13.0, Palette.ZOMBIE_YEUX_LUEUR)
	for dx: float in [-5.0, 5.0]:
		var oeil := _yeux_centre + Vector2(dx, 0)
		_yeux.draw_circle(oeil, 4.5, Palette.ZOMBIE_YEUX)
		_yeux.draw_arc(oeil, 4.5, 0, TAU, 12, Palette.CONTOUR, 2.0)
		_yeux.draw_circle(oeil + Vector2(_yeux_sens, 0), 1.6, Palette.CONTOUR)


func _dessiner_alerte(p: Vector2) -> void:
	# Point d'exclamation : le zombie t'a vu !
	Dessin.polygone(_yeux, PackedVector2Array([
		p + Vector2(-7, -26), p + Vector2(7, -26), p + Vector2(4, -4), p + Vector2(-4, -4)]), Palette.LAMPE)
	Dessin.cercle(_yeux, p + Vector2(0, 5), 5, Palette.LAMPE)


func _dessiner_essouffle(p: Vector2) -> void:
	# Gouttes de sueur qui sautent de sa tête : il reprend son souffle
	for i in 3:
		var vie := fmod(_temps * 1.5 + i / 3.0, 1.0)
		var c := p + Vector2((i - 1) * 20.0, 10.0 - vie * 24.0)
		var goutte := PackedVector2Array([c + Vector2(0, -14), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)])
		var couleur := Palette.LUNE.lightened(0.4)
		couleur.a = 1.0 - vie * 0.6
		_yeux.draw_colored_polygon(goutte, couleur)
		goutte.append(goutte[0])
		_yeux.draw_polyline(goutte, Color(Palette.CONTOUR, couleur.a), 2.0, true)


func _dessiner_etoiles(p: Vector2) -> void:
	# Petites étoiles qui tournent : le zombie est sonné
	for i in 3:
		var a := _temps * 6.0 + TAU * i / 3.0
		var c := p + Vector2(cos(a) * 18.0, sin(a) * 6.0 - 6.0)
		_yeux.draw_circle(c, 7.0, Palette.CONTOUR)
		_yeux.draw_circle(c, 5.0, Palette.LAMPE)


func _dessiner_cone() -> void:
	# Cône de vue dessiné au sol (repère pour le joueur), sans tenir compte des murs
	var demi := deg_to_rad(Reglages.ZOMBIE_VUE_ANGLE / 2.0)
	# Calculé dans le monde, puis projeté à l'écran
	var points := PackedVector2Array([Iso.ecran(global_position)])
	for i in 13:
		var a := _regard.angle() - demi + 2.0 * demi * i / 12.0
		points.append(Iso.ecran(global_position + Vector2(cos(a), sin(a)) * _portee_vue()))
	var couleur := Palette.ZOMBIE_VUE_ALERTE if _etat == Etat.POURSUITE else Palette.ZOMBIE_VUE
	_cone.draw_colored_polygon(points, couleur)


func _dessiner_question(p: Vector2) -> void:
	# Point d'interrogation : le zombie te cherche
	var police := ThemeDB.fallback_font
	_yeux.draw_string_outline(police, p + Vector2(-9, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, 8, Palette.CONTOUR)
	_yeux.draw_string(police, p + Vector2(-9, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.LAMPE)
