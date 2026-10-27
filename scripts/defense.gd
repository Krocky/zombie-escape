extends "res://scripts/base.gd"
## Niveau 4 : défense de la base (lot 4 h1). Le parking de la base, la nuit (lampe torche, brume), avec les
## constructions du joueur à leurs places (Base._camp : collisions, tourelles avec leurs balles) et chaque rescapé
## gardé devant sa tente. Mécanique des lieux (Niveau : HUD, cœurs, Frapper, Soigner, Guérir, pause), sans cachette
## ni objet à ramasser ; le héros part près de la voiture.
## Vagues (Reglages.DEFENSE_VAGUES) : un zombie de type tiré au hasard toutes les DEFENSE_DELAI_ZOMBIE secondes, à
## une entrée tirée au hasard (DEFENSE_ENTREES) ; quand tous ceux d'une vague sont battus, pause de
## DEFENSE_PAUSE_VAGUES secondes avec « Vague 2 / 3 » au centre. Chaque zombie marche vers le rescapé le plus proche
## (Zombie.marcher_vers), poursuit le héros s'il le voit ; un zombie qui touche un rescapé l'emporte (nuage) : il
## quittera la base (Partie.emporter_rescapes). Les tourelles chargées tirent.
## Flèches autour du héros vers chaque zombie hors de l'écran (couleur du type, plus transparente s'il est loin).
## Fin : victoire quand toutes les vagues sont battues, défaite si le héros n'a plus de cœurs.

const ZOMBIE := preload("res://scenes/zombie.tscn")
const TYPES_ZOMBIES := 3     # Zombie.Type : gros, maigre, coureur
## Flèches : centre (pixels d'écran, depuis les pieds du héros), rayon du cercle où elles sont posées
const CENTRE_FLECHES := Vector2(0, -60)
const RAYON_FLECHES := 100.0
## Un zombie dont la tête est à moins de MARGE_ECRAN du bord n'est pas « à l'écran » ; HAUT_ZOMBIE = sa tête
const MARGE_ECRAN := 20.0
const HAUT_ZOMBIE := 70.0
## Flèche opaque jusqu'à PRES, la plus transparente (ALPHA_LOIN) à partir de LOIN (distances du monde)
const PRES := 500.0
const LOIN := 1800.0
const ALPHA_LOIN := 0.55
## Rayon libre cherché autour d'une entrée pour y faire entrer un zombie (monde), pas vers le centre du parking
const RAYON_ENTREE := 26.0
const PAS_ENTREE := 40.0
## Le zombie sort du sol en entrant (s) ; attente avant l'écran de fin après la dernière vague (s)
const DUREE_ENTREE := 0.4
const ATTENTE_VICTOIRE := 2.5

var _vague := 0              # vague en cours (1 à n)
var _a_venir := []           # types des zombies de la vague pas encore entrés
var _attente := 0.0          # secondes avant le prochain zombie
var _entres := 0             # zombies entrés depuis le début
var _faits := -1             # zombies battus (ou guéris), pour l'objectif du HUD
var _emportes := []          # numéros des tentes (0 = la première) dont le rescapé a été emporté
var _avec_fleche := []       # zombies hors de l'écran (une flèche chacun)
var _fleches := Node2D.new() # flèches autour du héros : sans ombre, par-dessus le décor


func _en_defense() -> bool:
	return true


func _ready() -> void:
	super()
	$Interface.queue_free()   # pas de tiroir, de menu ni de Start pendant l'attaque
	$HUD.mode_defense()
	for rescape in _rescapes.values():
		rescape.actif = true
	rescapes_aux_tentes(true)
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_fleches.material = sans_ombre
	_fleches.z_as_relative = false
	_fleches.z_index = 5
	_fleches.draw.connect(_dessiner_fleches)
	add_child(_fleches)
	_commencer_vague(1, Reglages.DEFENSE_DEBUT)


