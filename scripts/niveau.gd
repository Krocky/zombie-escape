extends Node2D
## Le niveau : le supermarché abandonné. Relie le HUD au héros et dessine le sol.

const TAILLE := Vector2(2400, 1600)
const CARREAU := 80.0


var _heros_mort := false
var _fini := false
var _ramasses: Array = []
var _total_objets := 0
var _cachette_proche: Node2D = null
var _cachette_occupee: Node2D = null

@onready var _heros := $Monde/Heros


func _ready() -> void:
	$Nuit.color = Palette.NUIT * Color(Reglages.NUIT_CLARTE, Reglages.NUIT_CLARTE, Reglages.NUIT_CLARTE, 1.0)
	$HUD.deplacement.connect(_heros.definir_direction)
	$HUD.attaque.connect(_heros.attaquer)
	_heros.attaque.connect(_sur_attaque)
	_heros.pv_change.connect($HUD.afficher_pv)
	_heros.mort.connect(_sur_mort)
	_heros.bruit.connect(_sur_bruit)
	$HUD.cacher.connect(_sur_cacher)
	_heros.regler_limites_camera(Rect2(Vector2.ZERO, TAILLE))
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.touche_heros.connect(_heros.recevoir_degats)
	_total_objets = get_tree().get_nodes_in_group("objets").size()
	$HUD.afficher_objets(0, _total_objets)


func _physics_process(_delta: float) -> void:
	# Chaque zombie connaît la position du héros (il décide lui-même s'il le voit).
	var detectable := not _heros_mort and _cachette_occupee == null
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.connaitre_heros(_heros.global_position, detectable)
	# Cachette la plus proche, à portée
	_cachette_proche = null
	if not _heros_mort:
		var meilleure := Reglages.CACHETTE_PORTEE
		for cachette in get_tree().get_nodes_in_group("cachettes"):
			var d: float = cachette.distance_a(_heros.global_position)
			if d <= meilleure:
				meilleure = d
				_cachette_proche = cachette
	$HUD.etat_cachette(_cachette_proche != null, _cachette_occupee != null)
	if _heros_mort or _fini or _cachette_occupee:
		return
	# Objets ramassés en marchant dessus
	for objet in get_tree().get_nodes_in_group("objets"):
		if _heros.global_position.distance_to(objet.global_position) <= Reglages.OBJET_PORTEE:
			_ramasses.append(objet.ramasser())
			$HUD.afficher_objets(_ramasses.size(), _total_objets)
	# Sortie atteinte : victoire
	if _heros.global_position.distance_to($Monde/Sortie.global_position) <= Reglages.SORTIE_PORTEE:
		_finir(true)


func _sur_cacher() -> void:
	if _fini:
		return
	if _cachette_occupee:
		_cachette_occupee.occuper(false)
		_cachette_occupee = null
		_heros.sortir_cachette()
	elif _cachette_proche and not _heros_mort:
		_cachette_occupee = _cachette_proche
		_cachette_occupee.occuper(true)
		_heros.se_cacher()


func _sur_bruit(origine: Vector2, rayon: float) -> void:
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.entendre(origine, rayon)


## La batte touche les zombies proches, devant le héros (ou juste au-dessus/en dessous).
func _sur_attaque(origine: Vector2, sens: Vector2) -> void:
	for zombie in get_tree().get_nodes_in_group("zombies"):
		var vers_zombie: Vector2 = zombie.global_position - origine
		if vers_zombie.length() <= Reglages.ATTAQUE_PORTEE and vers_zombie.normalized().dot(sens) > -0.3:
			zombie.recevoir_coup(Reglages.ATTAQUE_DEGATS, origine)


func _sur_mort() -> void:
	_heros_mort = true
	_finir(false)


## Fin de partie : on note le résultat, puis l'écran de fin s'affiche.
func _finir(victoire: bool) -> void:
	if _fini:
		return
	_fini = true
	_heros.definir_direction(Vector2.ZERO)
	Partie.terminer(victoire, _ramasses)
	await get_tree().create_timer(2.0 if not victoire else 0.5).timeout
	get_tree().change_scene_to_file("res://scenes/fin.tscn")


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
