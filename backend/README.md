# WaferDb Backend

Tomcat web application exposing the SQLite WaferDb through JSON APIs.

## Intended deployment

- Tomcat context path: `http://olserver134.virgo.infn.it:8081/WaferDb`
- API root: `http://olserver134.virgo.infn.it:8081/WaferDb/api`
- Default database path: `/data/prod/rd/vac/waferdb.sqlite`

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
- `POST /api/wafers/{waferId}/statuses`
- `POST /api/wafers/{waferId}/activities`

POST requests use `application/x-www-form-urlencoded` parameters so the Flutter client can submit forms without adding a JSON parser dependency to the backend.

## Build

```bash
cd backend
mvn package
```

This produces `target/WaferDb.war`, ready to deploy into Tomcat.

## Deployment bundle

Build the deployable bundle for `olserver134.virgo.infn.it`:

```bash
bash scripts/package_backend_release.sh
```

This assembles:

- `backend/target/WaferDb.war`
- `backend/deploy/WaferDb.xml`
- `backend/deploy/setenv.sh.example`
- `scripts/init_server_db.sh`
- `dist/waferdb_backend_olserver134/DEPLOY.md`
