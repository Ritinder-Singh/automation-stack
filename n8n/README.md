# n8n Custom Image

This directory defines a custom n8n image with preinstalled Node.js modules.

## Why a custom image?

- Avoid runtime `npm install`
- Ensure reproducible environments
- Keep workflows deterministic
- Improve startup performance

## How it works

- Extends the official `n8nio/n8n` image
- Installs dependencies from `package.json`
- Exposes them to n8n via `NODE_PATH`

## Adding new modules

1. Edit `package.json`
2. Add the dependency
3. Rebuild the image (later)
4. Restart n8n

No changes to workflows required.

## Notes

- Do not install devDependencies
- Keep the dependency list small
- Prefer stable, well-maintained packages
