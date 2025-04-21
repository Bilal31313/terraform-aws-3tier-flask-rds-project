# Terraform AWS 3‑Tier Flask + RDS Project
# Terraform AWS **3‑Tier Flask + RDS** Project

A fully automated deployment of a classic 3‑tier web stack:

| Layer | AWS services | What Terraform builds |
|-------|--------------|-----------------------|
| **Networking** | VPC · public / private subnets · IGW · NAT GW | Public ALB, private app & DB tiers |
| **Compute** | EC2 (Ubuntu 22.04) · Application Load Balancer | Stateless Flask app served on **port 5000** |
| **Data** | Amazon RDS PostgreSQL (private subnet) | Password injected at boot—never hard‑coded |

---

## 🚀 Highlights

* **Infrastructure as Code** – every resource lives in `main.tf`; no console drift.  
* **Secure by design** – ALB SG open on 80; EC2 SG only accepts **5000** from the ALB SG; RDS SG accepts 5432 only from EC2 SG.  
* **Idempotent & reproducible** – `terraform fmt ‑check`, pinned provider (`aws ~> 5.0`).  
* **Secrets handled correctly** – `db_password` supplied via a `*.tfvars` file (git‑ignored) or AWS Secrets Manager, then passed to the app as environment variables.  

---

## 📂 Repository structure
terraform-aws-3tier-flask-rds-project/ ├── main.tf # All AWS resources ├── app/ │ └── app.py # Flask + psycopg2 demo app ├── .gitignore # Ignores state, plans, secrets, IDE files └── README.md

---

## 🔧 Prerequisites

* Terraform ≥ 1.6.0  
* AWS CLI configured (`aws configure`) with an IAM user / role that can create VPC‑level resources  
* A `*.tfvars` file **not committed to Git**:

  ```hcl
  db_password = "ReplaceWithA12$trongP@ss"
git clone https://github.com/Bilal31313/terraform-aws-3tier-flask-rds-project.git
cd terraform-aws-3tier-flask-rds-project

⚙️ Deployment

terraform init          # downloads AWS provider
terraform plan          # shows the execution plan
terraform apply         # creates ~30 resources in eu‑west‑2
echo "http://$(terraform output -raw alb_dns_name)"

🌐 Expected output
Hello from Terraform EC2 Flask App!
Postgres version: PostgreSQL 13.15 on x86_64-pc-linux-gnu, compiled by gcc ...

![image](https://github.com/user-attachments/assets/039bfff4-3636-4dde-9c91-369688205ce1)
![image](https://github.com/user-attachments/assets/6e03dbed-58a2-4df1-93d4-e7a38644c1d7)

🏗️ Architecture diagram
                ┌─────────────┐
                │  Internet   │
                └─────┬───────┘
                      │ :80
                      ▼
         ┌────────────────────────────┐
         │   Application Load Balancer│  (public subnets)
         └──────────┬─────────────────┘
            forward │:80 → :5000
                      ▼
         ┌────────────────────────────┐
         │   EC2 Flask App (port 5000)│  (private subnet)
         └──────────┬─────────────────┘
            connect │:5432
                      ▼
         ┌────────────────────────────┐
         │  RDS PostgreSQL (private)  │
         └────────────────────────────┘
Why port 5000 inside?
Flask’s default port is 5000, which keeps the example minimal—no extra reverse‑proxy layer. The ALB still exposes port 80 externally

🔗 How the app connects to RDS
Terraform provides the RDS endpoint (aws_db_instance.postgres.address) and db_password to the EC2 instance via user_data.

The startup script sets:
export DB_HOST="<actual-endpoint>"
export DB_PASSWORD="<password-from-tfvars-or-secrets-manager>"
app.py reads those env vars and opens a psycopg2 connection—no credentials in Git or instance metadata.

🧹 Clean‑up
terraform destroy

📄 Author
Bilal Khawaja
https://linkedin.com/in/bilal-khawaja-65b883243 
