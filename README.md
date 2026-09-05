# interkid.openrockets.com

Interkid is a custom SearXNG-powered metasearch experience for OpenRockets.

The root page is intentionally only the full-screen Interkid search hero. It preserves the visual treatment from the previous Interkid page (Google Sans Flex / Outfit typography, non-selectable wordmark, and the original YouTube background) while sending searches directly to the self-hosted SearXNG `/search` endpoint.

## Architecture

- **SearXNG** provides metasearch and result pages.
- **Custom `index.html`** replaces SearXNG's default home template.
- **Simple/light SearXNG theme** keeps result pages white.
- **Safe Search = 1** is the default.
- **Image proxying** is enabled.
- **Docker Compose** adds Valkey and enables SearXNG's limiter for a public deployment.
- **Single-container deployment** also works; the limiter stays off unless a Valkey URL is supplied.

## Run locally with Docker Compose

```bash
cp .env.example .env
openssl rand -hex 32
# Put the generated value in SEARXNG_SECRET inside .env

docker compose up --build
```

Open `http://localhost:8080`.

## Single-container deployment

Build the included `Dockerfile` and expose port `8080`.

Set these environment variables in the hosting platform:

- `SEARXNG_BASE_URL=https://interkid.openrockets.com/`
- `SEARXNG_SECRET=<a stable random secret>`

The entrypoint creates a temporary random secret if `SEARXNG_SECRET` is not set, so the service can still boot for previews. For production, use a stable secret.

## Production notes

For a public instance, prefer the Compose deployment (or equivalent separate Valkey service) and set:

- `SEARXNG_LIMITER=true`
- `SEARXNG_VALKEY_URL=valkey://<valkey-host>:6379/0`

SearXNG aggregates results from external search engines; it does not crawl and maintain its own full-web index.

## Rollback

The site that existed before the SearXNG conversion is preserved in:

`legacy-site-backup-2026-09-05`
