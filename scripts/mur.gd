extends StaticBody2D
## Obstacle du décor : mur, étagère, caisse...
## position = milieu du bord bas de l'emprise au sol.
## Dessin en vue 3/4 : face avant, côté droit et dessus (voir Dessin.boite).

enum Style { MUR, ETAGERE, CAISSE }

@export var taille := Vector2(200, 60)   # emprise au sol (collision)
@export var hauteur := 60.0              # hauteur de la face avant dessinée
@export var style := Style.MUR
## Fenêtres dans la face avant (murs hauts) : position x de leur centre, en local.
@export var fenetres := PackedFloat32Array()

const FENETRE_TAILLE := Vector2(150, 58)


func _ready() -> void:
	var forme := RectangleShape2D.new()
	forme.size = taille
	var collision := CollisionShape2D.new()
	collision.shape = forme
	collision.position = Vector2(0, -taille.y / 2.0)
	add_child(collision)
	# L'ombre au sol est sur un enfant placé sous les personnages (comme le cône des zombies)
	var ombre := Node2D.new()
	ombre.name = "Ombre"
	ombre.z_index = -1
	ombre.draw.connect(_dessiner_ombre.bind(ombre))
	add_child(ombre)


func _dessiner_ombre(ombre: Node2D) -> void:
	var e := Dessin.biais(taille.y)
	Dessin.ombre(ombre, Rect2(-taille.x / 2.0 - 16, -taille.y - 10, taille.x + e + 40, taille.y + 34))


func _draw() -> void:
	match style:
		Style.MUR:
			Dessin.boite(self, taille, hauteur, Palette.MUR, Palette.MUR_FACE, Palette.MUR_COTE)
			_dessiner_mur()
		Style.ETAGERE:
			Dessin.boite(self, taille, hauteur, Palette.ETAGERE, Palette.ETAGERE_FACE, Palette.ETAGERE_COTE)
			_dessiner_etagere()
		Style.CAISSE:
			Dessin.boite(self, taille, hauteur, Palette.CAISSE_BOIS, Palette.CAISSE_BOIS_FACE, Palette.CAISSE_BOIS_COTE)
			_dessiner_caisse()


## Hasard toujours identique pour un même obstacle (dépend de sa position).
func _hasard() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(position))
	return rng


func _dessiner_mur() -> void:
	var g := -taille.x / 2.0
	var d := taille.x / 2.0
	if hauteur < 50.0:
		return   # muret de bord : rien de plus
	# Plinthe en bas
	draw_rect(Rect2(g + 2, -14, taille.x - 4, 12), Palette.MUR_PLINTHE)
	draw_line(Vector2(g + 2, -14), Vector2(d - 2, -14), Palette.CONTOUR, 3.0)
	# Fissures
	var rng := _hasard()
	for i in int(taille.x / 260.0):
		var x := rng.randf_range(g + 30, d - 30)
		var y := -hauteur + rng.randf_range(10, 30)
		var p := Vector2(x, y)
		for j in 3:
			var suivant := p + Vector2(rng.randf_range(-14, 14), rng.randf_range(10, 22))
			draw_line(p, suivant, Palette.FISSURE, 2.0)
			p = suivant
	# Fenêtres éclairées par la lune
	for x in fenetres:
		var r := Rect2(Vector2(x - FENETRE_TAILLE.x / 2.0, -hauteur + 18), FENETRE_TAILLE)
		Dessin.rect(self, r.grow(6), Palette.MUR_COTE)
		Dessin.rect(self, r, Palette.FENETRE)
		for k: int in [1, 2]:
			var xv := r.position.x + r.size.x * k / 3.0
			draw_line(Vector2(xv, r.position.y), Vector2(xv, r.end.y), Palette.CONTOUR, 4.0)
		# Vitre cassée : quelques fêlures
		var c := r.position + Vector2(r.size.x * 0.2, r.size.y * 0.4)
		for a: float in [0.3, 1.6, 2.6, 4.2]:
			draw_line(c, c + Vector2.from_angle(a) * 16.0, Palette.CONTOUR, 1.5)
		draw_line(r.position + Vector2(r.size.x * 0.75, 6), r.position + Vector2(r.size.x * 0.88, 22), Color(1, 1, 1, 0.5), 2.0)


