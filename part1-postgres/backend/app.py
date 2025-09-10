
from flask import Flask
import os
import psycopg2

app = Flask(__name__)
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", 5432)
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASS = os.environ.get("DB_PASS", "postgres")
DB_NAME = os.environ.get("DB_NAME", "postgres")
BACKEND_ID = os.environ.get("BACKEND_ID", "unknown-backend")

@app.route("/health")
def health():
    return "OK", 200

@app.route("/data")
def data():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASS,
            dbname=DB_NAME
        )
        cur = conn.cursor()
        cur.execute("SELECT now(), inet_server_addr();")
        result = cur.fetchone()
        conn.close()

        response = {
            "timestamp": str(result[0]),
            "postgres_ip": result[1],
            "backend_id": BACKEND_ID
        }

        print(f"[{BACKEND_ID}] -> Connected to PostgreSQL at {result[1]}")
        return response, 200
    except Exception as e:
        print(f"[{BACKEND_ID}] ERROR -> {e}")
        return {"error": str(e)}, 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
