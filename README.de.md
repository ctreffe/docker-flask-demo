# docker-flask-demo

[English version](README.md)

Eine minimale Flask-Anwendung, die Docker-Containerisierung, den Import von
GitHub nach GitLab und CI/CD-Deployment über eine verwaltete Hosting-Plattform demonstriert.

## Projekt und Ziel

Das Ziel ist, den gesamten Weg vom Anwendungsquellcode zu einem laufenden Container
verständlich zu machen. Sie können die Demo lokal ausführen, ihren Begrüßungstext
über eine Umgebungsvariable ändern und dieselbe Anwendung in einem GitLab-Build-
und Deployment-Workflow verfolgen. Die Code- und Konfigurationsdateien enthalten
englische Kommentare, die die Schritte und ihren Zweck erklären.

GitHub ist die maßgebliche Quelle für die gepflegten Dateien. Die Hosting-Admins
importieren das öffentliche Repository in die Gruppe **Gemi** (Namespace `gemi`)
auf `gitlab.gwdg.de`. Nur die Hosting-Admins können in dieser Gruppe Projekte anlegen.
Ein optionaler GitLab-Job kopiert später neue GitHub-Commits in das GitLab-Repository.
Die Anwendung benötigt weder GitHub Actions noch eine GitHub-Container-Registry.

Die Demo hat eine Webseite und einen `/health`-Endpunkt. Sie hat bewusst keine
Anmeldung, Datenbank oder persistenten Benutzerdaten. Die Hosting-Admins konfigurieren
den öffentlichen Hostnamen, Reverse-Proxy, TLS und erforderliche
Zugriffsbeschränkungen separat.

## Dateien

| Datei | Zweck |
|---|---|
| `app.py` | Flask-Routen und der aus der Umgebung gelesene Begrüßungstext |
| `templates/index.html` | Webseite; der Begrüßungstext wird maskiert, bevor er zu HTML wird |
| `requirements.txt` | Festgelegte direkte Python-Abhängigkeiten: Flask und Gunicorn |
| `Dockerfile` | Linux-Image mit Gunicorn, einem Benutzer ohne Root-Rechte und einem HTTP-Healthcheck |
| `compose.yaml` | Lokaler Build und Zugriff über die Loopback-Schnittstelle des Rechners |
| `compose.hosting.yaml` | Hosting-Konfiguration mit dem externen Netzwerk `dockernet` |
| `.env.example` | Unbedenkliche Vorlage für die lokale Konfiguration |
| `.gitignore`, `.dockerignore` | Halten lokale Einstellungen und unnötige Dateien aus Git und dem Image heraus |
| `.gitattributes` | Erhält Linux-Zeilenenden in unter Windows bearbeiteten Skripten |
| `.gitlab-ci.yml` | Tests, optionale Synchronisation, Image-Build und Release-Regeln |
| `scripts/common.sh` | Gemeinsame Variablenprüfungen und temporäre Registry-Anmeldung |
| `scripts/build.sh` | Image bauen, Start testen und veröffentlichen; Registry-Digest erfassen |
| `scripts/deploy.sh` | Ziel prüfen, das erfasste Image deployen und das Backend verifizieren |
| `scripts/sync.sh` | GitHub-Commits nur dann nach GitLab kopieren, wenn ein Fast-Forward möglich ist |
| `tests/` | Tests für Anwendungsverhalten und CI-Skripte ohne echte Git-Pushes oder Deployments |
| `TROUBLESHOOTING.md` | Ein begrenzter Wiederherstellungshinweis zum beim Test aufgetretenen Docker-Desktop-Startproblem |
| `LICENSE` | MIT-Lizenz |

## Lokal mit Docker ausführen

Sie benötigen Docker Desktop mit Linux-Containern oder Docker Engine unter Linux
und Docker Compose v2 mit Unterstützung für `up --wait --wait-timeout` und
`config --format json`. Starten Sie Docker, bevor Sie die Befehle ausführen.
Führen Sie sie im Verzeichnis dieses Repositorys aus.

