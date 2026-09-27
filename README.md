# home-assistant-dbusfix

Tijdelijk custom Home Assistant Docker-image: de **officiële** image
`ghcr.io/home-assistant/home-assistant:<HA_VERSION>` waarin **uitsluitend**
`aiohomekit` is vervangen door een gepatchte fork.

De fix ([schellevis/aiohomekit@c4faacb](https://github.com/schellevis/aiohomekit/commit/c4faacbb3a9a42ec8f3e2e6aca9eb22b619d297a))
lost een lek op waarbij HomeKit-over-Bluetooth-sessies (bijv. Eve Energy) per
sessie een systeem-D-Bus-verbinding open laten staan, totdat de D-Bus-limiet
per gebruiker bereikt wordt ([home-assistant/core#179152](https://github.com/home-assistant/core/issues/179152)).

## Hoe het werkt

| Bestand | Doel |
|---|---|
| `pins.env` | Repo + **vaste commit-hash** van de gepatchte aiohomekit (enige pin). |
| `Dockerfile` | `FROM` de officiële HA-image, `pip install --no-deps --force-reinstall` van aiohomekit uit de tarball van die commit, en controleert dat precies die commit is geïnstalleerd. |
| `.github/workflows/build.yml` | Handmatige workflow: bouwt multi-arch (`linux/amd64,linux/arm64`) en pusht naar GHCR. |

Er worden geen andere pakketten aangeraakt (`--no-deps`). De workflow controleert
vooraf of de aiohomekit-versie die HA vereist (uit `homekit_controller/manifest.json`)
gelijk is aan de versie van de fork; bij een verschil stopt de build (zie hieronder).

## Een nieuwe HA-release bouwen

1. GitHub → **Actions** → *Build Home Assistant (aiohomekit D-Bus fix)* → **Run workflow**.
2. Vul `ha_version` in, bijv. `2026.9.3`.

Of via de CLI:

```sh
gh workflow run build.yml -R schellevis/home-assistant-dbusfix -f ha_version=2026.9.3
```

Resultaat:

- `ghcr.io/schellevis/home-assistant-dbusfix:2026.9.3`
- `ghcr.io/schellevis/home-assistant-dbusfix:2026.9.3-aiohomekit-6eb6bfc` (traceerbaar naar de fork-commit)

### Als de build faalt op "Versieverschil"

HA gebruikt dan een andere aiohomekit-versie dan de fork. Twee mogelijkheden:

- **De fix zit upstream** in die aiohomekit-versie → dit image is niet meer nodig, zie *Opruimen*.
- **Nog niet upstream** → rebase de fork op de nieuwe aiohomekit-release, zet de nieuwe
  commit-hash in `pins.env`, commit, en draai de workflow opnieuw.
  (Met `allow_version_mismatch` kun je bewust toch bouwen; niet aanbevolen.)

## Gebruiken

Docker Compose:

```yaml
services:
  homeassistant:
    image: ghcr.io/schellevis/home-assistant-dbusfix:2026.9.3
    # rest ongewijzigd t.o.v. de officiële image
```

Controleren in de draaiende container:

```sh
docker exec homeassistant python3 -c "import importlib.metadata as m; print(m.distribution('aiohomekit').read_text('direct_url.json'))"
```

Het GHCR-package is gekoppeld aan deze repo. Is het package privé, maak het dan
publiek (Package settings → Change visibility) of log op de HA-host in met
`docker login ghcr.io`.

## Opruimen zodra de fix upstream zit

1. Controleer dat de aiohomekit-release met de fix in een HA-release zit
   (zoek de fix in de [aiohomekit-changelog](https://github.com/Jc2k/aiohomekit/releases)
   en de aiohomekit-versie in `homeassistant/components/homekit_controller/manifest.json`).
2. Zet de HA-host terug op `ghcr.io/home-assistant/home-assistant:<versie>`.
3. Verwijder het package: `gh api -X DELETE /user/packages/container/home-assistant-dbusfix`
   (vereist `delete:packages`-scope) of via GitHub → Packages.
4. Verwijder deze repo: `gh repo delete schellevis/home-assistant-dbusfix`.

Er is niets anders te ruimen: geen secrets, geen schedules, geen externe infra.
