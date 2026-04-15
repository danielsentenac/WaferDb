#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/waferdb_backend_olserver134"

bash "$ROOT_DIR/scripts/build_backend.sh"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

cp "$ROOT_DIR/backend/target/WaferDb.war" "$DIST_DIR/"
cp "$ROOT_DIR/backend/deploy/WaferDb.xml" "$DIST_DIR/"
cp "$ROOT_DIR/backend/deploy/setenv.sh.example" "$DIST_DIR/"
cp "$ROOT_DIR/scripts/init_server_db.sh" "$DIST_DIR/"

cat > "$DIST_DIR/DEPLOY.md" <<'EOF'
# WaferDb Deployment Bundle

Target host: `olserver134.virgo.infn.it`

## Files

- `WaferDb.war`: Tomcat application
- `WaferDb.xml`: optional Tomcat context descriptor for `conf/Catalina/localhost/`
- `setenv.sh.example`: example runtime overrides
- `init_server_db.sh`: helper to create the SQLite file in `/data/prod/rd/vac`

## Suggested installation

1. Initialize the database:

   ```bash
   bash init_server_db.sh /data/prod/rd/vac/waferdb.sqlite
   ```

2. Install the Tomcat application:

   ```bash
   cp WaferDb.war "$CATALINA_BASE/webapps/"
   ```

3. Optional explicit context configuration:

   ```bash
   cp WaferDb.xml "$CATALINA_BASE/conf/Catalina/localhost/"
   ```

4. Optional runtime override setup:

   Merge `setenv.sh.example` into Tomcat's `setenv.sh`.

5. Restart Tomcat.

## Result

- App root: `http://olserver134.virgo.infn.it:8081/WaferDb`
- Health check: `http://olserver134.virgo.infn.it:8081/WaferDb/api/health`
EOF

echo "Prepared deployment bundle in $DIST_DIR"
