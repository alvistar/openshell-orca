# 1. Agent credentials stay on the gateway; the sandbox holds placeholders

Date: 2026-11-26. Status: accepted.

## Context

A bot runs Claude Code and Codex with the owner's subscriptions. Whatever the agent can read, a prompt injection can send elsewhere. The first spike passed `CLAUDE_CODE_OAUTH_TOKEN` as a plain environment variable, readable by the agent. OpenShell's stock Claude Code profile takes only an API key, billed per token.

## Decision

Both agents get their credentials from OpenShell providers. The sandbox sees only credential placeholders; the gateway's proxy puts the real value in the request, and only for the profile's hosts and binaries.

- Claude Code: the custom profile `providers/claude-code-oauth.yaml` injects a subscription token from `claude setup-token` as `Authorization: Bearer`. The token lasts a year and has no refresh.
- Codex: `providers/codex.yaml` with a ChatGPT login of its own. The gateway holds the refresh token and refreshes the access token; the sandbox's `auth.json` has no refresh token.

## Consequences

- The agent can still use the credentials through the allowed binaries, but cannot read them or use them from anywhere else.
- Claude Code works with a placeholder only because it does not check the token's shape locally (tested 2026-11-26, Claude Code 2.1.332). A release that adds such a check breaks every bot until the profile changes or an API key replaces the token.
- Each gateway needs its own Codex login: the workstation's login cannot be shared, because OpenAI rotates refresh tokens.

## Alternatives

- Token in the environment: simplest, but the agent can read and exfiltrate it.
- API keys through OpenShell's stock profiles: same isolation, billed per token instead of the subscription.
