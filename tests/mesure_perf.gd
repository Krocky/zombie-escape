extends SceneTree
## Mesure de performance (pas un test : pas lancé par lancer.sh).
## Usage : xvfb-run -a -s "-screen 0 2560x1600x24" godot --rendering-driver opengl3 --resolution 2560x1600 -s tests/mesure_perf.gd
## LIEU=maison pour l'autre lieu. Affiche appels de dessin, objets rendus et temps moyen d'une image.

var niveau
var f := 0
var debut := 0
var appels := 0.0
var objets := 0.0
var cpu := 0.0
var gpu := 0.0
var script_ms := 0.0
const N := 120

func _initialize():
	var lieu := OS.get_environment("LIEU")
	niveau = load("res://scenes/lieux/%s.tscn" % (lieu if lieu != "" else "supermarche")).instantiate()
	root.add_child(niveau)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)

func _process(_d):
	f += 1
	if f == 30:
		debut = Time.get_ticks_usec()
	if f > 30:
		appels += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objets += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		script_ms += (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	if f == 30 + N:
		var ms := (Time.get_ticks_usec() - debut) / 1000.0 / N
		print("appels de dessin: %.0f  objets: %.0f  noeuds: %d  image: %.1f ms (scripts %.1f, rendu cpu %.1f, gpu %.1f)" % [appels / N, objets / N,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), ms, script_ms / N, cpu / N, gpu / N])
		if OS.get_environment("CAPTURES") != "":
			root.get_texture().get_image().save_png(OS.get_environment("CAPTURES") + "/perf.png")
		quit()
	return false
