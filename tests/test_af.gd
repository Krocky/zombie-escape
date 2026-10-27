extends SceneTree
## Lot 4 (f) : fruit du potager. Le jardin construit (placement puis Poser) a tout de suite un fruit ; le héros le
## cueille en arrivant au bord du potager (fruit en réserve, sauvegardé, texte « Fruit cueilli ») ; pas de 2e fruit
## avant le délai (« Prochain fruit dans 3 h 00 ») ; délai raccourci : le fruit revient (mais il n'est pas cueilli
## tant qu'un fruit attend) ; heure qui recule : la cueillette est remise à maintenant ; au lieu suivant, le héros
## court x FRUIT_VITESSE (fruit mangé à l'arrivée, icône dans le HUD), puis vitesse normale après FRUIT_DUREE ;
## une sauvegarde version 8 est reprise (fruit prêt, rien en réserve). Captures : fruit prêt, cueilli, prochain,
## HUD du lieu. Affiche « ECHEC » à chaque vérification ratée. Efface la sauvegarde à la fin.
var g := 0
var phase := "jardin"
var partie
var reg
var echecs := 0
var origine := {}
var cueilli_a := 0.0
const FICHIER := "user://sauvegarde.json"
const TOUS := ["abri_1", "abri_2", "feu", "barricade", "atelier", "lampe", "jardin"]


func _initialize():
	partie = root.get_node("Partie")
	reg = root.get_node("Reglages")
	for nom in ["FRUIT_DELAI", "FRUIT_VITESSE", "FRUIT_DUREE"]:
		origine[nom] = reg.get(nom)


func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_af_%s.png" % n)
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1
func _aller(p):
	phase = p; g = 0
func _effacer():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	partie.inventaire = {}; partie.constructions = []; partie.poses = []; partie.remede = 0; partie.remede_annonce = false
	partie.rescapes = 0; partie.lieux_sauves = []; partie.batiments_vus = []; partie.etoiles_lieux = {}
	partie.skin = ""; partie.prenom = ""; partie.fruit = false; partie.fruit_cueilli = 0.0
func _heros(): return current_scene.get_node("Monde/Heros")
func _lu() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
## Le héros se place devant le potager (en bas de son emprise, monde) et marche vers lui.
func _devant_potager(ecart: float):
	var e: Rect2 = current_scene._batiments["jardin"].emprise()
	_heros().position = Vector2(e.get_center().x, e.end.y + ecart)


