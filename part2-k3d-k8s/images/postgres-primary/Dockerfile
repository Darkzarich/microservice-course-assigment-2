FROM postgres:16
ENV POSTGRES_DB=appdb POSTGRES_USER=app POSTGRES_PASSWORD=app
COPY init/ /docker-entrypoint-initdb.d/
