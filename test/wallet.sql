-- The table under test. It is named `wallet` because entrypoint.sh has the
-- master node block on `wait_for_table wallet` before it will start, so the
-- table that unblocks startup and the table whose rows we assert on are the
-- same one. SymmetricDS captures changes via triggers, which require a
-- primary key.
CREATE TABLE IF NOT EXISTS wallet (
    id      integer PRIMARY KEY,
    balance integer NOT NULL
);