func _physics_process(delta: float) -> void:
	super(delta)
	var zombies := get_tree().get_nodes_in_group("zombies")
	for tourelle in _tourelles:
		tourelle.viser(zombies, delta)
	_attaquer_rescapes(zombies)
	_actualiser_fleches(zombies)
	_afficher_objectif()
	if not _fini:
		_avancer_vagues(delta, zombies)


## Zombies de chaque vague (au moins une vague d'un zombie, même si la liste des réglages est vide).
func _vagues() -> Array:
	return Reglages.DEFENSE_VAGUES if not Reglages.DEFENSE_VAGUES.is_empty() else [1]


func _total_zombies() -> int:
	var total := 0
	for n in _vagues():
		total += n
	return total


## Vague n (1 = la première) : ses zombies (types au hasard) entreront après `attente` secondes ; annonce au centre.
func _commencer_vague(n: int, attente: float) -> void:
	_vague = n
	_a_venir = []
	for i in _vagues()[n - 1]:
		_a_venir.append(randi() % TYPES_ZOMBIES)
	_attente = attente
	$HUD.afficher_vague(n, _vagues().size())
	$HUD.annoncer("Vague %d / %d" % [n, _vagues().size()])


## Un zombie de la vague entre toutes les DEFENSE_DELAI_ZOMBIE s ; la vague est finie quand ils sont tous battus :
## pause puis vague suivante, ou victoire après la dernière.
func _avancer_vagues(delta: float, zombies: Array) -> void:
	_attente -= delta
	if not _a_venir.is_empty():
		if _attente <= 0.0:
			faire_entrer(_a_venir.pop_front())
			_attente = Reglages.DEFENSE_DELAI_ZOMBIE
	elif zombies.is_empty():
		if _vague < _vagues().size():
			_commencer_vague(_vague + 1, Reglages.DEFENSE_PAUSE_VAGUES)
		else:
			$HUD.annoncer("Base défendue !", ATTENTE_VICTOIRE)
			_finir(true, ATTENTE_VICTOIRE)


## Fait entrer un zombie (Zombie.Type) à une entrée tirée au hasard ; il sort du sol et part vers les rescapés.
func faire_entrer(type: int, entree := Vector2.INF) -> Node2D:
	if entree == Vector2.INF:
		entree = Reglages.DEFENSE_ENTREES.pick_random() if not Reglages.DEFENSE_ENTREES.is_empty() else Vector2(taille.x / 2.0, 110)
	var zombie := ZOMBIE.instantiate()
	zombie.type = type
	zombie.patrouille = Vector2.ZERO
	zombie.position = _place_libre(entree)
	$Monde.add_child(zombie)
	zombie.marcher_vers(_cible(zombie))
	var visuels: Dictionary = zombie.visuels()
	$Reperes.add_child(visuels["repere"])
	$Vue.add_child(visuels["vue"])
	visuels["vue"].scale = Vector2(1.0, 0.1)
	create_tween().tween_property(visuels["vue"], "scale", Vector2.ONE, DUREE_ENTREE).set_trans(Tween.TRANS_BACK)
	zombie.touche_heros.connect(_heros.recevoir_degats)
	_entres += 1
	return zombie


## Point libre (sans décor) le plus près de `p`, en allant vers le centre du parking (une construction ancienne peut
## être posée sur une entrée).
func _place_libre(p: Vector2) -> Vector2:
	var cercle := CircleShape2D.new()
	cercle.radius = RAYON_ENTREE
	var requete := PhysicsShapeQueryParameters2D.new()
	requete.shape = cercle
	requete.collision_mask = 1
	for k in 20:
		var essai := p.move_toward(taille / 2.0, k * PAS_ENTREE)
		requete.transform = Transform2D(0.0, essai)
		if get_world_2d().direct_space_state.intersect_shape(requete, 1).is_empty():
			return essai
	return p


