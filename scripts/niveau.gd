extends Node2D
## Le niveau : le supermarché abandonné. Relie le HUD au héros et dessine le sol.

const TAILLE := Vector2(2400, 1600)
const CARREAU := 80.0


var _heros_mort := false

@onready var _heros := $Monde/Heros


func _ready() -> void:
	$HUD.deplacement.connect(_heros.definir_direction)
	$HUD.attaque.connect(_heros.attaquer)
	_heros.attaque.connect(_sur_attaque)
	_heros.pv_change.connect($HUD.afficher_pv)
	_heros.mort.connect(_sur_mort)
	_heros.regler_limites_camera(Rect2(Vector2.ZERO, TAILLE))
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.touche_heros.connect(_heros.recevoir_degats)


func _physics_process(_delta: float) -> void:
	# Chaque zombie connaît la position du héros (il décide lui-même s'il le voit).
	var position_heros: Vector2 = Vector2.INF if _heros_mort else _heros.global_position
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.connaitre_position_heros(position_heros)


## La batte touche les zombies proches, devant le héros (ou juste au-dessus/en dessous).
func _sur_attaque(origine: Vector2, sens: Vector2) -> void:
	for zombie in get_tree().get_nodes_in_group("zombies"):
		var vers_zombie: Vector2 = zombie.global_position - origine
		if vers_zombie.length() <= Reglages.ATTAQUE_PORTEE and vers_zombie.normalized().dot(sens) > -0.3:
			zombie.recevoir_coup(Reglages.ATTAQUE_DEGATS, origine)


## Étape (c) : en attendant l'écran « Retour à la base » (étape e), on recommence le niveau.
func _sur_mort() -> void:
	_heros_mort = true
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, TAILLE), Palette.SOL)
	var x := CARREAU
	while x < TAILLE.x:
		draw_line(Vector2(x, 0), Vector2(x, TAILLE.y), Palette.SOL_JOINT, 3.0)
		x += CARREAU
	var y := CARREAU
	while y < TAILLE.y:
		draw_line(Vector2(0, y), Vector2(TAILLE.x, y), Palette.SOL_JOINT, 3.0)
		y += CARREAU
