from flask import Flask
import os
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

# ------------------------------------------------------------------
# Helper: open a one‑shot connection using env‑supplied credentials
# ------------------------------------------------------------------
def get_db_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),          # e.g. terraform‑postgres-db.xxxxxx.eu-west-2.rds.amazonaws.com
        database="postgres",
        user="postgresadmin",
        password=os.getenv("DB_PASSWORD"),
        cursor_factory=RealDictCursor,
    )

# ------------------------------------------------------------------
# Routes
# ------------------------------------------------------------------
@app.route("/")
def index():
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT version();")
            version = cur.fetchone()["version"]
    return f"Hello from Terraform EC2 Flask App!<br>Postgres version: {version}"

# ------------------------------------------------------------------
# Entrypoint
# ------------------------------------------------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
