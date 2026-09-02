# The official metabase/metabase image is based on Alpine Linux (musl libc), and the
# community DuckDB driver ships a native library built for glibc. Loading it on Alpine
# crashes the JVM (SIGSEGV) even after installing a glibc compatibility layer, so this
# image builds Metabase on a Debian-based JRE instead, per the driver's own instructions:
# https://github.com/motherduckdb/metabase_duckdb_driver
FROM eclipse-temurin:21-jre-jammy

ARG METABASE_VERSION=0.58.9
ARG METABASE_DUCKDB_DRIVER_VERSION=1.5.5.0
ARG DUCKDB_DRIVER_URL=https://github.com/motherduckdb/metabase_duckdb_driver/releases/download/${METABASE_DUCKDB_DRIVER_VERSION}/duckdb.metabase-driver.jar

ENV MB_PLUGINS_DIR=/home/metabase/plugins/

RUN groupadd -r metabase && useradd -r -g metabase metabase

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/metabase/plugins /home/metabase/data && \
    chown -R metabase:metabase /home/metabase

WORKDIR /home/metabase
ADD --chown=metabase:metabase https://downloads.metabase.com/v${METABASE_VERSION}/metabase.jar /home/metabase/
ADD --chown=metabase:metabase ${DUCKDB_DRIVER_URL} /home/metabase/plugins/duckdb.metabase-driver.jar

RUN chmod 755 /home/metabase/metabase.jar && \
    chmod 755 /home/metabase/plugins/duckdb.metabase-driver.jar

EXPOSE 3000

USER metabase

CMD ["java", "-jar", "/home/metabase/metabase.jar"]
