extends SceneTree
## Régression : un zombie battu ne doit jamais revivre, même si son son de coup joue encore.
var niveau; var f := 0; var h; var zr; var p0
func _initialize():
	niveau = load("res://scenes/niveau.tscn").instantiate()
	root.add_child(niveau); current_scene = niveau
func _physics_process(_d):
	f += 1
	if f == 3:
		h = niveau.get_node("Monde/Heros"); zr = niveau.get_node("Monde/ZombieRapide")
		h.position = zr.position + Vector2(-60, 0)
		zr.recevoir_coup(5, h.position)   # battu d'un coup
	if f == 50 and is_instance_valid(zr):
		p0 = zr.position
	if f > 3 and is_instance_valid(zr) and f < 200:
		# Simule un son de coup encore en cours (comme sur la tablette)
		if not zr.get_node("Coup").playing: zr.get_node("Coup").play()
	if f == 200:
		if is_instance_valid(zr): print("vivant? pv=", zr._pv, " immobile: ", zr.position == p0, " hors groupe: ", not zr.is_in_group("zombies"), " etat: ", zr._etat, " visible: ", zr.modulate.a)
	if f == 400:
		print("enleve apres le son: ", not is_instance_valid(zr)); quit()
	return false
