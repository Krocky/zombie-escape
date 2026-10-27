extends Node2D
## Logique commune à tous les lieux : relie le HUD au héros, gère cachettes, objets, rescapé, sortie et fin,
## et dessine le sol. Le contenu d'un lieu (murs, cachettes, objets, zombies, `Sortie`, départ du héros)
## est dans sa scène (`scenes/lieux/`), qui hérite de `niveau.tscn` et règle taille, graine et débris.
## Un lieu peut avoir un `Rescape` (enlevé s'il est déjà sauvé), et des portes à clef (`Porte`) : la clef
## (Objet de type « clef ») n'est pas un objet à rapporter, elle ouvre la porte de même teinte.
## Monde (physique, IA) en coordonnées monde, caché ; l'affichage isométrique est dans les calques
## SolEffets (ombres), Reperes (cônes de vue, ondes de bruit : sans ombre, au-dessus de la brume du sol)
## et Vue (trié en profondeur), voir Iso.

const CASE := 200.0          # une dalle (3 x 3 carreaux) couvre une case du monde
## Le sol est dessiné en blocs de BLOC x BLOC cases : chaque bloc n'est éclairé que par les
## lumières qui le touchent, et les blocs hors de l'écran ne sont pas dessinés.
const BLOC := 2

## Taille du sol du lieu, dans le monde (multiple de CASE).
@export var taille := Vector2(2400, 1600)
## Sol et débris : toujours le même tirage pour un lieu.
@export var graine := 7
@export var nombre_debris := 26
## Ambiance du lieu (Palette.AMBIANCES) : couleur de la nuit et du faisceau ; vide = nuit et lampe habituelles.
@export var ambiance := ""
## Sol en images V3 (« floor_... », une image par case) ; vide = dalles V2 tirées au hasard (DALLES).
@export var sol := ""
## Zones de sol différent (ex. carrelage de la cuisine) : image -> liste de Rect2 du monde, par-dessus `sol`.
@export var zones_sol := {}
## Dalles : nom et poids du tirage (la dalle propre est la plus fréquente).
const DALLES := {"dalle": 16, "dalle_fissuree": 2, "dalle_tache": 2, "dalle_flaque": 1, "dalle_gravats": 1, "dalle_papiers": 1}
const DEBRIS := ["debris_papiers", "debris_bout", "debris_planche", "debris_planches", "debris_carton"]


var _heros_mort := false
var _fini := false
var _ramasses: Array = []
var _clefs: Array = []     # teintes des clefs ramassées (hors objets à rapporter)
var _total_objets := 0
var _cachette_proche: Node2D = null
var _cachette_occupee: Node2D = null
var _meubles: Array = []   # décor qui devient transparent quand le héros est derrière
var _bandages_soin := Partie.bandages_infirmerie()   # bandages de l'infirmerie (pas des objets à rapporter)
var _soins := 0            # soins déjà faits dans cette mission
var _gueris := 0           # zombies guéris avec une fiole (après le remède)
var _places_objets: Array = []   # toutes les places possibles des objets (les débris les évitent toutes)

@onready var _heros := $Monde/Heros


## Avant le _ready des brouillards : ils couvrent tout le sol projeté.
## Avant le _ready des entités : elles retiennent leur place de départ.
func _enter_tree() -> void:
	_tirer_places()
	var gauche := Iso.ecran(Vector2(0, taille.y)).x
	for brume in [$BrumeSol, $Brouillard]:
		brume.position = Vector2(gauche, 0)
		brume.taille = Vector2(Iso.ecran(Vector2(taille.x, 0)).x - gauche, floorf(Iso.ecran(taille).y))


## Variété : chaque objet, rescapé ou zombie qui a d'autres `places` en prend une au hasard
## (0 = sa place dans la scène) ; au moins un objet change de place par rapport à la partie précédente dans ce lieu.
## Un zombie prend aussi la patrouille qui va avec (`patrouilles`, même ordre).
func _tirer_places() -> void:
	var entites := []
	for entite in $Monde.get_children():
		if "places" in entite and not entite.places.is_empty():
			entites.append(entite)
			if not entite is CharacterBody2D:
				_places_objets.append(entite.position)
				_places_objets.append_array(entite.places)
	if not Reglages.LIEUX_VARIES or entites.is_empty():
		return
	var ancien: Array = Partie.derniers_tirages.get(Partie.lieu, [])
	var tirage := []
	for essai in 20:
		tirage = entites.map(func(e: Node2D) -> int: return randi() % (e.places.size() + 1))
		if ancien.size() != tirage.size():
			break
		# Au moins un objet (pas seulement le rescapé ou le zombie) change de place
		var change := false
		for i in entites.size():
			change = change or (not entites[i] is CharacterBody2D and tirage[i] != ancien[i])
		if change:
			break
	Partie.derniers_tirages[Partie.lieu] = tirage
	for i in entites.size():
		var entite: Node2D = entites[i]
		var choix: int = tirage[i] - 1
		if choix < 0:
			continue
		entite.position = entite.places[choix]
		if "patrouilles" in entite and choix < entite.patrouilles.size():
			entite.patrouille = entite.patrouilles[choix]


