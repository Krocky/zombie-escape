extends CanvasLayer
## Vignettage : les bords de l'écran sont assombris (une seule image, calculée une fois).
## Sous le HUD, au-dessus du niveau ; ne bloque pas les doigts.


func _ready() -> void:
	var degrade := Gradient.new()
	degrade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	degrade.colors = PackedColorArray([Color(Palette.VIGNETTE, 0.0), Color(Palette.VIGNETTE, 0.0), Palette.VIGNETTE])
	var texture := GradientTexture2D.new()
	texture.gradient = degrade
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.05, 0.5)
	$Image.texture = texture