1. Kopieren Sie die Beispieleinstellungen. In Windows PowerShell:

   ```powershell
   Copy-Item .env.example .env
   ```

   Unter Linux oder macOS:

   ```sh
   cp .env.example .env
   ```

2. Öffnen Sie `.env` in einem Texteditor. Behalten Sie den vorgegebenen
   Begrüßungstext bei oder ändern Sie `GREETING_TEXT`. `APP_PORT=5000` wählt
   den lokalen Port.

3. Bauen und starten Sie den Container:

   ```sh
   docker compose up --build --detach --wait --wait-timeout 90
   ```

4. Öffnen Sie [die lokale Webseite](http://localhost:5000) und
   [den Health-Endpunkt](http://localhost:5000/health). Die Seite zeigt den
   Begrüßungstext; der Health-Endpunkt liefert `{"status":"ok"}` zurück.
   Haben Sie `APP_PORT` geändert, verwenden Sie diesen Port in beiden URLs.
   Sie können außerdem Zustand und Logs prüfen:

   ```sh
   docker compose ps
   docker compose logs --tail 100 app
   ```

5. Erzeugen Sie nach einer Änderung an `GREETING_TEXT` den Container neu:

   ```sh
   docker compose up --detach --force-recreate --wait --wait-timeout 90
   ```

   Laden Sie die Seite neu, um den neuen Text zu sehen. Eine Änderung an `.env`
   erfordert keinen Image-Neubau. Änderungen an `app.py`, der Vorlage oder den
   Abhängigkeiten erfordern einen Neubau.

6. Stoppen und entfernen Sie anschließend den lokalen Container und das Netzwerk
   dieser Demo:

   ```sh
   docker compose down
   ```

Der lokale Port ist an `127.0.0.1` gebunden; dieser Befehl veröffentlicht die Demo
daher nicht für andere Rechner. Die echte `.env` wird von Git ignoriert und ist
vom Image ausgeschlossen.

## So funktioniert die Umgebungsvariable

`.env.example` dokumentiert einen sicheren Wert. Ihre lokale `.env` liefert Werte
an Docker Compose. Der Block `environment` in `compose.yaml` reicht
`GREETING_TEXT` ausdrücklich an den Container weiter. Flask liest ihn beim
Start der Anwendung.

Auf GitLab liefert stattdessen eine CI/CD-Variable den Hosting-Wert. Das
Deployment-Skript löst `compose.hosting.yaml` auf und speichert die
Laufzeitkonfiguration auf dem Host. Diese gespeicherte Konfiguration enthält
den Begrüßungstext. Verwenden Sie für `GREETING_TEXT` nur öffentlichen Text;
die Webseite zeigt ihn allen Besuchern. Echte Secrets gehören in eine separat
geprüfte Secret-Konfiguration, niemals in dieses Repository oder Image.

## Optionaler Erstimport aus GitHub

1. Schicken Sie den Hosting-Admins diese öffentliche GitHub-URL, den gewünschten
   Projektnamen, die vorgesehene Revision und die gewünschte Sichtbarkeit:

   ```text
   https://github.com/ctreffe/docker-flask-demo.git
   ```

2. Die Hosting-Admins prüfen, ob der URL-Import auf `gitlab.gwdg.de` aktiviert ist.
   Sie wählen **New project/repository > Import project > Repository by URL**,
   importieren das Repository in **Gemi**, stellen die vereinbarte Sichtbarkeit
   ein und geben Ihnen Zugriff. Die öffentliche GitHub-Quelle benötigt für
   diesen Import keine GitHub-Zugangsdaten.
3. Öffnen Sie das importierte GitLab-Projekt und prüfen Sie den vorgesehenen
   Commit und die Dateien. Pipeline und Skripte sind bereits enthalten;
   YAML muss nicht kopiert werden.

Den Erstimport führt GitLab selbst aus, kein Runner. Er kopiert das Repository
einmal und richtet keine kontinuierliche Synchronisation ein. Die Hosting-Admins
prüfen den importierten CI-Code, bevor sie Zugriff auf Deployment-Runner oder
Zugangsdaten freigeben. Mit den Vorgaben läuft nur der isolierte Test-Job.

## Hosting-Einrichtung durch die Admins

Bestätigen Sie vor dem Aktivieren des Hostings Runner-Executors, Registry und
Berechtigungen auf der tatsächlichen GitLab-Instanz. Test- und Sync-Jobs erwarten
einen geeigneten Linux-Runner mit Docker-Executor. Build- und Deploy-Jobs erwarten
einen Linux-Runner mit **Shell-Executor**, der mit `apps.psych` und `production`
getaggt ist und auf dem Bash, Git, `python3`, Docker Engine, Docker Compose v2
und GNU `realpath` bereits verfügbar sind. Diese Jobs nutzen den Docker-Daemon
dieses Hosts; `image:` eines Jobs konfiguriert keinen Shell-Executor. Die
Tag-Namen allein belegen diese Fähigkeiten nicht.

Aktivieren Sie die Container Registry des Projekts und schützen Sie den
Default-Branch. Konfigurieren Sie, wer ihn ändern oder seine Pipelines starten
darf. Aktivieren Sie **Prevent outdated deployment jobs** in den
GitLab-Deployment-Einstellungen. Konfigurieren Sie die Kontrollen der Umgebung
`production`, soweit die installierte Edition sie unterstützt. Legen Sie ein
eigenes Anwendungsverzeichnis unterhalb eines vorhandenen Deployment-Stammverzeichnisses
an und bestätigen Sie, dass `dockernet` existiert.

Fügen Sie die folgenden Variablen unter **Settings > CI/CD > Variables** hinzu.
Hosting- und Sync-Einstellungen müssen geschützt und für ihre Jobs verfügbar
sein. Verwenden Sie in diesem Beispiel den Umgebungsbereich **All**: Build-
und Sync-Jobs deklarieren die Umgebung `production` nicht. Überschreiben Sie
weder vordefinierte `CI_*`-Variablen noch die Release-Artefaktvariablen
`APP_IMAGE`, `RELEASE_COMMIT`, `RELEASE_PIPELINE_ID`.

| Variable | Wert oder Zuständigkeit |
|---|---|
| `HOSTING_ENABLED` | `true` nach Prüfung der Hosting-Einrichtung; Vorgabe ist `false` |
| `GREETING_TEXT` | Öffentlicher Begrüßungstext, etwa `Hello from GitLab!`; die Anwendung hat eine Vorgabe |
| `DEPLOY_ROOT` | Absoluter Pfad eines vorhandenen, von den Admins freigegebenen Deployment-Stammverzeichnisses; niemals `/` |
| `DEPLOY_DIR` | Absoluter Pfad eines vorhandenen Anwendungsverzeichnisses strikt unterhalb dieses Stammverzeichnisses |
| `APP_CONTAINER_NAME` | Von den Admins zugewiesener eindeutiger Containername |
| `APP_NETWORK_ALIAS` | Von den Admins zugewiesener eindeutiger Backend-Name auf `dockernet` |
| `SYNC_ENABLED` | `true` nur dann, wenn spätere GitHub-Updates gewünscht sind; Vorgabe ist `false` |
| `GITLAB_SYNC_TOKEN` | Maskierter, geschützter Access Token mit `write_repository`, dessen Konto auf den geschützten Default-Branch pushen darf |

GitLab stellt `CI_REGISTRY`, `CI_REGISTRY_IMAGE`, `CI_REGISTRY_USER` und
`CI_REGISTRY_PASSWORD` für den Registry-Zugriff bereit. Die Skripte halten die
Registry-Anmeldung des Jobs temporär. Die Admins konfigurieren den gemeinsamen
Proxy für den Zugriff auf `APP_NETWORK_ALIAS:8000` und behandeln DNS, TLS und
Zugriffsbeschränkungen separat. Die Hosting-Compose-Datei veröffentlicht
keinen Host-Port.

Bevorzugen Sie für die Synchronisation einen Project Access Token, falls die
Instanz ihn unterstützt; verwenden Sie andernfalls einen dedizierten Personal
Access Token mit dem genannten Scope und angemessener Ablaufzeit. Verwenden
Sie für den Push dieses Beispiels nicht `CI_JOB_TOKEN`: Seine Pushes lösen
keine Folgepipeline aus. Pflegen Sie Anwendungsänderungen auf GitHub.
Nur auf GitLab vorhandene Commits würden die beiden Historien auseinanderlaufen
lassen und die Synchronisation stoppen.

## Optionale spätere Updates über einen Runner

Nachdem die Admins die Synchronisation aktiviert und ihren Token konfiguriert haben:

1. Prüfen und pushen Sie die vorgesehenen Änderungen auf den Default-Branch auf GitHub.
2. Öffnen Sie in GitLab **Build > Pipelines** und starten Sie eine neue Pipeline
   auf dem geschützten Default-Branch. Setzen Sie die Pipeline-Variable `RUN_SYNC`
   auf `true`.
3. Der Sync-Job holt `GITHUB_REPO_URL` und `GITHUB_BRANCH` ab (standardmäßig
   dieses Repository und `main`). Erweitern neue Commits die aktuelle GitLab-Historie,
   pusht er sie ohne Merge-Commit oder Force-Push. Stimmen die Historien überein,
   tut er nichts. Sind sie auseinander gelaufen, schlägt er fehl und die Admins
   müssen den Unterschied auflösen.
4. Ein erfolgreiches Update startet eine **neue Push-Pipeline** für den
   importierten Commit. Verfolgen Sie diese Pipeline für Tests, Build und ein
   mögliches Release. Die Sync-Pipeline selbst baut oder deployt den alten Checkout nicht.

Ein optionaler Zeitplan kann denselben Sync-Job mit `RUN_SYNC=true` starten.
Vereinbaren Sie dies separat mit den Admins. Ein neu synchronisierter letzter
Commit mit `[deploy]` kann die Folgepipeline zum Deployment veranlassen,
wenn Hosting aktiviert ist. Ein Zeitplan umgeht keine Prüfung und ändert
die Release-Regel nicht.

Der Sync-Job folgt einem Branch. Er spiegelt weder Tags noch andere Branches,
GitHub-Issues, Pull Requests oder Löschungen. War ein Push erfolgreich, aber
die Folgepipeline konnte nicht starten, starten Sie manuell eine normale
Pipeline auf dem importierten Default-Branch-Commit mit `RUN_SYNC=false`;
wiederholen Sie keinen davon unabhängigen Release-Commit.

## Build und Release-Regel

Normale Branch-Pipelines führen die Tests aus. Bei aktiviertem Hosting bauen
Push-Pipelines oder manuell gestartete Pipelines auf dem geschützten
Default-Branch außerdem ein Image, testen seinen Start und veröffentlichen
es in der GitLab Container Registry. Das Deployment erfordert zusätzlich
den exakten Teilstring **`[deploy]`** in der Nachricht dieses Commits.
Die Übereinstimmung unterscheidet Groß- und Kleinschreibung. `deploy`,
`[deployment]`, andere Branches, Tags, Merge-Request-Pipelines und die
Sync-Pipeline wählen den Deployment-Job nicht aus.

Prüfen Sie für ein Release die vollständigen Quellen, pushen Sie dann einen
Default-Branch-Commit mit einer Nachricht wie `Release demo [deploy]` nach
GitHub und starten Sie den Sync-Job. Die neue GitLab-Pipeline testet und baut
diese importierte Revision vor dem Deployment.

Das Deployment nutzt die unveränderliche `@sha256:`-Image-Referenz des Builds
und prüft deren Commit- und Pipeline-Labels. Es lehnt einen veralteten Branch-Stand
oder eine ältere Pipeline als das letzte erfolgreiche Deployment ab.
Das Skript prüft den vorhandenen Zielpfad vor Schreibzugriffen, startet das
Image über Compose, wartet auf dessen Healthcheck und prüft den HTTP-Zugriff
aus `dockernet`.

Nach der Abnahme enthält `DEPLOY_DIR/compose.json` die aufgelösten
Laufzeiteinstellungen; `DEPLOY_DIR/release.txt` erfasst Pipeline-ID, Commit und
Image-Digest. Anwendungscode liegt im Image und wird nicht aus dem
Runner-Checkout gemountet. Das Skript löscht keine Host-Daten oder Secrets.
Schlägt der Start oder die Backend-Prüfung fehl, schlägt der Job fehl und
behält die Kandidatenkonfiguration zur Diagnose. Der laufende Container
kann bereits geändert worden sein; es gibt keinen automatischen Rollback.
Die Admins prüfen den Dienst vor einer Wiederholung und behandeln eine
Wiederherstellung ausdrücklich.

Die Dateien sind eine Lehrimplementierung. Import, Runner-Kompatibilität,
Image-Build, Deployment, öffentliches Routing und Wiederherstellung müssen
auf der tatsächlichen GWDG-/Hosting-Umgebung geprüft werden, bevor sie
als funktionierender produktiver Workflow gelten können.

## Tests und Fehlerbehebung

GitLab führt `python -m unittest discover -s tests -v` und Shell-Syntaxprüfungen
aus. Sie können denselben Python-Befehl lokal mit Python 3.13 und installiertem
Flask ausführen; die Shell-Skript-Tests benötigen zusätzlich Bash (Git for
Windows wird unterstützt). Die Skript-Tests nutzen ein simuliertes
Git-Programm und pushen niemals oder legen echte Repositories an.

| Symptom | Was zu prüfen ist |
|---|---|
| Docker kann keine Verbindung herstellen | Docker Desktop starten und Linux-Container auswählen |
| Lokaler Port wird bereits verwendet | `APP_PORT` in `.env` ändern und den Container neu erzeugen |
| Begrüßungstext hat sich nicht geändert | Container nach einer Änderung an `.env` neu erzeugen |
| GitLab-Job wartet auf Ausführung | Runner-Verfügbarkeit, Executor, Tags und Zugriff auf geschützte Branches bestätigen |
| Nur Tests laufen | Hosting ist standardmäßig deaktiviert; Admins müssen es konfigurieren und aktivieren |
| Sync meldet auseinander gelaufene Historien | Beide Seiten erhalten und die Admins fragen; keinen Force-Push ausführen |
| Kein Deploy-Job erscheint | Exakten Marker, Default-/geschützten Branch, Hosting-Schalter und Pipeline-Quelle prüfen |
| Deployment schlägt fehl | Fehler und Logs des Jobs lesen; die Admins müssen den laufenden Dienst und die Kandidatenkonfiguration prüfen |

## Referenzen und Lizenz

- [Flask-Deployment mit Gunicorn](https://flask.palletsprojects.com/en/stable/deploying/gunicorn/)
- [Docker-Compose-Umgebungsinterpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)
- [GitLab-Import über eine Git-URL](https://docs.gitlab.com/user/import/third_party_systems/repo_by_url/)
- [GitLab-CI/CD-Variablen](https://docs.gitlab.com/ci/variables/)
- [GitLab-Job-Token-Verhalten beim Push](https://docs.gitlab.com/ci/jobs/ci_job_token/#allow-git-push-requests-to-your-project-repository)
- [GitLab-Deployment-Sicherheit](https://docs.gitlab.com/ci/environments/deployment_safety/)

Dieses Projekt wird unter der [MIT-Lizenz](LICENSE) bereitgestellt.
