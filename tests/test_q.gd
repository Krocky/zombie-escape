extends SceneTree
## Images V3 des boutons et des objets : Frapper (icon_hit, disque jaune) avec jauge de recharge, icône grisée
## puis rebond ; Cacher (icon_hide) grisé loin d'une cachette, normal tout près, « Sortir » dessiné en code une fois caché ;
## fiole (item_vial) et clef (item_key) aux trois teintes d'étiquette ; la clef hors inventaire, coûts et bonus.
var g := 0
var h
var hud
var ancienne = null


func _initialize():
	var partie = root.get_node("Partie")
	partie.choisir_lieu("supermarche")
	ancienne = current_scene
	change_scene_to_file("res://scenes/lieux/supermarche.tscn")


func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_q_%s.png" % n)


## Icônes de la fiole et des trois clefs, en haut au milieu (pour les captures).
func _dessiner_icones(zone: Control) -> void:
	var dessin = load("res://scripts/dessin.gd")
	zone.draw_rect(Rect2(Vector2.ZERO, zone.size), Color(0.1, 0.09, 0.16, 0.85))
	dessin.icone_objet(zone, "fiole", Vector2(40, 66), 56.0)
	var x := 110.0
	for teinte in ["rouge", "bleue", "verte"]:
		dessin.icone_objet(zone, "clef", Vector2(x, 66), 56.0, Color.WHITE, teinte)
		x += 84.0


func _physics_process(_d):
	if current_scene == null or current_scene == ancienne:
		return
	g += 1
	if g == 5:
		h = current_scene.get_node("Monde/Heros")
		hud = current_scene.get_node("HUD")
		for zz in get_nodes_in_group("zombies"):
			zz.position = Vector2(2300, 1550); zz._depart = zz.position; zz.patrouille = Vector2.ZERO
		var images = root.get_node("Images")
		var partie = root.get_node("Partie")
		print("images V3: ", ["item_vial", "item_key", "icon_hit", "icon_hide"].map(func(n): return images.v3_existe(n)), " (attendu tout vrai)")
		var bleue: Image = images.v3_teinte("item_key", root.get_node("Palette").CLEF["bleue"]).get_image()
		var rouge: Image = images.v3_texture("item_key").get_image()
		if rouge.is_compressed(): rouge.decompress()
		var rouges := 0
		var bleus := 0
		for y in rouge.get_height():
			for x in rouge.get_width():
				var c := rouge.get_pixel(x, y)
				if c.a > 0.8 and c.r > 0.7 and c.g < 0.4 and c.b < 0.4:
					rouges += 1
					var b := bleue.get_pixel(x, y)
					if b.b > b.r and b.b > b.g:
						bleus += 1
		print("clef bleue: ", bleus, " / ", rouges, " pixels rouges de l'etiquette devenus bleus (attendu tous)")
		print("clef: nom '", partie.nom("clef"), "' hors inventaire/bonus: ", not partie.NOMS.has("clef"), " (attendu Clef, true)")
		var zone := Control.new()
		zone.position = Vector2(400, 150)
		zone.size = Vector2(380, 80)
		zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.draw.connect(_dessiner_icones.bind(zone))
		hud.add_child(zone)
	if g == 40:
		print("loin d'une cachette: Cacher actif=", hud.get_node("BoutonCacher").actif, " (attendu false)",
			" Frapper recharge=", hud.get_node("BoutonAttaquer").recharge, " (attendu 0)")
		_snap("repos")
		h.attaquer()
	if g == 50:
		var r: float = hud.get_node("BoutonAttaquer").recharge
		print("apres un coup: recharge=", snappedf(r, 0.01), " (attendu entre 0 et 1)")
		_snap("recharge")
	if g == 5 + 35 + int(60 * root.get_node("Reglages").ATTAQUE_DELAI) + 3:
		var b = hud.get_node("BoutonAttaquer")
		print("recharge finie: ", b.recharge, " rebond en cours: ", b._rebond > 0.0, " (attendu 0, true)")
		# Tout près d'une cachette
		var cachette = get_nodes_in_group("cachettes")[0]
		h.position = cachette.global_position + Vector2(0, 40); h.velocity = Vector2.ZERO; h.get_node("Camera2D").reset_smoothing()
	if g == 120:
		print("pres de ", get_nodes_in_group("cachettes")[0].name, ": Cacher actif=", hud.get_node("BoutonCacher").actif, " (attendu true)")
		_snap("pres_cachette")
		current_scene._sur_cacher()
	if g == 160:
		var b = hud.get_node("BoutonCacher")
		print("cache: bouton '", b.texte, "' icone ", b.icone, " Frapper actif=", hud.get_node("BoutonAttaquer").actif, " (attendu Sortir, sortir, false)")
		_snap("cache")
		quit()
