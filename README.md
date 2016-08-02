# docker-symmetricds
SymmetricDS docker container

Environment variables

- **AWS_ACCESS_KEY_ID** AWS access key
- **AWS_SECRET_ACCESS_KEY** AWS secret key
- **AUTO_REGISTRATION** If new nodes should automatically register themselves (default true)
- **DATABASE_URL** Database URL (default postgresql://localhost:5432/symds)
- **ENGINE_NAME** engine-name
- **EXTERNAL_ID** external node id (e.g. shop id or microgrid name)
- **GROUP_ID** node group id (e.g. ground-group/cloud-group)
- **KEYSTORE_URL** If set, download a keystore containing a "sym" https certificate from this url, can be s3:// to download from Amazon S3
- **PROTOCOL** http or https
- **PULL_PERIOD** How often to run the pull job in ms (default: 60000)
- **PUSH_PERIOD** How often to run the push job in ms (default: 60000)
- **PURGE_RETENTION** How often batch files should be removed in ms (default 43200)
- **REGISTRATION_UR**L entrypoint where slaves should connect to register, must be empty for master node
- **SYNC_URL** entrypoint in the master node where slaves can register on

Args

- **SYMDS_URL** Points to the symmetricds-server zip file to download, can be used as a local cache with python -mSimpleHTTPServer
