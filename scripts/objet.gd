extends Node2D
## Un objet à ramasser. Le niveau le ramasse quand le héros marche dessus.
## Origine = au sol (coordonnées monde). Affichage isométrique dans le calque Vue.

@export_enum("conserve", "eau", "bandage", "piles", "fiole") var type := "conserve"

const HAUTEUR_ICONE := 46.0   # pixels d'écran
const DUREE_RAMASSAGE := 0.5
const PERIODE_ECLAT := 2.6    # un scintillement toutes les 2,6 s

var _temps := randf() * TAU
var _ramasse := 0.0   # > 0 : animation de ramassage
var _vue := Node2D.new()
var _eclat := Node2D.new()   # scintillement et étincelles : non assombris par la nuit


## Appelé par le niveau. Renvoie le type, puis l'objet s'envole et disparaît.
func ramasser() -> String:
	remove_from_group("objets")
	_ramasse = DUREE_RAMASSAGE
	return type


## Nœuds d'affichage, placés par le niveau.
func visuels() -> Dictionary:
	return {"vue": _vue}


func _ready() -> void:
	_vue.position = Iso.ecran(global_position)
	_vue.draw.connect(_dessiner)
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_eclat.material = sans_ombre
	_eclat.draw.connect(_dessiner_eclat)
	_vue.add_child(_eclat)


func _exit_tree() -> void:
	if is_instance_valid(_vue):
		_vue.queue_free()


func _process(delta: float) -> void:
	_temps += delta
	if _ramasse > 0.0:
		_ramasse -= delta
		if _ramasse <= 0.0:
			queue_free()
	_vue.queue_redraw()
	_eclat.queue_redraw()


func _flotte() -> float:
	var flotte := sin(_temps * 3.0) * 4.0 - 14.0
	if _ramasse > 0.0:
		flotte -= (1.0 - _ramasse / DUREE_RAMASSAGE) * 50.0
	return flotte


func _dessiner() -> void:
	var flotte := _flotte()
	var pulse := 1.0 + 0.06 * sin(_temps * 4.0)   # l'icône respire doucement
	if _ramasse > 0.0:
		var avance := 1.0 - _ramasse / DUREE_RAMASSAGE
		pulse += avance * 0.6
		_vue.modulate.a = 1.0 - avance
	Dessin.ombre(_vue, Rect2(-22, -7, 44, 14))
	# Petite lueur qui pulse (visible à la lampe)
	_vue.draw_circle(Vector2(0, flotte - HAUTEUR_ICONE / 2.0), 30.0 * pulse, Palette.LAMPE * Color(1, 1, 1, 0.12 + 0.08 * sin(_temps * 4.0)))
	Dessin.icone_objet(_vue, type, Vector2(0, flotte), HAUTEUR_ICONE * pulse)


## Scintillement régulier (repère discret dans le noir) et gerbe d'étincelles au ramassage.
func _dessiner_eclat() -> void:
	var centre := Vector2(0, _flotte() - HAUTEUR_ICONE * 0.6)
	if _ramasse > 0.0:
		var avance := 1.0 - _ramasse / DUREE_RAMASSAGE
		for i in 10:
			var direction := Vector2.from_angle(TAU * i / 10.0 + 0.3)
			_etoile(centre + direction * (12.0 + avance * 70.0), 7.0 * (1.0 - avance), 1.0 - avance)
		return
	var phase := fmod(_temps, PERIODE_ECLAT) / 0.45
	if phase < 1.0:
		var coin := Vector2(cos(_temps * 0.7) * 14.0, sin(_temps * 1.3) * 10.0)
		_etoile(centre + coin, 9.0 * sin(phase * PI), 0.9)


## Petite étoile à 4 branches.
func _etoile(p: Vector2, rayon: float, opacite: float) -> void:
	if rayon <= 0.5:
		return
	var couleur := Palette.LAMPE * Color(1, 1, 1, opacite)
	_eclat.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -rayon), p + Vector2(rayon * 0.25, -rayon * 0.25),
		p + Vector2(rayon, 0), p + Vector2(rayon * 0.25, rayon * 0.25), p + Vector2(0, rayon),
		p + Vector2(-rayon * 0.25, rayon * 0.25), p + Vector2(-rayon, 0), p + Vector2(-rayon * 0.25, -rayon * 0.25)]), couleur)
