# ISMS-Server nativ betreiben

Der Go-Server ist eine einzelne Binary. PostgreSQL muss laufen; der Server selbst braucht **kein Docker**.

Das Arbeitsverzeichnis der Binary muss das Installationsverzeichnis sein (dort liegen `.env` bzw. die systemd-Env-Datei und `migrations/`).

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

Aktuelle Dateinamen: [https://go.dev/dl/](https://go.dev/dl/). Alternativ die Binary auf einem anderen Rechner bauen und rüberkopieren:

```powershell
# Windows (im Ordner isms-server)
$env:GOOS="linux"; $env:GOARCH="amd64"; go build -o isms-server ./cmd/isms-server
scp isms-server nutzer@ubuntu-host:~/isms-server/
```

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

`ENV=production` erzwingt TLS (`TLS_CERT_FILE`, `TLS_KEY_FILE`) und ein gesetztes `JWT_SECRET`. Im internen LAN reicht meist `ENV=development` plus starkes Secret.

Katalog-XML nach `/opt/isms/catalog/` legen (das Skript im nächsten Schritt legt den Ordner an) oder `CATALOG_XML_PATH` auf den tatsächlichen Pfad setzen.

### 5. Bauen und als Dienst installieren

```bash
cd ~/BSI/isms-server   # oder dein Clone-Pfad
go build -o isms-server ./cmd/isms-server
sudo ./scripts/install-systemd.sh
```

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
- HTTPS: Zertifikat eintragen oder Reverse Proxy (nginx/Caddy) davor. Dev-Zertifikat: `scripts/generate-dev-cert.ps1` (siehe README).
- Binary-Update Ubuntu: neu bauen, `sudo cp isms-server /opt/isms/isms-server && sudo systemctl restart isms-server`.
