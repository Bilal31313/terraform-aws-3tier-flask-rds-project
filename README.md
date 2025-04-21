# Terraform AWS 3‑Tier Flask + RDS Project

A fully automated, end‑to‑end AWS deployment built with Terraform. This repository spins up:

1. **VPC** with public & private subnets, Internet Gateway & NAT Gateway  
2. **EC2 instance** running a simple Flask web application  
3. **RDS PostgreSQL** database in the private subnet  
4. **Application Load Balancer (ALB)** distributing HTTP traffic to the Flask app  
5. **Security Groups** locking down each layer  

---

## 🚀 Features

- **Infrastructure as Code**: All AWS resources defined in `main.tf`  
- **3‑Tier Architecture**: Networking → Compute → Database  
- **Auto‑Scaling‑Ready**: Stateless Flask app behind an ALB  
- **Secure by Design**: Private subnets for RDS, least‑privilege SGs  
- **Easy Deployment**: `terraform init && terraform apply`  

---

## 📋 Repository Structure

terraform-3tier-flask-rds/ ├── main.tf # Terraform configuration ├── .gitignore # Ignore state, cache, logs ├── README.md # (You are here!) └── app/ └── app.py # Simple Flask app


---

## 🔧 Prerequisites

- Terraform (v1.0+) installed  
- AWS CLI configured with appropriate IAM credentials  
- Python 3 & `pip install flask psycopg2-binary` (for local testing)  

---

## ⚙️ Deployment

1. **Clone** this repo:  
   git clone https://github.com/Bilal31313/terraform-aws-3tier-flask-rds-project.git 


Initialize Terraform (downloads providers, sets up state):

terraform init
Preview the changes:

terraform plan
Apply to create all resources:

terraform apply
After apply completes, Terraform will output the ALB DNS name.
Copy it and open in your browser to see:

Hello from Terraform EC2 Flask App!
DB Version: PostgreSQL X.Y.Z ...
![image](https://github.com/user-attachments/assets/039bfff4-3636-4dde-9c91-369688205ce1)
![image](https://github.com/user-attachments/assets/6e03dbed-58a2-4df1-93d4-e7a38644c1d7)

Architecture Diagram
                      ┌─────────────────────────┐
                      │       Internet          │
                      └────────────┬────────────┘
                                   │ HTTP
                                   ▼
                      ┌─────────────────────────┐
                      │  Application Load       │
                      │       Balancer          │
                      │   (Public Subnets)      │
                      └────────────┬────────────┘
                                   │ Forward to port 5000
                                   ▼
       ┌─────────────────────────────────────────────────┐
       │                     VPC                        │
       │ ┌────────────┐       ┌──────────────────────┐  │
       │ │ Public     │       │  Private             │  │
       │ │ Subnet AZ‑A│       │  Subnet AZ‑A         │  │
       │ │            │       │                      │  │
       │ │  ┌───────┐ │       │   ┌───────────────┐  │  │
       │ │  │ ALB   │ │──────▶│   │ EC2 Flask App │  │  │
       │ │  └───────┘ │       │   └───────────────┘  │  │
       │ └────────────┘       │                      │  │
       │       ▲              │   ┌───────────────┐  │  │
       │       │              │──▶│ RDS PostgreSQL│  │  │
       │   Health Checks      │   └───────────────┘  │  │
       │                      │                      │  │
       │    (AZ‑B mirrored)   │    (AZ‑B mirrored)   │  │
       └─────────────────────────────────────────────────┘

🧼Clean up 
Destroy your Terraform‑managed AWS resources
In the same directory where you ran terraform apply (your main.tf lives):

cd ~/terraform-3tier-app
terraform destroy
– Terraform will show you a plan of everything it will delete.
– Type yes when prompted, or run terraform destroy -auto-approve to skip confirmation.

This will delete your VPC, subnets, IGW, NAT gateway, security groups, EC2 instance, ALB, target group, listener, RDS subnet group & RDS instance.
📄 License & Author
Author: Bilal Khawaja
LinkedIn: https://linkedin.com/in/bilal-khawaja-65b883243
