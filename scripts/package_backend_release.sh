#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/load_site_config.sh"

DIST_DIR="$ROOT_DIR/dist/waferdb_backend_${WAFERDB_DIST_LABEL}"

bash "$ROOT_DIR/scripts/build_backend.sh"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

cp "$ROOT_DIR/backend/target/WaferDb.war" "$DIST_DIR/"
cp "$ROOT_DIR/scripts/init_server_db.sh" "$DIST_DIR/"
cp "$ROOT_DIR/backend/deploy/WaferDb.xml.example" "$DIST_DIR/"
cp "$ROOT_DIR/backend/deploy/setenv.sh.example" "$DIST_DIR/"

cat > "$DIST_DIR/WaferDb.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context path="$WAFERDB_CONTEXT_PATH" docBase="WaferDb.war" reloadable="false">
    <Parameter
        name="waferDbPath"
        value="$WAFERDB_DB_PATH"
        override="false" />
    <Parameter
        name="allowedOrigin"
        value="$WAFERDB_ALLOWED_ORIGIN"
        override="false" />
</Context>
EOF

cat > "$DIST_DIR/setenv.sh" <<EOF
#!/usr/bin/env bash

export WAFERDB_DB_PATH="$WAFERDB_DB_PATH"
export WAFERDB_ALLOWED_ORIGIN="$WAFERDB_ALLOWED_ORIGIN"

# Equivalent JVM-property form, if preferred:
# export CATALINA_OPTS="\${CATALINA_OPTS:-} -DWAFERDB_DB_PATH=$WAFERDB_DB_PATH -DWAFERDB_ALLOWED_ORIGIN=$WAFERDB_ALLOWED_ORIGIN"
EOF
chmod +x "$DIST_DIR/setenv.sh"

cat > "$DIST_DIR/DEPLOY.md" <<'EOF'
# WaferDb Deployment Bundle

Bundle values are generated from `config/site.env.local` when present.

## Files

- `WaferDb.war`: Tomcat application
- `WaferDb.xml`: site-specific Tomcat context descriptor for `conf/Catalina/localhost/`
- `WaferDb.xml.example`: sanitized template kept in the repo
- `setenv.sh`: site-specific runtime overrides
- `setenv.sh.example`: sanitized template kept in the repo
- `init_server_db.sh`: helper to create the SQLite file at the configured database path

## Suggested installation

1. Initialize the database:

   ```bash
   bash init_server_db.sh
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

   Merge `setenv.sh` into Tomcat's `setenv.sh`.

5. Restart Tomcat.

## Result

- App root: `__WAFERDB_APP_BASE__`
- Health check: `__WAFERDB_API_BASE__/health`
EOF

python3 - "$DIST_DIR/DEPLOY.md" "$WAFERDB_APP_BASE" "$WAFERDB_API_BASE" <<'PY'
from pathlib import Path
import sys

deploy_file = Path(sys.argv[1])
content = deploy_file.read_text()
content = content.replace("__WAFERDB_APP_BASE__", sys.argv[2])
content = content.replace("__WAFERDB_API_BASE__", sys.argv[3])
deploy_file.write_text(content)
PY

echo "Prepared deployment bundle in $DIST_DIR"
