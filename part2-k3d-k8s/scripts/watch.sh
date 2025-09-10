#!/usr/bin/env bash
watch -n1 '\
echo "--- BACKEND PODs"; kubectl -n highload-dns get pod -l app=backend -o wide; echo; \
echo "--- BACKEND ClusterIP EP"; kubectl -n highload-dns get ep backend -o wide; echo; \
echo "--- BACKEND HEADLESS EP"; kubectl -n highload-dns get ep backend-headless -o wide; echo; \
echo "--- PG REPLICAS PODs"; kubectl -n highload-dns get pod -l app=postgres,role=replica -o wide; echo; \
echo "--- PG REPLICAS EP"; kubectl -n highload-dns get ep postgres-replicas -o wide;'
