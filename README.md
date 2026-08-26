# Pi-hole Helper (`ph`)

<p align="center">
    <a href="https://github.com/elidholm/ph/actions/workflows/ci.yml"><img align="center" src="https://github.com/elidholm/ph/actions/workflows/ci.yml/badge.svg" alt="github actions"></a>
    <a href="https://github.com/zricethezav/gitleaks-action"><img align="center" src="https://img.shields.io/badge/protected%20by-gitleaks-blue" alt="gitleaks badge"></a>
    <a href="https://github.com/elidholm/ph/issues"><img align="center" src="https://img.shields.io/github/issues/elidholm/ph" alt="open issues"></a>
    <a href="https://github.com/elidholm/ph/commits/master"><img align="center" src="https://img.shields.io/github/commit-activity/m/elidholm/ph" alt="commit frequency"></a>
</p>

---

`ph` is a small Bash CLI wrapper around the Pi-hole REST API. It currently lets you temporarily disable Pi-hole blocking for a chosen duration, with blocking resuming automatically afterwards.

## Requirements

- Bash
- [`curl`](https://curl.se/)
- [`jq`](https://jqlang.org/)

## Installation (Linux)

1. Clone the repository:

   ```bash
   git clone https://github.com/elidholm/ph.git
   cd ph
   ```

2. Make the script executable:

   ```bash
   chmod +x ph
   ```

3. Export the base URL of your Pi-hole instance's API as `PIHOLE_API_URL` (add this to your shell profile, e.g. `~/.bashrc`, to persist it):

   ```bash
   export PIHOLE_API_URL='http://192.168.20.4/api'
   ```

4. Put `ph` on your `PATH`, for example:

   ```bash
   sudo cp ph /usr/local/bin/ph
   ```

   or, without root, symlink it into a user-owned `PATH` directory:

   ```bash
   mkdir -p ~/.local/bin
   ln -s "$(pwd)/ph" ~/.local/bin/ph
   ```

5. Export your Pi-hole admin password as `PIHOLE_API_KEY` (add this to your shell profile as well):

   ```bash
   export PIHOLE_API_KEY='your-pihole-password'
   ```

## Usage

```bash
ph disable           # Disable blocking for the default duration (10 seconds)
ph disable -30       # Disable blocking for 30 seconds
ph disable --help    # Show help for the disable command
ph --help            # Show general help
```

## Local development (bash tests)

Requirements: `bash` + [`bats-core`](https://github.com/bats-core/bats-core).

```bash
git clone https://github.com/elidholm/ph.git
cd ph
bats tests/unit/ph.bats
```

`tests/unit/` holds fast, mocked unit tests. `tests/smoke/` holds smoke tests that hit a real Pi-hole instance (e.g. the `pihole/pihole` Docker container used in CI) via `PIHOLE_API_URL`/`PIHOLE_API_KEY`, so `bats tests` is no longer run as a whole — running the unit tests explicitly avoids accidentally picking up smoke tests that need a live Pi-hole to pass.