## Rescapés encore là (pas emportés) : numéro de la tente (0 = la première) -> RescapeBase.
func _rescapes_presents() -> Dictionary:
	var presents := {}
	for id: String in _rescapes:
		if not _rescapes[id].emporte():
			presents[int(id.trim_prefix("tente_")) - 1] = _rescapes[id]
	return presents


## Là où va un zombie : le rescapé le plus proche, ou le héros quand il n'y en a plus.
func _cible(zombie: Node2D) -> Vector2:
	var cible: Vector2 = _heros.global_position
	var meilleure := INF
	for rescape in _rescapes_presents().values():
		var d: float = zombie.global_position.distance_to(rescape.global_position)
		if d < meilleure:
			meilleure = d
			cible = rescape.global_position
	return cible


## Chaque zombie marche vers le rescapé le plus proche ; s'il le touche, le rescapé est emporté.
func _attaquer_rescapes(zombies: Array) -> void:
	for zombie in zombies:
		zombie.marcher_vers(_cible(zombie))
		var presents := _rescapes_presents()
		for k in presents:
			if zombie.global_position.distance_to(presents[k].global_position) < Reglages.ZOMBIE_PORTEE_CONTACT:
				presents[k].emporter()
				_emportes.append(k)
				$HUD.annoncer("Un rescapé est emporté !", 1.2)


## Rescapés emportés jusqu'ici (numéros des tentes).
func emportes() -> Array:
	return _emportes


## Zombies qui ont une flèche (hors de l'écran).
func fleches() -> Array:
	return _avec_fleche


func vague() -> int:
	return _vague


## Flèches : un zombie est hors de l'écran quand sa tête n'est pas dans la vue de la caméra.
func _actualiser_fleches(zombies: Array) -> void:
	var vue := (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()).grow(-MARGE_ECRAN)
	_avec_fleche = zombies.filter(func(z: Node2D) -> bool:
		return not vue.has_point(Iso.ecran(z.global_position) + Vector2(0, -HAUT_ZOMBIE)))
	_fleches.position = Iso.ecran(_heros.global_position) + CENTRE_FLECHES
	_fleches.visible = not _heros_mort and not _fini
	_fleches.queue_redraw()


## Une flèche par zombie hors de l'écran, sur un cercle autour du héros, pointée vers lui.
func _dessiner_fleches() -> void:
	for zombie in _avec_fleche:
		if not is_instance_valid(zombie):
			continue
		var sens := (Iso.ecran(zombie.global_position) - _fleches.position).normalized()
		var cote := sens.orthogonal()
		var distance: float = zombie.global_position.distance_to(_heros.global_position)
		var alpha := lerpf(1.0, ALPHA_LOIN, clampf((distance - PRES) / (LOIN - PRES), 0.0, 1.0))
		var couleur: Color = Palette.FLECHES_ZOMBIES[zombie.type]
		var pointe := sens * (RAYON_FLECHES + 42.0)
		var forme := PackedVector2Array([pointe, sens * RAYON_FLECHES + cote * 28.0, sens * (RAYON_FLECHES + 12.0),
			sens * RAYON_FLECHES - cote * 28.0])
		var contour := PackedVector2Array()
		var milieu := sens * (RAYON_FLECHES + 16.0)
		for p in forme:
			contour.append(milieu + (p - milieu) * 1.35)
		_fleches.draw_colored_polygon(contour, Color(Palette.CONTOUR, alpha))
		_fleches.draw_colored_polygon(forme, Color(couleur, alpha))


## Objectif du HUD : tuer tous les zombies (battus / total des vagues).
func _afficher_objectif() -> void:
	if not is_node_ready():
		return
	var faits := _entres - get_tree().get_nodes_in_group("zombies").size()
	if faits != _faits:
		_faits = faits
		$HUD.afficher_objectif("tuer tous les zombies", faits, _total_zombies())


## Fin : rien n'a été ramassé (rien à perdre) ; les rescapés emportés quittent la base.
func _terminer(victoire: bool) -> void:
	Partie.terminer(victoire, [], false, _heros.intact(), _gueris, _emportes)
