#!/usr/bin/env bash
#
# Two-node SymmetricDS sync test. Brings up a ground and a cloud database each
# with a SymmetricDS node beside it, writes a row on the ground side, and
# asserts it arrives on the cloud side.
#
# Usage: scripts/run_tests.sh [--keep]
#
#   --keep   leave the stack running afterwards for inspection
#
# Exits non-zero if the row does not replicate within SYNC_TIMEOUT seconds.

set -euo pipefail

cd "$(dirname "$0")/.."

COMPOSE=(docker compose -f docker-compose.test.yml)
SYNC_TIMEOUT="${SYNC_TIMEOUT:-120}"
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

cleanup() {
    local status=$?
    if [ "$KEEP" -eq 1 ]; then
        echo "[ --keep given, leaving the stack up ]"
        return
    fi
    if [ "$status" -ne 0 ]; then
        echo "[ Failed. SymmetricDS logs follow. ]"
        "${COMPOSE[@]}" logs --tail 60 symds-ground symds-cloud || true
    fi
    "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Run psql against one of the databases. Args after the database name are
# passed through to psql. With no -c, psql reads SQL from stdin, so callers
# feed script files in by redirection rather than by bind mount.
psql_on() {
    local db="$1"; shift
    "${COMPOSE[@]}" run --rm --no-deps -T psql \
        -h "postgres-${db}" -U symds -d "$db" -v ON_ERROR_STOP=1 "$@"
}

# Poll until a query returns the expected value, or give up.
wait_for() {
    local db="$1" query="$2" want="$3" what="$4" timeout="$5"
    local deadline=$((SECONDS + timeout))
    echo "[ Waiting for ${what} ]"
    while [ "$SECONDS" -lt "$deadline" ]; do
        if [ "$(psql_on "$db" -At -c "$query" 2>/dev/null | tr -d '[:space:]')" = "$want" ]; then
            echo "[ ${what}: ok ]"
            return 0
        fi
        sleep 2
    done
    echo "[ Timed out after ${timeout}s waiting for ${what} ]" >&2
    return 1
}

# SYMDS_IMAGE names an already-built image to test. CI sets it so the image
# under test is the artifact that gets published, rather than a second build
# of the same Dockerfile. Unset, the stack builds from this checkout.
if [ -n "${SYMDS_IMAGE:-}" ]; then
    echo "[ Starting the stack against ${SYMDS_IMAGE} ]"
    "${COMPOSE[@]}" up -d postgres-ground postgres-cloud symds-ground symds-cloud
else
    echo "[ Building and starting the stack ]"
    "${COMPOSE[@]}" up -d --build postgres-ground postgres-cloud symds-ground symds-cloud
fi

# The table under test doubles as the table entrypoint.sh blocks on, so the
# ground node stays in its wait loop until this lands.
echo "[ Creating the wallet table on both sides ]"
psql_on ground < test/wallet.sql
psql_on cloud  < test/wallet.sql

# sym_* is created by the ground node itself at startup, so its configuration
# cannot be applied until that has happened.
wait_for ground \
    "SELECT count(*) FROM information_schema.tables WHERE table_name = 'sym_node_identity'" \
    1 "the ground node to create the sym_* tables" 120

echo "[ Applying SymmetricDS configuration ]"
psql_on ground < test/config.sql

wait_for cloud \
    "SELECT count(*) FROM sym_node WHERE node_group_id = 'cloud-group'" \
    1 "the cloud node to register" "$SYNC_TIMEOUT"

echo "[ Writing a row on the ground side ]"
psql_on ground -c "INSERT INTO wallet (id, balance) VALUES (1, 100)"

wait_for cloud "SELECT balance FROM wallet WHERE id = 1" \
    100 "the row to reach the cloud side" "$SYNC_TIMEOUT"

echo "[ Updating the row on the ground side ]"
psql_on ground -c "UPDATE wallet SET balance = 250 WHERE id = 1"

wait_for cloud "SELECT balance FROM wallet WHERE id = 1" \
    250 "the update to reach the cloud side" "$SYNC_TIMEOUT"

echo "[ PASS ]"
