extends Node2D
## Fruit du potager (lot 4 f) : pomme rouge brillante dessinée en code sur le potager de la base, avec un petit
## scintillement. La base la montre quand le fruit est prêt (Partie.fruit_pret) et la fait cueillir quand le
## héros arrive au bord du potager : gerbe d'étoiles, puis elle disparaît. `texte` : petit texte dans un cadre
## au-dessus du potager (prochain fruit, fruit cueilli), par-dessus le décor.
## Origine = coin avant de l'emprise du potager (monde) : la pomme est triée devant lui ; `sommet` = point du
## potager où elle est posée, à l'écran.

const RAYON := 13.0             # pixels d'écran
const DUREE_CUEILLETTE := 0.6
const PERIODE_ECLAT := 2.2      # un scintillement toutes les 2,2 s
const TAILLE_TEXTE := 26
const HAUT_TEXTE := 60.0        # au-dessus de la pomme (pixels d'écran)

## Point du potager (terre entre les plants) où la pomme est posée, à l'écran
var sommet := Vector2.ZERO
## Pomme visible (fruit prêt et potager posé)
var pret := false
## Petit texte au-dessus du potager ("" : rien)
var texte := ""

var _temps := 0.0
var _cueillette := 0.0          # > 0 : gerbe d'étoiles en cours
var _vue := Node2D.new()
var _texte := Node2D.new()      # enfant de _vue, par-dessus le décor


## Nœuds d'affichage, placés par la base.
func visuels() -> Dictionary:
	return {"vue": _vue}


## Le héros la cueille : gerbe d'étoiles, puis plus de pomme (jusqu'au prochain fruit).
func cueillir() -> void:
	_cueillette = DUREE_CUEILLETTE
	pret = false


func _ready() -> void:
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_vue.material = sans_ombre
	_vue.draw.connect(_dessiner)
	_texte.z_as_relative = false
	_texte.z_index = 5
	_texte.draw.connect(_dessiner_texte)
	_vue.add_child(_texte)


func _exit_tree() -> void:
	if is_instance_valid(_vue):
		_vue.queue_free()


func _process(delta: float) -> void:
	_temps += delta
	_cueillette = maxf(_cueillette - delta, 0.0)
	_vue.position = Iso.ecran(global_position)
	_vue.queue_redraw()
	_texte.queue_redraw()


func _dessiner() -> void:
	var centre := sommet - _vue.position + Vector2(0, -RAYON + sin(_temps * 2.5) * 1.5)
	if _cueillette > 0.0:
		var avance := 1.0 - _cueillette / DUREE_CUEILLETTE
		_vue.modulate.a = 1.0
		for i in 10:
			var direction := Vector2.from_angle(TAU * i / 10.0 + 0.3)
			_etoile(centre + direction * (10.0 + avance * 80.0), 8.0 * (1.0 - avance), 1.0 - avance)
		Dessin.pomme(_vue, centre + Vector2(0, -avance * 60.0), RAYON * (1.0 + avance * 0.5) * (1.0 - avance))
		return
	if not pret:
		return
	var pulse := 1.0 + 0.05 * sin(_temps * 4.0)
	_vue.draw_circle(centre, RAYON * 2.0 * pulse, Palette.LAMPE * Color(1, 1, 1, 0.12 + 0.06 * sin(_temps * 4.0)))
	Dessin.pomme(_vue, centre, RAYON * pulse)
	var phase := fmod(_temps, PERIODE_ECLAT) / 0.45
	if phase < 1.0:
		_etoile(centre + Vector2(-RAYON * 0.5, -RAYON * 0.6), 9.0 * sin(phase * PI), 0.95)


## Cadre sombre arrondi avec le texte en jaune, centré au-dessus de la pomme.
func _dessiner_texte() -> void:
	if texte == "":
		return
	var police := ThemeDB.fallback_font
	var taille := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_TEXTE) + Vector2(32, 20)
	var bas := sommet - _vue.position - Vector2(0, HAUT_TEXTE)
	var cadre := Rect2(bas - Vector2(taille.x / 2.0, taille.y), taille)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Palette.UI_CADRE
	fond.border_color = Palette.LAMPE
	fond.set_border_width_all(3)
	fond.set_corner_radius_all(16)
	_texte.draw_style_box(fond, cadre)
	var p := Vector2(cadre.position.x + 16, cadre.position.y + 10 + police.get_ascent(TAILLE_TEXTE))
	_texte.draw_string_outline(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_TEXTE, 6, Palette.CONTOUR)
	_texte.draw_string(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_TEXTE, Palette.LAMPE)


## Petite étoile à 4 branches.
func _etoile(p: Vector2, rayon: float, opacite: float) -> void:
	if rayon <= 0.5:
		return
	var couleur := Palette.LAMPE * Color(1, 1, 1, opacite)
	_vue.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -rayon), p + Vector2(rayon * 0.25, -rayon * 0.25),
		p + Vector2(rayon, 0), p + Vector2(rayon * 0.25, rayon * 0.25), p + Vector2(0, rayon),
		p + Vector2(-rayon * 0.25, rayon * 0.25), p + Vector2(-rayon, 0), p + Vector2(-rayon * 0.25, -rayon * 0.25)]), couleur)
