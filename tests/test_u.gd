extends SceneTree
## Combat et lisibilité (lot 3 b) : garde du gros (sonné un coup sur deux), préparation du coup (bras levés,
## immobile, le coup part à la fin du geste), esquive en reculant, ondes de bruit (pas discrets, batte forte),
## cônes de vue sur le calque des repères sans ombre. Captures : bras levés, ondes.
## Affiche « ECHEC » à chaque vérification ratée.
var g := 0
var phase := "garde"
var niveau
var h
var hud
var lent
var rapide
var reg
var ondes
var debut := -1
var pv := 0
var echecs := 0


func _initialize():
	reg = root.get_node("Reglages")
	root.get_node("Partie").choisir_lieu("supermarche")
	niveau = load("res://scenes/lieux/supermarche.tscn").instantiate()
	root.add_child(niveau)
	current_scene = niveau


func _snap(n): root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/capture_u_%s.png" % n)
func _verifier(texte: String, ok: bool) -> void:
	print(texte, " -> ", "OK" if ok else "ECHEC")
	if not ok:
		echecs += 1
func _aller(p):
	phase = p; g = 0; debut = -1
func _enlever(z):
	z.remove_from_group("zombies"); z.queue_free()
func _placer(z, decalage: Vector2):
	z.position = h.position + decalage
	z._depart = z.position
	z.patrouille = Vector2.ZERO
	z._regard = z.position.direction_to(h.position)
	z._delai_coup = 0.0
	z._etourdi = 0.0


func _physics_process(_d):
	g += 1
	match phase:
		"garde":
			if g == 2:
				h = niveau.get_node("Monde/Heros")
				h.position = Vector2(1100, 760)   # allée centrale
				lent = niveau.get_node("Monde/ZombieLent")
				rapide = niveau.get_node("Monde/ZombieRapide")
				_enlever(niveau.get_node("Monde/ZombieCoureur"))
				ondes = niveau.get_node("Reperes/Ondes")
				_placer(lent, Vector2(300, 0))
				rapide.position = Vector2(2200, 1450); rapide._depart = rapide.position; rapide.patrouille = Vector2.ZERO
			if g == 4:
				var pv_lent = lent._pv
				lent.recevoir_coup(1, h.position)
				_verifier("gros, 1er coup : dégâts %d -> %d, pas sonné (%.2f), pas repoussé, flash" % [pv_lent, lent._pv, lent._etourdi],
					lent._pv == pv_lent - 1 and lent._etourdi == 0.0 and lent._recul == Vector2.ZERO and lent._flash > 0.0)
			if g == 10:
				lent.recevoir_coup(1, h.position)
				_verifier("gros, 2e coup : sonné (%.2f) et repoussé" % lent._etourdi, lent._etourdi > 0.0 and lent._recul != Vector2.ZERO)
			if g == 40:
				lent.recevoir_coup(1, h.position)
				_verifier("gros, 3e coup : pas sonné", lent._etourdi == 0.0)
			if g == 42:
				rapide.recevoir_coup(1, h.position)
				_verifier("maigre : sonné à chaque coup (%.2f)" % rapide._etourdi, rapide._etourdi > 0.0)
				_verifier("PV en plus : gros %d, maigre %d, coureur %d (attendu 5, 3, 2)" % [reg.ZOMBIE_LENT_PV, reg.ZOMBIE_RAPIDE_PV, reg.ZOMBIE_COUREUR_PV],
					reg.ZOMBIE_LENT_PV == 5 and reg.ZOMBIE_RAPIDE_PV == 3 and reg.ZOMBIE_COUREUR_PV == 2)
				lent.position = Vector2(300, 1450); lent._depart = lent.position
			if g == 80:
				_aller("preparation")
		"preparation":
			if g == 1:
				pv = h._pv
				_placer(rapide, Vector2(30, 0))
			if debut < 0 and rapide.prepare_coup():
				debut = g
				_verifier("le maigre au contact lève les bras (après %d pas)" % g, g <= 5)
			if debut > 0 and g == debut + 10:
				_verifier("pendant le geste : immobile (%.0f) et pas encore de coup (cœurs %d)" % [rapide.velocity.length(), h._pv],
					rapide.velocity.length() < 1.0 and h._pv == pv and rapide.prepare_coup())
			if debut > 0 and g == debut + 25:
				_verifier("fin du geste, toujours au contact : 1 cœur perdu (%d -> %d)" % [pv, h._pv], h._pv == pv - 1)
				_enlever(rapide)
			if g == 120:
				_verifier("préparation vue", debut > 0)
				_aller("esquive")
		"esquive":
			if g == 1:
				pv = h._pv
				_placer(lent, Vector2(30, 0))
			if debut < 0 and lent.prepare_coup():
				debut = g
				h.definir_direction(Vector2.LEFT)   # il recule
			if debut > 0 and g == debut + 25:
				h.definir_direction(Vector2.ZERO)
				_verifier("esquive en reculant : aucun cœur perdu (%d -> %d), coup parti dans le vide (délai %.2f)" % [pv, h._pv, lent._delai_coup],
					h._pv == pv and not lent.prepare_coup() and lent._delai_coup > 0.0)
			if g == 100:
				_verifier("préparation du gros vue", debut > 0)
				# Capture : geste allongé pour qu'il soit encore là quand l'image est rendue
				reg.ZOMBIE_PREPARATION = 5.0
				_placer(lent, Vector2(35, 0))
				h._invulnerable = 10.0
			if g == 150:
				_verifier("bras levés pour la capture", lent.prepare_coup())
				_snap("bras")
			if g == 152:
				reg.ZOMBIE_PREPARATION = 0.3
				_verifier("cône de vue sur le calque des repères, sans ombre", lent._cone.get_parent().name == "Reperes"
					and lent._cone.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED)
				_enlever(lent)
				_aller("ondes")
		"ondes":
			if g == 60:
				ondes.ondes.clear()
				h.definir_direction(Vector2.DOWN)
			if g == 66:
				h.definir_direction(Vector2.ZERO)
				var pas = ondes.ondes.filter(func(o): return not o[3])
				_verifier("pas : onde discrète émise (%d), portée %s" % [pas.size(), str(pas[0][1]) if pas.size() > 0 else "-"],
					pas.size() >= 1 and pas[0][1] == reg.BRUIT_PAS)
				h.attaquer()
				var fortes = ondes.ondes.filter(func(o): return o[3])
				_verifier("batte : onde forte émise, portée %s" % (str(fortes[0][1]) if fortes.size() > 0 else "-"),
					fortes.size() == 1 and fortes[0][1] == reg.BRUIT_ATTAQUE)
				_verifier("onde dessinée sans ombre", ondes.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED)
			if g == 70:
				_snap("ondes")
			if g == 110:
				_verifier("ondes effacées après leur durée (%d)" % ondes.ondes.size(), ondes.ondes.is_empty())
				print("test_u : %d échec(s)" % echecs)
				quit()
	return false
