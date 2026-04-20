# WaferDb Backend

Tomcat web application exposing the SQLite WaferDb through JSON APIs.

## Configuration

Tracked backend files are sanitized. Keep deployment-specific values in the gitignored `config/site.env.local` file and regenerate it with `bash scripts/restore_local_site_env.sh ...` when needed.

The runtime database path can be overridden with:

- environment variable `WAFERDB_DB_PATH`
- JVM property `-DWAFERDB_DB_PATH=...`
- or the `waferDbPath` context parameter in `WEB-INF/web.xml`

The allowed CORS origin can also be overridden with:

- environment variable `WAFERDB_ALLOWED_ORIGIN`
- JVM property `-DWAFERDB_ALLOWED_ORIGIN=...`
- or the `allowedOrigin` context parameter in `WEB-INF/web.xml`

## API surface

- `GET /api/health`
- `GET /api/lookups`
- `GET /api/dashboard`
- `GET /api/wafers?q=&status=&limit=`
- `GET /api/wafers/{waferId}`
- `POST /api/wafers`
- `POST /api/wafers/{waferId}/history`
- `POST /api/wafers/{waferId}/statuses`
- `POST /api/wafers/{waferId}/activities`
- `POST /api/wafers/{waferId}/darkfield-runs`

POST requests use `application/x-www-form-urlencoded` parameters so the Flutter client can submit forms without adding a JSON parser dependency to the backend.

## Build

```bash
cd backend
mvn package
```

This produces `target/WaferDb.war`, ready to deploy into Tomcat.

## Deployment bundle

Build the deployable bundle using the current local site config:

```bash
bash scripts/package_backend_release.sh
```

This assembles:

- `backend/target/WaferDb.war`
- `backend/deploy/WaferDb.xml.example`
- `backend/deploy/setenv.sh.example`
- `scripts/init_server_db.sh`
- `dist/waferdb_backend_<label>/DEPLOY.md`
