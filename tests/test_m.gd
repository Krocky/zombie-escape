extends SceneTree
## Héros au choix, animation V3, zombie coureur.
## 1. Sans héros choisi : Titre -> Jouer -> « Choisis ton héros » ; toucher Fille, prénom, « C'est parti ! » -> Base
##    (« La base d'Eliott », sauvegarde) ; bouton Héros -> écran de choix prérempli -> Base.
## 2. Supermarché avec l'héroïne : poses walk_a / walk_b en marche, attack au coup, idle à l'arrêt ;
##    sans poses de marche : rebond + inclinaison. Écran de fin avec l'héroïne (« sortie »).
## 3. Coureur : 2 PV (lot 3 b), charge à 1,8 x la vitesse du lent, sourd, ne sent pas de dos, essoufflé 1,5 s après sa charge.
## Efface la sauvegarde à la fin.
var f := 0
var g := 0          # pas depuis le début de la phase
var phase := "titre"
var partie
var poses := {}
var h
var z
var mesures := {}
const E := ["PATROUILLE", "POURSUITE", "CHERCHE", "RETOUR", "ESSOUFFLE"]


func _initialize():
	partie = root.get_node("Partie")
	partie.skin = ""; partie.prenom = ""
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	change_scene_to_file("res://scenes/titre.tscn")


func _touch(pos, pressed, idx := 0):
	var e = InputEventScreenTouch.new(); e.index = idx; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_m_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
func _aller(p):
	phase = p; g = 0


