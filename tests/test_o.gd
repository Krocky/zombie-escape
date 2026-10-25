extends SceneTree
## Poses de dos (images V3) : héros et héroïne qui montent (haut, haut-gauche, haut-droite), descendent,
## s'arrêtent face au haut ; lampe dans la main gauche de l'image ; coup de batte de profil même vers le haut ;
## sans pose de dos complète : poses habituelles.
var g := 0
var skins := ["heros", "heroine"]
var i := 0
var h
var images
var poses := {}
var ancienne = null    # scène à remplacer


func _initialize():
	images = root.get_node("Images")
	_charger()


func _charger():
	var partie = root.get_node("Partie")
	partie.skin = skins[i]
	partie.choisir_lieu("supermarche")
	ancienne = current_scene
	change_scene_to_file("res://scenes/lieux/supermarche.tscn")
	g = 0


func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_o_%s_%s.png" % [skins[i], n])


func _marcher(ecran: Vector2):
	poses = {}
	h.definir_direction(root.get_node("Iso").direction_monde(ecran))


func _noter():
	var a = h._anim_v3()
	poses[a["nom"]] = poses.get(a["nom"], 0) + 1


func _lampe():
	var a = h._anim_v3()
	var nom: String = a["nom"]
	var l = images.v3_lampe(nom, a["dos"])
	var t = images.v3_taille(nom)
	return "%s lampe image %s (%d %% largeur, %d %% hauteur), a l'ecran %s" % [nom, l, int(100 * l.x / t.x), int(100 * l.y / t.y), h._lampe.position.round()]


func _physics_process(_d):
	# Le chargement peut prendre plusieurs pas (rattrapage) : attendre la nouvelle scène
	if current_scene == null or current_scene == ancienne:
		return
	g += 1
	var s: String = skins[i]
	if g == 5:
		h = current_scene.get_node("Monde/Heros")
		for zz in get_nodes_in_group("zombies"):
			zz.position = Vector2(2300, 1550); zz._depart = zz.position; zz.patrouille = Vector2.ZERO
		print("== ", s, " perso: ", h._perso)
		_marcher(Vector2.UP)
	if g > 5 and g < 60: _noter()
	if g == 50: _snap("monte")
	if g == 60:
		print("monte (haut): ", poses, " (attendu ", s, "_back_walk_a et _b) ", _lampe())
		_marcher(Vector2(-1, -1).normalized())
	if g > 60 and g < 110: _noter()
	if g == 100:
		print("monte (haut-gauche): ", poses, " retourne: ", h._lampe.position.x > 0, " ", _lampe())
		_snap("monte_gauche")
		_marcher(Vector2(1, -1).normalized())
	if g == 140:
		print("monte (haut-droite): ", h._anim_v3()["nom"], " ", _lampe())
		h.definir_direction(Vector2.ZERO)
	if g == 175:
		print("arret face au haut: ", h._anim_v3()["nom"], " (attendu ", s, "_back_iddle) ", _lampe(),
			" faisceau vers le haut: ", Vector2.from_angle(h._lampe.rotation).y < -0.5)
		_snap("arret_haut")
		h.attaquer()
	if g == 179:
		print("coup vers le haut: ", h._anim_v3()["nom"], " (attendu ", s, "_attack)")
	if g == 200: _marcher(Vector2.DOWN)
	if g > 200 and g < 250: _noter()
	if g == 245: _snap("descend")
	if g == 250:
		print("descend: ", poses, " (attendu ", s, "_walk_a et _b, pas de back) ", _lampe())
		# Une pose de dos manque : comportement habituel
		var m = images._manifest_v3()
		var sauve = m[s + "_back_walk_b"]
		m.erase(s + "_back_walk_b")
		h._regard = root.get_node("Iso").direction_monde(Vector2.UP)
		print("sans ", s, "_back_walk_b: arret ", images.v3_animation(s, 0.0, false, false, 6.0, true)["nom"],
			", marche ", images.v3_animation(s, 0.1, true, false, 6.0, true)["nom"], " (attendu poses habituelles)")
		m[s + "_back_walk_b"] = sauve
		h.definir_direction(Vector2.ZERO)
	if g == 260:
		i += 1
		if i < skins.size():
			_charger()
		else:
			quit()
