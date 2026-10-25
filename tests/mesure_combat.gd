extends SceneTree
## Mesure du combat (pas un test) : le héros reste immobile dans l'allée centrale du supermarché et frappe
## dès que la batte est prête et un zombie à portée. Pour chaque cas : coups donnés, cœurs perdus, durée.
## Lancer : xvfb-run godot --rendering-driver opengl3 -s tests/mesure_combat.gd
## (pas de physique de rendu : les pas de physique comptent, 60 par seconde).

const CAS := [["Gros seul", ["ZombieLent"]], ["Maigre seul", ["ZombieRapide"]], ["Coureur seul", ["ZombieCoureur"]],
	["Gros + maigre de deux côtés", ["ZombieLent", "ZombieRapide"]]]
const HEROS := Vector2(1100, 760)
const PLACES := [Vector2(1400, 760), Vector2(800, 760)]
const DUREE_MAX := 20.0

var cas := -1
var niveau: Node
var h
var zombies := []
var pas := 0
var coups := 0
var pv_depart := 0


func _initialize():
	root.get_node("Partie").choisir_lieu("supermarche")
	_suivant()


func _suivant():
	cas += 1
	if niveau:
		niveau.queue_free()
		niveau = null
	if cas >= CAS.size():
		quit()
		return
	niveau = load("res://scenes/lieux/supermarche.tscn").instantiate()
	root.add_child(niveau)
	pas = 0
	coups = 0
	zombies = []


func _physics_process(_d):
	if niveau == null:
		return
	pas += 1
	if pas == 2:
		h = niveau.get_node("Monde/Heros")
		h.position = HEROS
		pv_depart = h._pv
		var noms: Array = CAS[cas][1]
		for z in niveau.get_tree().get_nodes_in_group("zombies"):
			if not noms.has(z.name):
				z.remove_from_group("zombies")
				z.queue_free()
		for i in noms.size():
			var z = niveau.get_node("Monde/" + noms[i])
			z.position = PLACES[i]
			z._depart = PLACES[i]
			z.patrouille = Vector2.ZERO
			z._regard = z.position.direction_to(HEROS)
			zombies.append(z)
		return
	if pas < 3:
		return
	var vivants := zombies.filter(func(z): return is_instance_valid(z) and not z._battu)
	if vivants.is_empty() or h._pv <= 0 or pas > DUREE_MAX * 60:
		print("%s : %d coups, %.1f s, %d cœur(s) perdu(s)%s" % [CAS[cas][0], coups, pas / 60.0, pv_depart - h._pv,
			"" if vivants.is_empty() else " (zombie(s) pas battu(s))"])
		_suivant()
		return
	# Il se tourne vers le zombie le plus proche et frappe dès que possible
	vivants.sort_custom(func(a, b): return a.position.distance_to(h.position) < b.position.distance_to(h.position))
	var proche = vivants[0]
	h._regard = h.position.direction_to(proche.position)
	if h.recharge() == 0.0 and proche.position.distance_to(h.position) <= root.get_node("Reglages").ATTAQUE_PORTEE:
		h.attaquer()
		coups += 1
