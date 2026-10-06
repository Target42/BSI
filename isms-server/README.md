# ISMS Server (Go)

REST-API für kollaborative IT-Grundschutz-Projekte. Mehrere Nutzer können parallel an einem Projekt arbeiten (Zielobjekte, Bewertungen, Baustein-Anwendbarkeit).

## Voraussetzungen

- Go 1.22+
- PostgreSQL lokal (oder optional Docker Compose)

## Lokale Entwicklung (IDE)

### 1. Datenbank anlegen (einmalig)

PostgreSQL läuft lokal. Als Superuser (z. B. `postgres`):

```powershell
psql -U postgres -f scripts/setup-local-db.sql
```

Oder manuell: User `ismsserver` / Passwort `ismsserver`, Datenbank `isms`.

### 2. Konfiguration

```powershell
cd isms-server
copy .env.example .env
```

`.env` bei Bedarf anpassen. Beim Start werden Migrationen automatisch ausgeführt.

### 3. Starten

**VS Code / Cursor:** Launch-Konfiguration **„ISMS Server“** (F5).

**Terminal:**

```powershell
cd isms-server
go run ./cmd/isms-server
```

Beim ersten Start wird ein Admin-Benutzer angelegt (`admin@example.com` / `changeme`).

**Web-UI:** Im Browser dieselbe Adresse wie die API öffnen, z. B. `http://localhost:8080`. Eingebettet in der Go-Binary, kein npm. Öffentliche Projekte sind ohne Anmeldung sichtbar (nur Lesen). Private Projekte und Schreiben brauchen ein Konto und Mitgliedschaft. Neue Benutzer registrieren sich selbst. Ein Besitzer nimmt sie per E-Mail auf oder erzeugt einen Einladungslink, der weitergegeben werden kann. Sachbearbeitung kann ohne Desktop-Client arbeiten: Projekte anlegen und pflegen, Zielobjekte, Arbeitsplatz (Bausteine/Anforderungen, Vererbung, Empfehlungen, Massenstatus), Katalog, Bewertungen, Maßnahmen, Mitglieder, Soll-Ist inkl. CSV und Druck. Administratoren legen Benutzer an und spielen den Katalog ein. Hinter nginx-Prefix: `WEB_PUBLIC_BASE=/isms`.

**Suchmaschinen:** Indexierbar sind die Startseite ohne Anmeldung und, sobald Installer im Ordner `downloads` liegen, `/downloads`. Projekte, Katalog und Konten bleiben mit `noindex` und in `robots.txt` gesperrt, damit Bewertungen nicht in der Suche landen. `MAIL_PUBLIC_URL` auf die öffentliche HTTPS-Adresse setzen; daraus kommen kanonische URL und `/sitemap.xml`. Google findet den Server nur, wenn diese Adresse aus dem Internet erreichbar ist, und die Property muss in der Search Console angemeldet werden. Bei einem Pfad-Prefix liest Google ausschließlich `https://<host>/robots.txt`, nicht `/isms/robots.txt`.

