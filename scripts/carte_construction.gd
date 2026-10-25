extends Control
## Carte d'une construction sur l'écran Base : nom, coût (icônes des objets), effet en une phrase,
## bouton « Construire » (actif seulement si on a assez d'objets) ou « Construit ».
## Carte large (portrait) : le coût est sur la ligne du nom, la carte est moins haute.

## Toucher « Construire » : la base fait la construction.
signal construire(construction: String)

const TAILLE_ICONE := 40.0
const LARGEUR_COMPACTE := 600.0   # à partir de cette largeur, coût sur la ligne du nom

## Nom de la construction (clé de Partie.CONSTRUCTIONS), donné par la base.
var construction := ""

@onready var _bouton: Control = $Bouton


func _ready() -> void:
	_bouton.appuye.connect(func(): construire.emit(construction))
	actualiser()


## Appelé par la base quand l'inventaire ou les constructions changent.
func actualiser() -> void:
	var fait := Partie.est_construit(construction)
	_bouton.texte = "Construit" if fait else "Construire"
	_bouton.couleur = Palette.SORTIE if fait else Palette.LAMPE
	_bouton.actif = Partie.peut_construire(construction)
	queue_redraw()


func _draw() -> void:
	var fait := Partie.est_construit(construction)
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Palette.UI_CADRE
	cadre.border_color = Palette.SORTIE if fait else Palette.CONTOUR
	cadre.set_border_width_all(5)
	cadre.set_corner_radius_all(20)
	draw_style_box(cadre, Rect2(Vector2.ZERO, size))
	var police := ThemeDB.fallback_font
	var x := 18.0
	var largeur: float = _bouton.position.x - x - 10.0
	# Nom (réduit s'il est trop long)
	var titre: String = Partie.CONSTRUCTIONS.get(construction, construction)
	var taille := 28
	while taille > 16 and police.get_string_size(titre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > largeur:
		taille -= 2
	draw_string_outline(police, Vector2(x, 36), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 6, Palette.CONTOUR)
	draw_string(police, Vector2(x, 36), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Palette.LAMPE)
	# Coût : une icône par type d'objet avec son nombre (grisé si on n'en a pas assez)
	var cout := Partie.cout(construction)
	var debut := Vector2(x + 20, 88)
	if size.x >= LARGEUR_COMPACTE:
		debut = Vector2(x + police.get_string_size(titre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + 50, 52)
	var pas := minf((largeur + x - debut.x) / maxf(cout.size(), 1.0), 100.0)
	var i := 0
	for type in cout:
		var assez: bool = fait or Partie.inventaire.get(type, 0) >= cout[type]
		var pieds := debut + Vector2(i * pas, 0)
		Dessin.icone_objet(self, type, pieds, TAILLE_ICONE, Color.WHITE if assez else Color(0.55, 0.55, 0.65, 0.6))
		var texte := "x%d" % cout[type]
		var p := pieds + Vector2(TAILLE_ICONE * 0.5, -6)
		draw_string_outline(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Palette.CONTOUR)
		draw_string(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.UI_TEXTE if assez else Palette.COEUR)
		i += 1
	# Effet
	var phrase := Partie.effet(construction)
	taille = 20
	while taille > 14 and police.get_string_size(phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > largeur:
		taille -= 1
	draw_string(police, Vector2(x, size.y - 14), phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Palette.UI_TEXTE)
