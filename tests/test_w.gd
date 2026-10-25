extends SceneTree
## Variété (lot 3 d) : deux parties de suite dans chaque lieu, au moins un objet a changé de place ;
## toutes les places possibles (objets, rescapé, départs de zombies) sont hors des obstacles, les patrouilles
## ne traversent pas le décor ; la fiche de la carte (infos_lieu) compte toujours les bons objets ;
## LIEUX_VARIES = false : tout reste à sa place de la scène.
## Affiche « ECHEC » à chaque vérification ratée.
var g := 0
var etape := 0
var partie
var reg
var echecs := 0
var avant := {}

const LIEUX := ["supermarche", "maison"]
const RAYON := 20.0   # un peu plus que les pieds du héros (14) et du zombie (16)


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")
	partie.skin = "heros"
	partie.lieux_sauves = []
	partie.remede = 0
	_charger()


func _lieu() -> String:
	return LIEUX[etape / 2] if etape < 4 else "supermarche"


func _charger() -> void:
	partie.choisir_lieu(_lieu())
	g = 0
	change_scene_to_file(partie.scene_lieu())


func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_w_%s.png" % n)
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1


## Places tirées des entités qui en ont d'autres : nom -> position (départ retenu pour un zombie ou le rescapé).
func _positions() -> Dictionary:
	var resultat := {}
	for entite in current_scene.get_node("Monde").get_children():
		if "places" in entite and not entite.places.is_empty():
			resultat[String(entite.name)] = entite._depart if "_depart" in entite else entite.position
	return resultat


## Positions et places écrites dans la scène du lieu (avant tirage) : nom -> [position, places, patrouille, patrouilles].
func _scene_lue() -> Dictionary:
	var etat: SceneState = load(partie.scene_lieu()).get_state()
	var resultat := {}
	for i in etat.get_node_count():
		var valeurs := {}
		for k in etat.get_node_property_count(i):
			valeurs[etat.get_node_property_name(i, k)] = etat.get_node_property_value(i, k)
		if valeurs.has("places"):
			resultat[String(etat.get_node_name(i))] = [valeurs.get("position", Vector2.ZERO), valeurs["places"],
				valeurs.get("patrouille", Vector2.ZERO), valeurs.get("patrouilles", PackedVector2Array())]
	return resultat


func _libre(espace: PhysicsDirectSpaceState2D, p: Vector2) -> bool:
	var forme := CircleShape2D.new()
	forme.radius = RAYON
	var requete := PhysicsShapeQueryParameters2D.new()
	requete.shape = forme
	requete.transform = Transform2D(0, p)
	requete.collision_mask = 1
	return espace.intersect_shape(requete, 1).is_empty()


func _passage(espace: PhysicsDirectSpaceState2D, a: Vector2, b: Vector2) -> bool:
	var requete := PhysicsRayQueryParameters2D.create(a, b, 1)
	return espace.intersect_ray(requete).is_empty()


func _verifier_places() -> void:
	var espace: PhysicsDirectSpaceState2D = current_scene.get_world_2d().direct_space_state
	var lue := _scene_lue()
	_verifier("%s : entités avec plusieurs places (%d)" % [_lieu(), lue.size()], lue.size() >= 7)
	for nom in lue:
		var depart: Vector2 = lue[nom][0]
		var toutes := [depart] + Array(lue[nom][1])
		for p in toutes:
			_verifier("%s / %s à %s hors des obstacles" % [_lieu(), nom, p], _libre(espace, p))
		if nom.begins_with("Zombie"):
			var patrouilles := [lue[nom][2]] + Array(lue[nom][3])
			for i in toutes.size():
				var fin: Vector2 = toutes[i] + patrouilles[min(i, patrouilles.size() - 1)]
				_verifier("%s / %s patrouille %s -> %s sans obstacle" % [_lieu(), nom, toutes[i], fin],
					_passage(espace, toutes[i], fin) and _libre(espace, fin))
	var objets := get_nodes_in_group("objets").size()
	_verifier("%s : fiche de la carte = %d objets" % [_lieu(), objets], partie.infos_lieu(_lieu())["objets"].size() == objets)
	# Chaque entité est sur une de ses places
	var ici := _positions()
	for nom in ici:
		var toutes := [lue[nom][0]] + Array(lue[nom][1])
		_verifier("%s / %s sur une de ses places" % [_lieu(), nom], ici[nom] in toutes)


func _physics_process(_d):
	if current_scene == null or not current_scene.has_node("Monde"):
		return
	g += 1
	if g == 10:
		# Zombies figés (ils ne bougent plus : on compare les places tirées)
		for z in get_nodes_in_group("zombies"):
			z.process_mode = Node.PROCESS_MODE_DISABLED
		var ici := _positions()
		print("partie ", etape + 1, " (", _lieu(), ") : ", ici)
		if etape < 4:
			_verifier_places()
		match etape:
			0, 2:
				avant = ici
			1, 3:
				var change := 0
				for nom in ici:
					if nom.begins_with("Objet") and ici[nom] != avant[nom]:
						change += 1
				_verifier("%s : objets qui ont changé de place entre deux parties (%d)" % [_lieu(), change], change >= 1)
				_verifier("%s : tirage différent de la partie précédente" % _lieu(), ici != avant)
			4:
				var lue := _scene_lue()
				var pareil := true
				for nom in ici:
					pareil = pareil and ici[nom] == lue[nom][0]
				_verifier("LIEUX_VARIES = false : tout reste à sa place de la scène", pareil)
	if g == 45:
		_snap(etape + 1)
	if g == 50:
		etape += 1
		if etape == 4:
			reg.LIEUX_VARIES = false
		if etape > 4:
			reg.LIEUX_VARIES = true
			print("test_w : ", "TOUT OK" if echecs == 0 else "%d ECHEC(S)" % echecs)
			quit()
			return
		_charger()
