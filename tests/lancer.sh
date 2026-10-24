#!/bin/bash
# Lance les tests de non-régression (Godot 4.4.1 + écran virtuel Xvfb).
# Usage : GODOT=/chemin/vers/godot CAPTURES=/dossier/captures tests/lancer.sh [800x1280|1280x800]
# Chaque test affiche ses résultats ; les captures d'écran vont dans $CAPTURES.
cd "$(dirname "$0")/.." || exit 1
RES=${1:-1280x800}
mkdir -p "${CAPTURES:=/tmp/captures}"
export CAPTURES
"$GODOT" --headless --import >/dev/null 2>&1
for t in tests/test_*.gd; do
	echo "== $t ($RES)"
	timeout 90 xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --rendering-driver opengl3 --resolution "$RES" -s "$t" 2>&1 \
		| grep -vE "ALSA|audio|vsync|^\s+at: (set_use_vsync|init_output|initialize)|^$|Godot Engine|OpenGL API"
done
