extends SceneTree
## Captures d'un lieu (pas un test, pas lancé par lancer.sh) : LIEU=maison|supermarche, POSITIONS="x,y;x,y;..."
## (héros, une capture par position, zombies figés), ZOOM=0.5 pour voir plus large, CACHER=1 pour se cacher
## à chaque position (cachette la plus proche). Captures dans $CAPTURES/<lieu>_<n>.png.
var f := 0
var niveau
var h
var positions := []
func _initialize():
	var lieu := OS.get_environment("LIEU")
	root.get_node("Partie").lieu = lieu
	niveau = load("res://scenes/lieux/%s.tscn" % lieu).instantiate()
	root.add_child(niveau)
	for p in OS.get_environment("POSITIONS").split(";", false):
		var xy = p.split(",")
		positions.append(Vector2(float(xy[0]), float(xy[1])))
func _physics_process(_d):
	f += 1
	if f == 2:
		h = niveau.get_node("Monde/Heros")
		for z in get_nodes_in_group("zombies"):
			z.set_physics_process(false)
		if OS.get_environment("ZOOM") != "":
			var z := float(OS.get_environment("ZOOM"))
			h.get_node("Camera2D").zoom = Vector2(z, z)
	var i := (f - 4) / 40
	if (f - 4) % 40 == 0 and i < positions.size():
		h.position = positions[i]; h.velocity = Vector2.ZERO; h.get_node("Camera2D").reset_smoothing()
	if OS.get_environment("CACHER") != "" and i < positions.size() and (f - 4) % 40 in [12, 38]:
		niveau._sur_cacher()
	if (f - 4) % 40 == 35 and i < positions.size():
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/%s_%d.png" % [OS.get_environment("LIEU"), i])
	if i >= positions.size():
		quit()
