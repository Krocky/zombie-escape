extends SceneTree
## Lot 2 (d) : la maison. Carte -> Maison disponible (fiche : 3 zombies, 5 objets) -> Y aller ;
## pièces reliées par des portes (on passe par les trous, pas à travers les cloisons) ;
## 3 cachettes (armoire, dessous de lit, baignoire) : on s'y cache, un zombie tout près ne voit rien ;
## sortie par la porte d'entrée -> Victoire « de la maison ».
var f := 0
var partie
var h
var pvs := []
const E = ["PATROUILLE", "POURSUITE", "CHERCHE", "RETOUR"]
const CACHETTES := {"Armoire": Vector2(165, 820), "Lit": Vector2(625, 415), "Baignoire": Vector2(1310, 325)}
func _initialize():
	partie = root.get_node("Partie")
	partie.inventaire = {}; partie.constructions = []
	change_scene_to_file("res://scenes/carte.tscn")
func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 1; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_k_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
func _placer(p):
	h.position = p; h.velocity = Vector2.ZERO; h.get_node("Camera2D").reset_smoothing()
## Se cacher dans la cachette n (g = pas depuis le début de la séquence)
func _cachette(nom, g):
	var bouton = _centre(current_scene.get_node("HUD/BoutonCacher"))
	if g == 0:
		_placer(CACHETTES[nom])
	if g == 4: _touch(bouton, true)
	if g == 12: _touch(bouton, false)
	if g == 20:
		print(nom, ": cache=", h._cache, " (attendu true)")
		# Le zombie rapide arrive tout près, il regarde vers la cachette
		var z = current_scene.get_node("Monde/ZombieRapide")
		z.position = h.position + Vector2(160, 0); z._depart = z.position; z.patrouille = Vector2.ZERO
		z._changer_etat(0); z._regard = Vector2.LEFT
	if g == 30: _snap(nom.to_lower())
	if g == 100:
		var z = current_scene.get_node("Monde/ZombieRapide")
		print(nom, ": zombie tout pres ", E[z._etat], " pv=", pvs, " (attendu PATROUILLE, pas de degats)")
		_touch(bouton, true)
	if g == 108: _touch(bouton, false)
	if g == 116:
		print(nom, ": sorti=", not h._cache)
		var z = current_scene.get_node("Monde/ZombieRapide")
		z.position = Vector2(1500, 1100); z._depart = z.position
func _physics_process(_d):
	f += 1
	if f == 20:
		print("maison disponible: ", partie.lieu_disponible("maison"), " infos: ", partie.infos_lieu("maison"), " (attendu 3 zombies [0, 0, 1], 5 objets)")
		_touch(current_scene._place("maison"), true)
	if f == 26: _touch(Vector2.ZERO, false)
	if f == 32:
		print("fiche visible: ", current_scene.get_node("Fiche").visible, " (attendu true)")
		_snap("fiche")
		_touch(_centre(current_scene.get_node("Fiche/YAller")), true)
	if f == 38: _touch(Vector2.ZERO, false)
	if f == 60:
		print("scene: ", current_scene.name, " (attendu Maison) lieu: ", partie.lieu)
		h = current_scene.get_node("Monde/Heros")
		h.pv_change.connect(func(p, _m): pvs.append(p))
		var styles := []
		for c in get_nodes_in_group("cachettes"): styles.append(c.name + "=" + str(c.style))
		print("zombies: ", get_nodes_in_group("zombies").size(), " objets: ", get_nodes_in_group("objets").size(),
			" cachettes: ", styles, " sortie: ", current_scene.has_node("Monde/Sortie"), " taille: ", current_scene.taille)
		_snap("depart")
	if f == 120:
		var calmes := true
		for z in get_nodes_in_group("zombies"): calmes = calmes and z._etat == 0
		print("depart sur: zombies en patrouille=", calmes, " pv=", pvs)
		# Zombies à l'écart (au fond de la cuisine) pour tester les portes
		for z in get_nodes_in_group("zombies"):
			z.position = Vector2(1500, 1100); z._depart = z.position; z.patrouille = Vector2.ZERO
		_placer(Vector2(1000, 940)); h.definir_direction(Vector2.LEFT)
	if f == 220:
		h.definir_direction(Vector2.ZERO)
		print("porte cuisine -> salon: x=", round(h.position.x), " (attendu < 780)")
		_placer(Vector2(600, 900)); h.definir_direction(Vector2.UP)
	if f == 300:
		h.definir_direction(Vector2.ZERO)
		print("cloison: y=", round(h.position.y), " (attendu > 675, bloque)")
		_placer(Vector2(380, 900)); h.definir_direction(Vector2.UP)
	if f == 380:
		h.definir_direction(Vector2.ZERO)
		print("porte salon -> chambre: y=", round(h.position.y), " (attendu < 640)")
		_snap("chambre")
	if f >= 400 and f < 520: _cachette("Armoire", f - 400)
	if f >= 530 and f < 650: _cachette("Lit", f - 530)
	if f >= 660 and f < 780: _cachette("Baignoire", f - 660)
	if f >= 790 and f < 800 and f % 2 == 0:
		var objets = get_nodes_in_group("objets")
		if objets.size() > 0: _placer(objets[0].position)
	if f == 805: _placer(current_scene.get_node("Monde/Sortie").position + Vector2(0, 30))
	if f == 860:
		print("scene: ", current_scene.name, " resultat: ", partie.resultat, " (attendu Fin, victoire)")
		print("message: ", "Tu es sorti %s !" % partie.LIEUX[partie.lieu]["du"])
		_snap("victoire")
		quit()
	return false
