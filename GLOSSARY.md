# Glossary

**Workload image**: the container image a sandbox runs: Orca server, Claude Code, Codex and gh. It holds no OpenShell code; the gateway adds the supervisor.
_Avoid_: sandbox image, base image

**Gateway**: the OpenShell control plane that creates, stops, starts and updates sandboxes and holds provider credentials.

**Sandbox**: one isolated workload created by a gateway from a workload image, with its own workspace and policy. One sandbox runs one Orca server.

**Workspace**: the sandbox's `/sandbox` directory, kept across stop, start and image update; deleted with the sandbox. It is the sandbox user's home.

**Orca server**: the headless Orca runtime (`orca serve`) inside a sandbox, which a desktop Orca pairs with.

**Bot**: an Orca bot that lives on one Orca server and runs agents there.

**Pairing**: the trust between a desktop Orca and an Orca server, made once with the pairing URL; it survives an image update and is lost when the sandbox is deleted.

**Image update**: moving a stopped sandbox to another workload image while it keeps its ID and workspace.
_Avoid_: upgrade, redeploy

**Rollout**: the operator's decision to run an image update on a sandbox. Never automatic.

**Provider**: a gateway-side record that holds one credential and the hosts and binaries allowed to use it.

**Credential placeholder**: the opaque value (`openshell:resolve:env:...`) a sandbox sees instead of a credential; the gateway's proxy replaces it on the way out.
_Avoid_: token, secret (for what the sandbox holds)
