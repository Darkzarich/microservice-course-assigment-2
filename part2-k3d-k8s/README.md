# Homework: Application fault tolerance. Part B, the extended example with k8s under Postgres

Ready "out of the box" project under k3d, without external pulls from clusters: all images are uploaded to the local registry "k3d-registry.localhost:5000".

The task is to run provided shell scripts and see how the system handles different failure scenarios, describe and provide screenshots of the results.

## Quick start:

To carry out the work, you need to [install k3d](https://k3d.io/stable/)

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

## Steps:

My own observations after running provided with the assignment scripts.

Do note that the script that was provided as part of the task was not always producing the same result or expected behavior. In some phases it did not work the way I expected it to work. It may be my machine, system etc problem or the script itself. Changing some delays, amount of requests, etc. did not help 😔

### 1. Printing all resources (pods, services, deployments, etc.) in the namespace `highload-dns`.

This gives us overview of the current state:

<details>
<summary>CLICK TO EXPAND</summary>

![Step 1](/part2-k3d-k8s/screenshots/1.jpg)

</details>

### 2. Testing with `scripts/load-test.sh` script:

The scripts sends a series of requests and we can see that requests are balanced between the two backend replicas and two postgres replicas.

<details>
<summary>CLICK TO EXPAND</summary>

![Step 2](/part2-k3d-k8s/screenshots/2.jpg)

</details>

### 3. Phase 0: baseline (2 backend, 2 replicas):

From this point we run the script `scripts/demo_failover.sh` to see how the system handles different failure scenarios.

Phase 0 basically does the same as `load-test.sh`. Just shows that requests are **initially** balanced between the two backend replicas and two postgres replicas.

<details>
<summary>CLICK TO EXPAND</summary>

![Phase 0](/part2-k3d-k8s/screenshots/phase0.jpg)

</details>

### 4. Phase A: disable ONE PG replica (scale to 1):

In this phase we disable one of the postgres replicas imitating a replica failure and see how the system continues to work.

We can see that the requests are still balanced between the two backend replicas but only one postgres replica is operating (also shown in the logs).

<details>
<summary>CLICK TO EXPAND</summary>

![Phase A](/part2-k3d-k8s/screenshots/phaseA.jpg)

</details>

### 5. Phase A.restore: replicas back to 2:

In this phase we restore the amount of postgres replicas back to 2.

We can see that the initially we keep operating only one postgres replica (the reason for this is explained above in the Hints section) but eventually requests are balanced between the two backend replicas and two postgres replicas.

<details>
<summary>CLICK TO EXPAND</summary>

![Phase A.restore](/part2-k3d-k8s/screenshots/phaseA-restore.jpg)

</details>

### 6. Phase B: disable ONE backend (scale to 1):

In this phase we disable one of the backend replicas imitating a backend failure and see how the system continues to work.

We can see that the requests are still balanced between two postgres replicas but only one backend is handling the requests (also shown in the logs).

<details>
<summary>CLICK TO EXPAND</summary>

![Phase B](/part2-k3d-k8s/screenshots/phaseB.jpg)

</details>

### 7. Phase B.restore: backend back to 2:

In this phase we restore the amount of backend replicas back to 2.

And we're **SUPPOSED** to see that the requests are balanced between the two backend replicas and two postgres replicas, returning to the baseline state.

But in fact, we're still seeing only one backend replica handling the requests.

This is probably because it takes time for the backend replica to become healthy again and the amount of requests, sleep intervals and other parameters are not tuned enough **by default** so the script phase is over before the new backend pod is ready.

Another guess is that DNS is not yet ready to resolve the new pod IP.

<details>
<summary>CLICK TO EXPAND</summary>

![Phase B.restore](/part2-k3d-k8s/screenshots/phaseB-restore.jpg)

</details>

### 8. Phase C: 1 backend + 1 PG replica:

In this phase we specifically create a situation where we have only one backend replica and one postgres replica.

We can see that only one backend replica is handling the requests and only one postgres replica is operating.

<details>
<summary>CLICK TO EXPAND</summary>

![Phase C](/part2-k3d-k8s/screenshots/phaseC.jpg)

</details>

### 9. Phase C.drop: deleting the ONLY backend pod (observe errors -> recovery):

In this phase we delete the only backend replica - no backend replicas are left, so the system is in a state where it can't handle requests.

We can see that deleting a pod takes time / has some delay and we still manage to handle the first requests sent by the script,
but after that we see a series of 502 Bad Gateway errors which signalize that the application is not available.

<details>
<summary>CLICK TO EXPAND</summary>

![Phase C.drop](/part2-k3d-k8s/screenshots/phaseC-drop.jpg)

</details>

### 10. Phase C.restore: waiting for backend rollout, then verify:

After deleting the only pod, since backend service manifest describes `kind: Deployment` which creates a `ReplicaSet` which ensures that the specified number of replicas are running, the backend pod will be recreated automatically.

In this phase we just checked rollout status of the backend deployment and we can see that the rollout is successful which means that the new pod was created.

We're **SUPPOSED** to see that the new pod is handling the requests now but in fact, we're still seeing only errors. The problem is likely the same as was in the step 7.

The script is over before the new backend pod can handle the requests.

<details>
<summary>CLICK TO EXPAND</summary>

![Phase C.restore](/part2-k3d-k8s/screenshots/phaseC-restore.jpg)

![Phase C.restore2](/part2-k3d-k8s/screenshots/phaseC-restore2.jpg)

</details>
