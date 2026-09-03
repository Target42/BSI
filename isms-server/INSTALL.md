# ISMS-Server nativ betreiben

Der Go-Server ist eine einzelne Binary. PostgreSQL muss laufen; der Server selbst braucht **kein Docker**.

Das Arbeitsverzeichnis der Binary muss das Installationsverzeichnis sein (dort liegen `.env` bzw. die systemd-Env-Datei und `migrations/`). Die Web-Oberfläche steckt in der Binary.

---

## Ubuntu (24.04 / 22.04)

Getestet gegen systemd und das PostgreSQL-Paket aus den Ubuntu-Quellen. Alle Befehle im Terminal, Abschnitte mit `sudo` brauchen Root.

### 1. Pakete

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib git openssl curl
```

Go 1.22+ wird zum Bauen gebraucht. Unter **Ubuntu 24.04** reicht oft:

```bash
sudo apt install -y golang-go
go version
```

Unter **Ubuntu 22.04** ist `apt`-Go zu alt. Offizielles Tarball (Beispiel amd64):

```bash
curl -fsSL -o /tmp/go.tgz https://go.dev/dl/go1.24.6.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tgz
echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.profile
source ~/.profile
go version
```

Aktuelle Dateinamen: [https://go.dev/dl/](https://go.dev/dl/). Alternativ beide Targets (Linux + Windows) bauen und die Linux-Binary rüberkopieren:

```powershell
# Windows (im Ordner isms-server)
.\scripts\build.ps1
scp dist\isms-server-linux-amd64 nutzer@ubuntu-host:~/isms-server/isms-server
```

```bash
# Linux / WSL / Git Bash
./scripts/build.sh
scp dist/isms-server-linux-amd64 nutzer@ubuntu-host:~/isms-server/isms-server
```

Nur ein Target: `.\scripts\build.ps1 -Targets linux` bzw. `./scripts/build.sh linux`.
Ausgaben landen in `dist/` (`isms-server-linux-amd64`, `isms-server-windows-amd64.exe`).

### 2. Quellcode

```bash
git clone <dein-repo-url> BSI
cd BSI/isms-server
```

### 3. PostgreSQL

```bash
sudo systemctl enable --now postgresql
sudo -u postgres psql -f scripts/setup-local-db.sql
```

Das legt User `ismsserver` / Passwort `ismsserver` und Datenbank `isms` an. Wenn User oder DB schon existieren, die Fehlermeldung ignorieren oder per `sudo -u postgres psql` manuell prüfen:

```bash
sudo -u postgres psql -c '\du ismsserver'
sudo -u postgres psql -c '\l isms'
```

Anderes Passwort: in PostgreSQL ändern **und** in der Env-Datei `DATABASE_URL` anpassen.

### 4. Konfiguration

```bash
cp .env.example .env
nano .env
```

Mindestens:

```env
ENV=development
DATABASE_URL=postgres://ismsserver:ismsserver@localhost:5432/isms?sslmode=disable
HTTP_ADDR=:8080
JWT_SECRET=<mindestens 32 zufällige Zeichen>
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=<sicheres Passwort>
CATALOG_XML_PATH=/opt/isms/catalog/XML_Kompendium_2023.xml
```

Secret erzeugen:

```bash
openssl rand -base64 48
```

`ENV=production` erzwingt ein gesetztes `JWT_SECRET` und entweder TLS am Go-Prozess (`TLS_CERT_FILE` / `TLS_KEY_FILE`) oder TLS am nginx mit `TRUSTED_PROXIES`. DuckDNS-Beispiel: `deploy/nginx-isms.conf` plus `deploy/isms.env.nginx.example`.

Katalog-XML nach `/opt/isms/catalog/` legen (das Skript im nächsten Schritt legt den Ordner an) oder `CATALOG_XML_PATH` auf den tatsächlichen Pfad setzen.

### 5. Bauen und als Dienst installieren

**Variante A — Pakete (.deb / .rpm), empfohlen zum Verteilen**

Auf einem Linux-Rechner (oder WSL) mit [nfpm](https://nfpm.goreleaser.com/install/):

```bash
cd ~/BSI
./scripts/build-linux-packages.sh          # Server + Client, falls Binaries da
./scripts/build-linux-packages.sh server   # nur Server
```

Pakete liegen in `dist/packages/`. Installation z. B. auf Ubuntu:

```bash
sudo apt install ./dist/packages/isms-server_*_amd64.deb
# Qt-Client (nach qmake/make, Binary z. B. in build/ISMS):
# sudo apt install ./dist/packages/isms-werkzeug_*_amd64.deb
```

Die Server-Umgebung liegt in `/etc/isms/isms.env` (wird beim Update nicht überschrieben). Danach `JWT_SECRET` und `ADMIN_PASSWORD` setzen und `sudo systemctl restart isms-server`.

**Variante B — Skript ohne Paketmanager**

```bash
cd ~/BSI/isms-server   # oder dein Clone-Pfad
./scripts/build.sh linux
cp dist/isms-server-linux-amd64 ./isms-server
sudo ./scripts/install-systemd.sh
```

(Alternativ weiterhin: `go build -o isms-server ./cmd/isms-server`.)

Das installiert:

| Pfad | Inhalt |
|------|--------|
| `/opt/isms/isms-server` | Binary |
| `/opt/isms/migrations/` | SQL-Migrationen (werden beim Start ausgeführt) |
| `/etc/isms/isms.env` | Umgebung (Kopie von `.env` bzw. `.env.example`) |
| `isms-server.service` | systemd, User `isms`, Autostart |

Falls die Env-Datei schon existierte, wird sie **nicht** überschrieben. Nach dem ersten Kopieren von `.env.example` Werte anpassen und neu starten:

```bash
sudo nano /etc/isms/isms.env
sudo systemctl restart isms-server
```

### 6. Prüfen

```bash
sudo systemctl status isms-server
curl -s http://127.0.0.1:8080/health
sudo journalctl -u isms-server -f
```

Firewall, wenn Clients von anderen Rechnern kommen:

```bash
sudo ufw allow 8080/tcp
sudo ufw reload
```

Port 5432 **nicht** nach außen öffnen — der Client spricht nur mit der API.

### 7. Dienst steuern

```bash
sudo systemctl restart isms-server
sudo systemctl stop isms-server
sudo systemctl disable --now isms-server   # stoppen und Autostart aus
```

### 8. Client

Im Login: **Mit Server verbinden**, URL `http://<ubuntu-host>:8080`.  
Erster Admin: `ADMIN_EMAIL` / `ADMIN_PASSWORD` aus `/etc/isms/isms.env`.

