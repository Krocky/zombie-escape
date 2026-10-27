extends StaticBody2D
## Voiture garée sur le parking de la base : image V5 (IMAGES, selon la couleur), sinon dessinée en code : carrosserie,
## habitacle vitré, roues, phares. `survie` : la voiture de survie (galerie de toit chargée, phares allumés) ; quand le
## héros est près d'elle, le bouton Start ouvre la carte. Sinon une épave (rouille sur le capot, phares éteints).
## position = milieu du bord bas de l'emprise au sol (comme Mur). Affichage isométrique découpé en bandes triées
## (Iso.bandes_dessin) : le héros passe devant ou derrière.

@export var taille := Vector2(110, 230)   # emprise au sol (collision), longue en x ou en y
@export var couleur := "rouille"           # carrosserie : clé de Palette.VOITURES
@export var survie := false

const CAISSE := Vector2(10, 38)       # bas et haut de la carrosserie (pixels à l'écran)
const HABITACLE := 66.0               # haut du toit
const GALERIE := 82.0                 # haut des bagages sur le toit (voiture de survie)
const ROUE := Vector2(24, 15)         # rayon des roues : le long de la voiture (monde), en hauteur (écran)
## Image V5 de chaque couleur (dessin en code si elle manque)
const IMAGES := {"survie": "base_survival_car", "rouille": "prop_wreck_rust", "rouge": "prop_wreck_red",
	"jaune": "prop_wreck_yellow"}

var _vue := Node2D.new()   # dans le calque Vue (trié en profondeur)
var _sol := Node2D.new()   # dans le calque du sol (ombre)


func _ready() -> void:
	var forme := RectangleShape2D.new()
	forme.size = taille
	var collision := CollisionShape2D.new()
	collision.shape = forme
	collision.position = Vector2(0, -taille.y / 2.0)
	add_child(collision)
	_vue.y_sort_enabled = true
	if _image() != "":
		Iso.habiller(_image(), emprise(), _vue, Iso.miroir_pour(_image(), taille.x >= taille.y))
		return   # l'image a déjà son ombre
	_sol.draw.connect(func() -> void: Iso.ombre(_sol, emprise(), 0.9))
	_construire()


## Nœuds d'affichage, placés par le niveau : {"vue": ..., "sol": ...}.
func visuels() -> Dictionary:
	return {"vue": _vue, "sol": _sol}


func emprise() -> Rect2:
	return Rect2(global_position + Vector2(-taille.x / 2.0, -taille.y), taille)


## Image V5 de la voiture, "" si elle manque.
func _image() -> String:
	var nom: String = IMAGES.get(couleur, "")
	return nom if nom != "" and Images.existe(nom) else ""


## Distance d'un point du monde au bord de la voiture (0 dessus).
func distance_a(p: Vector2) -> float:
	var e := emprise()
	return p.distance_to(p.clamp(e.position, e.end))


## Point à l'écran : u le long de la voiture, v en travers (monde, depuis le coin arrière), z en hauteur (écran).
func _point(u: float, v: float, z: float) -> Vector2:
	var p := emprise().position + (Vector2(u, v) if taille.x >= taille.y else Vector2(v, u))
	return Iso.ecran(p) - Vector2(0, z)


