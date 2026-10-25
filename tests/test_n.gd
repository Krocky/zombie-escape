extends SceneTree
## Écran Réglages : Base -> bouton Réglages ; + / − changent Reglages et sont sauvegardés (user://reglages.json) ;
## limites (bouton grisé) ; interrupteur Oui / Non ; pages < > ; « Valeurs d'origine » ; la valeur changée
## compte dans le niveau (cœurs, vitesse) ; relecture du fichier (valeur hors limites ramenée).
## Efface user://reglages.json à la fin et remet les valeurs d'origine.
var f := 0
var g := 0
var phase := "base"
var partie
var pj
var reg
var mesures := {}


func _initialize():
	partie = root.get_node("Partie")
	pj = root.get_node("ParametresJeu")
	reg = root.get_node("Reglages")
	partie.skin = "heros"
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	change_scene_to_file("res://scenes/base.tscn")


func _touch(pos, pressed, idx := 0):
	var e = InputEventScreenTouch.new(); e.index = idx; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_n_%s.png" % n)
func _centre(n): return n.get_global_rect().get_center()
func _aller(p):
	phase = p; g = 0
## Appui puis relâchement sur un nœud, à partir du pas « debut » de la phase
## (un chemin de nœud n'est cherché qu'à l'appui : la scène peut changer avant le relâchement)
func _appui(noeud_ou_pos, debut):
	if noeud_ou_pos is String and g == debut: noeud_ou_pos = current_scene.get_node(noeud_ou_pos)
	if g == debut: _touch(noeud_ou_pos if noeud_ou_pos is Vector2 else _centre(noeud_ou_pos), true)
	if g == debut + 6: _touch(Vector2.ZERO, false)
func _ligne(i): return current_scene._boutons[i]


func _physics_process(_d):
	f += 1; g += 1
	match phase:
		"base":
			if g == 20:
				var b = current_scene.get_node("Reglages")
				print("bouton Reglages: ", b.size, " dans l'ecran: ", current_scene.get_viewport_rect().encloses(b.get_global_rect()))
				_snap("base")
			if g == 30 or g == 36: _appui("Reglages", 30)
			if g == 60:
				print("scene: ", current_scene.name, " (attendu Parametres)")
				_aller("page1")
		"page1":
			if g == 1:
				var tout_dedans := true
				for e in current_scene._boutons:
					for b in [e[2], e[3]]:
						if b and not current_scene.get_viewport_rect().encloses(b.get_global_rect()): tout_dedans = false
				print("page 1: ", current_scene.get_node("Titre").text, " lignes: ", current_scene._boutons.size(), " boutons dans l'ecran: ", tout_dedans)
			# Vitesse + 3 fois, cœurs - 1 fois
			for k in 3: if g == 5 + k * 14 or g == 11 + k * 14: _appui(_ligne(0)[3], 5 + k * 14)
			if g == 50 or g == 56: _appui(_ligne(1)[2], 50)
			if g == 90:
				print("vitesse: ", reg.HEROS_VITESSE, " (attendu 290) coeurs: ", reg.HEROS_PV, " (attendu 4)")
				print("fichier: ", FileAccess.get_file_as_string("user://reglages.json"))
				_snap("page1")
			# Limite basse des cœurs : 4 -> 1, puis le bouton moins est grisé
			if g == 100:
				reg.HEROS_PV = 1; current_scene._actualiser()
				print("coeurs au minimum: bouton moins actif=", _ligne(1)[2].actif, " (attendu false)")
			if g == 110 or g == 116: _appui(_ligne(1)[2], 110)
			if g == 130:
				print("appui sur moins grise: coeurs ", reg.HEROS_PV, " (attendu 1)")
				reg.HEROS_PV = 4; pj.sauvegarder()
				_aller("page2")
		"page2":
			if g == 1 or g == 7: _appui(current_scene.get_node("Suivant"), 1)
			if g == 20:
				print("page suivante: ", current_scene.get_node("Titre").text)
				var ips = _ligne(4)
				print("interrupteur ips: '", ips[2].texte, "' valeur ", reg.AFFICHER_IPS)
			if g == 30 or g == 36: _appui(_ligne(4)[2], 30)
			if g == 60:
				print("apres appui: '", _ligne(4)[2].texte, "' valeur ", reg.AFFICHER_IPS, " (attendu Non / false)")
				_snap("page2")
			if g == 70 or g == 76: _appui(current_scene.get_node("Remettre"), 70)
			if g == 100:
				print("valeurs d'origine (page 2): ips ", reg.AFFICHER_IPS, " (attendu true) ; page 1 gardee: vitesse ", reg.HEROS_VITESSE, " (attendu 290)")
			if g == 110 or g == 116: _appui(current_scene.get_node("Precedent"), 110)
			if g == 130 or g == 136: _appui(current_scene.get_node("Precedent"), 130)
			if g == 160:
				print("2 x precedent depuis la page 2: ", current_scene.get_node("Titre").text, " (attendu la derniere page, 5/5)")
				_snap("page5")
				_aller("niveau")
		"niveau":
			if g == 1:
				partie.choisir_lieu("supermarche")
				change_scene_to_file("res://scenes/lieux/supermarche.tscn")
			if g == 10:
				var h = current_scene.get_node("Monde/Heros")
				for z in get_nodes_in_group("zombies"): z.position = Vector2(2300, 1550); z._depart = z.position; z.patrouille = Vector2.ZERO
				print("dans le niveau: coeurs ", h._pv_max, " (attendu 4)")
				h.position = Vector2(600, 1450)
				h.definir_direction(Vector2.RIGHT)
			if g == 20: mesures["x"] = current_scene.get_node("Monde/Heros").position.x
			if g == 50:
				print("vitesse mesuree: ", snappedf((current_scene.get_node("Monde/Heros").position.x - mesures["x"]) / 0.5, 1), " (attendu 290)")
				_aller("relire")
		"relire":
			if g == 1:
				# Fichier écrit à la main avec une valeur trop grande : ramenée au maximum
				var fichier := FileAccess.open("user://reglages.json", FileAccess.WRITE)
				fichier.store_string('{"HEROS_VITESSE": 9999, "ZOMBIE_COUREUR_DUREE_CHARGE": 3.5, "INCONNU": 3}')
				fichier.close()
				pj.charger()
				print("relecture: vitesse ", reg.HEROS_VITESSE, " (attendu 500, maximum) charge ", reg.ZOMBIE_COUREUR_DUREE_CHARGE, " (attendu 3.5)")
				for page in range(pj.PAGES.size()): pj.remettre_page(page)
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://reglages.json"))
				print("remis: vitesse ", reg.HEROS_VITESSE, " coeurs ", reg.HEROS_PV)
				quit()
	return false
