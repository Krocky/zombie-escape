extends Node
## Qualité d'affichage. Si le jeu reste sous Reglages.QUALITE_SEUIL_IPS images par seconde pendant
## Reglages.QUALITE_DELAI secondes dans un lieu, il passe en qualité basse pour toute la partie
## (jusqu'à ce qu'on relance l'appli) :
## - l'écran est calculé à la résolution de base (1280x720 agrandie) au lieu de la résolution de
##   la tablette : deux fois moins de pixels en largeur et en hauteur pour tout le dessin, lumières
##   et nuit comprises (les lumières 2D de Godot sont calculées pixel par pixel, sans calque à part) ;
## - moins de particules : brume plus clairsemée, gerbes d'étincelles plus petites.
## Le niveau appelle surveiller() ; les entités lisent `basse` au moment de dessiner.

signal changee

const ATTENTE_DEPART := 2.0   # secondes ignorées à l'arrivée dans un lieu (chargement)

var basse := false
var _surveille := false
var _depuis := 0.0   # temps passé dans le lieu
var _lent := 0.0     # temps passé sous le seuil, d'affilée


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Reglages.QUALITE_BASSE_FORCEE:
		passer_en_basse()


## Appelé par le niveau : mesure seulement pendant l'exploration.
func surveiller(actif: bool) -> void:
	_surveille = actif
	_depuis = 0.0
	_lent = 0.0


func _process(delta: float) -> void:
	if basse or not _surveille or not Reglages.QUALITE_AUTO:
		return
	_depuis += delta
	if _depuis < ATTENTE_DEPART:
		return
	_lent = _lent + delta if Engine.get_frames_per_second() < Reglages.QUALITE_SEUIL_IPS else 0.0
	if _lent >= Reglages.QUALITE_DELAI:
		passer_en_basse()


func passer_en_basse() -> void:
	if basse:
		return
	basse = true
	# Rendu à la taille de base puis agrandi à l'écran (même cadrage, moins de pixels)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	changee.emit()