Installer für die Qt-GUI und den Delphi-Client stecken **nicht** in der Binary. Liegen Dateien im Ordner `downloads`, bietet die Startseite den Download an. Siehe [Desktop-Clients zum Download](#desktop-clients-zum-download).

**Katalog:** Ist die Datenbank noch leer, importiert der Server automatisch die IT-Grundschutz-XML, wenn er sie findet. Suchreihenfolge:

1. `CATALOG_XML_PATH` aus `.env`
2. `%USERPROFILE%\Documents\XML_Kompendium_2023.xml`
3. `isms-server/catalog/XML_Kompendium_2023.xml`

Tipp für deine Umgebung — in `.env` eintragen:

```env
CATALOG_XML_PATH=D:\RADStudio\Delphi\BSI\xml\XML_Kompendium_2023.xml
```

Manueller Import bleibt für Updates: in der Web-UI **Katalog → XML importieren** (Administrator) oder die Admin-API.

### Alternative: Docker Compose

```powershell
cd isms-server
docker compose up -d
# DATABASE_URL in .env auf postgres://isms:isms@localhost:5432/isms?sslmode=disable setzen
go run ./cmd/isms-server
```

### API testen

```bash
# Login
curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"admin@example.com\",\"password\":\"changeme\"}"

# Projekt anlegen (Token aus Login einsetzen)
curl -s -X POST http://localhost:8080/api/v1/projects \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Cloud-Infrastruktur\",\"description\":\"Hauptprojekt\",\"catalogVersion\":\"2023\"}"
```

## Konfiguration

Umgebungsvariablen (optional `.env` im Verzeichnis `isms-server/`):

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `ENV` | `development` | `production` erzwingt starkes JWT und TLS (am Prozess oder per nginx + `TRUSTED_PROXIES`) |
| `DATABASE_URL` | `postgres://ismsserver:ismsserver@localhost:5432/isms?sslmode=disable` | PostgreSQL |
| `HTTP_ADDR` | `:8080` | Listen-Adresse. Hinter nginx: `127.0.0.1:8098` |
| `JWT_SECRET` | (Dev-Fallback) | Secret für JWT; **Pflicht in Produktion** (min. 32 Zeichen) |
| `JWT_TTL` | `8h` | Token-Gültigkeit (`8h`, `30m`, …) |
| `TLS_CERT_FILE` | — | TLS-Zertifikat, wenn der Go-Prozess selbst HTTPS spricht |
| `TLS_KEY_FILE` | — | TLS-Schlüssel |
| `TRUSTED_PROXIES` | — | CIDRs des Reverse-Proxy. In Produktion Alternative zu TLS am Go-Prozess |
| `ADMIN_EMAIL` | `admin@example.com` | Erster Admin (nur wenn DB leer) |
| `ADMIN_PASSWORD` | `changeme` | Passwort für ersten Admin |
| `ADMIN_DISPLAY_NAME` | `Administrator` | Anzeigename |
| `DOWNLOADS_DIR` | `downloads` | Ordner für optionale Client-Installer. Ist er leer, bietet die Web-UI keinen Download |

### JWT-Secret erzeugen (Produktion)

```powershell
# Beispiel mit OpenSSL
openssl rand -base64 48
```

In `.env` eintragen: `JWT_SECRET=<generierter Wert>` und `ENV=production`.

### HTTPS (Entwicklung)

Self-signed Zertifikat erzeugen:

```powershell
cd isms-server
.\scripts\generate-dev-cert.ps1
```

In `.env`:

```env
TLS_CERT_FILE=certs/server.crt
TLS_KEY_FILE=certs/server.key
HTTP_ADDR=:8443
```

Im Qt-Client: `https://localhost:8443` und **„Self-signed TLS-Zertifikat akzeptieren“** aktivieren.

## Desktop-Clients zum Download

Die Installer für die **Qt-GUI** (Paket `isms-werkzeug`) und den **Delphi-Client** werden nicht mitübersetzt und nicht in die Server-Binary gepackt. Sie liegen in einem eigenen Verzeichnis auf dem Server. Der Administrator entscheidet, ob der Download angeboten wird: Dateien in den Ordner legen, oder den Ordner leer lassen, wenn die Software anders verteilt wird (Softwareverteilung, Paketquelle, USB).

Die Web-Oberfläche liest den Ordner bei jedem Seitenaufruf. Ein Neustart des Dienstes ist zum Austauschen nicht nötig. Fehlt der Ordner oder enthält er keine Installer, erscheinen weder der Menüpunkt **Download** noch Links auf der Startseite.

| Betrieb | Ordner |
|---------|--------|
| Entwicklung (`go run` im Ordner `isms-server`) | `isms-server/downloads/` |
| Ubuntu, systemd oder Paket | `/opt/isms/downloads/` |
| Windows-Dienst | `%ProgramData%\ISMS\downloads\` |

Anderer Pfad über `DOWNLOADS_DIR` in `.env` bzw. `/etc/isms/isms.env`, danach den Dienst einmal neu starten, damit die Variable gilt. Die Dateien selbst lassen sich danach ohne Neustart ersetzen.

Nur diese Endungen werden ausgeliefert: `.deb`, `.rpm`, `.AppImage`, `.exe`, `.msi`, `.msix`, `.zip`, `.dmg`, `.tgz`, `.tar.gz`. Andere Dateien (Notizen, `.env`) ignoriert der Server.

Damit die Oberfläche die Programme benennt, muss der **Dateiname** einen dieser Bestandteile enthalten (Groß/Klein egal):

| Dateiname enthält | Anzeige |
|-------------------|---------|
| `werkzeug` oder `qt-gui` | Qt-GUI |
| `delphi` oder `bsiclient` | Delphi-Client |

Beispiele:

```text
/opt/isms/downloads/isms-werkzeug_1.2.0_amd64.deb
/opt/isms/downloads/isms-werkzeug-1.2.0-1.x86_64.rpm
/opt/isms/downloads/BSIClient-Setup.exe
```

Die Linux-Pakete der Qt-GUI erzeugt `./scripts/build-linux-packages.sh client` unter `dist/packages/`. Den Delphi-Client als Setup-Datei ablegen, im Namen `BSIClient` oder `delphi`. Es reicht, nur die Varianten hinzulegen, die angeboten werden sollen — nur das `.deb`, oder nur die Windows-Datei des Delphi-Clients.

### Dateien austauschen

Neue Fassung anbieten: Datei hinzukopieren oder die bestehende **unter gleichem Namen überschreiben**. Alte Fassung entfernen: Datei löschen. Beides ist sofort in der Web-UI sichtbar, der Dienst bleibt laufen.

Ubuntu, User `isms` muss die Dateien lesen können:

```bash
sudo install -o isms -g isms -m 0644 dist/packages/isms-werkzeug_*_amd64.deb /opt/isms/downloads/
sudo install -o isms -g isms -m 0644 BSIClient-Setup.exe /opt/isms/downloads/
# nicht mehr anbieten:
sudo rm -f /opt/isms/downloads/isms-werkzeug_1.1.0_amd64.deb
```

Windows (PowerShell, Eingabeaufforderung als Administrator ist nicht nötig, wenn der Ordner beschreibbar ist):

```powershell
Copy-Item .\isms-werkzeug_1.2.0_amd64.deb "$env:ProgramData\ISMS\downloads\" -Force
Copy-Item .\BSIClient-Setup.exe "$env:ProgramData\ISMS\downloads\" -Force
Remove-Item "$env:ProgramData\ISMS\downloads\BSIClient-Setup.exe"
```

Download-Adresse: `https://<host>/downloads/<dateiname>`. Hinter einem Pfad-Prefix: `https://<host>/isms/downloads/<dateiname>`.

Login liefert `accessToken` und `expiresAt` (RFC3339). Abgelaufene Tokens antworten mit `401` und `{"error":"token_expired"}`.

## Endpunkte (MVP)

| Methode | Pfad | Beschreibung |
|---------|------|--------------|
| `GET` | `/health` | Healthcheck |
| `POST` | `/api/v1/auth/login` | Login |
| `GET` | `/api/v1/auth/me` | Aktueller User |
| `GET/POST` | `/api/v1/projects` | Projekte listen/anlegen |
| `GET/PATCH/DELETE` | `/api/v1/projects/{id}` | Projekt |
| `GET/POST` | `/api/v1/projects/{id}/target-objects` | Zielobjekte |
| `PATCH/DELETE` | `/api/v1/target-objects/{id}` | Zielobjekt |
| `GET/PUT` | `.../requirements/{id}/assessment` | Bewertung (mit Optimistic Locking) |
| `GET` | `.../assessments` | Alle Bewertungen eines Zielobjekts |
| `GET/PUT` | `.../bausteine/{id}/applicability` | Baustein-Anwendbarkeit |
| `GET/POST` | `.../requirements/{id}/measures` | Maßnahmen |
| `PATCH/DELETE` | `/measures/{id}` | Maßnahme bearbeiten/löschen |
| `GET` | `/catalog/versions` | Verfügbare Katalogversionen |
| `GET` | `/catalog/{version}/bausteine` | Bausteine (read-only) |
| `GET` | `/catalog/bausteine/{id}/requirements` | Anforderungen eines Bausteins |
| `GET` | `/admin/users` | Nutzerliste (Admin) |
| `POST` | `/admin/users` | Benutzer anlegen (Admin) |
| `POST` | `/admin/catalog/import` | Grundschutz-XML hochladen (Admin, multipart `file`) |
| `GET/POST/PATCH/DELETE` | `/projects/{id}/members` | Projekt-Mitglieder |
| `GET` | `/projects/{id}/report/soll-ist` | Soll-Ist-Report (`?targetObjectId=` optional) |

## Testplan Server-Modus (Qt-Client)

Voraussetzungen: PostgreSQL läuft, Server gestartet (`go run ./cmd/isms-server`), Katalog importiert.

### 1. Basis

- [ ] Client starten → Login-Dialog: „Mit Server verbinden“, `http://localhost:8080`, Admin-Login
- [ ] Projekt anlegen oder öffnen, Zielobjekt wählen, Baustein + Anforderung öffnen
- [ ] Bewertung (Status, Notiz) speichern, Client neu starten → Daten noch vorhanden

### 2. Benutzer & Mitglieder

- [ ] Als Admin: **Projekt → Projektmitglieder** → „Neuen Benutzer anlegen“ (z. B. `kollege@example.com`)
- [ ] Benutzer zum Projekt hinzufügen (Rolle: Bearbeiter)
- [ ] Zweite Client-Instanz mit Kollegen-Login → gleiches Projekt sichtbar

### 3. Konfliktbehandlung (zwei Clients)

- [ ] Beide Clients: gleiche Anforderung im gleichen Zielobjekt öffnen
- [ ] Client A: Status ändern (speichert automatisch)
- [ ] Client B: ebenfalls ändern → Konfliktmeldung, Server-Version wird geladen
- [ ] Optional: Maßnahme in beiden bearbeiten → gleiches Verhalten bei Maßnahmen

### 4. Rollen und Sichtbarkeit

- [ ] Öffentlich: ohne Anmeldung sichtbar (nur Lesen); Privat: nur Mitglieder
- [ ] Leser: kann Projekt öffnen, aber nicht speichern (HTTP 403)
- [ ] Besitzer: kann Mitglieder und Sichtbarkeit verwalten; Bearbeiter: kann Bewertungen ändern

### 5. Admin

- [ ] **Datei → IT-Grundschutz XML importieren** (nur Admin) → Katalog auf Server aktualisiert

### 6. Sitzung & Sicherheit

- [ ] Client neu starten mit gültigem Token → automatischer Login ohne Passwort
- [ ] `JWT_TTL=2m` setzen, warten → Client fordert Re-Login (Statusleiste / Dialog)
- [ ] **Projekt → Server-Sitzung erneuern** → neues Token ohne Neustart
- [ ] Optional HTTPS: Dev-Zertifikat, `https://localhost:8443`, TLS-Checkbox im Login

## Bauen (Linux + Windows)

```powershell
.\scripts\build.ps1
```

```bash
./scripts/build.sh
```

Erzeugt in `dist/`: `isms-server-linux-amd64` und `isms-server-windows-amd64.exe`.

Die Linux-Binary auf einem laufenden Server austauschen, ohne neu zu installieren: Dienst stoppen, Datei nach `/opt/isms/isms-server` kopieren, Besitzer `isms` und Modus `0755` setzen, Dienst starten. Befehle: [INSTALL.md](INSTALL.md), Abschnitt **Serverprogramm austauschen**.

## Nativer Betrieb (Dienst)

Kurzanleitung und Install-Skripte: **[INSTALL.md](INSTALL.md)**

- Windows: `.\scripts\install-windows-service.ps1` (NSSM-Dienst oder geplante Aufgabe)
- Ubuntu: Abschnitt **Ubuntu** in [INSTALL.md](INSTALL.md), Skript `sudo ./scripts/install-systemd.sh`

## Nächste Schritte

- Reverse Proxy: `deploy/nginx-isms.conf` (Subdomain) oder `deploy/nginx-prefix.conf` (Pfad `/isms`)
- Refresh-Tokens (optional, längere Sessions ohne erneutes Passwort)