func _ready() -> void:
	var nuit: Color = Palette.AMBIANCES[ambiance][0] if Palette.AMBIANCES.has(ambiance) else Palette.NUIT
	$Nuit.color = nuit * Color(Reglages.NUIT_CLARTE, Reglages.NUIT_CLARTE, Reglages.NUIT_CLARTE, 1.0)
	if Palette.AMBIANCES.has(ambiance):
		_heros.couleur_lampe(Palette.AMBIANCES[ambiance][1])
	# Affichage isométrique : chaque entité donne ses nœuds d'affichage
	$Monde.visible = false
	# Rescapé déjà sauvé : il ne réapparaît plus dans ce lieu
	for rescape in get_tree().get_nodes_in_group("rescapes"):
		if Partie.rescape_sauve(Partie.lieu):
			rescape.remove_from_group("rescapes")
			rescape.get_parent().remove_child(rescape)
			rescape.queue_free()
		else:
			rescape.suit_change.connect(_sur_rescape)
	for entite in $Monde.get_children():
		if entite.has_method("voir_a_travers"):
			_meubles.append(entite)
		if entite.has_method("visuels"):
			var visuels: Dictionary = entite.visuels()
			if visuels.has("sol"):
				$SolEffets.add_child(visuels["sol"])
			if visuels.has("repere"):
				$Reperes.add_child(visuels["repere"])
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
	$HUD.soigner.connect(_sur_soigner)
	$HUD.guerir.connect(_sur_guerir)
	$HUD.pause_demandee.connect(mettre_en_pause.bind(true))
	$Pause.reprendre.connect(mettre_en_pause.bind(false))
	$Pause.retour_base.connect(_abandonner)
	# Limites de la caméra : le sol projeté, plus la hauteur des murs du fond
	var gauche := Iso.ecran(Vector2(0, taille.y)).x
	var droite := Iso.ecran(Vector2(taille.x, 0)).x
	var bas := Iso.ecran(taille).y
	_heros.regler_limites_camera(Rect2(gauche - 40, -330, droite - gauche + 80, bas + 400))
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.touche_heros.connect(_heros.recevoir_degats)
	for objet in get_tree().get_nodes_in_group("objets"):
		if not Partie.NOMS_SPECIAUX.has(objet.type):
			_total_objets += 1
	$HUD.afficher_objets(0, _total_objets)
	_afficher_objectif()
	_sur_rescape(false)
	_manger_fruit()
	Qualite.surveiller(true)


func _exit_tree() -> void:
	Qualite.surveiller(false)
	get_tree().paused = false


## Geste « retour » d'Android : ouvre la pause (ou la referme), sauf si la scène le traite elle-même (base).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready() and _pause_au_retour():
		mettre_en_pause(not get_tree().paused)


## Vrai si le geste « retour » ouvre la pause. Une scène héritée qui a son propre _notification (la base) renvoie
## faux : en GDScript, le _notification de chaque classe parente est aussi appelé.
func _pause_au_retour() -> bool:
	return true


## Pause : tout le lieu est figé (zombies, héros, sons, animations), seul le menu Pause tourne.
func mettre_en_pause(pause: bool) -> void:
	if _fini and pause:
		return
	$HUD.relacher()
	_heros.definir_direction(Vector2.ZERO)
	get_tree().paused = pause
	$Pause.ouvrir(pause)


## « Retour à la base » dans la pause : défaite normale (moitié des objets ramassés perdus), écran de fin aussitôt.
func _abandonner() -> void:
	mettre_en_pause(false)
	_finir(false, 0.0)