func _dessiner_etagere() -> void:
	var g := -taille.x / 2.0
	var d := taille.x / 2.0
	var rng := _hasard()
	# Montants verticaux
	var nb_montants := maxi(int(taille.x / 140.0), 1)
	for i in nb_montants + 1:
		var x := lerpf(g + 4, d - 4, float(i) / nb_montants)
		draw_line(Vector2(x, -hauteur), Vector2(x, 0), Palette.CONTOUR, 5.0)
	# Trois rayons, avec des produits oubliés posés dessus
	var etage := hauteur / 3.0
	for n in 3:
		var y_planche := -n * etage - 4.0
		var x := g + 8.0
		while x < d - 18.0:
			var largeur := rng.randf_range(14, 24)
			if rng.randf() < 0.45:   # rayon à moitié vide
				var haut := rng.randf_range(10, etage - 8.0)
				var couleur: Color = Palette.PRODUITS[rng.randi() % Palette.PRODUITS.size()]
				var r := Rect2(x, y_planche - haut, largeur, haut)
				draw_rect(r, couleur.darkened(0.2))
				draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), couleur)   # haut éclairé
				draw_rect(r, Palette.CONTOUR, false, 2.0)
			x += largeur + rng.randf_range(4, 16)
		draw_line(Vector2(g + 2, y_planche), Vector2(d - 2, y_planche), Palette.CONTOUR, 5.0)
		draw_line(Vector2(g + 4, y_planche - 2), Vector2(d - 4, y_planche - 2), Palette.ETAGERE_PLANCHE, 2.0)
	# Rayon vu de dessus quand il est long vers le fond : séparation centrale + produits
	if taille.y > taille.x:
		var coins := Dessin.dessus_boite(taille, hauteur)
		var milieu_avant := (coins[0] + coins[1]) / 2.0
		var milieu_arriere := (coins[2] + coins[3]) / 2.0
		draw_line(milieu_avant, milieu_arriere, Palette.CONTOUR, 3.0)
		var t := 0.05
		while t < 0.95:
			if rng.randf() < 0.5:
				var cote := -1.0 if rng.randf() < 0.5 else 1.0
				var p := milieu_avant.lerp(milieu_arriere, t) + Vector2(cote * taille.x * 0.25 - 6, -6)
				var couleur: Color = Palette.PRODUITS[rng.randi() % Palette.PRODUITS.size()]
				Dessin.rect(self, Rect2(p, Vector2(12, 12)), couleur.darkened(0.2))
			t += 0.06


func _dessiner_caisse() -> void:
	var g := -taille.x / 2.0
	var d := taille.x / 2.0
	# Face avant : cadre, lattes et croisillon
	var cadre := Rect2(g + 7, -hauteur + 7, taille.x - 14, hauteur - 14)
	for i in range(1, 4):
		var x := g + taille.x * i / 4.0
		draw_line(Vector2(x, cadre.position.y), Vector2(x, cadre.end.y), Palette.FISSURE, 2.0)
	draw_line(cadre.position, cadre.end, Palette.CONTOUR, 5.0)
	draw_rect(cadre, Palette.CONTOUR, false, 3.0)
	# Dessus : lattes parallèles au bord avant
	var coins := Dessin.dessus_boite(taille, hauteur)
	for i in range(1, 4):
		var t := i / 4.0
		draw_line(coins[0].lerp(coins[3], t) + Vector2(3, 0), coins[1].lerp(coins[2], t) - Vector2(3, 0), Palette.FISSURE, 2.0)
