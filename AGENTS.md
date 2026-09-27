# AGENTS.md

Instructies voor AI-agents en mensen die aan deze repo werken.

## Doel en scope

Deze repo bouwt een **tijdelijke** Home Assistant-image: officiële HA-image +
gepatchte `aiohomekit` (BLE D-Bus connection leak fix). Niets anders.

## Harde regels

- Vervang **alleen** `aiohomekit`. Altijd `pip install --no-deps --force-reinstall`;
  voeg geen andere pakketten, patches of configuratie toe.
- Baseer altijd op een **expliciete** HA-versie (`ghcr.io/home-assistant/home-assistant:<X.Y.Z>`),
  nooit `stable`, `latest` of `dev`.
- `AIOHOMEKIT_REF` in `pins.env` is altijd een **volledige 40-tekens commit-hash**,
  nooit een branch of tag. `pins.env` is de enige plek waar de pin staat.
- Geen secrets toevoegen; de workflow gebruikt alleen `GITHUB_TOKEN`.
- Geen schedules/automatische triggers toevoegen zonder expliciete vraag van de eigenaar.

## Veelvoorkomende taken

**Nieuwe HA-versie bouwen:** geen codewijziging nodig.
`gh workflow run build.yml -f ha_version=<versie>`.

**Build faalt op versieverschil:** controleer eerst of de fix upstream in
aiohomekit zit (Jc2k/aiohomekit, bestanden `aiohomekit/controller/ble/pairing.py`
en `discovery.py`: `disconnect()` wordt aangeroepen ongeacht `is_connected`).
- Zit hij upstream en gebruikt HA die versie → stel opruimen voor (README, *Opruimen*).
- Anders → fork (schellevis/aiohomekit) rebasen op de nieuwe versie, nieuwe
  commit-hash in `pins.env`, en de commit-boodschap vermeldt oude → nieuwe hash.

**Verifiëren:** de Dockerfile faalt zelf als de geïnstalleerde aiohomekit niet
uit `AIOHOMEKIT_REF` komt of niet importeert. Check na een run de job summary
en `docker buildx imagetools inspect ghcr.io/schellevis/home-assistant-dbusfix:<versie>`.

## Structuur

- `pins.env` — fork-repo + commit-hash
- `Dockerfile` — build (ARGs: `HA_VERSION`, `AIOHOMEKIT_REPO`, `AIOHOMEKIT_REF`)
- `.github/workflows/build.yml` — handmatige multi-arch build + push naar GHCR
