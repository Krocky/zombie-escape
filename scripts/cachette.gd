extends StaticBody2D
## Une cachette (carton ou congélateur). Le héros s'y cache tout près.
## position = milieu du bord bas de l'emprise au sol (coordonnées monde).
## Affichage isométrique (voir Iso) : le niveau place visuels() dans ses calques.

enum Style { CARTON, CONGELATEUR }

@export var style := Style.CARTON
@export var taille := Vector2(110, 70)   # emprise au sol (collision)
@export var hauteur := 70.0              # hauteur du dessin de secours (pixels d'écran)

var _occupee := false
var _temps := 0.0
var _vue := Node2D.new()      # dans le calque Vue (trié en profondeur)
var _sol := Node2D.new()      # dans le calque du sol (ombre)
var _dessus := Node2D.new()   # par-dessus la cachette : les yeux du héros caché
var _haut_dessus := Vector2.ZERO   # milieu du dessus, à l'écran
var _secousse := 0.0


## Distance entre un point et le bord de la cachette (0 si dedans).
func distance_a(point: Vector2) -> float:
	var emprise := Rect2(global_position + Vector2(-taille.x / 2.0, -taille.y), taille)
	var proche := point.clamp(emprise.position, emprise.end)
	return point.distance_to(proche)


func occuper(occupee: bool) -> void:
	_occupee = occupee
	_secousse = 0.3
	_dessus.queue_redraw()


## Nœuds d'affichage, placés par le niveau : {"vue": ..., "sol": ...}.
func visuels() -> Dictionary:
	return {"vue": _vue, "sol": _sol}


func _ready() -> void:
	var forme := RectangleShape2D.new()
	forme.size = taille
	var collision := CollisionShape2D.new()
	collision.shape = forme
	collision.position = Vector2(0, -taille.y / 2.0)
	add_child(collision)
	var emprise := Rect2(global_position + Vector2(-taille.x / 2.0, -taille.y), taille)
	var c := Iso.coins(emprise)
	_vue.y_sort_enabled = true
	_sol.draw.connect(func() -> void: Iso.ombre(_sol, emprise, 0.8))
	var nom := "carton" if style == Style.CARTON else "congelateur"
	var haut_image := hauteur
	if Images.existe(nom):
		Iso.habiller(nom, emprise, _vue, Iso.miroir_pour(nom, taille.x >= taille.y))
		haut_image = Iso.hauteur_image(nom, emprise) * 0.62
	else:
		var boite := Node2D.new()
		boite.position = c[1]
		var relatifs := PackedVector2Array()
		for p in c:
			relatifs.append(p - c[1])
		var couleurs := [Palette.CARTON, Palette.CARTON_FACE, Palette.CARTON_COTE] if style == Style.CARTON \
			else [Palette.CONGELATEUR, Palette.CONGELATEUR_FACE, Palette.CONGELATEUR_COTE]
		boite.draw.connect(func() -> void: Dessin.boite_iso(boite, relatifs, hauteur, couleurs[0], couleurs[1], couleurs[2]))
		_vue.add_child(boite)
	# Les yeux se dessinent juste après la cachette (trié un pixel plus bas que son coin avant)
	_dessus.position = c[1] + Vector2(0, 1)
	_haut_dessus = (c[0] + c[2]) * 0.5 - Vector2(0, haut_image) - _dessus.position
	_dessus.draw.connect(_dessiner_dessus)
	_vue.add_child(_dessus)


func _process(delta: float) -> void:
	# La cachette tremble un instant (de côté seulement : le tri en profondeur ne bouge pas)
	if _secousse > 0.0:
		_secousse = maxf(_secousse - delta, 0.0)
		_vue.position.x = sin(_secousse * 70.0) * 4.0 * _secousse / 0.3
	if _occupee:
		_temps += delta
		_dessus.queue_redraw()


func _dessiner_dessus() -> void:
	if not _occupee:
		return
	# Fente sombre et deux yeux qui regardent à gauche et à droite
	Dessin.ellipse(_dessus, _haut_dessus, Vector2(22, 9), Palette.CONTOUR, false)
	var regard := sin(_temps * 1.5) * 2.0
	for dx: float in [-7.0, 7.0]:
		_dessus.draw_circle(_haut_dessus + Vector2(dx, 0), 5.0, Palette.UI_TEXTE)
		_dessus.draw_circle(_haut_dessus + Vector2(dx + regard, 0), 2.2, Palette.CONTOUR)
