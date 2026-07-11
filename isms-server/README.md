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

**Katalog:** Ist die Datenbank noch leer, importiert der Server automatisch die IT-Grundschutz-XML, wenn er sie findet. Suchreihenfolge:

1. `CATALOG_XML_PATH` aus `.env`
2. `%USERPROFILE%\Documents\XML_Kompendium_2023.xml`
3. `isms-server/catalog/XML_Kompendium_2023.xml`

Tipp für deine Umgebung — in `.env` eintragen:

```env
CATALOG_XML_PATH=D:\RADStudio\Delphi\BSI\xml\XML_Kompendium_2023.xml
```

Manueller Import (Admin-API) bleibt für Updates verfügbar.

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
| `ENV` | `development` | `production` erzwingt starkes JWT + TLS |
| `DATABASE_URL` | `postgres://ismsserver:ismsserver@localhost:5432/isms?sslmode=disable` | PostgreSQL |
| `HTTP_ADDR` | `:8080` | Listen-Adresse (HTTP oder HTTPS) |
| `JWT_SECRET` | (Dev-Fallback) | Secret für JWT; **Pflicht in Produktion** (min. 32 Zeichen) |
| `JWT_TTL` | `24h` | Token-Gültigkeit (`8h`, `30m`, …) |
| `TLS_CERT_FILE` | — | TLS-Zertifikat (Pflicht in Produktion) |
| `TLS_KEY_FILE` | — | TLS-Schlüssel (Pflicht in Produktion) |
| `ADMIN_EMAIL` | `admin@example.com` | Erster Admin (nur wenn DB leer) |
| `ADMIN_PASSWORD` | `changeme` | Passwort für ersten Admin |
| `ADMIN_DISPLAY_NAME` | `Administrator` | Anzeigename |

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

### 4. Rollen

- [ ] Leser: kann Projekt öffnen, aber nicht speichern (HTTP 403)
- [ ] Besitzer: kann Mitglieder verwalten; Bearbeiter: kann Bewertungen ändern

### 5. Admin

- [ ] **Datei → IT-Grundschutz XML importieren** (nur Admin) → Katalog auf Server aktualisiert

### 6. Sitzung & Sicherheit

- [ ] Client neu starten mit gültigem Token → automatischer Login ohne Passwort
- [ ] `JWT_TTL=2m` setzen, warten → Client fordert Re-Login (Statusleiste / Dialog)
- [ ] **Projekt → Server-Sitzung erneuern** → neues Token ohne Neustart
- [ ] Optional HTTPS: Dev-Zertifikat, `https://localhost:8443`, TLS-Checkbox im Login

## Nächste Schritte

- Deployment-Dokumentation (Reverse Proxy, Let's Encrypt)
- Refresh-Tokens (optional, längere Sessions ohne erneutes Passwort)
