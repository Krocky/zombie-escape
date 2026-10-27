extends SceneTree
## Lot 3 (f1) : la pharmacie. Carte -> Pharmacie disponible (fiche : 3 zombies, 5 objets, la clef n'y compte pas)
## -> Y aller ; porte de la réserve fermée sans clef (le héros bute, la porte montre la clef) ; la clef ramassée
## ne compte pas dans « Objets » ni dans l'objectif, elle s'affiche à part dans le HUD ; avec elle, la porte s'ouvre
## et on entre dans la réserve ; à la sortie, la clef n'est pas rapportée à la base. Efface la sauvegarde à la fin.
var f := 0
var partie
var h
var niveau
var porte
var FICHIER: String:   # sauvegarde de la partie en cours (lot 4 d)
	get:
		return root.get_node("Partie").fichier()


func _initialize():
	partie = root.get_node("Partie")
	_effacer()
	partie.skin = "heros"
	change_scene_to_file("res://scenes/carte.tscn")


func _effacer():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.rescapes = 0; partie.lieux_sauves = []; partie.batiments_vus = []; partie.etoiles_lieux = {}


func _verifier(nom, ok):
	print(("OK   " if ok else "ECHEC ") + nom)


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_y_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
func _placer(p):
	h.position = p; h.velocity = Vector2.ZERO; h.get_node("Camera2D").reset_smoothing()


func _physics_process(_d):
	f += 1
	# --- Carte ---
	if f == 20:
		var infos = partie.infos_lieu("pharmacie")
		print("pharmacie: disponible=", partie.lieu_disponible("pharmacie"), " infos=", infos)
		_verifier("pharmacie disponible sur la carte", partie.lieu_disponible("pharmacie"))
		_verifier("3 zombies (gros, maigre, coureur)", infos["zombies"] == [0, 1, 2])
		_verifier("6 objets a trouver (boite de balles comprise), sans la clef", infos["objets"].size() == 6 and not "clef" in infos["objets"])
		_verifier("objectif 2 piles", partie.texte_objectif("pharmacie") == "rapporter 2 piles")
		_touch(current_scene._place("pharmacie"), true)
	if f == 26: _touch(Vector2.ZERO, false)
	if f == 50:
		_verifier("fiche de la pharmacie ouverte", current_scene.get_node("Fiche").visible)
		_snap("fiche")
		_touch(_centre(current_scene.get_node("Fiche/YAller")), true)
	if f == 56: _touch(Vector2.ZERO, false)
	# --- Pharmacie ---
	if f == 100:
		niveau = current_scene
		_verifier("scene Pharmacie", niveau.name == "Pharmacie" and partie.lieu == "pharmacie")
		h = niveau.get_node("Monde/Heros")
		porte = niveau.get_node("Monde/PorteReserve")
		var cachettes = get_nodes_in_group("cachettes").size()
		print("zombies: ", get_nodes_in_group("zombies").size(), " cachettes: ", cachettes, " rescapes: ", get_nodes_in_group("rescapes").size(),
			" compteur: '", niveau.get_node("HUD/CompteurObjets").text, "'")
		_verifier("3 cachettes, 1 rescape", cachettes == 3 and get_nodes_in_group("rescapes").size() == 1)
		_verifier("compteur 0 / 6 (clef hors compteur)", niveau.get_node("HUD/CompteurObjets").text == "Objets : 0 / 6")
		# Zombies figés : le test ne parle que de la porte
		for z in get_nodes_in_group("zombies"):
			z.set_physics_process(false)
		_snap("depart")
		# Sans clef : on marche vers la porte
		_placer(Vector2(1650, 720)); h.definir_direction(Vector2.UP)
	if f == 190:
		h.definir_direction(Vector2.ZERO)
		print("sans clef: y=", round(h.position.y), " ouverte=", porte.ouverte(), " bulle=", porte._bulle_visible)
		_verifier("porte fermee sans clef (heros bloque devant)", not porte.ouverte() and h.position.y > 620.0)
		_verifier("la porte montre la clef qu'il faut", porte._bulle_visible)
	if f == 220:
		_snap("porte_fermee")
		# La clef (à l'une de ses places) : on marche dessus
		_placer(niveau.get_node("Monde/ObjetClef").position)
	if f == 240:
		print("clef: clefs=", niveau._clefs, " ramasses=", niveau._ramasses, " compteur: '", niveau.get_node("HUD/CompteurObjets").text, "'")
		_verifier("clef ramassee, a part", niveau._clefs == ["rouge"] and niveau._ramasses.is_empty())
		_verifier("clef hors compteur", niveau.get_node("HUD/CompteurObjets").text == "Objets : 0 / 6")
		_verifier("clef affichee dans le HUD", niveau.get_node("HUD")._clef.visible)
		_verifier("clef hors objectif", partie.avancee_objectif("pharmacie", niveau._ramasses) == 0)
	if f == 270:
		_snap("clef")
		# Avec la clef : la porte s'ouvre, on entre dans la réserve
		_placer(Vector2(1650, 720)); h.definir_direction(Vector2.UP)
	if f == 300:
		_snap("porte_ouverte")
	if f == 360:
		h.definir_direction(Vector2.ZERO)
		print("avec clef: y=", round(h.position.y), " ouverte=", porte.ouverte(), " clefs=", niveau._clefs)
		_verifier("porte ouverte avec la clef", porte.ouverte())
		_verifier("heros entre dans la reserve", h.position.y < 580.0)
		_verifier("la clef a servi (plus dans le HUD)", niveau._clefs.is_empty() and not niveau.get_node("HUD")._clef.visible)
	if f == 380:
		_snap("reserve")
		# Les piles de la réserve
		_placer(niveau.get_node("Monde/ObjetPiles").position)
	if f == 400:
		_verifier("piles de la reserve ramassees (1 / 6)", niveau.get_node("HUD/CompteurObjets").text == "Objets : 1 / 6")
		_placer(niveau.get_node("Monde/Sortie").position + Vector2(0, 30))
	if f == 460:
		print("fin: scene=", current_scene.name, " resultat=", partie.resultat["rapportes"], " inventaire=", partie.inventaire)
		_verifier("victoire", partie.resultat["victoire"])
		_verifier("clef pas rapportee a la base", not "clef" in partie.resultat["rapportes"] and not partie.inventaire.has("clef"))
	if f == 500:
		_effacer()
		quit()
