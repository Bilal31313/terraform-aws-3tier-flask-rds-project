from flask import Flask
import psycopg2

app = Flask(__name__)

def get_db_connection():
    conn = psycopg2.connect(
        host="terraform-postgres-db.ctggoqecgawg.eu-west-2.rds.amazonaws.com",
        database="postgres",
        user="postgresadmin",
        password="MySecurePassword123!"
    )
    return conn

@app.route('/')
def hello():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('SELECT version();')
    db_version = cur.fetchone()
    cur.close()
    conn.close()
    return f'Hello from Terraform EC2 Flask App!<br>DB Version: {db_version[0]}'

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