func _physics_process(delta: float) -> void:
	# Chaque zombie connaît la position du héros (il décide lui-même s'il le voit).
	var detectable := not _heros_mort and _cachette_occupee == null
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.connaitre_heros(_heros.global_position, detectable)
	# Le rescapé suit le héros ; un zombie qui le touche le renvoie se cacher (seul le contact compte)
	for rescape in get_tree().get_nodes_in_group("rescapes"):
		rescape.connaitre_heros(_heros.global_position, _heros.regard(), _cachette_occupee != null or _heros_mort)
		for zombie in get_tree().get_nodes_in_group("zombies"):
			if zombie.global_position.distance_to(rescape.global_position) < Reglages.ZOMBIE_PORTEE_CONTACT:
				rescape.effrayer()
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
	$HUD.afficher_recharge(_heros.recharge())
	$HUD.afficher_fruit(_heros.temps_fruit())
	$HUD.etat_soin(_peut_soigner())
	$HUD.etat_guerison(Partie.remede_trouve(), _zombie_a_guerir() != null)
	# Un grand meuble devant le héros devient transparent : on le voit toujours
	var pieds := Iso.ecran(_heros.global_position) if not _heros_mort and _cachette_occupee == null else Vector2.INF
	for meuble in _meubles:
		meuble.voir_a_travers(pieds, delta)
	if _heros_mort or _fini or _cachette_occupee:
		return
	# Objets ramassés en marchant dessus (une clef va à part : ni compteur, ni objectif, ni base)
	for objet in get_tree().get_nodes_in_group("objets"):
		if _heros.global_position.distance_to(objet.global_position) <= Reglages.OBJET_PORTEE:
			if Partie.NOMS_SPECIAUX.has(objet.type):
				_clefs.append(objet.teinte)
				objet.ramasser()
				$HUD.afficher_clefs(_clefs)
				continue
			_ramasses.append(objet.ramasser())
			$HUD.afficher_objets(_ramasses.size(), _total_objets, _ramasses)
			_afficher_objectif()
	# Porte à clef : elle s'ouvre quand le héros arrive devant avec la bonne clef (la clef sert une fois) ;
	# sans elle, la porte montre la clef qu'il faut
	for porte in get_tree().get_nodes_in_group("portes"):
		if porte.ouverte():
			continue
		var devant: bool = porte.distance_a(_heros.global_position) <= Reglages.PORTE_PORTEE
		if devant and porte.teinte in _clefs:
			_clefs.erase(porte.teinte)
			porte.ouvrir()
			$HUD.afficher_clefs(_clefs)
		else:
			porte.indiquer(devant)
	# Sortie atteinte : victoire
	if _heros.global_position.distance_to($Monde/Sortie.global_position) <= Reglages.SORTIE_PORTEE:
		_finir(true)


## Fruit du potager cueilli à la base : mangé à l'arrivée (même si la mission est perdue ensuite), le héros court
## plus vite un moment (Reglages.FRUIT_VITESSE, FRUIT_DUREE).
func _manger_fruit() -> void:
	if Partie.manger_fruit():
		_heros.accelerer(Reglages.FRUIT_VITESSE, Reglages.FRUIT_DUREE)


func _afficher_objectif() -> void:
	$HUD.afficher_objectif(Partie.texte_objectif(Partie.lieu) if Partie.total_objectif(Partie.lieu) > 0 else "",
		Partie.avancee_objectif(Partie.lieu, Partie.avec_guerisons(_ramasses, _gueris)), Partie.total_objectif(Partie.lieu))


## Le joystick donne une direction à l'écran ; le héros se déplace dans le monde.
func _sur_deplacement(direction: Vector2) -> void:
	_heros.definir_direction(Iso.direction_monde(direction) if direction != Vector2.ZERO else Vector2.ZERO)


## Icône du rescapé dans le HUD : en couleur quand il suit le héros, grisée sinon, cachée s'il n'y en a pas.
func _sur_rescape(_suit: bool) -> void:
	var rescapes := get_tree().get_nodes_in_group("rescapes")
	$HUD.afficher_rescape(not rescapes.is_empty(), _rescape_suit())


func _rescape_suit() -> bool:
	for rescape in get_tree().get_nodes_in_group("rescapes"):
		if rescape.suit():
			return true
	return false


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


## Soin possible : héros blessé, un bandage (infirmerie ou ramassé), soins de la mission pas épuisés.
func _peut_soigner() -> bool:
	return not _fini and not _heros_mort and _heros.blesse() and _soins < Reglages.SOIN_PAR_MISSION \
		and (_bandages_soin > 0 or "bandage" in _ramasses)


