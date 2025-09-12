# Homework: Application fault tolerance (Part B, extended example with k8s under postgres)

Ready project "out of the box" under k3d, without external pulls from clusters: all images are uploaded to the local registry "k3d-registry.localhost:5000".

To carry out the work, you need to install k3d (https://k3d.io/stable/installation)

## Quick start:

0. cluster + local registry (k3d-managed):

```bash
$ ./k3d/create.sh
```

1. build and push all necessary images to the local registry:

```bash
$ ./images/build_and_push.sh
```

2. deploy manifests:

```bash
$ ./k8s/apply.sh
```

3. port forward:

```bash
$ kubectl -n highload-dns port-forward svc/nginx 8081:80
```

4. load test:

```bash
$ ./scripts/load-test.sh http://127.0.0.1:8081/users
```

5. failure demo (illustration):

```bash
$ ./scripts/watch.sh # "dashboard" for easy observation, better to open in a separate terminal window
$ ./scripts/demo_failover.sh http://127.0.0.1:8081/users
```

5. delete cluster:

```bash
$ ./k3d/delete.sh
```

## What's inside:

- `k3d/` - create/delete cluster with k3d-managed registry.
- `images/` - Dockerfiles:
- - `postgres-primary` - init scripts (`001_init.sql`, `002_pg_hba.sh`), configure user, table, replication and `pg_hba` for pod subnet.
- - `postgres-replica` - auto cloning `pg_basebackup` + `standby.signal`.
- - `haproxy` - `server-template` on `postgres-replicas` + `resolvers parse-resolv-conf` + stats (see `:8404/stats`).
- - `backend` - FastAPI, `/users` endpoint returns `{`users`:N,`pod`:`<HOSTNAME>`}`.
- - `nginx` - in manifests, the config is taken from ConfigMap.
- `k8s/` - k8s-compatible manifests:
- - headless‑service `backend-headless` (so that nginx goes to POD IP without problems),
- - `postgres-replicas` Service (type ClusterIP) with the selector `role=replica`,
- - Deployments and Services for all components.
- `scripts/`
- - `load-test.sh`, `watch.sh`, `demo_failover.sh` for convenient failure illustration.

HAProxy stats

```bash
$ kubectl -n highload-dns port-forward deploy/haproxy 8404:8404
```

browser: http://127.0.0.1:8404/stats

Notes on networks (!):
Under k3d, the default pod-CIDR is `10.42.0.0/16`. If you have a different one, adjust the range in `images/postgres-primary/init/002_pg_hba.sh` before building

## Hints:

1. Why can we see db=unknown in some lines at the beginning of the test?
   We read the HAProxy logs `--since=1s`. If there are few requests or the delay is more than a second, the HAProxy log line for this specific request might not have been included in the cut. You can soften it to `--since=2s` or slightly increase the frequency/number of attempts in the load test.

2. Why do we always see only one `pg1` if the replicas returned to 2 in Phase A?
   After the second replica returns, we only see `pg1` for a few seconds - this is a normal stage of DNS convergence and health checks and/or connection stickiness. After this, `pg1`/`pg2` balancing is restored.

3. Why does Phase C show lingering 502 Bad Gateway after deleting the only backend pod and even immediately after the rollout status?

This is not a script bug, but the behavior of nginx + headless service:

- we specifically direct nginx to the backend-headless (pod IP) to see the real `backend=<POD_IP:8000>` in the log.
- nginx by default resolves the name once and sticks to the IP. When the pod is deleted, the name is no longer resolved, attempts are made to the old IP, a series of 502 until nginx itself does not resolve (which may not happen in time without special settings).
