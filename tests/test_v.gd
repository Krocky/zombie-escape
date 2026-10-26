extends SceneTree
## Lot 3 (c) : objets utiles. Infirmerie et jardin construits depuis le tiroir de la base (5 cartes dans l'écran),
## soin avec le bandage de l'infirmerie (un seul soin par mission), soin avec un bandage ramassé (consommé :
## plus dans les objets rapportés ni dans l'objectif), conserve offerte par le jardin au retour.
## Captures : tiroir à 5 cartes, base avec le jardin, bouton Soigner, écran de fin.
## Affiche « ECHEC » à chaque vérification ratée.
var g := 0
var phase := "base"
var partie
var reg
var niveau
var h
var hud
var echecs := 0


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")
	partie.inventaire = {"bandage": 3, "eau": 2, "conserve": 1}
	partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.batiments_vus = []
	partie.sauvegarder()
	change_scene_to_file("res://scenes/base.tscn")


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_v_%s.png" % n)
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1
func _aller(p):
	phase = p; g = 0
func _carte(nom):
	for c in current_scene.get_node("Interface/Constructions").get_children():
		if c.construction == nom: return c
func _appuyer(nom): _touch(_carte(nom).get_node("Bouton").get_global_rect().get_center(), true)
func _soin(): return current_scene.get_node("HUD")._soin
## Lieu chargé directement, sans zombies (ils ne gênent pas le test)
func _lieu(id):
	partie.choisir_lieu(id)
	change_scene_to_file(partie.scene_lieu())
func _preparer_lieu():
	niveau = current_scene
	h = niveau.get_node("Monde/Heros")
	hud = niveau.get_node("HUD")
	for z in get_nodes_in_group("zombies"):
		z.remove_from_group("zombies"); z.queue_free()


