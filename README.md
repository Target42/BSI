# ISMS

IT-Grundschutz mit Web-Oberfläche, Qt-Client und Delphi-Client. Der Server ist eine Go-Binary mit PostgreSQL. Die Web-Oberfläche steckt in der Binary. Desktop-Clients werden getrennt gebaut und optional zum Download angeboten.

Ausführlich zu Umgebung, nginx und API: [isms-server/INSTALL.md](isms-server/INSTALL.md), [isms-server/README.md](isms-server/README.md).

## Nur Binaries

Go 1.22 oder neuer. CGO ist nicht nötig, Windows kann die Linux-Binary mitbauen.

```powershell
cd isms-server
.\scripts\build.ps1
```

```bash
cd isms-server
./scripts/build.sh
```

Nur ein System: `.\scripts\build.ps1 -Targets linux` oder `./scripts/build.sh linux`.

Ausgabe in `isms-server/dist/`:

| Datei | System |
|---|---|
| `isms-server-linux-amd64` | Linux |
| `isms-server-windows-amd64.exe` | Windows |

### Qt-Client

Linux, im Ordner `build/`:

```bash
sudo apt install -y build-essential qt6-base-dev qt6-base-dev-tools libqt6sql6-sqlite libhunspell-dev
mkdir -p build && cd build
qmake6 CONFIG+=release ../BSI.pro && make -j"$(nproc)"
```

Die Datei heißt `build/ISMS`. Unter Windows mit Qt 6 im PATH analog `qmake CONFIG+=release ..\BSI.pro` und `mingw32-make`; die Datei heißt dann `ISMS.exe`.

### Delphi-Client

RAD Studio 12, Win32:

```bat
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
msbuild Delphi\BSIClient.dproj /t:Build /p:Config=Release /p:Platform=Win32
```

Die Datei liegt unter `Delphi\Win32\Release\BSIClient.exe`.

## Pakete (.deb und .rpm)

Pakete entstehen auf Linux oder in WSL mit [nfpm](https://nfpm.goreleaser.com/install/). Die Version kommt vom Git-Tag (`v0.1.0` wird zu `0.1.0`). Ohne Tag gilt `0.1.0`, sofern nichts anderes gesetzt ist.

```bash
./scripts/build-linux-packages.sh          # Server und, wenn qmake6 da ist, der Qt-Client
./scripts/build-linux-packages.sh server   # nur Server
./scripts/build-linux-packages.sh client   # nur Qt-Client
ISMS_VERSION=0.1.0 ./scripts/build-linux-packages.sh server
```

Die Pakete liegen in `dist/packages/`. Der Server heißt `isms-server`, der Qt-Client `isms-werkzeug`. Ein Windows-Installer wird hier nicht gebaut.

## Auf einem laufenden Server

PostgreSQL muss laufen. Die Datenbank legt das Paket oder `install-systemd.sh` lokal an, wenn `DATABASE_URL` auf diesen Rechner zeigt und Rolle sowie Datenbank noch fehlen.

### Erstinstallation mit Paket

```bash
sudo apt install ./dist/packages/isms-server_*_amd64.deb
sudo nano /etc/isms/isms.env
sudo systemctl restart isms-server
```

In der Env-Datei mindestens `JWT_SECRET` (32 Zeichen oder mehr) und `ADMIN_PASSWORD` setzen. `ENV=production` verlangt zusätzlich TLS am Go-Prozess oder nginx mit `TRUSTED_PROXIES`. nginx:

```bash
sudo isms-setup-nginx subdomain isms.example.com
sudo isms-setup-nginx prefix /isms
```

Beim Pfad-Prefix muss `WEB_PUBLIC_BASE=/isms` in `/etc/isms/isms.env` stehen.

### Erstinstallation ohne Paket

```bash
cd isms-server
./scripts/build.sh linux
cp dist/isms-server-linux-amd64 ./isms-server
sudo ./scripts/install-systemd.sh
sudo nano /etc/isms/isms.env
sudo systemctl restart isms-server
```

Unter Windows, im Ordner `isms-server`, als Administrator: `.\scripts\install-windows-service.ps1`. Die Installation liegt in `%ProgramData%\ISMS`.

### Neue Version einspielen

`/etc/isms/isms.env`, die Datenbank und `downloads/` bleiben. Dienst stoppen, Binary und bei diesem Stand neue SQL-Dateien kopieren, Dienst starten:

```bash
sudo systemctl stop isms-server
sudo install -o isms -g isms -m 0755 isms-server-linux-amd64 /opt/isms/isms-server
sudo install -o isms -g isms -m 0644 migrations/*.sql /opt/isms/migrations/
sudo systemctl start isms-server
curl -s http://127.0.0.1:8080/health
```

Ein Paket-Update mit `apt install` der neuen `.deb` ersetzt Binary und Migrationen ebenfalls und lässt `/etc/isms/isms.env` stehen.

Unter Windows den Dienst `ISMSServer` oder die geplante Aufgabe **ISMS Server** stoppen, `isms-server.exe` und den Ordner `migrations` in `%ProgramData%\ISMS` ersetzen, dann wieder starten. `.env` in diesem Ordner nicht überschreiben.

Prüfung: `systemctl status isms-server` und `journalctl -u isms-server -f`.

Client-Installer, die die Startseite anbieten soll, nach `/opt/isms/downloads/` legen. Der Dateiname des Qt-Pakets enthält `werkzeug` oder `qt-gui`, der des Delphi-Clients `BSIClient` oder `delphi`. Dafür ist kein Neustart nötig.
