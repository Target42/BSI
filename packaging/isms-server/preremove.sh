#!/bin/sh
# Dienst stoppen, Konfiguration und Datenbank bleiben erhalten.
set -e

if command -v systemctl >/dev/null 2>&1; then
  systemctl stop isms-server >/dev/null 2>&1 || true
  systemctl disable isms-server >/dev/null 2>&1 || true
fi
