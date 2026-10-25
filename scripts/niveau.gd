extends Node2D
## Logique commune à tous les lieux : relie le HUD au héros, gère cachettes, objets, sortie et fin,
## et dessine le sol. Le contenu d'un lieu (murs, cachettes, objets, zombies, `Sortie`, départ du héros)
## est dans sa scène (`scenes/lieux/`), qui hérite de `niveau.tscn` et règle taille, graine et débris.
## Monde (physique, IA) en coordonnées monde, caché ; l'affichage isométrique est dans les calques
## SolEffets (ombres, cônes de vue) et Vue (trié en profondeur), voir Iso.

const CASE := 200.0          # une dalle (3 x 3 carreaux) couvre une case du monde

## Taille du sol du lieu, dans le monde (multiple de CASE).
@export var taille := Vector2(2400, 1600)
## Sol et débris : toujours le même tirage pour un lieu.
@export var graine := 7
@export var nombre_debris := 26
## Dalles : nom et poids du tirage (la dalle propre est la plus fréquente).
const DALLES := {"dalle": 16, "dalle_fissuree": 2, "dalle_tache": 2, "dalle_flaque": 1, "dalle_gravats": 1, "dalle_papiers": 1}
const DEBRIS := ["debris_papiers", "debris_bout", "debris_planche", "debris_planches", "debris_carton"]


var _heros_mort := false
var _fini := false
var _ramasses: Array = []
var _total_objets := 0
var _cachette_proche: Node2D = null
var _cachette_occupee: Node2D = null

@onready var _heros := $Monde/Heros


## Avant le _ready des brouillards : ils couvrent tout le sol projeté.
func _enter_tree() -> void:
	var gauche := Iso.ecran(Vector2(0, taille.y)).x
	for brume in [$BrumeSol, $Brouillard]:
		brume.position = Vector2(gauche, 0)
		brume.taille = Vector2(Iso.ecran(Vector2(taille.x, 0)).x - gauche, floorf(Iso.ecran(taille).y))


func _ready() -> void:
	$Nuit.color = Palette.NUIT * Color(Reglages.NUIT_CLARTE, Reglages.NUIT_CLARTE, Reglages.NUIT_CLARTE, 1.0)
	# Affichage isométrique : chaque entité donne ses nœuds d'affichage
	$Monde.visible = false
	for entite in $Monde.get_children():
		if entite.has_method("visuels"):
			var visuels: Dictionary = entite.visuels()
			if visuels.has("sol"):
				$SolEffets.add_child(visuels["sol"])
			if visuels.has("vue"):
				$Vue.add_child(visuels["vue"])
	_tirer_sol()
	$HUD.deplacement.connect(_sur_deplacement)
	$HUD.attaque.connect(_heros.attaquer)
	_heros.attaque.connect(_sur_attaque)
	_heros.pv_change.connect($HUD.afficher_pv)
	_heros.mort.connect(_sur_mort)
	_heros.bruit.connect(_sur_bruit)
	$HUD.cacher.connect(_sur_cacher)
	# Limites de la caméra : le sol projeté, plus la hauteur des murs du fond
	var gauche := Iso.ecran(Vector2(0, taille.y)).x
	var droite := Iso.ecran(Vector2(taille.x, 0)).x
	var bas := Iso.ecran(taille).y
	_heros.regler_limites_camera(Rect2(gauche - 40, -330, droite - gauche + 80, bas + 400))
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.touche_heros.connect(_heros.recevoir_degats)
	_total_objets = get_tree().get_nodes_in_group("objets").size()
	$HUD.afficher_objets(0, _total_objets)
	_afficher_objectif()


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
			$HUD.afficher_objets(_ramasses.size(), _total_objets, _ramasses)
			_afficher_objectif()
	# Sortie atteinte : victoire
	if _heros.global_position.distance_to($Monde/Sortie.global_position) <= Reglages.SORTIE_PORTEE:
		_finir(true)


func _afficher_objectif() -> void:
	$HUD.afficher_objectif(Partie.texte_objectif(Partie.lieu) if Partie.total_objectif(Partie.lieu) > 0 else "",
		Partie.avancee_objectif(Partie.lieu, _ramasses), Partie.total_objectif(Partie.lieu))


## Le joystick donne une direction à l'écran ; le héros se déplace dans le monde.
func _sur_deplacement(direction: Vector2) -> void:
	_heros.definir_direction(Iso.direction_monde(direction) if direction != Vector2.ZERO else Vector2.ZERO)


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
			zombie.recevoir_coup(Partie.degats_batte(), origine)


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


# Sol tiré une fois : [nom, rectangle à l'écran, retourné] pour les dalles puis les débris
var _sol := []


func _tirer_sol() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var total := 0
	for nom in DALLES:
		total += DALLES[nom]
	var colonnes := int(taille.x / CASE)
	var lignes := int(taille.y / CASE)
	# De l'arrière vers l'avant : la tranche de chaque dalle est cachée par la suivante
	for somme in colonnes + lignes - 1:
		for i in colonnes:
			var j := somme - i
			if j < 0 or j >= lignes:
				continue
			var tirage := rng.randi() % total
			var nom := "dalle"
			for n in DALLES:
				tirage -= DALLES[n]
				if tirage < 0:
					nom = n
					break
			if not Images.existe(nom):
				nom = "dalle"
			var haut := Iso.ecran(Vector2(i, j) * CASE)
			if Images.existe(nom):
				var r := Images.region(nom)
				var e := 2.0 * CASE * Iso.K / r.size.x
				_sol.append([nom, Rect2(haut - Vector2(r.size.x * e / 2.0, 0), r.size * e), rng.randf() < 0.5])
			else:
				_sol.append(["", Rect2(haut, Vector2(CASE, CASE)), false])
	# Débris au sol, hors des obstacles et loin des objets et de la sortie
	var interdits := []
	for entite in $Monde.get_children():
		if entite is StaticBody2D and "taille" in entite:
			interdits.append(Rect2(entite.position + Vector2(-entite.taille.x / 2.0, -entite.taille.y), entite.taille).grow(50))
		elif entite is Node2D and not entite is CharacterBody2D:
			interdits.append(Rect2(entite.position - Vector2(70, 70), Vector2(140, 140)))
	var places := 0
	for essai in nombre_debris * 10:
		if places >= nombre_debris:
			break
		var p := Vector2(rng.randf_range(120, taille.x - 80), rng.randf_range(240, taille.y - 60))
		var libre := true
		for r in interdits:
			if r.has_point(p):
				libre = false
		var nom: String = DEBRIS[rng.randi() % DEBRIS.size()]
		if libre and Images.existe(nom):
			var r := Images.region(nom)
			var e := rng.randf_range(0.3, 0.42)
			_sol.append([nom, Rect2(Iso.ecran(p) - Vector2(r.size.x, r.size.y * 1.6) * e / 2.0, r.size * e), rng.randf() < 0.5])
			interdits.append(Rect2(p - Vector2(60, 60), Vector2(120, 120)))
			places += 1


func _draw() -> void:
	for morceau in _sol:
		if morceau[0] != "":
			Images.dessiner(self, morceau[0], morceau[1], morceau[2])
		else:
			# Secours : losange de carrelage
			var haut: Vector2 = morceau[1].position
			var c := Iso.coins(Rect2(Iso.monde(haut), Vector2(CASE, CASE)))
			Dessin.polygone(self, PackedVector2Array([c[3], c[2], c[1], c[0]]), Palette.SOL)