## Bouton Soigner : le bandage de l'infirmerie d'abord (on garde ceux ramassés pour l'objectif), sinon un
## bandage ramassé, qui ne sera plus rapporté ni compté dans l'objectif.
func _sur_soigner() -> void:
	if not _peut_soigner():
		return
	if _bandages_soin > 0:
		_bandages_soin -= 1
	else:
		_ramasses.erase("bandage")
		$HUD.afficher_objets(_ramasses.size(), _total_objets, _ramasses)
		_afficher_objectif()
	_soins += 1
	_heros.soigner(Reglages.SOIN_COEURS)


## Zombie qu'une fiole peut guérir : le remède est trouvé, le héros (ni caché ni K.O.) a ramassé une fiole,
## et le plus proche des zombies est à moins de Reglages.GUERIR_PORTEE. Sinon null.
func _zombie_a_guerir() -> Node2D:
	if _fini or _heros_mort or _cachette_occupee or not Partie.remede_trouve() or not "fiole" in _ramasses:
		return null
	var proche: Node2D = null
	var meilleure := Reglages.GUERIR_PORTEE
	for zombie in get_tree().get_nodes_in_group("zombies"):
		var d: float = zombie.global_position.distance_to(_heros.global_position)
		if d <= meilleure:
			meilleure = d
			proche = zombie
	return proche


## Bouton Guérir : la fiole est lancée (plus rapportée ni comptée), le zombie redevient humain ; il comptera
## comme un rescapé sauvé au retour, et pour l'objectif « guérir ».
func _sur_guerir() -> void:
	var zombie := _zombie_a_guerir()
	if zombie == null:
		return
	_ramasses.erase("fiole")
	# Personnage du guéri : le suivant après ceux déjà à la base (comme dans les tentes, Partie.persos_base)
	zombie.guerir(_heros.global_position, Partie.perso_gueri(Partie.rescapes - Partie.lieux_sauves.size() + _gueris))
	_gueris += 1
	$HUD.afficher_objets(_ramasses.size(), _total_objets, _ramasses)
	_afficher_objectif()


func _sur_bruit(origine: Vector2, rayon: float) -> void:
	$Reperes/Ondes.emettre(origine, rayon, rayon > Reglages.BRUIT_PAS)   # plus fort que les pas : coup de batte
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
## attente : secondes avant l'écran de fin (par défaut 0,5 en victoire, 2 en défaite) ; le délai ne compte pas en pause.
func _finir(victoire: bool, attente := -1.0) -> void:
	if _fini:
		return
	_fini = true
	_heros.definir_direction(Vector2.ZERO)
	Partie.terminer(victoire, _ramasses, victoire and _rescape_suit(), _heros.intact(), _gueris)
	if attente < 0.0:
		attente = 0.5 if victoire else 2.0
	if attente > 0.0:
		await get_tree().create_timer(attente, false).timeout
	get_tree().change_scene_to_file("res://scenes/fin.tscn")


# Sol tiré une fois, par bloc : bloc (Vector2i) -> [[nom, rectangle à l'écran, retourné], ...]
# (sol V3 : [nom, rectangle du monde, coin de sa case])
var _dalles := {}
var _debris := {}


func _tirer_sol() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	if sol != "" and Images.existe(sol):
		_tirer_sol_v3()
	else:
		_tirer_dalles(rng)
	_tirer_debris(rng)


## Sol en images V3 : chaque case reçoit l'image de `sol`, ou celle de la zone qui la couvre ; une case à
## cheval sur une zone est coupée (rectangles du monde, projetés avec leur morceau de l'image).
func _tirer_sol_v3() -> void:
	var colonnes := int(taille.x / CASE)
	var lignes := int(taille.y / CASE)
	for j in lignes:
		for i in colonnes:
			var case := Rect2(Vector2(i, j) * CASE, Vector2(CASE, CASE))
			var bloc := Vector2i(i, j) / BLOC
			if not _dalles.has(bloc):
				_dalles[bloc] = []
			var couverte := false
			var morceaux := []
			for nom in zones_sol:
				if not Images.existe(nom):
					continue
				for zone: Rect2 in zones_sol[nom]:
					if zone.encloses(case):
						couverte = true
						morceaux = [[nom, case]]
					elif zone.intersects(case) and not couverte:
						morceaux.append([nom, zone.intersection(case)])
			if not couverte:
				morceaux.push_front([sol, case])
			for m in morceaux:
				_dalles[bloc].append([m[0], m[1], case.position])