func _physics_process(_d):
	g += 1
	match phase:
		"jardin":
			if g == 1:
				_effacer()
				partie.inventaire = {"eau": 2, "conserve": 1}
				partie.skin = "heros"; partie.prenom = "Eliott"
				partie.batiments_vus = TOUS.duplicate()   # pas de chute : seul le jardin posé tombera
				partie.batiments_vus.erase("jardin")
				partie.sauvegarder()
				change_scene_to_file("res://scenes/base.tscn")
			if g == 20:
				_verifier("pas de jardin : pas de fruit", not partie.fruit_pret() and not current_scene._fruit.pret)
				current_scene._construire("jardin")
				current_scene.placer_fantome(partie.PLACES_DEPART["jardin"])
			if g == 26:
				_verifier("place libre pour le jardin (%s)" % current_scene.raison_refus(), current_scene.raison_refus() == "")
				current_scene.poser_construction()
			if g == 120:
				var b = current_scene
				_verifier("jardin construit et posé", partie.est_construit("jardin") and b._batiments.has("jardin") and b._batiments["jardin"].pose())
				_verifier("fruit prêt dès la construction du jardin", partie.fruit_pret() and b._fruit.pret)
				_devant_potager(70.0)
			if g == 150:
				_verifier("loin du bord (70) : pas encore cueilli, pas de texte (« %s »)" % current_scene._fruit.texte,
					not partie.fruit and current_scene._fruit.texte == "")
				_snap("pret")
				_aller("cueillette")
		"cueillette":
			if g == 1:
				_heros().definir_direction(Vector2(0, -1))   # vers le potager
			if g == 40:
				_heros().definir_direction(Vector2.ZERO)
				var b = current_scene
				_verifier("fruit cueilli en marchant jusqu'au potager", partie.fruit and not b._fruit.pret)
				_verifier("heure de cueillette retenue", absf(partie.fruit_cueilli - partie.maintenant()) < 5.0)
				cueilli_a = partie.fruit_cueilli
				_verifier("texte « %s »" % b._fruit.texte, b._fruit.texte == "Fruit cueilli : plus rapide au prochain niveau !")
				var lu := _lu()
				_verifier("sauvegardé : version %s, fruit %s" % [lu.get("version"), lu.get("fruit")],
					int(lu.get("version", 0)) == 9 and lu.get("fruit") == true and absf(float(lu.get("fruit_cueilli", 0)) - cueilli_a) < 1.0)
			if g == 50: _snap("cueilli")
			if g == 240:
				var b = current_scene
				_verifier("pas de 2e fruit avant le délai", not partie.fruit_pret() and not b._fruit.pret and not partie.cueillir_fruit())
				_verifier("près du potager : « %s »" % b._fruit.texte, b._fruit.texte == "Prochain fruit dans 3 h 00")
				_verifier("texte_duree : 2 h 14, 5 min, 1 min", b.texte_duree(2 * 3600 + 13 * 60 + 20) == "2 h 14"
					and b.texte_duree(290) == "5 min" and b.texte_duree(3) == "1 min")
				_snap("prochain")
				reg.FRUIT_DELAI = 2.0
			if g == 400:
				var b = current_scene
				_verifier("délai raccourci (2 s) : le fruit revient", partie.fruit_pret() and b._fruit.pret)
				_verifier("un fruit attend déjà : pas cueilli (« %s »)" % b._fruit.texte,
					partie.fruit and partie.fruit_cueilli == cueilli_a and b._fruit.texte == "Tu as déjà un fruit pour le prochain lieu")
				# Heure de la tablette qui recule : la dernière cueillette serait dans le futur
				reg.FRUIT_DELAI = origine["FRUIT_DELAI"]
				partie.fruit_cueilli = partie.maintenant() + 7200.0
				var reste: float = partie.secondes_avant_fruit()
				_verifier("heure qui recule : cueillette remise à maintenant (reste %d s)" % reste,
					partie.fruit_cueilli <= partie.maintenant() and absf(reste - reg.FRUIT_DELAI) < 5.0)
				_verifier("et sauvegardée", float(_lu().get("fruit_cueilli", 0)) <= partie.maintenant())
				_aller("lieu")
		"lieu":
			if g == 1:
				reg.FRUIT_DUREE = 2.0
				partie.choisir_lieu("supermarche")
				change_scene_to_file("res://scenes/lieux/supermarche.tscn")
			if g == 20:
				_verifier("fruit mangé à l'arrivée (plus en réserve, sauvegardé)", not partie.fruit and _lu().get("fruit") == false)
				_verifier("course rapide : %.2f s restantes" % _heros().temps_fruit(), _heros().temps_fruit() > 1.0)
				_verifier("icône du fruit dans le HUD", current_scene.get_node("HUD")._fruit.visible)
				_heros().position = Vector2(1300, 750)
				_heros().definir_direction(Vector2(1, 0))
			if g == 26:
				var v: float = _heros().velocity.length()
				_verifier("vitesse x%.1f : %.0f (attendu %.0f)" % [reg.FRUIT_VITESSE, v, reg.HEROS_VITESSE * reg.FRUIT_VITESSE],
					absf(v - reg.HEROS_VITESSE * reg.FRUIT_VITESSE) < 2.0)
				_heros().definir_direction(Vector2.ZERO)
			if g == 50: _snap("hud")
			if g == 140:
				_heros().position = Vector2(1300, 750)
				_heros().definir_direction(Vector2(1, 0))
			if g == 146:
				var v: float = _heros().velocity.length()
				_verifier("après %.0f s : vitesse normale %.0f, icône cachée" % [reg.FRUIT_DUREE, v],
					_heros().temps_fruit() == 0.0 and absf(v - reg.HEROS_VITESSE) < 2.0 and not current_scene.get_node("HUD")._fruit.visible)
				_heros().definir_direction(Vector2.ZERO)
				_aller("reprise")
		"reprise":
			if g == 1:
				change_scene_to_file("res://scenes/titre.tscn")
			if g == 10:
				# Sauvegarde version 8 (avant le fruit), jardin construit : reprise, fruit prêt, rien en réserve
				_effacer()
				var v8 := {"version": 8, "inventaire": {"conserve": 2}, "constructions": ["jardin"], "remede": 1,
					"remede_annonce": false, "skin": "heroine", "prenom": "Eliott", "rescapes": 1, "lieux_sauves": ["maison"],
					"batiments_vus": ["jardin"], "etoiles": {"maison": 2}, "poses": [{"nom": "jardin", "x": 1250, "y": 420}]}
				var f := FileAccess.open(FICHIER, FileAccess.WRITE)
				f.store_string(JSON.stringify(v8)); f.close()
				partie.charger()
				var lu := _lu()
				_verifier("v8 reprise : version %s, rien de perdu" % lu.get("version"), int(lu.get("version", 0)) == 9
					and lu["constructions"] == ["jardin"] and int(lu["inventaire"]["conserve"]) == 2 and lu["prenom"] == "Eliott"
					and int(lu["rescapes"]) == 1 and lu["poses"].size() == 1 and int(lu["etoiles"]["maison"]) == 2)
				_verifier("v8 reprise : pas de fruit en réserve, fruit prêt sur le potager",
					not partie.fruit and partie.fruit_cueilli == 0.0 and partie.fruit_pret() and lu.get("fruit") == false)
			if g == 20:
				for nom in origine: reg.set(nom, origine[nom])
				_effacer()
				print("test_af : %d échec(s)" % echecs)
				quit()
