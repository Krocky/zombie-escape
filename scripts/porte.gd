extends StaticBody2D
## Porte fermée à clef (pharmacie : la réserve). Elle bloque tout le monde (couche décor) jusqu'à ce que
## le héros arrive devant avec la clef de même teinte : le niveau appelle alors `ouvrir()`, la porte
## s'efface et laisse le passage. Image V2 « porte_fermee » (cadenas), sinon dessin en code.
## position = milieu du bord bas de l'emprise au sol (comme Mur) ; elle bouche un trou entre deux cloisons.
## Affichage isométrique : le niveau place visuels() dans ses calques.

## Emprise au sol (collision) : longueur du trou x épaisseur de la cloison.
@export var taille := Vector2(200, 30)
## Clef qui l'ouvre (clé de Palette.CLEF, comme Objet.teinte).
@export_enum("rouge", "bleue", "verte") var teinte := "rouge"

const DUREE_OUVERTURE := 0.5   # la porte s'efface
const HAUTEUR_SECOURS := 120.0

var _ouverte := false
var _vue := Node2D.new()      # dans le calque Vue (trié en profondeur)
var _bulle := Node2D.new()    # clef dans une bulle, au-dessus de la porte, quand le héros arrive sans elle
var _bulle_visible := false
var _temps := 0.0
var _hauteur := HAUTEUR_SECOURS
var _image_ecran := Rect2()
var _collision := CollisionShape2D.new()


func _ready() -> void:
	var forme := RectangleShape2D.new()
	forme.size = taille
	_collision.shape = forme
	_collision.position = Vector2(0, -taille.y / 2.0)
	add_child(_collision)
	_vue.y_sort_enabled = true
	var long_en_x := taille.x >= taille.y
	if Images.existe("porte_fermee"):
		_image_ecran = Iso.habiller("porte_fermee", emprise(), _vue, Iso.miroir_pour("porte_fermee", long_en_x))
		_hauteur = Iso.hauteur_image("porte_fermee", emprise())
	else:
		var boite := Node2D.new()
		var c := Iso.coins(emprise())
		boite.position = c[1]
		for i in c.size():
			c[i] -= boite.position
		boite.draw.connect(func() -> void:
			Dessin.boite_iso(boite, c, HAUTEUR_SECOURS, Palette.MUR, Palette.MUR_FACE, Palette.MUR_COTE)
			# Cadenas de la teinte de la clef, au milieu de la face
			var milieu: Vector2 = (c[0] + c[1]) / 2.0 + Vector2(0, -HAUTEUR_SECOURS * 0.45)
			Dessin.rect(boite, Rect2(milieu - Vector2(12, 10), Vector2(24, 22)), Palette.CLEF[teinte]))
		_vue.add_child(boite)
	# Bulle : par-dessus tout, au-dessus de la porte, non assombrie par la nuit
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_bulle.material = sans_ombre
	_bulle.position = Iso.ecran(global_position + Vector2(0, -taille.y / 2.0)) + Vector2(0, 4)
	_bulle.draw.connect(_dessiner_bulle)
	_vue.add_child(_bulle)


## Nœuds d'affichage, placés par le niveau.
func visuels() -> Dictionary:
	return {"vue": _vue}


func _exit_tree() -> void:
	if is_instance_valid(_vue):
		_vue.queue_free()


func emprise() -> Rect2:
	return Rect2(global_position + Vector2(-taille.x / 2.0, -taille.y), taille)


func ouverte() -> bool:
	return _ouverte


## Distance entre un point et le bord de la porte (0 si dedans).
func distance_a(point: Vector2) -> float:
	var e := emprise()
	return point.distance_to(point.clamp(e.position, e.end))


## Appelé par le niveau : le héros est devant sans la clef (montre la clef qu'il faut).
func indiquer(montrer: bool) -> void:
	if montrer != _bulle_visible:
		_bulle_visible = montrer
		_bulle.queue_redraw()


## Appelé par le niveau quand le héros arrive devant avec la clef : plus de collision, la porte s'efface.
func ouvrir() -> void:
	if _ouverte:
		return
	_ouverte = true
	indiquer(false)
	_collision.set_deferred("disabled", true)
	var fondu := create_tween()
	fondu.tween_property(_vue, "modulate:a", 0.0, DUREE_OUVERTURE)
	fondu.tween_callback(_vue.hide)


## Appelé par le niveau à chaque pas : la porte devient transparente quand le héros est derrière.
func voir_a_travers(pieds: Vector2, delta: float) -> void:
	if _ouverte or _image_ecran.size == Vector2.ZERO:
		return
	var vise := Iso.opacite_devant(_image_ecran, Iso.coins(emprise()), pieds)
	_vue.modulate.a = move_toward(_vue.modulate.a, vise, delta * 3.0)


func _process(delta: float) -> void:
	if _bulle_visible:
		_temps += delta
		_bulle.queue_redraw()


## Bulle ronde avec la clef de la bonne teinte, qui flotte au-dessus de la porte.
func _dessiner_bulle() -> void:
	if not _bulle_visible:
		return
	var centre := Vector2(0, -_hauteur - 40.0 + sin(_temps * 4.0) * 5.0)
	Dessin.cercle(_bulle, centre, 34.0, Palette.UI_CADRE)
	_bulle.draw_arc(centre, 34.0, 0.0, TAU, 32, Palette.CLEF[teinte], 4.0)
	Dessin.icone_objet(_bulle, "clef", centre + Vector2(0, 20), 40.0, Color.WHITE, teinte)
