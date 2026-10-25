extends SceneTree
## Rescapé : caché avec « ? », suit le héros après contact (HUD en couleur), attend quand le héros se cache,
## réapparaît derrière le héros s'il est bloqué trop loin, retourne se cacher si un zombie le touche,
## sauvé à la sortie (écran de fin, sauvegarde version 5), ne réapparaît plus ; fiche de la carte ;
## pas sauvé si le héros meurt ; reprise d'une sauvegarde version 4 ; page Rescapé de l'écran Réglages.
var f := 0
var partie
var rg
var r   # rescapé
var depart := Vector2.ZERO
var avant := Vector2.ZERO
const FICHIER := "user://sauvegarde.json"


func _initialize():
	partie = root.get_node("Partie")
	rg = root.get_node("Reglages")
	_effacer()
	partie.choisir_lieu("supermarche")
	change_scene_to_file(partie.scene_lieu())


func _effacer():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	partie.inventaire = {}; partie.constructions = []; partie.remede = 0; partie.remede_annonce = false
	partie.rescapes = 0; partie.lieux_sauves = []


func _touch(pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_p_%s.png" % n)
func _heros(): return current_scene.get_node("Monde/Heros")
func _hud(): return current_scene.get_node("HUD")
func _icone(): return "visible %s en couleur %s" % [_hud()._rescape.visible, _hud()._rescape_suit]
func _etat(): return r.Etat.keys()[r._etat]
func _calmer():
	for z in get_nodes_in_group("zombies"): z.position = Vector2(2300, 1550); z._depart = z.position; z.patrouille = Vector2.ZERO


func _physics_process(_d):
	f += 1
	# --- Supermarché : caché, puis il suit ---
	if f == 20:
		_calmer()
		r = current_scene.get_node("Monde/Rescape")
		depart = r.position
		print("rescape: ", _etat(), " a ", depart, " pose: ", r._pose()["nom"], " (attendu CACHE survivor_hiding) HUD: ", _icone(), " (attendu visible, pas en couleur)")
		var h = _heros()
		h.position = depart + Vector2(-160, 60)
		h._regard = Vector2(1, -0.4).normalized()
	if f == 60:
		print("heros a 170 : ", _etat(), " (attendu CACHE)")
		_snap("cache")
		_heros().position = depart + Vector2(-30, 10)
	if f == 66:
		print("contact: ", _etat(), " (attendu SUIT) HUD: ", _icone(), " (attendu en couleur)")
		_heros().definir_direction(Vector2.DOWN)
	if f > 66 and f < 130 and f % 20 == 0:
		print("  suit: distance ", int(r.position.distance_to(_heros().position)), " pose ", r._pose()["nom"])
	if f == 125: _snap("suit")
	if f == 130:
		var h = _heros()
		h.definir_direction(Vector2.ZERO)
		print("heros a ", h.position.round(), " rescape a ", r.position.round(), " distance ", int(r.position.distance_to(h.position)),
			" (attendu ~", rg.RESCAPE_DISTANCE, ") vitesse rescape ", rg.RESCAPE_VITESSE, " < heros ", rg.HEROS_VITESSE)
	# --- Le héros se cache : il attend ---
	if f == 160:
		var carton = current_scene.get_node("Monde/Carton1")
		_heros().position = carton.position + Vector2(0, 45)
		r.position = carton.position + Vector2(90, 70)
	if f == 166:
		current_scene._sur_cacher()
		avant = r.position
	if f == 200:
		print("heros cache: ", _etat(), " (attendu ATTEND) immobile: ", r.position.distance_to(avant) < 1.0, " pose ", r._pose()["nom"], " HUD: ", _icone())
		_snap("attend")
		current_scene._sur_cacher()
	if f == 210: print("heros sorti: ", _etat(), " (attendu SUIT)")
	# --- Bloqué trop loin derrière une étagère : il réapparaît derrière le héros ---
	if f == 230:
		var h = _heros()
		h.position = Vector2(650, 1060)
		h._regard = Vector2.DOWN
		r.position = Vector2(650, 300)
	if f == 380:
		print("bloque derriere l'etagere: distance ", int(r.position.distance_to(_heros().position)), " (attendu <= ", rg.RESCAPE_DISTANCE + 5,
			") a ", r.position.round(), " (attendu derriere le heros, y < 1060)")
		_snap("teleporte")
	# --- Un zombie le touche : il retourne se cacher ---
	if f == 400:
		var z = get_nodes_in_group("zombies")[0]
		z.position = r.position + Vector2(20, 0)
	if f == 403:
		print("touche par un zombie: ", _etat(), " (attendu RETOUR) HUD: ", _icone(), " (attendu pas en couleur)")
		_calmer()
	if f == 420: _snap("peur")
	if f == 880:
		print("revenu: ", _etat(), " (attendu CACHE) a sa place: ", r.position.distance_to(depart) < 12.0)
		_heros().position = depart + Vector2(-30, 10)
	if f == 886:
		print("re-contact: ", _etat(), " (attendu SUIT)")
		var sortie = current_scene.get_node("Monde/Sortie").position
		_heros().position = sortie + Vector2(0, 30)
		r.position = sortie + Vector2(60, 80)
	# --- Sortie : sauvé ---
	if f == 960:
		var res = partie.resultat
		print("scene: ", current_scene.name, " rescape sauve: ", res["rescape"], " total: ", partie.rescapes, " lieux: ", partie.lieux_sauves)
		print("resume: ", current_scene.get_node("Resume").text.replace("\n", " | "))
		var b = current_scene.get_node("RetourBase")
		print("bouton dans l'ecran: ", current_scene.get_viewport_rect().encloses(b.get_global_rect()))
		var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
		print("sauvegarde: version ", d["version"], " rescapes ", d["rescapes"], " lieux_sauves ", d["lieux_sauves"])
		_snap("fin")
		change_scene_to_file(partie.scene_lieu())
	if f == 1000:
		print("supermarche rejoue: rescapes dans le lieu ", get_nodes_in_group("rescapes").size(), " (attendu 0) noeud: ",
			current_scene.has_node("Monde/Rescape"), " HUD: ", _icone(), " (attendu pas visible)")
		_snap("sans_rescape")
		change_scene_to_file("res://scenes/carte.tscn")
	# --- Carte ---
	if f == 1030:
		print("infos: supermarche ", partie.infos_lieu("supermarche")["rescapes"], " maison ", partie.infos_lieu("maison")["rescapes"])
		_touch(current_scene._place("supermarche"), true)
	if f == 1036: _touch(Vector2.ZERO, false)
	if f == 1060:
		_snap("fiche_sauve")
		_touch(current_scene._place("maison"), true)
	if f == 1066: _touch(Vector2.ZERO, false)
	if f == 1090:
		_snap("fiche_maison")
		partie.choisir_lieu("maison")
		change_scene_to_file(partie.scene_lieu())
	# --- Maison : il suit, puis le héros meurt -> pas sauvé ---
	if f == 1130:
		_calmer()
		r = current_scene.get_node("Monde/Rescape")
		print("maison: rescape ", _etat(), " HUD: ", _icone())
		_heros().position = r.position + Vector2(-60, 40)
		_heros()._regard = Vector2.RIGHT
	if f == 1170:
		_snap("maison_cache")
		_heros().position = r.position + Vector2(-30, 10)
	if f == 1176:
		print("maison contact: ", _etat())
		_heros().recevoir_degats(99, _heros().position + Vector2(10, 0))
	if f == 1280:
		print("mort: scene ", current_scene.name, " rescape sauve: ", partie.resultat["rescape"], " (attendu false) lieux: ", partie.lieux_sauves, " (attendu [supermarche])")
		# --- Reprise d'une sauvegarde version 4 ---
		var v4 := FileAccess.open(FICHIER, FileAccess.WRITE)
		v4.store_string(JSON.stringify({"version": 4, "inventaire": {"eau": 2}, "constructions": [], "remede": 1, "remede_annonce": false, "skin": "heroine", "prenom": "Eliott"}))
		v4.close()
		partie.rescapes = 0; partie.lieux_sauves = []; partie.inventaire = {}
		partie.charger()
		var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
		print("reprise v4: rescapes ", partie.rescapes, " lieux ", partie.lieux_sauves, " eau ", partie.inventaire.get("eau"), " prenom ", partie.prenom,
			" -> reecrite en version ", d["version"], " avec rescapes ", d.get("rescapes"), " lieux_sauves ", d.get("lieux_sauves"))
		var pj = root.get_node("ParametresJeu")
		var page = pj.PAGES[pj.PAGES.size() - 1]
		var noms = []
		for reglage in page[1]: noms.append(reglage[0])
		print("page reglages: ", page[0], " ", noms)
		_effacer()
		partie.skin = ""; partie.prenom = ""
		quit()
