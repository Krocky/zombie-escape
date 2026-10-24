extends SceneTree
var niveau; var f := 0; var z; var h; var d0
func _initialize():
	niveau = load("res://scenes/niveau.tscn").instantiate()
	root.add_child(niveau)
func _physics_process(_d):
	f += 1
	if f == 3:
		z = niveau.get_node("Monde/ZombieLent"); h = niveau.get_node("Monde/Heros")
		h.position = z.position + Vector2(250, 0)
	if f == 5: d0 = z.position.distance_to(h.position)
	if f == 90:
		var d1 = z.position.distance_to(h.position)
		print("poursuite: ", d0, " -> ", d1, " etat=", z._etat, (" OK" if d1 < d0 - 50 and z._etat == 1 else " ECHEC"))
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_b.png")
		h.position = Vector2(2000, 1450)
	if f == 300:
		print("abandon: etat=", z._etat, (" OK" if z._etat != 1 else " ECHEC"))
		quit()
	return false
