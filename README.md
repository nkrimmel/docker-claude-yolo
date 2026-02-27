# Claude Code Docker Launcher

Startet Claude Code in einem isolierten Docker-Container mit Folder-Mapping.
Der Container kann **nur** auf das gemountete Projektverzeichnis zugreifen – dein restliches Dateisystem ist geschützt.

## Setup

```bash
# 1. API Key setzen (in .bashrc/.zshrc für Persistenz)
export ANTHROPIC_API_KEY="sk-ant-..."

# 2. Script ausführbar machen
chmod +x claude-docker.sh

# 3. Image bauen & Claude starten
./claude-docker.sh /pfad/zu/deinem/projekt
```

## Verwendung

```bash
# Aktuelles Verzeichnis als Projekt
./claude-docker.sh

# Bestimmtes Projekt
./claude-docker.sh ~/projects/mein-projekt

# YOLO-Modus (keine Rückfragen) – sicher dank Container-Isolation
./claude-docker.sh --yolo ~/projects/mein-projekt

# Image neu bauen (z.B. nach Claude Code Update)
./claude-docker.sh --build
```

## Was passiert

- **Dockerfile** installiert Node.js 22, Git, Python3 und Claude Code
- **claude-docker.sh** baut das Image (einmalig) und startet einen Container
- Dein Projektordner wird als `/workspace` in den Container gemountet
- npm-Cache wird als Docker Volume persistiert (schnellere Starts)
- Container wird nach Beenden automatisch gelöscht (`--rm`)

## Warum Docker?

Mit `--dangerously-skip-permissions` kann Claude Code beliebige Shell-Befehle ausführen.
Ohne Docker betrifft das dein **gesamtes** Dateisystem.
Im Container ist Claude auf `/workspace` (= dein Projekt) beschränkt.

## Hinweise

- Der `ANTHROPIC_API_KEY` muss als Umgebungsvariable gesetzt sein
- Git-Commits innerhalb des Containers landen im gemounteten Verzeichnis
- Für maximale Sicherheit: vorher einen Git-Branch erstellen
