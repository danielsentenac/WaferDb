#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
TARGET_DIR="$BACKEND_DIR/target"
CLASSES_DIR="$TARGET_DIR/classes"
STAGING_DIR="$TARGET_DIR/waferdb-war"
WAR_FILE="$TARGET_DIR/WaferDb.war"

SERVLET_API_JAR="${SERVLET_API_JAR:-$HOME/.m2/repository/javax/servlet/javax.servlet-api/3.1.0/javax.servlet-api-3.1.0.jar}"
SQLITE_JDBC_JAR="${SQLITE_JDBC_JAR:-$HOME/.m2/repository/org/xerial/sqlite-jdbc/3.21.0/sqlite-jdbc-3.21.0.jar}"

if [[ ! -f "$SERVLET_API_JAR" ]]; then
    echo "Missing servlet API jar: $SERVLET_API_JAR" >&2
    exit 1
fi

if [[ ! -f "$SQLITE_JDBC_JAR" ]]; then
    echo "Missing sqlite JDBC jar: $SQLITE_JDBC_JAR" >&2
    exit 1
fi

rm -rf "$TARGET_DIR"
mkdir -p "$CLASSES_DIR" "$STAGING_DIR/WEB-INF/classes" "$STAGING_DIR/WEB-INF/lib"

JAVA_SOURCES=()
while IFS= read -r source_file; do
    JAVA_SOURCES+=("$source_file")
done < <(find "$BACKEND_DIR/src/main/java" -type f -name '*.java' | sort)

javac \
    --release 8 \
    -cp "$SERVLET_API_JAR:$SQLITE_JDBC_JAR" \
    -d "$CLASSES_DIR" \
    "${JAVA_SOURCES[@]}"

cp -a "$BACKEND_DIR/src/main/webapp/." "$STAGING_DIR/"
cp -a "$CLASSES_DIR/." "$STAGING_DIR/WEB-INF/classes/"
cp "$SQLITE_JDBC_JAR" "$STAGING_DIR/WEB-INF/lib/"

(
    cd "$STAGING_DIR"
    jar cf "$WAR_FILE" .
)

echo "Built $WAR_FILE"
