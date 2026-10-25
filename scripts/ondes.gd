extends Node2D
## Ondes de bruit : un cercle clair qui s'agrandit au sol jusqu'à la portée du bruit (pas, coup de batte),
## pour comprendre pourquoi un zombie arrive. Calque sans ombre (visible dans la nuit) ; toutes les ondes
## sont dessinées par ce seul nœud. Le cercle est calculé dans le monde, puis projeté (Iso).

const DUREE_PAS := 0.45      # secondes pour qu'une onde de pas atteigne sa portée
const DUREE_FORTE := 0.6     # onde du coup de batte
const POINTS := 40           # points du cercle

var ondes := []   # chaque onde : [origine (monde), rayon, âge, forte]


func _ready() -> void:
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = sans_ombre


## forte : coup de batte (onde plus épaisse et plus visible) ; sinon un pas (discrète).
func emettre(origine: Vector2, rayon: float, forte: bool) -> void:
	if rayon > 0.0:
		ondes.append([origine, rayon, 0.0, forte])


func _process(delta: float) -> void:
	if ondes.is_empty():
		return
	for onde in ondes:
		onde[2] += delta
	ondes = ondes.filter(func(onde: Array) -> bool: return onde[2] < (DUREE_FORTE if onde[3] else DUREE_PAS))
	queue_redraw()


func _draw() -> void:
	for onde in ondes:
		var avance: float = onde[2] / (DUREE_FORTE if onde[3] else DUREE_PAS)
		var rayon: float = onde[1] * (1.0 - pow(1.0 - avance, 2.0))   # rapide au début, ralentit au bord
		var couleur := Color(Palette.ONDE_BRUIT, (0.7 if onde[3] else 0.3) * (1.0 - avance))
		var points := PackedVector2Array()
		for i in POINTS + 1:
			points.append(Iso.ecran(onde[0] + Vector2.from_angle(TAU * i / POINTS) * rayon))
		draw_polyline(points, couleur, 5.0 if onde[3] else 2.5, true)
