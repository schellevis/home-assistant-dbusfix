# home-assistant-dbusfix

Temporary custom Home Assistant Docker image: the **official** image
`ghcr.io/home-assistant/home-assistant:<HA_VERSION>` with **only**
`aiohomekit` replaced by a patched fork.

The fix ([schellevis/aiohomekit@c4faacb](https://github.com/schellevis/aiohomekit/commit/c4faacbb3a9a42ec8f3e2e6aca9eb22b619d297a))
resolves a leak where HomeKit-over-Bluetooth sessions (e.g. Eve Energy) leave one
system D-Bus connection open per session, until the per-user D-Bus connection
limit is reached ([home-assistant/core#179152](https://github.com/home-assistant/core/issues/179152)).

## How it works

| File | Purpose |
|---|---|
| `pins.env` | Repo + **fixed commit hash** of the patched aiohomekit (the only pin). |
| `Dockerfile` | `FROM` the official HA image, `pip install --no-deps --force-reinstall` aiohomekit from that commit's tarball, and verifies that exactly that commit is installed. |
| `.github/workflows/build.yml` | Build workflow (manual or called by `auto.yml`): builds multi-arch (`linux/amd64,linux/arm64`) and pushes to GHCR. |
| `.github/workflows/auto.yml` | Daily check for a new stable HA release; builds it automatically and tags it `:latest`. |

No other packages are touched (`--no-deps`). Before building, the workflow checks
that the aiohomekit version required by HA (from `homekit_controller/manifest.json`)
matches the fork's version; if they differ, the build stops (see below).

## Automatic builds for new HA releases

`auto.yml` runs daily (05:17 UTC). It looks up the latest **stable** HA release
(`home-assistant/core` releases/latest, so no betas) and, if
`ghcr.io/schellevis/home-assistant-dbusfix:<version>` does not exist yet, builds it
and pushes it as `:<version>` **and** `:latest`. You can also trigger it by hand
(Actions → *Auto-build nieuwste HA-release* → Run workflow).

If the automatic build fails (typically the aiohomekit version mismatch described
below), GitHub emails you about the failed run. Until you fix it, the next daily
run will fail again; `:latest` stays on the last good build.

Note: GitHub disables scheduled workflows after 60 days without repository
activity. You'll get an email about that; re-enable the workflow under Actions.

## Building a specific HA release manually

1. GitHub → **Actions** → *Build Home Assistant (aiohomekit D-Bus fix)* → **Run workflow**.
2. Enter `ha_version`, e.g. `2026.9.3`.

Or via the CLI:

```sh
gh workflow run build.yml -R schellevis/home-assistant-dbusfix -f ha_version=2026.9.3
```

Tick `tag_latest` (or add `-f tag_latest=true`) to also move `:latest`; only do
that for the newest release.

Result:

- `ghcr.io/schellevis/home-assistant-dbusfix:2026.9.3`
- `ghcr.io/schellevis/home-assistant-dbusfix:2026.9.3-aiohomekit-6eb6bfc` (traceable to the fork commit)
- `ghcr.io/schellevis/home-assistant-dbusfix:latest` (automatic builds, or with `tag_latest`)

### If the build fails with "Versieverschil" (version mismatch)

HA then uses a different aiohomekit version than the fork. Two possibilities:

- **The fix is upstream** in that aiohomekit version → this image is no longer needed, see *Cleanup*.
- **Not upstream yet** → rebase the fork onto the new aiohomekit release, put the new
  commit hash in `pins.env`, commit, and run the workflow again.
  (With `allow_version_mismatch` you can deliberately build anyway; not recommended.)

## Usage

Docker Compose:

```yaml
services:
  homeassistant:
    image: ghcr.io/schellevis/home-assistant-dbusfix:2026.9.3  # or :latest
    # everything else unchanged compared to the official image
```

With `:latest` you get new HA releases the same way as with the official
`:stable` tag (pull + recreate, or via Watchtower/Diun etc.). Pinning a version is
more predictable.

Verify inside the running container:

```sh
docker exec homeassistant python3 -c "import importlib.metadata as m; print(m.distribution('aiohomekit').read_text('direct_url.json'))"
```

The GHCR package is linked to this repo. If the package is private, make it
public (Package settings → Change visibility) or log in on the HA host with
`docker login ghcr.io`.

## Cleanup once the fix is upstream

1. Confirm that the aiohomekit release containing the fix is included in an HA release
   (look for the fix in the [aiohomekit releases](https://github.com/Jc2k/aiohomekit/releases)
   and check the aiohomekit version in `homeassistant/components/homekit_controller/manifest.json`).
2. Switch the HA host back (if you use `:latest`, switch to the official `:stable`) to `ghcr.io/home-assistant/home-assistant:<version>`.
3. Delete the package: `gh api -X DELETE /user/packages/container/home-assistant-dbusfix`
   (requires the `delete:packages` scope) or via GitHub → Packages.
4. Delete this repo: `gh repo delete schellevis/home-assistant-dbusfix`.

There is nothing else to clean up: no secrets and no external infrastructure; the daily schedule disappears with the repo.
(To stop the automatic builds without deleting anything: `gh workflow disable auto.yml -R schellevis/home-assistant-dbusfix`.)
