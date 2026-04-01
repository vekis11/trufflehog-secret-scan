<div align="center">

# TruffleHog Secret Scan Lab

**End-to-end reference for shipping a small API with Docker, Nginx, Terraform, and split CI/CD pipelines that treat secret scanning as a first-class gate.**

[![Stack](https://img.shields.io/badge/stack-FastAPI_%7C_Nginx_%7C_Docker-009688?style=flat-square)](https://fastapi.tiangolo.com/)
[![IaC](https://img.shields.io/badge/IaC-Terraform_%28Docker_provider%29-7B42BC?style=flat-square)](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
[![CI](https://img.shields.io/badge/CI-GitHub_Actions-2088FF?style=flat-square)](https://github.com/features/actions)
[![TruffleHog](https://img.shields.io/badge/secrets-TruffleHog-00C853?style=flat-square)](https://github.com/trufflesecurity/trufflehog)
[![detect-secrets](https://img.shields.io/badge/secrets-Yelp_detect--secrets-FF6B6B?style=flat-square)](https://github.com/Yelp/detect-secrets)

</div>

---

## Table of contents

- [Why this project exists](#why-this-project-exists)
- [What was implemented](#what-was-implemented)
- [Architecture at a glance](#architecture-at-a-glance)
- [Repository layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Run locally](#run-locally)
- [CI/CD pipelines](#cicd-pipelines)
- [Secret scanning behavior](#secret-scanning-behavior)
- [Optional: `.secrets.baseline` for local use](#optional-secretsbaseline-for-local-use)
- [Security and ethics](#security-and-ethics)

---

## Why this project exists

Modern teams leak credentials through **config files, env snippets, and copy-pasted examples** long before production. Regulators and security programs expect **automated secret detection** in CI—not a one-off manual audit.

This repository is a **deliberately small but complete vertical slice** that shows how to:

1. Run a real HTTP service (**FastAPI**) behind **Nginx** in **Docker**.
2. Describe the same stack with **Terraform** using the **Docker provider** (no cloud bill required—only a local Docker engine).
3. Wire **GitHub Actions** so **build, test, IaC validation, and secret scanning** are separate, observable stages.
4. Run **two scanners in parallel CI workflows**—**TruffleHog** (broad detectors, optional verification) and **Yelp detect-secrets** (plugin-based static scan)—each performing a **full-repository** pass with **no baseline allowlist** in Actions, so anything that looks like a leaked credential fails the job unless you remove or relocate the material.

It is suitable as a **template**, **training repo**, or **proof of concept** for “secure SDLC” discussions.

---

## What was implemented

### Application layer

| Item | Description |
|------|-------------|
| **FastAPI service** | `app/main.py` exposes `/` and `/health` for liveness checks and simple smoke testing. |
| **Container image** | `app/Dockerfile` builds a slim Python 3.12 image, installs dependencies, and runs **Uvicorn** on port `8000`. |
| **Automated tests** | `app/tests/test_main.py` uses **pytest** and **httpx** `TestClient` for fast unit-level API checks—no live server required. |
| **Dependency splits** | `app/requirements.txt` for runtime; `app/requirements-dev.txt` pulls runtime + **pytest** + **httpx** for CI and local dev. |

### Edge and orchestration

| Item | Description |
|------|-------------|
| **Nginx reverse proxy** | `nginx/default.conf` terminates HTTP on port 80 inside the proxy container and forwards to the app upstream (`app:8000` in Compose; Terraform assigns the **network alias `app`** so the same config works). |
| **Docker Compose** | `docker-compose.yml` defines **app** (build + healthcheck) and **nginx** (published **8080→80**), with `depends_on` tied to app health. |
| **Terraform on Docker** | Under `terraform/`: `versions.tf` pins the **kreuzwerker/docker** provider; `main.tf` builds the app image, creates a user-defined network, runs the app container with a healthcheck, and runs Nginx with the config volume-mounted. `variables.tf` / `outputs.tf` expose naming and the public URL hint. |

### CI/CD (GitHub Actions)

All workflows live under `.github/workflows/` and use **least-privilege** `contents: read` where applicable.

| Workflow file | What it does |
|---------------|----------------|
| **`ci.yml`** | **Continuous integration**: checkout → Python 3.12 + pip cache → install `requirements-dev.txt` → **`pytest`** → **Docker Buildx** build of the app image (cache backed by **GitHub Actions cache**), **no registry push** (fits free-tier and lab use). |
| **`terraform.yml`** | **IaC gate** (runs when `terraform/**` changes): **HashiCorp setup-terraform** → **`terraform fmt -check`** → **`terraform init -backend=false`** → **`terraform validate`**. Keeps modules syntactically correct without needing cloud credentials. |
| **`trufflehog.yml`** | **Dedicated secret scan #1**: **TruffleHog** container runs **`filesystem .`** from the repo root with **`--fail`** and **GitHub Actions** annotations—**entire tree**, including **`samples/unsafe-fixtures/`**. |
| **`detect-secrets.yml`** | **Dedicated secret scan #2**: **Yelp detect-secrets** (**1.5.0**) runs **`scan --all-files --force-use-all-plugins`** over the repo; if **`results`** is non-empty, the job **fails** and uploads **`detect_secrets_report.json`** as an artifact. Only **`.git/`**, caches, and **`.secrets.baseline`** (self-referential noise) are excluded from the scan path. |

Together, this implements a **split pipeline** pattern: build/test and IaC validation do not run inside the same job graph as TruffleHog or detect-secrets, so failures are **easier to attribute** and **permissions can evolve independently** (for example, stricter rules on secret scanners later).

### Deliberate “bad” fixtures (for scanner demos)

| Path | Role |
|------|------|
| **`samples/unsafe-fixtures/demo_database.yaml`** | Synthetic YAML resembling **database credentials**, **AWS-style keys** (including documented example-style material), **GitHub PAT-shaped** strings, **email/password** fields, **Stripe test key**, **Slack webhook** URL. |
| **`samples/unsafe-fixtures/legacy_config.py`** | Same idea in Python constants: AWS-shaped keys, **GitLab**/**Azure DevOps**-style tokens, DB user/password, contact emails. |
| **`.secrets.baseline`** | Historical **detect-secrets** snapshot (optional). **CI no longer uses it for pass/fail**; keep it for local experiments or migrate to a baseline-based policy if you soften the pipeline later. |

> These files exist **only** to exercise scanners and training scenarios. They must **never** hold real secrets.

---

## Architecture at a glance

```mermaid
flowchart LR
  subgraph Client
    U[Browser / curl]
  end
  subgraph Docker_host
    N[Nginx :8080]
    A[FastAPI :8000]
  end
  subgraph CI_GitHub_Actions
    CI[CI: test + image build]
    TF[Terraform: fmt + validate]
    TH[TruffleHog workflow]
    DS[detect-secrets workflow]
  end
  U --> N
  N --> A
  CI --> A
  TH -->|full repo| Docker_host
  DS -->|full repo| Docker_host
```

**Runtime data path:** outside traffic hits **Nginx** on the host-mapped port; Nginx proxies to the **app** container. **Terraform** and **Compose** are two ways to create that same logical topology on a single machine.

---

## Repository layout

```text
.
├── app/
│   ├── Dockerfile
│   ├── main.py
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   └── tests/
│       └── test_main.py
├── nginx/
│   └── default.conf
├── terraform/
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
├── samples/
│   └── unsafe-fixtures/          # synthetic “leaks” for demos only
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── terraform.yml
│       ├── trufflehog.yml
│       └── detect-secrets.yml
├── .secrets.baseline             # Yelp detect-secrets baseline
├── docker-compose.yml
└── README.md
```

---

## Prerequisites

- **Docker Desktop** (or any Docker Engine) for Compose and for Terraform’s Docker provider.
- **Python 3.12+** if you run tests or regenerate the baseline locally.
- **Terraform ≥ 1.5** on your PATH if you run `terraform` locally (CI installs its own).
- A **GitHub** remote if you want Actions to execute (public repos fit common free-tier CI usage).

---

## Run locally

### Option A — Docker Compose (fastest)

```powershell
docker compose up --build
```

Then open: `http://localhost:8080/health`

### Option B — Terraform (same stack, declarative)

```bash
cd terraform
terraform init
terraform apply
```

Default **Nginx** host port is **8080** (see `terraform/variables.tf` and outputs).

---

## CI/CD pipelines

| Trigger (typical) | Workflows involved |
|-------------------|--------------------|
| Push / PR to `main` (app code) | **`ci.yml`** |
| Push / PR touching `terraform/**` | **`terraform.yml`** (path-filtered) |
| Push / PR (secret posture) | **`trufflehog.yml`**, **`detect-secrets.yml`** |

**Design choice:** TruffleHog and detect-secrets are **not** folded into `ci.yml` so you can:

- rerun or tune scanners without rebuilding images,
- assign different failure policies per tool,
- mirror how organizations onboard **AppSec-owned** workflows separately from **platform** build jobs.

---

## Secret scanning behavior

Both workflows are configured for **maximum coverage of the checked-out tree** (not a path allowlist). With the included **`samples/unsafe-fixtures/`** demo files, **expect both jobs to fail** until you delete those fixtures, move them out of the repo, or replace this policy with something softer (for example baseline-based detect-secrets or path excludes).

### TruffleHog (`trufflehog.yml`)

- **Triggers:** `push` / `pull_request` to `main`, plus **`workflow_dispatch`** for manual reruns.
- **Command shape:** `trufflehog filesystem . --fail --no-update --github-actions` inside the official image, volume-mounted at the repository root (`fetch-depth: 0` checkout so git metadata is available if the tool consults it).
- **Outcome:** any detector hit fails the workflow (exit per TruffleHog’s **`--fail`** semantics).

### Yelp detect-secrets (`detect-secrets.yml`)

- **Scan:** `detect-secrets scan --all-files --force-use-all-plugins` over **`.`**, excluding **`.git/`**, **`.pytest_cache`**, **`__pycache__`**, and **`.secrets.baseline`** (that file’s hashed fields otherwise create circular noise).
- **Outcome:** JSON report is written to **`detect_secrets_report.json`**; if **`results`** contains any file entries, the step **exits with code 1**. On failure, the workflow uploads **`detect-secrets-report`** as a **GitHub Actions artifact** for triage.

---

## Optional: `.secrets.baseline` for local use

CI does **not** gate on the baseline anymore. You can still generate one for **local** pre-commit hooks or experiments:

```bash
pip install "detect-secrets==1.5.0"
detect-secrets scan --all-files \
  --exclude-files '\.secrets\.baseline' \
  --exclude-files '\.pytest_cache' \
  --force-use-all-plugins > .secrets.baseline
detect-secrets audit .secrets.baseline   # optional interactive review
```

---

## Security and ethics

- **Never** replace synthetic values in `samples/unsafe-fixtures/` with real API keys, passwords, or tokens.
- A **strict full-repo scan** will stay red while deliberate “bad” fixtures remain in-tree; that is intentional if you want a **zero-tolerance** signal. For training-only content, use a **separate branch**, **submodule**, or **artifact** not scanned by CI.
- This repo is a **lab**: production systems should combine secret scanning with **pre-commit hooks**, **private scanning** for monorepos, **vaults/KMS**, and **short-lived credentials**—this project illustrates **one slice** of that story (CI detection + dual tools), not the whole security program.

---

<div align="center">

**Built as a practical reference for Docker + Nginx + Terraform + GitHub Actions + TruffleHog + detect-secrets.**

</div>
