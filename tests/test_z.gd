extends SceneTree
## Lot 3 (f2) : suite du remède. Avant le remède : bouton Guérir caché et inactif, même avec une fiole près d'un zombie,
## objectif du supermarché « rapporter 1 fiole ». Après (jauge pleine) : objectif « guérir 1 zombie », Guérir inactif
## sans fiole ou loin des zombies, actif avec une fiole ramassée près d'un zombie ; la fiole est consommée, le zombie
## guéri n'est plus un zombie, l'objectif est rempli (HUD, fin), le rescapé est compté (une tente de plus).
## Captures : bouton Guérir actif, nuage, survivant assis, écran de fin, base.
## Affiche « ECHEC » à chaque vérification ratée.
var g := 0
var phase := "avant"
var partie
var reg
var niveau
var h
var hud
var zombie
var echecs := 0
var rescapes_avant := 0
var place_gueri := Vector2.ZERO


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")
	partie.inventaire = {}
	partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.rescapes = 0; partie.lieux_sauves = []; partie.batiments_vus = []
	partie.sauvegarder()
	_lieu("supermarche")


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_z_%s.png" % n)
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1
func _aller(p):
	phase = p; g = 0
func _lieu(id):
	partie.choisir_lieu(id)
	change_scene_to_file(partie.scene_lieu())
func _bouton(): return hud._guerir
func _objectif() -> String: return hud.get_node("Objectif").text
## Lieu chargé : on garde un seul zombie (le gros), loin du héros pour l'instant
func _preparer_lieu():
	niveau = current_scene
	h = niveau.get_node("Monde/Heros")
	hud = niveau.get_node("HUD")
	zombie = null
	for z in get_nodes_in_group("zombies"):
		if zombie == null and z.type == 0:
			zombie = z
		else:
			z.remove_from_group("zombies"); z.queue_free()
	zombie.global_position = h.global_position + Vector2(1200, 0)
func _fiole():
	for o in get_nodes_in_group("objets"):
		if o.type == "fiole": return o


func _physics_process(_d):
	g += 1
	match phase:
		"avant":
			if g == 20:
				_preparer_lieu()
				_verifier("avant le remède : objectif « %s »" % partie.texte_objectif("supermarche"), partie.texte_objectif("supermarche") == "rapporter 1 fiole de remède")
				niveau._ramasses.append("fiole")
				zombie.global_position = h.global_position + Vector2(120, 0)
			if g == 25:
				_verifier("avant le remède : Guérir caché et inactif (fiole + zombie proche)", not _bouton().visible and not _bouton().actif)
				_verifier("avant le remède : aucun zombie à guérir", niveau._zombie_a_guerir() == null)
			if g == 27:
				partie.remede = reg.REMEDE_FIOLES; partie.remede_annonce = true
				rescapes_avant = partie.rescapes
				_lieu("supermarche")
				_aller("apres")
		"apres":
			if g == 5:
				_preparer_lieu()
				_verifier("après le remède : objectif « %s »" % partie.texte_objectif("supermarche"), partie.texte_objectif("supermarche") == "guérir 1 zombie")
			if g == 10:
				_verifier("HUD : '%s'" % _objectif(), "guérir 1 zombie (0/1)" in _objectif())
				_verifier("Guérir visible, inactif sans fiole", _bouton().visible and not _bouton().actif)
				_verifier("bouton Guérir >= 100 px et dans l'écran", _bouton().size.x >= 100 and _bouton().size.y >= 100
					and niveau.get_viewport().get_visible_rect().encloses(_bouton().get_global_rect()))
				var r: Rect2 = _bouton().get_global_rect()
				var chevauche := false
				for b in [hud.get_node("BoutonAttaquer"), hud.get_node("BoutonCacher"), hud._soin]:
					chevauche = chevauche or r.intersects(b.get_global_rect())
				_verifier("Guérir ne chevauche pas Frapper, Cacher ni Soigner", not chevauche)
				h.global_position = _fiole().global_position
			if g == 14:
				_verifier("fiole ramassée (%s)" % str(niveau._ramasses), "fiole" in niveau._ramasses)
				_verifier("fiole mais zombie loin : Guérir inactif", not _bouton().actif)
				zombie.global_position = h.global_position + Vector2(reg.GUERIR_PORTEE - 40.0, 0)
			if g == 18:
				_verifier("fiole + zombie proche : Guérir actif", _bouton().actif)
			if g == 40:
				_snap("bouton")
				_touch(_bouton().get_global_rect().get_center(), true)
			if g == 46:
				_touch(Vector2.ZERO, false)
				_verifier("zombie guéri (hors du groupe zombies)", zombie.gueri() and not zombie.is_in_group("zombies"))
				_verifier("fiole consommée (%s)" % str(niveau._ramasses), not "fiole" in niveau._ramasses)
				_verifier("HUD : objectif rempli '%s'" % _objectif(), "(1/1)" in _objectif())
				_verifier("plus de zombie : Guérir inactif", not _bouton().actif)
				place_gueri = zombie.global_position
			if g == 46 + 40:
				_snap("nuage")
			if g == 46 + 120:
				_verifier("guéri : il ne bouge plus", place_gueri.distance_to(zombie.global_position) < 1.0)
				_snap("gueri")
				partie.inventaire = {}
				niveau._finir(true, 0.0)
			if g == 46 + 126:
				var r = partie.resultat
				_verifier("résultat : %d guéri, mission %s" % [r["gueris"], r["mission"]], r["gueris"] == 1 and r["mission"])
				_verifier("rescapé compté : %d -> %d" % [rescapes_avant, partie.rescapes], partie.rescapes == rescapes_avant + 1)
				_verifier("fiole pas rapportée (%s)" % str(r["rapportes"]), not "fiole" in r["rapportes"])
			if g == 46 + 170:
				var resume: String = current_scene.get_node("Resume").text
				_verifier("écran de fin : « Mission réussie » et ligne de guérison", current_scene.name == "Fin"
					and "guéri" in resume and "Mission" in current_scene.get_node("Titre").text)
				_snap("fin")
				change_scene_to_file("res://scenes/base.tscn")
				_aller("base")
		"base":
			if g == 10:
				_verifier("base : une tente", "tente_1" in current_scene._batiments_visibles())
			if g == 160:
				_snap("base")
				Fichier.effacer(partie.FICHIER)
				partie.constructions = []; partie.inventaire = {}; partie.remede = 0; partie.remede_annonce = false
				partie.rescapes = 0; partie.lieux_sauves = []; partie.batiments_vus = []
				print("test_z : %d échec(s)" % echecs)
				quit()
	return false
