FROM postgres:16
ENV PRIMARY_SERVICE=postgres-primary \
    REPL_USER=repl \
    REPL_PASSWORD=repl
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh
CMD ["/scripts/run-replica.sh"]
