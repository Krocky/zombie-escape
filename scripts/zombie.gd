extends CharacterBody2D
## Un zombie : il patrouille, voit le héros dans son cône de vue, entend le bruit,
## poursuit, cherche là où il l'a perdu, puis retourne patrouiller.
## Le niveau lui donne la position du héros (connaitre_heros) et les bruits (entendre).
## Origine = aux pieds (tri par Y).

## Le zombie touche le héros : le niveau transmet les dégâts.
signal touche_heros(degats: int, depuis: Vector2)

enum Type { LENT, RAPIDE }
enum Etat { PATROUILLE, POURSUITE, CHERCHE, RETOUR }

const MASQUE_DECOR := 1   # couche physique des murs et cachettes (bloquent la vue)
const SON_CRI_GROS := preload("res://sons/zombie_gros.mp3")
const SON_CRI_MAIGRE := preload("res://sons/zombie_maigre.mp3")
const SONS_COUP := [preload("res://sons/taper1.mp3"), preload("res://sons/taper2.mp3"), preload("res://sons/taper3.mp3")]

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


## detectable = faux quand le héros est caché ou K.O.
func connaitre_heros(position_heros: Vector2, detectable: bool) -> void:
	_position_heros = position_heros
	_heros_detectable = detectable


## Un bruit a été fait en « origine » ; il porte jusqu'à « rayon ».
func entendre(origine: Vector2, rayon: float) -> void:
	if _battu or _etat == Etat.POURSUITE:
		return
	if global_position.distance_to(origine) <= rayon:
		_point_recherche = origine
		_changer_etat(Etat.CHERCHE)


func _ready() -> void:
	_depart = global_position
	_pv = Reglages.ZOMBIE_LENT_PV if type == Type.LENT else Reglages.ZOMBIE_RAPIDE_PV
	if patrouille != Vector2.ZERO:
		_regard = patrouille.normalized()
	$Cri.stream = SON_CRI_GROS if type == Type.LENT else SON_CRI_MAIGRE
	$Cri.volume_db = Reglages.SONS_VOLUME
	$Coup.volume_db = Reglages.SONS_VOLUME
	# Le cône est dessiné sur un enfant placé sous les personnages et le décor
	$Cone.draw.connect(_dessiner_cone)


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
	return Reglages.ZOMBIE_LENT_DEGATS if type == Type.LENT else Reglages.ZOMBIE_RAPIDE_DEGATS


func _vitesse() -> float:
	var poursuite := _etat == Etat.POURSUITE or _etat == Etat.CHERCHE
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
	var dans_cone := distance < Reglages.ZOMBIE_PORTEE_CONTACT * 1.5 \
		or rad_to_deg(absf(_regard.angle_to(vers_heros))) <= Reglages.ZOMBIE_VUE_ANGLE / 2.0
	if not dans_cone:
		return false
	var rayon := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -8), _position_heros + Vector2(0, -8), MASQUE_DECOR, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(rayon).is_empty()


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	if _battu:
		_disparition = maxf(_disparition - delta, 0.0)
		queue_redraw()
		$Cone.visible = false
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
		if _etat != Etat.POURSUITE:
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
			if not voit and (_temps_sans_voir > Reglages.ZOMBIE_DELAI_ABANDON or global_position.distance_to(cible) < 10.0):
				_changer_etat(Etat.CHERCHE)
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
			and _delai_coup == 0.0 and _etourdi == 0.0:
		_delai_coup = Reglages.ZOMBIE_DELAI_DEGATS
		touche_heros.emit(_degats(), global_position)

	var direction := global_position.direction_to(cible) if global_position.distance_to(cible) > 4.0 else Vector2.ZERO
	if _etourdi > 0.0:
		direction = Vector2.ZERO
	velocity = direction * _vitesse() + _recul
	_recul = _recul.move_toward(Vector2.ZERO, 2000.0 * delta)
	move_and_slide()
	if direction != Vector2.ZERO:
		_regard = _regard.slerp(direction, minf(8.0 * delta, 1.0)).normalized()
	_temps += delta * (2.0 if _etat == Etat.POURSUITE else 1.0)
	queue_redraw()
	$Cone.queue_redraw()


func _changer_etat(nouvel_etat: Etat) -> void:
	_etat = nouvel_etat
	_temps_sans_voir = 0.0
	_temps_recherche = 0.0


func _draw() -> void:
	var s := -1.0 if _regard.x < 0.0 else 1.0
	var pas := sin(_temps * 8.0) * 4.0
	var tangue := sin(_temps * 4.0) * 2.0
	modulate = Color(2.0, 2.0, 2.0) if _flash > 0.0 else Color.WHITE  # éclair quand il est frappé
	if _battu:
		# Il bascule en arrière et s'efface
		var avance := 1.0 - _disparition / 0.6
		modulate.a = 1.0 - avance
		draw_set_transform(Vector2.ZERO, -s * avance * PI / 2.0, Vector2(1.25, 1.25) * (1.0 - avance * 0.3))
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.25, 1.25))
	var rayon_ombre := 34.0 if type == Type.LENT else 24.0
	Dessin.ombre(self, Rect2(-rayon_ombre, -10, rayon_ombre * 2.0, 20))
	if type == Type.LENT:
		_dessiner_gros(s, pas, tangue)
	else:
		_dessiner_maigre(s, pas, tangue)
	if _etourdi > 0.0 and not _battu:
		_dessiner_etoiles(Vector2(0, -116 if type == Type.LENT else -110))
	elif _etat == Etat.POURSUITE and not _battu:
		_dessiner_alerte(Vector2(0, -116 if type == Type.LENT else -110))
	elif _etat == Etat.CHERCHE and not _battu:
		_dessiner_question(Vector2(0, -116 if type == Type.LENT else -110))


