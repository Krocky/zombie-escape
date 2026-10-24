extends CharacterBody2D
## Un zombie : il patrouille, poursuit le héros s'il le repère, puis abandonne.
## Le niveau lui donne la position du héros (connaitre_position_heros).
## Origine = aux pieds (tri par Y).

## Le zombie touche le héros : le niveau transmet les dégâts.
signal touche_heros(degats: int, depuis: Vector2)

enum Type { LENT, RAPIDE }
enum Etat { PATROUILLE, POURSUITE, RETOUR }

@export var type := Type.LENT
## Point de patrouille, relatif à la position de départ : il fait l'aller-retour.
@export var patrouille := Vector2(300, 0)

var _etat := Etat.PATROUILLE
var _depart := Vector2.ZERO
var _vers_bout := true
var _position_heros := Vector2.INF
var _temps_loin := 0.0
var _regarde_gauche := false
var _temps := 0.0
var _pv := 1
var _recul := Vector2.ZERO
var _etourdi := 0.0
var _delai_coup := 0.0
var _flash := 0.0
var _disparition := 0.0   # > 0 : le zombie est battu et disparaît


func connaitre_position_heros(position_heros: Vector2) -> void:
	_position_heros = position_heros


func _ready() -> void:
	_depart = global_position
	_pv = Reglages.ZOMBIE_LENT_PV if type == Type.LENT else Reglages.ZOMBIE_RAPIDE_PV


## Appelé par le niveau quand la batte du héros le touche.
func recevoir_coup(degats: int, depuis: Vector2) -> void:
	if _disparition > 0.0:
		return
	_pv -= degats
	_recul = depuis.direction_to(global_position) * Reglages.ZOMBIE_RECUL
	_etourdi = Reglages.ZOMBIE_ETOURDI
	_flash = 0.15
	_changer_etat(Etat.POURSUITE)
	if _pv <= 0:
		# Battu : il tombe et disparaît en fumée (pas de gore)
		_disparition = 0.6
		remove_from_group("zombies")
		$CollisionShape2D.set_deferred("disabled", true)


func _degats() -> int:
	return Reglages.ZOMBIE_LENT_DEGATS if type == Type.LENT else Reglages.ZOMBIE_RAPIDE_DEGATS


func _vitesse() -> float:
	if type == Type.LENT:
		return Reglages.ZOMBIE_LENT_VITESSE if _etat == Etat.POURSUITE else Reglages.ZOMBIE_LENT_VITESSE_PATROUILLE
	return Reglages.ZOMBIE_RAPIDE_VITESSE if _etat == Etat.POURSUITE else Reglages.ZOMBIE_RAPIDE_VITESSE_PATROUILLE


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	if _disparition > 0.0:
		_disparition -= delta
		queue_redraw()
		if _disparition <= 0.0:
			queue_free()
		return
	_etourdi = maxf(_etourdi - delta, 0.0)
	_delai_coup = maxf(_delai_coup - delta, 0.0)
	var distance_heros := global_position.distance_to(_position_heros)
	var cible := global_position
	match _etat:
		Etat.PATROUILLE, Etat.RETOUR:
			if distance_heros < Reglages.ZOMBIE_DISTANCE_DETECTION:
				_changer_etat(Etat.POURSUITE)
			elif _etat == Etat.RETOUR:
				cible = _depart
				if global_position.distance_to(_depart) < 10.0:
					_changer_etat(Etat.PATROUILLE)
			else:
				cible = _depart + patrouille if _vers_bout else _depart
				if global_position.distance_to(cible) < 10.0:
					_vers_bout = not _vers_bout
		Etat.POURSUITE:
			cible = _position_heros
			_temps_loin = _temps_loin + delta if distance_heros > Reglages.ZOMBIE_DISTANCE_ABANDON else 0.0
			if _temps_loin > Reglages.ZOMBIE_DELAI_ABANDON:
				_changer_etat(Etat.RETOUR)

	if _etat == Etat.POURSUITE and distance_heros < Reglages.ZOMBIE_PORTEE_CONTACT and _delai_coup == 0.0 and _etourdi == 0.0:
		_delai_coup = Reglages.ZOMBIE_DELAI_DEGATS
		touche_heros.emit(_degats(), global_position)

	var direction := global_position.direction_to(cible) if global_position.distance_to(cible) > 4.0 else Vector2.ZERO
	if _etourdi > 0.0:
		direction = Vector2.ZERO
	velocity = direction * _vitesse() + _recul
	_recul = _recul.move_toward(Vector2.ZERO, 2000.0 * delta)
	move_and_slide()
	if absf(direction.x) > 0.1:
		_regarde_gauche = direction.x < 0.0
	_temps += delta * (2.0 if _etat == Etat.POURSUITE else 1.0)
	queue_redraw()


func _changer_etat(nouvel_etat: Etat) -> void:
	_etat = nouvel_etat
	_temps_loin = 0.0


func _draw() -> void:
	var s := -1.0 if _regarde_gauche else 1.0
	var pas := sin(_temps * 8.0) * 4.0
	var tangue := sin(_temps * 4.0) * 2.0
	modulate = Color(2.0, 2.0, 2.0) if _flash > 0.0 else Color.WHITE  # éclair quand il est frappé
	if _disparition > 0.0:
		# Il bascule en arrière et s'efface
		var avance := 1.0 - _disparition / 0.6
		modulate.a = 1.0 - avance
		draw_set_transform(Vector2.ZERO, -s * avance * PI / 2.0, Vector2(1.25, 1.25) * (1.0 - avance * 0.3))
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.25, 1.25))
	Dessin.ellipse(self, Vector2.ZERO, Vector2(26 if type == Type.LENT else 18, 8), Palette.OMBRE, false)
	if type == Type.LENT:
		_dessiner_gros(s, pas, tangue)
	else:
		_dessiner_maigre(s, pas, tangue)
	if _etourdi > 0.0 and _disparition <= 0.0:
		_dessiner_etoiles(Vector2(0, -116 if type == Type.LENT else -110))
	elif _etat == Etat.POURSUITE and _disparition <= 0.0:
		_dessiner_alerte(Vector2(0, -116 if type == Type.LENT else -110))


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
