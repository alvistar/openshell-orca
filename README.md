# openshell-orca

A workload image for running [Orca](https://github.com/stablyai/orca) server and its bots inside an [OpenShell](https://github.com/ai-openshell/openshell) sandbox, with Claude Code, Codex and gh.

```
ghcr.io/alvistar/openshell-orca:orca-<v>_claude-<v>_codex-<v>_<commit>
ghcr.io/alvistar/openshell-orca:latest
```

The image runs on linux/amd64 and linux/arm64 and is based on `nvcr.io/nvidia/base/ubuntu:24.04`, OpenShell's default. It does not contain OpenShell: the gateway injects its supervisor, so an OpenShell release needs no new image.

## Why it is shaped this way

- **One Orca server per sandbox.** An Orca bot is not a process of its own. Orca's runtime starts the agent and serves it hooks, MCP tools and the `orca` CLI on loopback, so the whole runtime (`orca serve`) runs in the sandbox, and the desktop Orca pairs with it as a remote server.
- **State lives in the workspace.** The user is `1500:1500` with `HOME=/sandbox`. Orca's pairing (`~/.config/orca`), its bots (`~/.orca`) and the agents' state are on the persistent workspace and survive an image update.
- **Binaries are fixed.** Claude Code, Codex and gh live in `/usr/local/bin`, owned by root, with self-update off. OpenShell's network rules match a binary's real path, and the agents must not replace their own binaries. The image is the release channel.
- **No credentials in the sandbox.** Providers on the gateway hold them; the sandbox sees only placeholders ([ADR 0001](docs/adr/0001-credentials-as-gateway-placeholders.md)).

## Layout

| Path | What it is |
|---|---|
| `Dockerfile`, `docker/` | The image. `docker/fetch` downloads and checks every binary; `docker/start-orca` is the sandbox command. |
| `scripts/resolve-versions` | Latest Orca server, Claude Code, Codex and gh releases with their SHA-256, as build arguments. |
| `scripts/update-sandbox` | Moves a stopped sandbox to another image, keeping its ID and workspace. |
| `providers/` | OpenShell provider profiles for Claude Code (subscription token) and Codex (ChatGPT login). |
| `policy/sandbox-policy.yaml` | Reference sandbox policy. |
| `.github/workflows/image.yml` | Image build, run by hand for now (`gh workflow run image`); the schedule is written but off. |

## Builds

The workflow reads the latest releases and builds a new image only when its tag does not exist yet, that is when Orca server, Claude Code or Codex has a new release, or when `main` has a new commit. Each build publishes both architectures under the exact tag and moves `latest`.

For now it runs only by hand: `gh workflow run image`. The triggers for a build every 6 hours and on every push to `main` are in the workflow, commented out.

Sandboxes never move on their own: an image update is a decision the operator takes with `scripts/update-sandbox`.

To build locally:

```sh
args=(); while IFS= read -r l; do args+=(--build-arg "$l"); done < <(scripts/resolve-versions)
docker build "${args[@]}" -t openshell-orca:local .
```

## Gateway settings

| Setting | Value | Why |
|---|---|---|
| `sandbox_uid` / `sandbox_gid` (Helm `server.sandboxUid` / `server.sandboxGid`) | `1500` | Kubernetes runs sandboxes as 1000 by default; the workspace files are owned by 1500. |
| `enable_sandbox_updates` (Helm `gatewayConfig."openshell.gateway".enable_sandbox_updates`) | `true` | Needed by `scripts/update-sandbox`. Read OpenShell's "Activate Sandbox Updates" first. |
| `persist_workspace` (Docker driver only) | `true` | On Kubernetes the workspace is always a PVC. |

## Credentials

Import both profiles once per gateway:

```sh
openshell profile import -f providers/claude-code-oauth.yaml
openshell profile import -f providers/codex.yaml
```

**Claude Code.** Make a token with `claude setup-token`. When the token wraps on screen, join the lines: a cut token fails with `401 OAuth access token is invalid`. Then:

```sh
CLAUDE_CODE_OAUTH_TOKEN=<token> openshell provider create --name claude --type claude-code-oauth --credential CLAUDE_CODE_OAUTH_TOKEN
```

**Codex.** Log in with a Codex home of its own, never your workstation's: OpenAI rotates refresh tokens, so two holders of one login log each other out.

```sh
export CODEX_HOME=$(mktemp -d)
codex login --device-auth
openshell provider create --name codex --type codex \
  --credential "CODEX_AUTH_ACCESS_TOKEN=$(jq -er .tokens.access_token "$CODEX_HOME/auth.json")" \
  --credential "CODEX_AUTH_ACCOUNT_ID=$(jq -er .tokens.account_id "$CODEX_HOME/auth.json")"
CODEX_AUTH_REFRESH_TOKEN=$(jq -er .tokens.refresh_token "$CODEX_HOME/auth.json") \
  openshell provider refresh configure codex --credential-key CODEX_AUTH_ACCESS_TOKEN \
    --strategy oauth2-refresh-token --material client_id=app_EMoamEEZ73f0CkXaXp7hrann \
    --secret-material-env refresh_token=CODEX_AUTH_REFRESH_TOKEN
openshell provider refresh rotate codex --credential-key CODEX_AUTH_ACCESS_TOKEN
rm -rf "$CODEX_HOME"
```

## Run a bot

```sh
openshell sandbox create --name my-bot \
  --from ghcr.io/alvistar/openshell-orca:<tag> \
  --policy policy/sandbox-policy.yaml \
  --no-auto-providers --provider claude --provider codex \
  --detach --restart-policy on-failure -- start-orca
openshell sandbox exec -n my-bot --no-login-shell -- sed -n 's/^Pairing URL: //p' /sandbox/serve.log
openshell forward start 16768 my-bot -d
```

Add the server in Orca (Settings → Remote Orca Servers) with the pairing URL, then create the bot there. `orca pair` inside the sandbox fails with `network_exposure_failed`: use the URL that `orca serve` prints at start. The server listens on 16768 (`ORCA_PORT`), because a desktop Orca already uses 6768.

## Update a bot's image

```sh
scripts/update-sandbox --gateway <gateway> my-bot ghcr.io/alvistar/openshell-orca:<tag> --forward 16768
```

It stops the sandbox, updates its image with `SandboxUpdates/UpdateSandbox` (there is no CLI command for this), starts it again and restarts the forward. It needs [uv](https://docs.astral.sh/uv/) and the `openshell` CLI logged in to the gateway.

## Development

The check command is `prek run --all-files && prek run --all-files --hook-stage manual` (tools from `mise.toml`). CI runs the same.

## License

MIT, see [LICENSE](LICENSE). Orca, Claude Code, Codex and gh keep their own licenses.