func _dessiner_gros(s: float, pas: float, tangue: float) -> void:
	# Jambes courtes
	Dessin.rect(self, Rect2(-16 + pas * 0.5, -22, 13, 20), Palette.ZOMBIE_PANTALON)
	Dessin.rect(self, Rect2(3 - pas * 0.5, -22, 13, 20), Palette.ZOMBIE_PANTALON)
	# Gros ventre en t-shirt
	Dessin.ellipse(self, Vector2(tangue, -46), Vector2(28, 28), Palette.ZOMBIE_TSHIRT)
	# Bras qui pendent
	Dessin.ellipse(self, Vector2(-s * 26 + tangue, -40), Vector2(8, 16), Palette.ZOMBIE_PEAU_OMBRE)
	Dessin.ellipse(self, Vector2(s * 28 + tangue, -42), Vector2(8, 16), Palette.ZOMBIE_PEAU)
	# Tête
	var t := Vector2(s * 4 + tangue, -84)
	Dessin.ellipse(self, t, Vector2(17, 16), Palette.ZOMBIE_PEAU)
	_dessiner_visage(t, s)


func _dessiner_maigre(s: float, pas: float, tangue: float) -> void:
	# Jambes fines
	Dessin.rect(self, Rect2(-9 + pas, -34, 7, 32), Palette.ZOMBIE_PANTALON)
	Dessin.rect(self, Rect2(2 - pas, -34, 7, 32), Palette.ZOMBIE_PANTALON)
	# Corps maigre, penché en avant
	Dessin.polygone(self, PackedVector2Array([
		Vector2(-9 + s * 4, -70), Vector2(9 + s * 4, -70), Vector2(9, -32), Vector2(-9, -32)]), Palette.ZOMBIE_TSHIRT)
	# Bras tendus vers l'avant
	draw_line(Vector2(s * 6, -64), Vector2(s * 34, -56 + tangue), Palette.CONTOUR, 9.0)
	draw_line(Vector2(s * 6, -64), Vector2(s * 34, -56 + tangue), Palette.ZOMBIE_PEAU, 5.0)
	# Tête
	var t := Vector2(s * 8, -82 + tangue)
	Dessin.ellipse(self, t, Vector2(12, 13), Palette.ZOMBIE_PEAU)
	_dessiner_visage(t, s)


func _dessiner_visage(t: Vector2, s: float) -> void:
	# Grands yeux jaunes un peu ahuris et bouche ouverte
	for dx in [-5.0, 5.0]:
		var oeil := t + Vector2(dx + s * 3, -3)
		Dessin.cercle(self, oeil, 4.5, Palette.ZOMBIE_YEUX, false)
		draw_arc(oeil, 4.5, 0, TAU, 12, Palette.CONTOUR, 2.0)
		draw_circle(oeil + Vector2(s, 0), 1.6, Palette.CONTOUR)
	Dessin.ellipse(self, t + Vector2(s * 3, 7), Vector2(4, 3), Palette.CONTOUR, false)


func _dessiner_alerte(p: Vector2) -> void:
	# Point d'exclamation : le zombie t'a vu !
	Dessin.polygone(self, PackedVector2Array([
		p + Vector2(-7, -26), p + Vector2(7, -26), p + Vector2(4, -4), p + Vector2(-4, -4)]), Palette.LAMPE)
	Dessin.cercle(self, p + Vector2(0, 5), 5, Palette.LAMPE)


func _dessiner_etoiles(p: Vector2) -> void:
	# Petites étoiles qui tournent : le zombie est sonné
	for i in 3:
		var a := _temps * 6.0 + TAU * i / 3.0
		var c := p + Vector2(cos(a) * 18.0, sin(a) * 6.0 - 6.0)
		draw_circle(c, 7.0, Palette.CONTOUR)
		draw_circle(c, 5.0, Palette.LAMPE)


func _dessiner_cone() -> void:
	# Cône de vue dessiné au sol (repère pour le joueur), sans tenir compte des murs
	var demi := deg_to_rad(Reglages.ZOMBIE_VUE_ANGLE / 2.0)
	var points := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		var a := _regard.angle() - demi + 2.0 * demi * i / 12.0
		points.append(Vector2(cos(a), sin(a)) * _portee_vue())
	var couleur := Palette.ZOMBIE_VUE_ALERTE if _etat == Etat.POURSUITE else Palette.ZOMBIE_VUE
	$Cone.draw_colored_polygon(points, couleur)


func _dessiner_question(p: Vector2) -> void:
	# Point d'interrogation : le zombie te cherche
	var police := ThemeDB.fallback_font
	draw_string_outline(police, p + Vector2(-9, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, 8, Palette.CONTOUR)
	draw_string(police, p + Vector2(-9, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.LAMPE)
