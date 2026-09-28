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

---

## Deploying to your own AWS account

### Prerequisites

- An AWS account with billing enabled
- [AWS CLI v2](https://aws.amazon.com/cli/), configured with credentials for an IAM user with sufficient permissions to create the resources below (see Step 1)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.16
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- A Linux shell for running Ansible (WSL2 + Ubuntu on Windows, or native on macOS/Linux), with Python 3.12+, `pip`, and [Helm](https://helm.sh/docs/intro/install/)
- `kubectl`
- **A domain name you own and control DNS for.** The ALB uses a real, publicly-trusted, DNS-validated ACM certificate — there is no self-signed fallback in this configuration. Register one (e.g. via Cloudflare, Namecheap, or any registrar) before starting.

### Step 1: Bootstrap AWS credentials (one-time, manual)

This is the one deliberate exception to "no manual console steps" — every Terraform run needs some initial credential to authenticate with, and that first credential cannot itself be created by Terraform.

1. In the AWS Console, go to **IAM → Users → Create user** (e.g. name it `<your-project>-terraform`)
2. Attach the `AdministratorAccess` policy
3. Go to the new user → **Security credentials → Create access key** → choose "Command Line Interface (CLI)"
4. Run `aws configure` and enter the generated Access Key ID, Secret Access Key, and your preferred region (e.g. `ap-southeast-1`)

### Step 2: Bootstrap the Terraform state backend

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

Note the `state_bucket_name` and `lock_table_name` outputs, then **edit `terraform/versions.tf`** and replace the hardcoded backend values with your own bootstrap output (Terraform backend blocks can't reference variables, so this is a manual edit):

```hcl
backend "s3" {
  bucket         = "<your-state-bucket-name-from-step-2>"
  key            = "contactform/terraform.tfstate"
  region         = "<your-region>"
  dynamodb_table = "<your-lock-table-name-from-step-2>"
  encrypt        = true
}
```

### Step 3: Configure your variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
domain_name      = "<your-domain.com>"
api_access_cidrs = ["<your-public-ip>/32"]  # find it: curl https://checkip.amazonaws.com
```

### Step 4: Provision the infrastructure

```bash
terraform init
terraform apply
```

Takes 15-20 minutes (EKS and RDS dominate). Note the `acm_validation_record` output, then add it as a CNAME record at your domain's DNS provider to validate the certificate. Confirm it's issued before continuing:

```bash
aws acm describe-certificate --certificate-arn "$(terraform output -raw alb_certificate_arn)" --query Certificate.Status
```

### Step 5: Build and push the application image

```bash
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin "${ECR_URL%%/*}"
docker build --provenance=false --sbom=false -t "$ECR_URL:v1" app
docker push "$ECR_URL:v1"
```

If your tag isn't `v1`, update `app_image_tag` in `ansible/roles/app/defaults/main.yml` to match.

### Step 6: Connect kubectl to the new cluster

```bash
aws eks update-kubeconfig --region <your-region> --name <your-eks-cluster-name>
```

Run this in whichever shell you'll run Ansible from (WSL2, if you're on Windows — `kubectl` context isn't shared between Windows and WSL, so if you also want to run `kubectl` commands directly from Windows PowerShell, run the same command there too).

Verify:
```bash
kubectl get nodes
```

### Step 7: Deploy with Ansible

```bash
cd ansible
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
```

Ansible reads the Terraform outputs directly:

```bash
cd ../terraform
terraform output -json > ../ansible/terraform_outputs.json
cd ../ansible
ansible-playbook site.yml
```

This installs the AWS Load Balancer Controller, the Secrets Store CSI Driver, and deploys the app + Ingress. Note the ALB hostname it prints at the end (or fetch it with `kubectl get ingress`).

### Step 8: Point your domain at the ALB

At your DNS provider, add a CNAME (or ALIAS/ANAME if your provider supports it at the apex) record:

```
<your-domain.com>  →  <alb-hostname-from-step-7>.elb.amazonaws.com
```

Make sure the record is **not proxied** if your DNS provider offers a proxy/CDN option (e.g. Cloudflare's orange cloud) — it must resolve directly to the ALB, otherwise the provider will try to terminate TLS itself instead of passing through to your ACM certificate.

### Step 9: Verify

```bash
curl https://<your-domain.com>/healthz
```

Submit the form in a browser, then confirm it landed in the database:

```bash
kubectl exec -it deploy/contactform-app -- python -c "
import os, psycopg2
conn = psycopg2.connect(
    host=os.environ['DB_HOST'],
    port=os.environ.get('DB_PORT', '5432'),
    dbname=os.environ['DB_NAME'],
    user=os.environ['DB_USER'],
    password=os.environ['DB_PASSWORD'],
)
cur = conn.cursor()
cur.execute('SELECT id, name, email, message, created_at FROM submissions ORDER BY id DESC LIMIT 5;')
for row in cur.fetchall():
    print(row)
"
```

### Tearing down

To avoid ongoing cost when you're done:

```bash
kubectl delete ingress --all   # detaches the ALB before Terraform destroys it
cd terraform
terraform destroy
```

The bootstrap S3 bucket/DynamoDB table from Step 2 are cheap to leave running (pennies/month) if you plan to redeploy later; destroy them too via `terraform/bootstrap` if you want a full teardown.
