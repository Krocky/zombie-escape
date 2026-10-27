extends SceneTree
## Captures de la base tout construit (pas un test, pas lancé par lancer.sh) : SCENE=base|defense,
## POSITIONS="x,y;..." (héros), ZOOM, SANS_UI=1 (interface cachée). Remplit la partie en cours (sauvegarde) :
## toutes les constructions (2 barricades, 2 tourelles), 10 rescapés, tout déjà apparu (pas de chute), fruit prêt ;
## l'efface à la fin. Captures dans $CAPTURES/<scene>_<n>.png.
var f := 0
var h
var positions := []
var partie
func _initialize():
	partie = root.get_node("Partie")
	partie.skin = "heros"; partie.prenom = "Eliott"; partie.remede = 0; partie.remede_annonce = false
	partie.inventaire = {"balles": 2}
	partie.constructions = ["barricade", "atelier", "lampe", "infirmerie", "jardin", "tourelle"]
	partie.poses = [["barricade", Vector2(1560, 1120)], ["atelier", Vector2(1600, 680)], ["lampe", Vector2(870, 1060)],
		["jardin", Vector2(1250, 420)], ["tourelle", Vector2(1000, 1150)], ["barricade", Vector2(1340, 1250)],
		["tourelle", Vector2(560, 700)]]
	partie.balles_tourelles = [25, 0]
	partie.rescapes = 10; partie.lieux_sauves = ["supermarche", "maison", "pharmacie"]
	partie.batiments_vus = ["abri_1", "abri_2", "feu", "barricade", "barricade_2", "atelier", "lampe", "jardin", "tourelle", "tourelle_2"]
	for k in 10: partie.batiments_vus.append("tente_%d" % (k + 1))
	partie.fruit_cueilli = 0.0; partie.fruit = false
	partie.sauvegarder()   # sinon une partie laissée par un test interrompu serait relue à la place
	var scene := OS.get_environment("SCENE")
	if scene == "defense":
		partie.lieu = "defense"
		change_scene_to_file("res://scenes/lieux/defense.tscn")
	else:
		change_scene_to_file("res://scenes/base.tscn")
	for p in OS.get_environment("POSITIONS").split(";", false):
		var xy = p.split(",")
		positions.append(Vector2(float(xy[0]), float(xy[1])))
func _physics_process(_d):
	if current_scene == null or not current_scene.has_node("Monde/Heros"):
		return
	f += 1
	if f == 3:
		h = current_scene.get_node("Monde/Heros")
		if OS.get_environment("SANS_UI") != "":
			for n in ["Interface", "HUD"]:
				if current_scene.has_node(n): current_scene.get_node(n).visible = false
		if OS.get_environment("ZOOM") != "":
			var z := float(OS.get_environment("ZOOM"))
			h.get_node("Camera2D").zoom = Vector2(z, z)
	if f < 4:
		return
	for z in get_nodes_in_group("zombies"):
		z.set_physics_process(false)
	var i := (f - 4) / 50
	if (f - 4) % 50 == 0 and i < positions.size():
		h.position = positions[i]; h.velocity = Vector2.ZERO; h.get_node("Camera2D").reset_smoothing()
	if (f - 4) % 50 == 45 and i < positions.size():
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/%s_%d.png" % [OS.get_environment("SCENE"), i])
	if i >= positions.size():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(partie.fichier()))
		quit()
