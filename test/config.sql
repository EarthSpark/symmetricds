-- SymmetricDS configuration for the two-node sync test.
--
-- This is SymmetricDS's own configuration schema (sym_*), populated directly
-- rather than by any application, so the test depends on nothing outside this
-- repo. It runs against the ground database only: the config channel
-- replicates it to the cloud node when that node registers.
--
-- Applied after the ground node's `symadmin create-sym-tables` has created
-- these tables; run_tests.sh waits for that.

-- Two groups, linked in both directions. The ground node pushes to the cloud
-- node ('P'); the cloud node's changes wait to be pulled ('W').
INSERT INTO sym_node_group (node_group_id, description) VALUES
    ('ground-group', 'Node running next to the ground database'),
    ('cloud-group',  'Node running next to the cloud database')
ON CONFLICT DO NOTHING;

INSERT INTO sym_node_group_link (source_node_group_id, target_node_group_id, data_event_action) VALUES
    ('ground-group', 'cloud-group',  'P'),
    ('cloud-group',  'ground-group', 'W')
ON CONFLICT DO NOTHING;

-- Identity of the ground node. sym_node_identity is what makes this node
-- consider itself 'ground-1' rather than an unregistered node; without it the
-- engine waits for registration against a URL it does not have.
INSERT INTO sym_node (node_id, node_group_id, external_id, sync_enabled, sync_url) VALUES
    ('ground-1', 'ground-group', 'ground-1', 1, 'http://symds-ground:31415/sync/ground-engine')
ON CONFLICT DO NOTHING;

INSERT INTO sym_node_identity (node_id) VALUES ('ground-1')
ON CONFLICT DO NOTHING;

INSERT INTO sym_node_security (node_id, node_password, registration_enabled) VALUES
    ('ground-1', 'ground-1-password', 0)
ON CONFLICT DO NOTHING;

-- Capture changes on `wallet` onto the default channel, which SymmetricDS
-- auto-configures at create-sym-tables time.
INSERT INTO sym_trigger (trigger_id, source_table_name, channel_id, create_time, last_update_time) VALUES
    ('wallet', 'wallet', 'default', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT DO NOTHING;

-- Route in both directions so the test can assert either way.
INSERT INTO sym_router (router_id, source_node_group_id, target_node_group_id, router_type, create_time, last_update_time) VALUES
    ('ground-to-cloud', 'ground-group', 'cloud-group',  'default', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('cloud-to-ground', 'cloud-group',  'ground-group', 'default', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT DO NOTHING;

INSERT INTO sym_trigger_router (trigger_id, router_id, initial_load_order, create_time, last_update_time) VALUES
    ('wallet', 'ground-to-cloud', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('wallet', 'cloud-to-ground', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT DO NOTHING;