### 9. Öffentlich: DuckDNS + nginx

Wie beim Wahlhelfer: Let's Encrypt am Host-nginx, Go nur auf localhost. Port **8098**, weil 8080 oft schon belegt ist.

1. DuckDNS-A-Record (z. B. `isms.duckdns.org`) auf die öffentliche IP; Router **80** und **443** zum nginx-Host.
2. In `deploy/nginx-isms.conf` und unten den Hostnamen ersetzen, falls er nicht `isms.duckdns.org` ist.
3. Env nach `deploy/isms.env.nginx.example` (`HTTP_ADDR=127.0.0.1:8098`, `TRUSTED_PROXIES=127.0.0.1,::1`, `ENV=production`, starkes `JWT_SECRET` und `ADMIN_PASSWORD`).
4. nginx und Zertifikat:

```bash
sudo cp deploy/nginx-isms.conf /etc/nginx/sites-available/isms
sudo ln -sf /etc/nginx/sites-available/isms /etc/nginx/sites-enabled/isms
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d isms.duckdns.org
```

5. Firewall: `80/tcp` und `443/tcp` öffnen, **8098 nicht** nach außen. Health-Check intern: `curl -s http://127.0.0.1:8098/health`.
6. Client-URL: `https://isms.duckdns.org`.

Go und nginx müssen auf **derselben Maschine** laufen (`127.0.0.1`). Läuft ISMS auf einem anderen Rechner, in der nginx-`upstream`-Zeile die LAN-IP eintragen und `TRUSTED_PROXIES` auf die nginx-Adresse setzen.

---

## Windows: als Dienst

Im Ordner `isms-server` **als Administrator**:

```powershell
.\scripts\install-windows-service.ps1
```

Das Skript baut die Binary, kopiert sie nach `%ProgramData%\ISMS` (mitsamt `migrations` und `.env`) und richtet Autostart ein:

- **NSSM** (wenn im PATH): echter Windows-Dienst `ISMSServer`
- sonst: geplante Aufgabe **ISMS Server** (Start beim Hochfahren, Neustart bei Absturz)

Steuern:

```powershell
# NSSM-Dienst
Start-Service ISMSServer
Stop-Service ISMSServer
Get-Service ISMSServer

# geplante Aufgabe
Start-ScheduledTask -TaskName "ISMS Server"
Stop-ScheduledTask -TaskName "ISMS Server"
```

Deinstallieren:

```powershell
.\scripts\uninstall-windows-service.ps1
```

Optional: `.\scripts\install-windows-service.ps1 -InstallDir D:\ISMS`

Datenbank vorher analog anlegen:

```powershell
psql -U postgres -f scripts/setup-local-db.sql
```

---

## Hinweise

- Logs Ubuntu: `journalctl -u isms-server`. Windows/NSSM: `%ProgramData%\ISMS\logs\`.
- Katalog-Import nur beim **ersten** Start, wenn die DB noch leer ist. Später: Client **Datei → IT-Grundschutz XML importieren**.
- HTTPS: Reverse Proxy (nginx) vor dem Server, Vorlage `deploy/nginx-isms.conf` (DuckDNS + Certbot, Backend `127.0.0.1:8098`). Env: `deploy/isms.env.nginx.example`. Der Go-Dienst nur lokal binden (`HTTP_ADDR=127.0.0.1:8098`), `TRUSTED_PROXIES=127.0.0.1,::1`, Client-URL `https://isms.duckdns.org`. Ohne eigenen Hostnamen: `location /isms/` in den bestehenden vHost (Client dann `https://<host>/isms`, in `.env` `WEB_PUBLIC_BASE=/isms`). Dev-Zertifikat ohne Proxy: `scripts/generate-dev-cert.ps1` (siehe README).
- Binary-Update Ubuntu: neu bauen, `sudo cp isms-server /opt/isms/isms-server && sudo systemctl restart isms-server`.
