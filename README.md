# Contact Form App

A simple contact form web application: visitors submit their name, email, and a
message, which is stored in PostgreSQL. Submissions are never displayed back
to anyone (not even the submitter) — the app only ever shows a generic
confirmation message, and stored data is viewable only by querying the
database directly.

## Tech stack

- **Application:** Python 3.11, Flask, served by Gunicorn
- **Database:** PostgreSQL 16
- **Container:** Docker (non-root user, read-only root filesystem)
- **Testing:** pytest, ruff (lint)
- **Infrastructure:** Terraform (AWS: VPC, EKS, RDS, ALB, Secrets Manager, IAM, Security Hub/Config/CloudTrail)
- **Deployment:** Ansible (Kubernetes manifests, AWS Load Balancer Controller, Secrets Store CSI Driver)
- **CI:** GitHub Actions (lint, tests, dependency audit, secret scanning, Docker build, Terraform validation, Ansible lint)

## Running it locally

Requires Docker Desktop.

1. **Copy the environment template and fill in values:**
   ```bash
   cp .env.example .env
   cp app/.env.example app/.env
   ```

2. **Start the app and database:**
   ```bash
   docker compose up -d --build
   ```

3. **Open the app:**
   ```
   http://localhost:5000
   ```

4. **Check it's healthy:**
   ```bash
   curl http://localhost:5000/healthz
   ```

### Running tests

```bash
cd app
python -m venv .venv
.venv/Scripts/activate   # Windows; use source .venv/bin/activate on macOS/Linux
pip install -r requirements-dev.txt
pytest
```

### Stopping

```bash
docker compose down
```

---

## AWS deployment

This app also runs on AWS — EKS, RDS, behind an Application Load Balancer —
provisioned entirely with Terraform and deployed with Ansible, both run from
a local workstation.

The app's production domain is `contactkhama.com`, secured with a real,
publicly-trusted, DNS-validated ACM certificate.

**Live URL:** the AWS environment is torn down at the
end of each working session to avoid idle cost, and rebuilt at the start of
the next — so `contactkhama.com` is only live while the environment is
actively up. It will be kept running continuously in the days leading up to
the live demonstration.
