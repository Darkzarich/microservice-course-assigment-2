
from fastapi import FastAPI
import os
import socket
import psycopg2

app = FastAPI()

DB_HOST = os.getenv("DB_HOST", "haproxy")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_USER = os.getenv("DB_USER", "app")
DB_PASSWORD = os.getenv("DB_PASSWORD", "app")
DB_NAME = os.getenv("DB_NAME", "appdb")

@app.get("/health")
def health():
    return {"status": "OK", "pod": socket.gethostname()}

@app.get("/users")
def users():
    pod = socket.gethostname()
    try:
        conn = psycopg2.connect(
            host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, dbname=DB_NAME, connect_timeout=2
        )
        cur = conn.cursor()
        cur.execute("SELECT count(*) FROM users;")
        cnt = cur.fetchone()[0]
        cur.close()
        conn.close()
        return {"users": cnt, "pod": pod}
    except Exception as e:
        return {"error": str(e), "pod": pod}
