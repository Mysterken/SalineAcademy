# SalineAcademy

## Quickstart
 
Prerequisites:
  - Docker
  - make

Steps:
  - Run the following commands:

```shell
git clone git@github.com:Mysterken/SalineAcademy.git
cd SalineAcademy
cp .env.example .env
git submodule update --init --recursive
make start
```

## Development

Get a list of all available commands from make:

```shell
make help
```

---
Get all API endpoints from `https://localhost/api/docs`

---
Fix for common issues:

  - Permission issues: `docker compose run --rm php chown -R $(id -u):$(id -g) .`
  - Slow api response: If on windows, move the project to the WSL filesystem