func _tirer_dalles(rng: RandomNumberGenerator) -> void:
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
			var bloc := Vector2i(i, j) / BLOC
			if not _dalles.has(bloc):
				_dalles[bloc] = []
			if Images.existe(nom):
				var r := Images.region(nom)
				var e := 2.0 * CASE * Iso.K / r.size.x
				_dalles[bloc].append([nom, Rect2(haut - Vector2(r.size.x * e / 2.0, 0), r.size * e), rng.randf() < 0.5])
			else:
				_dalles[bloc].append(["", Rect2(haut, Vector2(CASE, CASE)), false])


func _tirer_debris(rng: RandomNumberGenerator) -> void:
	# Débris au sol, hors des obstacles et loin des objets et de la sortie
	var interdits := []
	for entite in $Monde.get_children():
		if entite is StaticBody2D and "taille" in entite:
			interdits.append(Rect2(entite.position + Vector2(-entite.taille.x / 2.0, -entite.taille.y), entite.taille).grow(50))
		elif entite is Node2D and not entite is CharacterBody2D:
			interdits.append(Rect2(entite.position - Vector2(70, 70), Vector2(140, 140)))
	for p in _places_objets:
		interdits.append(Rect2(p - Vector2(70, 70), Vector2(140, 140)))
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
			var bloc := Vector2i(p / CASE) / BLOC
			if not _debris.has(bloc):
				_debris[bloc] = []
			_debris[bloc].append([nom, Rect2(Iso.ecran(p) - Vector2(r.size.x, r.size.y * 1.6) * e / 2.0, r.size * e), rng.randf() < 0.5])
			interdits.append(Rect2(p - Vector2(60, 60), Vector2(120, 120)))
			places += 1
	# Blocs de l'arrière vers l'avant (la tranche d'une dalle est cachée par celles de devant),
	# puis les débris par-dessus toutes les dalles
	var blocs := _dalles.keys()
	blocs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	var position_sol := 0
	for liste in [_dalles, _debris]:
		for bloc in blocs:
			if liste.has(bloc):
				var noeud := Node2D.new()
				noeud.draw.connect(_dessiner_sol.bind(noeud, liste[bloc]))
				add_child(noeud)
				move_child(noeud, position_sol)   # sous tout le reste du niveau
				position_sol += 1


## Coins (haut, droit, avant, gauche) d'une image de sol V3 en coordonnées de texture (0 à 1), un peu
## rentrés pour ne pas prendre le bord transparent du losange (sinon un joint sombre entre les cases).
const SOL_V3_UV := [Vector2(0.5, 0.008), Vector2(0.992, 0.5), Vector2(0.5, 0.992), Vector2(0.008, 0.5)]


func _dessiner_sol(noeud: Node2D, morceaux: Array) -> void:
	# Sol V3 : morceaux [nom, rectangle du monde, coin de sa case], un tableau de triangles par image
	# (une seule commande de dessin par image et par bloc)
	var tableaux := {}   # nom -> [points, uvs, indices]
	for morceau in morceaux:
		if not (morceau.size() == 3 and morceau[2] is Vector2):
			continue
		if not tableaux.has(morceau[0]):
			tableaux[morceau[0]] = [PackedVector2Array(), PackedVector2Array(), PackedInt32Array()]
		var t: Array = tableaux[morceau[0]]
		var r: Rect2 = morceau[1]
		var debut: int = t[0].size()
		for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			t[0].append(Iso.ecran(p))
			var u: Vector2 = (p - morceau[2]) / CASE   # (0,0) haut, (1,0) droit, (0,1) gauche
			t[1].append(SOL_V3_UV[0] + (SOL_V3_UV[1] - SOL_V3_UV[0]) * u.x + (SOL_V3_UV[3] - SOL_V3_UV[0]) * u.y)
		for i in [0, 1, 2, 0, 2, 3]:
			t[2].append(debut + i)
	for nom in tableaux:
		var t: Array = tableaux[nom]
		var blanc := PackedColorArray()
		blanc.resize(t[0].size())
		blanc.fill(Color.WHITE)
		RenderingServer.canvas_item_add_triangle_array(noeud.get_canvas_item(), t[2], t[0], blanc, t[1],
			PackedInt32Array(), PackedFloat32Array(), Images.texture(nom).get_rid())
	for morceau in morceaux:
		if morceau.size() == 3 and morceau[2] is Vector2:
			continue
		if morceau[0] != "":
			Images.dessiner(noeud, morceau[0], morceau[1], morceau[2])
		else:
			# Secours : losange de carrelage
			var haut: Vector2 = morceau[1].position
			var c := Iso.coins(Rect2(Iso.monde(haut), Vector2(CASE, CASE)))
			Dessin.polygone(noeud, PackedVector2Array([c[3], c[2], c[1], c[0]]), Palette.SOL)