func _construire() -> void:
	var long := maxf(taille.x, taille.y)
	var large := minf(taille.x, taille.y)
	var corps: Color = Palette.VOITURES.get(couleur, Palette.VOITURES["grise"])
	# Le long côté visible est éclairé (face +y) ou dans l'ombre (face +x), selon le sens de la voiture
	var en_x := taille.x >= taille.y
	var cote := corps.darkened(0.25 if en_x else 0.42)
	var bout := corps.darkened(0.42 if en_x else 0.25)
	var formes := []
	_boite(formes, 0.0, long, 0.0, large, CAISSE.x, CAISSE.y, corps, cote, bout)
	if not survie:
		# Rouille sur le capot
		_face(formes, [_point(long * 0.8, large * 0.2, CAISSE.y), _point(long * 0.95, large * 0.3, CAISSE.y),
			_point(long * 0.9, large * 0.7, CAISSE.y), _point(long * 0.76, large * 0.5, CAISSE.y)], corps.darkened(0.5), false)
	_boite(formes, long * 0.22, long * 0.7, large * 0.1, large * 0.9, CAISSE.y, HABITACLE, corps.lightened(0.08),
		Palette.VITRE, Palette.VITRE.darkened(0.25))
	# Reflet sur le pare-brise
	_face(formes, [_point(long * 0.7, large * 0.25, CAISSE.y + 8.0), _point(long * 0.7, large * 0.35, CAISSE.y + 8.0),
		_point(long * 0.7, large * 0.55, HABITACLE - 6.0), _point(long * 0.7, large * 0.45, HABITACLE - 6.0)], Palette.VITRE_REFLET, false)
	# Montant entre les deux vitres du côté
	_face(formes, [_point(long * 0.45, large * 0.9, CAISSE.y), _point(long * 0.48, large * 0.9, CAISSE.y),
		_point(long * 0.48, large * 0.9, HABITACLE), _point(long * 0.45, large * 0.9, HABITACLE)], corps.lightened(0.08))
	if survie:
		# Galerie de toit chargée : un gros sac et un bidon
		_boite(formes, long * 0.28, long * 0.52, large * 0.2, large * 0.8, HABITACLE, GALERIE, Palette.BAGAGE,
			Palette.BAGAGE.darkened(0.25), Palette.BAGAGE.darkened(0.4))
		_boite(formes, long * 0.55, long * 0.66, large * 0.3, large * 0.6, HABITACLE, GALERIE - 4.0, Palette.SORTIE,
			Palette.SORTIE.darkened(0.3), Palette.SORTIE.darkened(0.45))
	# Phares sur l'avant visible : allumés sur la voiture de survie
	var phare := Palette.PHARE if survie else Palette.PHARE.darkened(0.6)
	for v: float in [0.12, 0.7]:
		_face(formes, [_point(long, large * v, 24.0), _point(long, large * (v + 0.18), 24.0),
			_point(long, large * (v + 0.18), 32.0), _point(long, large * v, 32.0)], phare)
	# Deux roues sur le long côté visible
	for u: float in [0.2, 0.8]:
		var roue := PackedVector2Array()
		var jante := PackedVector2Array()
		for k in 14:
			var a := TAU * k / 14.0
			roue.append(_point(long * u + cos(a) * ROUE.x, large + 1.0, ROUE.y + sin(a) * ROUE.y))
			jante.append(_point(long * u + cos(a) * ROUE.x * 0.45, large + 1.0, ROUE.y + sin(a) * ROUE.y * 0.45))
		_face(formes, roue, Palette.PNEU)
		_face(formes, jante, Palette.PIERRE, false)
	Iso.bandes_dessin(formes, Iso.coins(emprise()), _vue)


## Polygone à l'écran (et son contour) ajouté aux formes.
func _face(formes: Array, points: Array, couleur_face: Color, avec_contour := true) -> void:
	var poly := PackedVector2Array(points)
	formes.append([poly, couleur_face])
	if avec_contour:
		formes.append_array(Iso.contour(poly))


## Boîte (u0..u1 le long, v0..v1 en travers, z0..z1 en hauteur) : long côté visible, bout visible, dessus.
func _boite(formes: Array, u0: float, u1: float, v0: float, v1: float, z0: float, z1: float,
		dessus: Color, cote: Color, bout: Color) -> void:
	_face(formes, [_point(u0, v1, z0), _point(u1, v1, z0), _point(u1, v1, z1), _point(u0, v1, z1)], cote)
	_face(formes, [_point(u1, v0, z0), _point(u1, v1, z0), _point(u1, v1, z1), _point(u1, v0, z1)], bout)
	_face(formes, [_point(u0, v0, z1), _point(u1, v0, z1), _point(u1, v1, z1), _point(u0, v1, z1)], dessus)
