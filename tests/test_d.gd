extends SceneTree
var niveau; var f := 0; var h; var zr; var zl; var pvs := []
const E = ["PATROUILLE","POURSUITE","CHERCHE","RETOUR"]
func _initialize():
	niveau = load("res://scenes/lieux/supermarche.tscn").instantiate()
	root.add_child(niveau); current_scene = niveau
func _touch(idx, pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = idx; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_d_%s.png" % n)
func _physics_process(_d):
	f += 1
	var taille = root.get_visible_rect().size
	var cacher = taille - Vector2(130, 300)
	var frapper = taille - Vector2(130, 130)
	if f == 3:
		h = niveau.get_node("Monde/Heros"); zr = niveau.get_node("Monde/ZombieRapide"); zl = niveau.get_node("Monde/ZombieLent")
		h.pv_change.connect(func(p, m): pvs.append(p))
		zr.position = Vector2(2200, 1450); zr.patrouille = Vector2.ZERO; zr._depart = zr.position  # écarté
		# Test 1 : héros DERRIERE le zombie lent (qui regarde à droite), à 150 px
		zl.patrouille = Vector2.ZERO; zl._depart = zl.position
		h.position = zl.position + Vector2(-150, 0); h.get_node("Camera2D").reset_smoothing()
	if f == 30: print("1 derriere a 150px, immobile: ", E[zl._etat], " (attendu PATROUILLE)")
	if f == 31: _touch(1, frapper, true)
	if f == 37: _touch(1, frapper, false)
	if f == 40: print("2 apres coup de batte (bruit): ", E[zl._etat], " (attendu CHERCHE ou POURSUITE)"); _snap("bruit")
	if f == 41:
		# Test 3 : de l'autre côté d'une étagère, devant lui mais caché par le mur
		zl.position = Vector2(650, 760); zl._depart = zl.position; zl._changer_etat(0); zl._regard = Vector2.UP
		h.position = Vector2(650, 380); h.get_node("Camera2D").reset_smoothing()
	if f == 60: print("3 derriere etagere: ", E[zl._etat], " (attendu PATROUILLE)")
	if f == 61:
		zl._regard = Vector2.RIGHT
		h.position = Vector2(950, 760)
	if f == 80: print("4 devant lui a 300px: ", E[zl._etat], " (attendu POURSUITE)")
	if f == 81:
		# Test 5 : se cacher dans Carton2 (250, 870) poursuivi
		h.position = Vector2(250, 760); zl.position = Vector2(550, 760); zl._point_recherche = h.position
		h.get_node("Camera2D").reset_smoothing()
	if f == 84: _touch(1, cacher, true)
	if f == 92: _touch(1, cacher, false); print("5 cache: ", h._cache)
	if f == 100: _snap("cache")
	if f == 400: print("6 apres 5s cache: ", E[zl._etat], " pv=", pvs, " (attendu CHERCHE/RETOUR/PATROUILLE, pas de degats)")
	if f == 401: _touch(1, cacher, true)
	if f == 409: _touch(1, cacher, false)
	if f == 416: print("7 sorti: ", not h._cache)
	if f == 425: quit()
	return false
