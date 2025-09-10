# Homework: Application resiliency (Part А, extended example for Postgres)

## Goal

Show resiliency on levels:

- Database (several PostgreSQL instances behind HAProxy)
- Application (several backend instances behind Nginx)

## System components

- PostgreSQL followers (2 instances without a leader)
- HAProxy (load-balancing for PostgreSQL followers)
- `backend1`, `backend2` (two instances of Python Flask-application that uses PostgreSQL)
- Nginx - balances `backend1` and `backend2` over HTTP
- `load-test/run.sh` - sends requests generating load to the application to "/data" endpoint

## How to run

```bash
$ docker-compose up -d --build
$ ./load-test/run.sh
```

## Steps

### А) Shutting down a PostgreSQL follower

1. Run the script to generate load:

```bash
$ ./load-test/run.sh
```

2. Imitate the failure of one follower:

```bash
$ docker kill postgres-slave1
```

3. Notice, the system continues to work through the second follower. To restore the node, you can use `docker compose restart postgres-slave1`

### Б) Shutting down a backend instance

1. Run the script to generate load:

```bash
$ ./load-test/run.sh
```

2. Imitate the failure of one instance:

```bash
$ docker kill backend1
```

3. Notice, nginx continues to serve traffic to the second backend

4. Restore the instance:

```bash
$ docker-compose restart backend1
```

### How to check the logs

```bash
$ docker-compose logs haproxy
$ docker-compose logs nginx
$ docker logs -f backend1
$ docker logs -f postgres-slave1
```

### Expected result

- All components work together, requests are balanced between the two instances of the application and the two PostgreSQL instances.
- When one of the PostgreSQL instances or the backend instance is shut down, the application remains available and functional.
