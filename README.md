# Claude Code Docker Launcher

Startet Claude Code in einem isolierten Docker-Container mit Folder-Mapping.
Der Container kann **nur** auf das gemountete Projektverzeichnis zugreifen – dein restliches Dateisystem ist geschützt.

## Setup

```bash
# 1. Script ausführbar machen
chmod +x claude-docker.sh

# 2. Config anlegen und editieren
cp .config.example .config
nano .config
```

## Auth: Subscription vs. API Key

Konfiguriere `AUTH_MODE` in `.config`, oder lass es auf `"auto"`.

### Subscription (Pro/Team/Enterprise)

```bash
# Einmalig einloggen – öffnet Browser-URL
./claude-docker.sh --login

# Danach einfach starten
./claude-docker.sh ~/projects/mein-projekt
```

### API Key

In `.config` setzen:
```bash
AUTH_MODE="apikey"
ANTHROPIC_API_KEY="sk-ant-..."
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

## Konfiguration

Alle Einstellungen liegen in `.config` (siehe `.config.example`):

| Variable         | Beschreibung                          | Default              |
|------------------|---------------------------------------|----------------------|
| AUTH_MODE        | `auto`, `subscription` oder `apikey`  | `auto`               |
| ANTHROPIC_API_KEY| API Key für apikey-Modus              | (leer)               |
| IMAGE_NAME       | Docker Image Name                     | `claude-code`        |
| CONTAINER_NAME   | Container Name                        | `claude-code-session`|
| CPU_LIMIT        | CPU-Limit (z.B. `4`)                  | (unbegrenzt)         |
| MEMORY_LIMIT     | RAM-Limit (z.B. `8g`)                 | (unbegrenzt)         |
| GPU              | GPU-Passthrough (z.B. `all`)          | (deaktiviert)        |

> ⚠️ `.config` ist in `.gitignore` und wird **nicht** committed.
> Nur `.config.example` wird versioniert.

## Dateistruktur

```
├── .config.example   # Template (wird committed)
├── .config           # Deine Config (wird NICHT committed)
├── .gitignore
├── claude-docker.sh  # Launcher Script
├── Dockerfile
└── README.md
```