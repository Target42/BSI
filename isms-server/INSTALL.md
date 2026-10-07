# ISMS-Server nativ betreiben

Der Go-Server ist eine einzelne Binary. PostgreSQL muss laufen; der Server selbst braucht **kein Docker**.

Das Arbeitsverzeichnis der Binary muss das Installationsverzeichnis sein (dort liegen `.env` bzw. die systemd-Env-Datei und `migrations/`). Die Web-Oberfläche steckt in der Binary. Client-Installer (Qt-GUI, Delphi) nicht: die legt der Administrator nach `downloads/` im Arbeitsverzeichnis, siehe README Abschnitt **Desktop-Clients zum Download**.

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
git clone https://github.com/Target42/BSI.git BSI
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

Das Paket und `install-systemd.sh` legen Rolle und Datenbank selbst an, wenn `DATABASE_URL` auf `localhost` zeigt und beides noch fehlt. Ist `DATABASE_URL` gar nicht gesetzt, wird eine lokale Datenbank `isms` in `/etc/isms/isms.env` eingetragen. Eine URL auf einen anderen Host lässt die lokale Datenbank unberührt.

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

`ENV=production` erzwingt ein gesetztes `JWT_SECRET` und entweder TLS am Go-Prozess (`TLS_CERT_FILE` / `TLS_KEY_FILE`) oder TLS am nginx mit `TRUSTED_PROXIES`. nginx: Subdomain `deploy/nginx-isms.conf` oder Pfad-Prefix `deploy/nginx-prefix.conf`.

Öffentliche Website: `IMPRESSUM_NAME`, `IMPRESSUM_STREET`, `IMPRESSUM_POSTAL_CODE`, `IMPRESSUM_CITY` und `IMPRESSUM_EMAIL` setzen. Daraus wird `/impressum`.

Katalog-XML nach `/opt/isms/catalog/` legen (das Skript im nächsten Schritt legt den Ordner an) oder `CATALOG_XML_PATH` auf den tatsächlichen Pfad setzen.

### 5. Bauen und als Dienst installieren

**Variante A — Pakete (.deb / .rpm), empfohlen zum Verteilen**