func _physics_process(_d):
	g += 1
	match phase:
		"base":
			if g == 12:
				current_scene.ouvrir_tiroir(true)
			if g == 40:
				var ecran = current_scene.get_viewport_rect()
				var cartes = current_scene.get_node("Interface/Constructions").get_children()
				var dedans := true
				var boutons := true
				for c in cartes:
					dedans = dedans and ecran.encloses(c.get_global_rect())
					var b = c.get_node("Bouton")
					boutons = boutons and b.size.x >= 100 and b.size.y >= 100
				_verifier("tiroir : %d cartes, toutes dans l'écran, boutons >= 100 px" % cartes.size(), cartes.size() == 5 and dedans and boutons)
				var noms := []
				for c in cartes: noms.append(c.construction)
				_verifier("cartes infirmerie et jardin présentes", "infirmerie" in noms and "jardin" in noms)
				_verifier("infirmerie et jardin constructibles", _carte("infirmerie").get_node("Bouton").actif and _carte("jardin").get_node("Bouton").actif)
				_snap("tiroir")
				_appuyer("infirmerie")
			if g == 46: _touch(Vector2.ZERO, false)
			if g == 60: current_scene.ouvrir_tiroir(true)
			if g == 80: _appuyer("jardin")
			if g == 86: _touch(Vector2.ZERO, false)
			if g == 100:
				_verifier("construits : infirmerie %s, jardin %s" % [partie.est_construit("infirmerie"), partie.est_construit("jardin")],
					partie.est_construit("infirmerie") and partie.est_construit("jardin"))
				_verifier("coûts payés : inventaire %s" % str(partie.inventaire),
					partie.inventaire.get("bandage", 0) == 0 and partie.inventaire.get("eau", 0) == 0 and partie.inventaire.get("conserve", 0) == 0)
				_verifier("jardin dans le camp", "jardin" in current_scene._batiments_visibles())
			if g == 160:
				_snap("base_jardin")
				_lieu("supermarche")
				_aller("infirmerie")
		"infirmerie":
			if g == 5:
				_preparer_lieu()
				_verifier("infirmerie : 1 bandage de soin au départ (%d)" % niveau._bandages_soin, niveau._bandages_soin == reg.INFIRMERIE_BANDAGES)
			if g == 10:
				_verifier("Soigner inactif sans blessure", not _soin().actif)
				_verifier("bouton Soigner >= 100 px et dans l'écran", _soin().size.x >= 100 and _soin().size.y >= 100
					and niveau.get_viewport().get_visible_rect().encloses(_soin().get_global_rect()))
				h.recevoir_degats(2, h.global_position + Vector2(50, 0))
			if g == 14:
				_verifier("blessé (%d/%d) : Soigner actif" % [h._pv, h._pv_max], _soin().actif)
			if g == 40:
				_snap("soigner")
				_touch(_soin().get_global_rect().get_center(), true)
			if g == 46:
				_touch(Vector2.ZERO, false)
				_verifier("soin : +%d cœur (%d/%d), bandage de l'infirmerie utilisé (%d)" % [reg.SOIN_COEURS, h._pv, h._pv_max, niveau._bandages_soin],
					h._pv == h._pv_max - 2 + reg.SOIN_COEURS and niveau._bandages_soin == 0)
				_verifier("soigné mais pas intact (étoile « aucun cœur perdu »)", not h.intact())
				# Un bandage ramassé ensuite : le soin de la mission est déjà pris
				niveau._ramasses.append("bandage")
			if g == 50:
				_verifier("2e soin refusé (%d par mission)" % reg.SOIN_PAR_MISSION, not _soin().actif)
			if g == 60:
				partie.constructions = ["jardin"]   # sans infirmerie
				_lieu("maison")
				_aller("ramasse")
		"ramasse":
			if g == 5:
				_preparer_lieu()
				_verifier("sans infirmerie : aucun bandage de soin", niveau._bandages_soin == 0)
				h.recevoir_degats(1, h.global_position + Vector2(50, 0))
			if g == 10:
				_verifier("blessé sans bandage : Soigner inactif", not _soin().actif)
				h.global_position = niveau.get_node("Monde/ObjetBandage").global_position
			if g == 14:
				_verifier("bandage ramassé (%s), objectif 1/2" % str(niveau._ramasses),
					niveau._ramasses == ["bandage"] and partie.avancee_objectif("maison", niveau._ramasses) == 1)
				_verifier("blessé avec un bandage ramassé : Soigner actif", _soin().actif)
				_touch(_soin().get_global_rect().get_center(), true)
			if g == 20:
				_touch(Vector2.ZERO, false)
				_verifier("soin avec le bandage ramassé : %d/%d" % [h._pv, h._pv_max], h._pv == h._pv_max)
				_verifier("bandage consommé : ramassés %s, objectif %d/2, compteur '%s'" % [str(niveau._ramasses),
					partie.avancee_objectif("maison", niveau._ramasses), hud.get_node("CompteurObjets").text],
					niveau._ramasses.is_empty() and partie.avancee_objectif("maison", niveau._ramasses) == 0
					and hud.get_node("CompteurObjets").text.begins_with("Objets : 0"))
				_verifier("plein : Soigner inactif", not _soin().actif)
				h.global_position = niveau.get_node("Monde/ObjetPiles").global_position
			if g == 24:
				partie.inventaire = {}
				niveau._finir(true, 0.0)
			if g == 30:
				var r = partie.resultat
				_verifier("rapportés %s (sans le bandage soigné)" % str(r["rapportes"]), r["rapportes"] == ["piles"])
				_verifier("jardin : %s offert, inventaire %s" % [str(r["jardin"]), str(partie.inventaire)],
					r["jardin"] == ["conserve"] and partie.inventaire.get("conserve", 0) == reg.JARDIN_CONSERVES)
			if g == 70:
				_verifier("écran de fin : ligne du jardin", current_scene.name == "Fin" and "jardin" in current_scene.get_node("Resume").text)
				_snap("fin")
				# Ne pas laisser de constructions aux autres tests
				Fichier.effacer(partie.FICHIER)
				partie.constructions = []; partie.inventaire = {}; partie.remede = 0; partie.remede_annonce = false
				partie.batiments_vus = []
				print("test_v : %d échec(s)" % echecs)
				quit()
	return false