func _physics_process(_d):
	f += 1; g += 1
	match phase:
		"titre":
			if g == 10: _touch(_centre(current_scene.get_node("Centre/Colonne/Jouer")), true)
			if g == 16: _touch(Vector2.ZERO, false)
			if g == 40:
				print("1. scene apres Jouer: ", current_scene.name, " (attendu ChoixHeros)")
				_snap("choix")
				_touch(current_scene._cartes["heroine"].get_center(), true)
			if g == 46: _touch(Vector2.ZERO, false)
			if g == 50:
				current_scene.get_node("Prenom").text = "Eliott"
				var v = current_scene.get_node("Valider")
				print("bouton C'est parti: ", v.size, " >= 100 px: ", v.size.y >= 100, " dans l'ecran: ",
					current_scene.get_viewport_rect().encloses(v.get_global_rect()), " champ prenom dans l'ecran: ",
					current_scene.get_viewport_rect().encloses(current_scene.get_node("Prenom").get_global_rect()))
			if g == 80:
				_snap("choix_fille")
				_touch(_centre(current_scene.get_node("Valider")), true)
			if g == 86: _touch(Vector2.ZERO, false)
			if g == 110:
				print("scene: ", current_scene.name, " (attendu Base) titre: '", current_scene.get_node("Interface/Haut/Titre").text,
					"' skin: ", partie.skin, " prenom: ", partie.prenom)
				print("sauvegarde: ", FileAccess.get_file_as_string("user://sauvegarde.json"))
				var b = current_scene.get_node("Interface/Heros")
				print("bouton Heros: ", b.size, " dans l'ecran: ", current_scene.get_viewport_rect().encloses(b.get_global_rect()))
				_snap("base")
				_touch(_centre(b), true)
			if g == 116: _touch(Vector2.ZERO, false)
			if g == 140:
				print("scene: ", current_scene.name, " (attendu ChoixHeros) prenom prerempli: ", current_scene.get_node("Prenom").text,
					" choisi: ", current_scene._choisi)
				_touch(_centre(current_scene.get_node("Valider")), true)
			if g == 146: _touch(Vector2.ZERO, false)
			if g == 170:
				print("retour: ", current_scene.name, " (attendu Base)")
				partie.choisir_lieu("supermarche")
				change_scene_to_file("res://scenes/lieux/supermarche.tscn")
				_aller("niveau")
		"niveau":
			if g == 5:
				h = current_scene.get_node("Monde/Heros")
				for zz in get_nodes_in_group("zombies"):
					zz.position = Vector2(2300, 1550); zz._depart = zz.position; zz.patrouille = Vector2.ZERO
				print("2. skin du heros dans le niveau: ", h._perso)
				h.definir_direction(Vector2.RIGHT)
			if g > 5 and g < 70:
				var a = h._anim_v3()
				poses[a["nom"]] = poses.get(a["nom"], 0) + 1
			if g == 60: _snap("marche")
			if g == 70:
				print("poses en marche: ", poses, " (attendu heroine_walk_a et heroine_walk_b)")
				h.definir_direction(Vector2.ZERO)
			if g == 80:
				print("pose a l'arret: ", h._anim_v3()["nom"], " (attendu heroine_iddle)")
				h.attaquer()
			if g == 84:
				print("pose pendant le coup: ", h._anim_v3()["nom"], " (attendu heroine_attack)")
				_snap("coup")
			if g == 90:
				# Sans poses de marche : rebond vertical et inclinaison de la pose immobile
				var m = root.get_node("Images")._manifest_v3()
				var sauve = [m["heroine_walk_a"], m["heroine_walk_b"]]
				m.erase("heroine_walk_a"); m.erase("heroine_walk_b")
				var hauts := []
				for t in [0.05, 0.12, 0.2]:
					var a = root.get_node("Images").v3_animation("heroine", t, true)
					hauts.append([a["nom"], snappedf(a["decalage"].y, 0.1), snappedf(a["angle"], 0.001)])
				print("sans walk_a/b: ", hauts, " (attendu heroine_iddle, decalage < 0, angle != 0)")
				m["heroine_walk_a"] = sauve[0]; m["heroine_walk_b"] = sauve[1]
			if g == 100:
				_aller("coureur")
		"coureur":
			if g == 1:
				z = current_scene.get_node("Monde/ZombieCoureur")
				print("3. coureur pv: ", z._pv, " (lent ", root.get_node("Reglages").ZOMBIE_LENT_PV, ", rapide ",
					root.get_node("Reglages").ZOMBIE_RAPIDE_PV, ")")
				# Le héros juste derrière le coureur (dos tourné) et du bruit : il ne réagit pas
				z.position = Vector2(1400, 1120); z._depart = z.position; z.patrouille = Vector2.ZERO
				z._regard = Vector2.RIGHT
				h.position = Vector2(1360, 1120)
			if g == 3:
				for zz in get_nodes_in_group("zombies"): zz.entendre(h.position, 2000.0)
			if g == 30:
				print("heros colle dans son dos + bruit: ", E[z._etat], " (attendu PATROUILLE) ; zombie lent: ",
					E[current_scene.get_node("Monde/ZombieLent")._etat], " (il entend : CHERCHE)")
				_snap("coureur_dos")
				# Le héros devant lui, loin : il charge
				h.position = Vector2(1700, 1120)
			if g == 40:
				print("heros dans le cone: ", E[z._etat], " (attendu POURSUITE)")
				h.position = Vector2(2300, 300)   # hors de portée : on mesure la charge sans contact
				z.position = Vector2(500, 1120); z._point_recherche = Vector2(2300, 1120)
			if z and is_instance_valid(z) and z._etat == 1 and not mesures.has("charge"):
				mesures["charge"] = g
			if g == 45: mesures["x0"] = z.position.x
			if g == 75:
				var v = (z.position.x - mesures["x0"]) / 0.5
				var attendu = root.get_node("Reglages").ZOMBIE_LENT_VITESSE * root.get_node("Reglages").ZOMBIE_COUREUR_VITESSE_FOIS
				print("vitesse de charge: ", snappedf(v, 1), " (attendu ", attendu, ", heros ", root.get_node("Reglages").HEROS_VITESSE, ")")
				_snap("coureur_charge")
			if z and is_instance_valid(z) and z._etat == 4 and not mesures.has("souffle_debut"):
				mesures["souffle_debut"] = g
				print("essouffle apres ", snappedf((g - mesures["charge"]) / 60.0, 0.01), " s de charge (reglage ",
					root.get_node("Reglages").ZOMBIE_COUREUR_DUREE_CHARGE, " s)")
				h.position = z.position + Vector2(-150, 30)   # derrière lui, pour la capture
				h.get_node("Camera2D").reset_smoothing()
			if mesures.has("souffle_debut") and g == mesures["souffle_debut"] + 30:
				print("essouffle: vitesse ", snappedf(z.velocity.length(), 0.1), " etat ", E[z._etat], " (attendu 0, ESSOUFFLE)")
				_snap("coureur_essouffle")
			if mesures.has("souffle_debut") and z._etat != 4 and not mesures.has("souffle_fin"):
				mesures["souffle_fin"] = g
				print("fin de l'essoufflement apres ", snappedf((g - mesures["souffle_debut"]) / 60.0, 0.01), " s -> ", E[z._etat])
				# Un coup de batte (il en faut 2 depuis le lot 3 b)
				h.position = z.position + Vector2(-60, 0)
				h._regard = Vector2.RIGHT
			if mesures.has("souffle_fin") and g == mesures["souffle_fin"] + 3:
				h.attaquer()
			if mesures.has("souffle_fin") and g == mesures["souffle_fin"] + 10:
				print("coureur apres 1 coup: battu=", z._battu, " pv=", z._pv, " (attendu false, pv ", root.get_node("Reglages").ZOMBIE_COUREUR_PV - 1, ")")
				_aller("fin")
			if g > 600:
				print("ECHEC : le coureur n'a pas fini sa charge"); _aller("fin")
		"fin":
			if g == 1:
				partie.resultat = {"victoire": true, "rapportes": ["eau"], "perdus": [], "mission": false, "bonus": [], "fioles": 0}
				change_scene_to_file("res://scenes/fin.tscn")
			if g == 40:
				print("fin: '", current_scene.get_node("Resume").text.split("\n")[0], "'")
				_snap("victoire")
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sauvegarde.json"))
				partie.skin = ""; partie.prenom = ""
				quit()
	return false