Auf einem Linux-Rechner (oder WSL) mit [nfpm](https://nfpm.goreleaser.com/install/):

```bash
cd ~/BSI
./scripts/build-linux-packages.sh          # Server und, wenn qmake6 da ist, der Qt-Client
./scripts/build-linux-packages.sh server   # nur Server
./scripts/build-linux-packages.sh client   # nur Qt-Client
```

Den Qt-Client baut das Skript mit, sobald `qmake6` im PATH liegt. Sonst vorher:

```bash
sudo apt install -y qt6-base-dev qt6-base-dev-tools libqt6sql6-sqlite libhunspell-dev
mkdir -p build && cd build
qmake6 CONFIG+=release ../BSI.pro && make -j"$(nproc)"
```

Pakete liegen in `dist/packages/`. Installation z. B. auf Ubuntu:

```bash
sudo apt install ./dist/packages/isms-server_*_amd64.deb
sudo apt install ./dist/packages/isms-werkzeug_*_amd64.deb
```

Die Server-Umgebung liegt in `/etc/isms/isms.env` (wird beim Update nicht überschrieben). Beim ersten Start legt das Paket die lokale PostgreSQL-Datenbank an, wenn sie noch fehlt. Danach `JWT_SECRET` und `ADMIN_PASSWORD` setzen und `sudo systemctl restart isms-server`.

nginx (zwei Varianten, siehe Abschnitt 9):

```bash
sudo isms-setup-nginx subdomain isms.example.com
sudo isms-setup-nginx prefix /isms
```

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
| `/opt/isms/downloads/` | Optionale Installer (Qt-GUI, Delphi-Client). Leer = kein Download |
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

### Serverprogramm austauschen

Nur die Binary ersetzen, ohne Neuinstallation. `/etc/isms/isms.env`, Datenbank und `downloads/` bleiben. Auf dem Linux-Rechner, im Verzeichnis mit der neuen Datei `isms-server-linux-amd64`:

```bash
sudo systemctl stop isms-server
sudo install -o isms -g isms -m 0755 isms-server-linux-amd64 /opt/isms/isms-server
sudo systemctl start isms-server
sudo systemctl status isms-server
```

`install` kopiert die Datei und setzt Besitzer `isms` sowie das Ausführungsrecht. Liegen zum gleichen Stand neue SQL-Dateien vor, dieselben Rechte wie bei der Erstinstallation, danach starten:

```bash
sudo install -o isms -g isms -m 0644 migrations/*.sql /opt/isms/migrations/
```

Der Dienst liest `migrations/` aus `/opt/isms` beim Start. Die Umgebung in `/etc/isms/isms.env` nicht überschreiben.

### 8. Client

Im Login: **Mit Server verbinden**, URL `http://<ubuntu-host>:8080`.  
Erster Admin: `ADMIN_EMAIL` / `ADMIN_PASSWORD` aus `/etc/isms/isms.env`.

**Download über die Web-Oberfläche (optional).** Installer nicht in die Binary packen. Dateien nach `/opt/isms/downloads/` legen; die Startseite zeigt sie erst dann. Qt-GUI: Dateiname enthält `werkzeug` oder `qt-gui` (z. B. das `.deb` aus `dist/packages/`). Delphi-Client: Dateiname enthält `BSIClient` oder `delphi`. Austauschen heißt überschreiben oder löschen, ohne Dienst-Neustart. Details und Windows-Pfad: README, Abschnitt **Desktop-Clients zum Download**.

```bash
sudo install -o isms -g isms -m 0644 isms-werkzeug_*_amd64.deb /opt/isms/downloads/
sudo install -o isms -g isms -m 0644 BSIClient-Setup.exe /opt/isms/downloads/
```

### 9. Öffentlich: nginx

Let's Encrypt am Host-nginx, Go nur auf localhost. Port **8098**, weil 8080 oft schon belegt ist. Zwei Varianten, immer nur eine davon.

Go und nginx laufen auf **derselben Maschine** (`127.0.0.1`). Läuft ISMS auf einem anderen Rechner, in der nginx-`proxy_pass`- bzw. `upstream`-Zeile die LAN-IP eintragen und `TRUSTED_PROXIES` auf die nginx-Adresse setzen.

Firewall: `80/tcp` und `443/tcp` öffnen, **8098 nicht** nach außen. Health-Check intern: `curl -s http://127.0.0.1:8098/health`.

Beide Varianten setzen in `/etc/isms/isms.env` `HTTP_ADDR=127.0.0.1:8098` und `TRUSTED_PROXIES=127.0.0.1,::1`. Für Produktion zusätzlich `ENV=production`, ein `JWT_SECRET` mit mindestens 32 Zeichen und ein gesetztes `ADMIN_PASSWORD`, danach `sudo systemctl restart isms-server`.

#### Subdomain

Eigener vHost, z. B. `isms.example.com` oder `isms.duckdns.org`. `WEB_PUBLIC_BASE` bleibt leer. Client-URL: `https://isms.example.com`.

Vorlage: `deploy/nginx-isms.conf`, Umgebung: `deploy/isms.env.nginx.example`.

```bash
sudo isms-setup-nginx subdomain isms.example.com
sudo certbot --nginx -d isms.example.com
```

Ohne das Skript: Hostname `isms.example.com` in `deploy/nginx-isms.conf` ersetzen, nach `/etc/nginx/sites-available/isms.conf` kopieren, Site aktivieren, `nginx -t`, reload, dann Certbot. DNS-A-Record auf die öffentliche IP; Router **80** und **443** zum nginx-Host.

`MAIL_PUBLIC_URL=https://isms.example.com` setzen. Die Startseite liefert dann `/robots.txt` und `/sitemap.xml` unter dieser Adresse. Property in der Google Search Console anmelden. Bei Pfad-Prefix steht die Sitemap unter `https://<host>/isms/sitemap.xml`; die `robots.txt` muss am Host-Wurzelverzeichnis liegen, nicht unter `/isms/`.

#### Pfad-Prefix

ISMS hängt an einem bestehenden vHost, Standardpfad `/isms`. In `/etc/isms/isms.env` muss `WEB_PUBLIC_BASE=/isms` stehen. Client-URL: `https://<host>/isms`.

Vorlage: `deploy/nginx-prefix.conf`, Umgebung: `deploy/isms.env.nginx-prefix.example`.

```bash
sudo isms-setup-nginx prefix /isms
```

Das schreibt `/etc/nginx/snippets/isms-prefix.conf`. In den bestehenden `server { }`-Block (den HTTPS-vHost):

```nginx
include snippets/isms-prefix.conf;
```

Danach `sudo nginx -t && sudo systemctl reload nginx`. Anderer Pfad: `sudo isms-setup-nginx prefix /grundschutz` und denselben Wert als `WEB_PUBLIC_BASE`.

---

## Windows: als Dienst

Im Ordner `isms-server` **als Administrator**:

```powershell
.\scripts\install-windows-service.ps1
```

Das Skript baut die Binary, kopiert sie nach `%ProgramData%\ISMS` (mitsamt `migrations` und `.env`) und richtet Autostart ein. Den Ordner `%ProgramData%\ISMS\downloads` legt es leer an; dorthin kommen optionale Client-Installer (siehe Abschnitt 8).

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
- HTTPS: Reverse Proxy (nginx), Backend `127.0.0.1:8098`. Subdomain: `deploy/nginx-isms.conf` bzw. `isms-setup-nginx subdomain <host>`, Client-URL `https://<host>`. Pfad-Prefix: `deploy/nginx-prefix.conf` bzw. `isms-setup-nginx prefix /isms`, Client-URL `https://<host>/isms`, `WEB_PUBLIC_BASE=/isms`. Dev-Zertifikat ohne Proxy: `scripts/generate-dev-cert.ps1` (siehe README).
- Serverprogramm austauschen, ohne Neuinstallation: Abschnitt **Serverprogramm austauschen**.
