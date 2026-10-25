# Zombie Escape

Jeu mobile Android 2D (Godot 4.4, GDScript) : un survivant explore des lieux abandonnés la nuit, évite ou affronte des zombies un peu rigolos, sauve des rescapés et rapporte des objets pour reconstruire sa base et trouver un remède. Pas de gore, pensé pour un enfant.

- Game design : Eliott (10 ans). Développement : son père, avec Claude Code.
- Documentation complète (vision, conventions, décisions, journal) : [CLAUDE.md](CLAUDE.md).
- Revue du code et du gameplay, propositions : [docs/revue.md](docs/revue.md) ; prompts des prochaines étapes : [docs/lot3-prompts.md](docs/lot3-prompts.md).
- Réglages d'équilibrage (vitesses, cœurs, dégâts...) : [data/reglages.gd](data/reglages.gd).
- Chaque push construit un APK (GitHub Actions) ; sur `main`, une Release `build-N` le publie.
- Tests automatiques : `tests/lancer.sh` (voir CLAUDE.md, section Tests).
