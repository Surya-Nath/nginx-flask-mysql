# week2-nginx-flask-mysql

N-tier lab: **Nginx → Flask → MariaDB**.

## Architecture

| Service | Image / build | Internal | Published on host | Talks to |
|---|---|---|---|---|
| `proxy` | `./proxy` → ECR `week2-nginx` | 80 | **80** | `backend:8000` (frontnet) |
| `backend` | `./backend` → ECR `week2-flask` | 8000 | none | `db:3306` (backnet) |
| `db` | `mariadb:10-focal` (not built) | 3306 | none | volume `db-data` |

```
browser :80
  → proxy (nginx 1.27, user-facing)
  → http://backend:8000     [frontnet]
  → Flask hello.py (USER app)
  → host db, secret file    [backnet]
  → MariaDB + named volume db-data
```

`db` is not on `frontnet`. `3306` and `8000` are expose-only.

## Request path (why not localhost)

- Nginx `proxy_pass http://backend:8000` — Compose DNS name, not `127.0.0.1`.
- Flask `host="db"` — `localhost` inside the Flask container is Flask itself.
- DB healthcheck uses `127.0.0.1` **on purpose**: that command runs *inside* the db container.

## Local

```bash
https://github.com/Surya-Nath/nginx-flask-mysql.git
cd nginx-flask-mysql
docker compose up --build -d
curl -s localhost:80
docker compose ps
docker compose down          # keeps db-data
docker compose down -v       # wipes posts
```

Expect four `Hello Blog post #N` lines. Host should listen on `:80` only.

`db/password.txt` is a lab secret. Do not reuse it outside this repo.

## Image decisions

**backend**

- `python:3.10-alpine`
- `requirements.txt` before `hello.py` (pip layer cache)
- `Werkzeug==2.0.3` pinned — Flask 2.0.1 breaks on Werkzeug 3 (`url_quote` removed)
- non-root `USER app`
- no `dev-envs` / VS Code stage
- `PYTHONDONTWRITEBYTECODE` + `PYTHONUNBUFFERED`

**proxy**

- `nginx:1.27-alpine` (sample was 1.13)
- conf: `proxy_pass http://backend:8000` plus `Host` / `X-Forwarded-*` / timeouts

Official MariaDB is never built or pushed to ECR.

## Compose decisions

- `depends_on: condition: service_healthy` — wait for `mysqladmin ping`, not a `sleep 30`
- named volume `db-data:/var/lib/mysql`
- `restart: unless-stopped`
- published port: **80 only**

Prod file is `compose.prod.yaml`: `image:` from ECR, no `build:`.

### Non-root Flask + Compose secrets

Docker Compose on Ubuntu 24 ignored `secrets.mode`. Default mount was `0600` root/1000. Process `app` got `PermissionError` on `/run/secrets/db-password` (HTTP 500).

Prod workaround: bind-mount the password file so the app user can read it.

```yaml
# backend in compose.prod.yaml
volumes:
  - ./db/password.txt:/run/secrets/db-password:ro
```

`db` still uses the Compose secret (`MYSQL_ROOT_PASSWORD_FILE`); that process starts as root.

## CI

Push `main`:

- GitHub Actions `.github/workflows/build-push.yml`
- Jenkinsfile (same stages, one controller reused from week 1)

Both build `./backend` and `./proxy`, tag `:SHA` and `:latest`, push:

- `413816840602.dkr.ecr.ap-south-1.amazonaws.com/week2-flask`
- `413816840602.dkr.ecr.ap-south-1.amazonaws.com/week2-nginx`

Never push MariaDB.

GitHub secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`. Jenkins credential ID `aws-cli`.

## AWS (default VPC only)

`tf-lab/` creates one `t3.micro` in the default VPC, reuses SG `devops-lab-sg` (22 from the jump host, 80 from the world, no 3306). Instance profile `ecr-pull-role` (ECR pull, no long-lived keys on the box).

`ansible-lab/` installs Docker + AWS CLI v2, copies `compose.prod.yaml` + password file, ECR login, `compose pull && up`, curls `localhost:80`.

```bash
cd tf-lab
terraform init
terraform plan -out=tfplan
terraform apply tfplan          # copy public_ip into ansible-lab/inventory.ini

cd ../ansible-lab
ansible-playbook -i inventory.ini site.yml

curl -sI http://<public_ip>/
# 3306 must fail from the internet

terraform destroy               # same day
```

Jump/Jenkins box is separate. Stop it at night; do not terminate every lab day if you still need the controller.

## Failures worth remembering

1. Flask 2.0.1 + unpinned Werkzeug → `cannot import name url_quote` → backend restart loop → Nginx 502.
2. Wrong / rotated password file vs existing `db-data` volume → healthcheck ping fails (datadir keeps the old root password).
3. `docker compose stop db` → app 502 / “can't connect to db”; `depends_on` does not watch runtime.
4. `compose down -v` deletes `db-data`.
5. Host port 80 already taken → proxy bind error.
6. Ansible `command:` does not run a shell — `docker compose pull && up -d` parsed `-d` as a flag on `pull`.
7. Ubuntu 24.04 has no `awscli` apt package — install AWS CLI v2.
8. Non-root + Compose secrets permissions → 500 (see above).

## Logic answers

- Flask uses hostname `db` because Compose DNS is per-network; `localhost` is the Flask container.
- A named volume survives `compose down` and container replace. The container writable layer does not. `down -v` removes the volume.
- `sleep 30` is a bad healthcheck: too short on a slow boot, wasted time on a fast one, and it never checks that mysqld accepts queries.
- Who may use 3306: only containers on `backnet` (Flask). Not the proxy, not the host, not the internet.
- `compose down` vs `down -v`: containers gone vs containers + named volumes gone.

## Layout

```
backend/          Dockerfile, hello.py, requirements.txt
proxy/            Dockerfile, conf
db/password.txt   lab only
compose.yaml      local build
compose.prod.yaml ECR images
.github/workflows/build-push.yml
Jenkinsfile
tf-lab/           default VPC + EC2
ansible-lab/      one playbook
```
