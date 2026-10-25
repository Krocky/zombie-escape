extends SceneTree
## Lot 3 (e) : motivation. Reprise d'une sauvegarde version 6 (sans étoiles) réécrite en version 7,
## meilleur nombre d'étoiles gardé par lieu (un moins bon score ne l'écrase pas), sauvegardé et relu,
## objets rapportés par les rescapés de la base (jamais de fiole, ajoutés à l'inventaire, ligne de l'écran de fin).
## Captures : carte avec les étoiles sous les lieux, fiche avec les étoiles, écran de fin.
## Affiche « ECHEC » à chaque vérification ratée.
var g := 0
var phase := "donnees"
var partie
var reg
var echecs := 0


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")


func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_x_%s.png" % n)
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1
func _aller(p):
	phase = p; g = 0
func _vider():
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.rescapes = 0; partie.lieux_sauves = []; partie.batiments_vus = []; partie.etoiles_lieux = {}
	partie.skin = "heros"; partie.prenom = ""


func _physics_process(_d):
	g += 1
	match phase:
		"donnees":
			if g == 2:
				# Reprise d'une version 6 : tout est relu, pas d'étoiles, réécrite aussitôt en version 7
				_vider()
				Fichier.ecrire_json(partie.FICHIER, {"version": 6, "inventaire": {"eau": 2}, "constructions": ["atelier"],
					"remede": 1, "remede_annonce": false, "skin": "heroine", "prenom": "Eliott", "rescapes": 1,
					"lieux_sauves": ["maison"], "batiments_vus": ["feu"]})
				partie.skin = ""
				partie.charger()
				_verifier("v6 relue : inventaire %s, atelier, rescapés %d, skin %s" % [str(partie.inventaire), partie.rescapes, partie.skin],
					partie.inventaire.get("eau", 0) == 2 and partie.est_construit("atelier") and partie.rescapes == 1
					and partie.skin == "heroine" and partie.lieux_sauves == ["maison"])
				_verifier("v6 relue : aucune étoile (%s)" % str(partie.etoiles_lieux),
					partie.etoiles_lieux.is_empty() and partie.meilleures_etoiles("supermarche") == 0)
				var fichier = Fichier.lire_json(partie.FICHIER)
				_verifier("réécrite en version %s avec « etoiles »" % str(fichier.get("version")),
					int(fichier.get("version", 0)) == 7 and fichier.get("etoiles") is Dictionary)

				# Étoiles : le meilleur score seulement
				_vider()
				partie.choisir_lieu("supermarche")
				partie.terminer(true, ["fiole"], false, true)   # sorti + objectif + sans blessure
				_verifier("supermarché : 3 étoiles gagnées, meilleur %d" % partie.meilleures_etoiles("supermarche"),
					partie.etoiles() == 3 and partie.meilleures_etoiles("supermarche") == 3)
				partie.terminer(true, [], false, false)          # sorti seulement
				_verifier("puis 1 étoile : meilleur gardé à %d" % partie.meilleures_etoiles("supermarche"),
					partie.etoiles() == 1 and partie.meilleures_etoiles("supermarche") == 3)
				partie.terminer(false, [], false, false)
				_verifier("puis défaite : meilleur gardé à %d" % partie.meilleures_etoiles("supermarche"), partie.meilleures_etoiles("supermarche") == 3)
				partie.choisir_lieu("maison")
				partie.terminer(false, [], false, false)
				_verifier("maison perdue : 0 étoile", partie.meilleures_etoiles("maison") == 0)
				partie.terminer(true, [], false, false)
				_verifier("maison : 1 étoile", partie.meilleures_etoiles("maison") == 1)
				partie.terminer(true, ["bandage", "bandage"], false, false)
				_verifier("maison : 2 étoiles, meilleur monte à %d" % partie.meilleures_etoiles("maison"), partie.meilleures_etoiles("maison") == 2)
				# Sauvegardé et relu
				partie.etoiles_lieux = {}
				partie.charger()
				_verifier("étoiles relues : %s" % str(partie.etoiles_lieux),
					partie.meilleures_etoiles("supermarche") == 3 and partie.meilleures_etoiles("maison") == 2 and partie.meilleures_etoiles("pharmacie") == 0)

				# Rescapés au travail
				_vider()
				partie.choisir_lieu("supermarche")
				partie.terminer(true, [], true, false)
				_verifier("rescapé sauvé dans la mission : il ne rapporte rien cette fois (%s)" % str(partie.resultat["trouvailles"]),
					partie.rescapes == 1 and partie.resultat["trouvailles"].is_empty())
				partie.rescapes = 3
				var fiole := false
				var bon_nombre := true
				for i in 40:
					partie.inventaire = {}
					partie.terminer(i % 2 == 0, [], false, false)   # victoire ou défaite : à chaque retour
					var t: Array = partie.resultat["trouvailles"]
					bon_nombre = bon_nombre and t.size() == 3 * reg.RESCAPE_OBJETS
					fiole = fiole or "fiole" in t
					var total := 0
					for n in partie.inventaire.values(): total += n
					bon_nombre = bon_nombre and total == t.size() + partie.resultat["jardin"].size()
				_verifier("3 rescapés : %d objet(s) chacun à chaque retour, ajoutés à l'inventaire" % reg.RESCAPE_OBJETS, bon_nombre)
				_verifier("jamais de fiole", not fiole)
				partie.rescapes = 0
				partie.terminer(true, [], false, false)
				_verifier("sans rescapé : rien", partie.resultat["trouvailles"].is_empty())

				# Pour les captures : 3 étoiles au supermarché, 1 à la maison, 2 rescapés
				_vider()
				partie.etoiles_lieux = {"supermarche": 3, "maison": 1}
				change_scene_to_file("res://scenes/carte.tscn")
				_aller("carte")
		"carte":
			if g == 40:
				_snap("carte")
				current_scene._ouvrir("supermarche")
			if g == 80:
				_verifier("fiche ouverte", current_scene.get_node("Fiche").visible)
				_snap("fiche")
				current_scene._ouvrir("maison")
			if g == 120:
				_snap("fiche_maison")
				# Cas le plus chargé : rescapé sauvé, objectif, jardin, rescapés au travail, fiole versée (6 lignes)
				partie.rescapes = 2
				partie.constructions = ["jardin"]
				partie.choisir_lieu("maison")
				partie.terminer(true, ["bandage", "bandage", "fiole"], true, false)
				change_scene_to_file("res://scenes/fin.tscn")
				_aller("fin")
		"fin":
			if g == 150:
				var texte: String = current_scene.get_node("Resume").text
				_verifier("écran de fin : « Tes rescapés ont trouvé : ... »", "Tes rescapés ont trouvé : " in texte)
				_verifier("trouvailles %s dans l'inventaire %s" % [str(partie.resultat["trouvailles"]), str(partie.inventaire)],
					partie.resultat["trouvailles"].size() == 2 * reg.RESCAPE_OBJETS)
				var resume: Label = current_scene.get_node("Resume")
				_verifier("résumé de %d lignes dans sa zone (police %d)" % [resume.get_line_count(), resume.get_theme_font_size("font_size")],
					resume.get_line_count() * resume.get_line_height() <= resume.size.y)
				_snap("fin")
				Fichier.effacer(partie.FICHIER)
				_vider()
				partie.skin = ""
				print("test_x : %d échec(s)" % echecs)
				quit()
	return false
