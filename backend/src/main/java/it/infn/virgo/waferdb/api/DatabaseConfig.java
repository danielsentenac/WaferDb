package it.infn.virgo.waferdb.api;

import javax.servlet.ServletContext;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

final class DatabaseConfig {
    private static final String CONTEXT_KEY = DatabaseConfig.class.getName();
    private static final String DEFAULT_DB_PATH = "data/waferdb.sqlite";
    private static final String DEFAULT_ALLOWED_ORIGIN = "*";

    private final Path databasePath;
    private final String allowedOrigin;

    private DatabaseConfig(Path databasePath, String allowedOrigin) {
        this.databasePath = databasePath;
        this.allowedOrigin = allowedOrigin;
    }

    static DatabaseConfig from(ServletContext context) throws SQLException {
        Object existing = context.getAttribute(CONTEXT_KEY);
        if (existing instanceof DatabaseConfig) {
            return (DatabaseConfig) existing;
        }

        synchronized (context) {
            Object secondRead = context.getAttribute(CONTEXT_KEY);
            if (secondRead instanceof DatabaseConfig) {
                return (DatabaseConfig) secondRead;
            }

            try {
                Class.forName("org.sqlite.JDBC");
            } catch (ClassNotFoundException exception) {
                throw new SQLException("SQLite JDBC driver is not available.", exception);
            }

            String configuredPath = firstNonBlank(
                System.getenv("WAFERDB_DB_PATH"),
                System.getProperty("WAFERDB_DB_PATH"),
                context.getInitParameter("waferDbPath"),
                DEFAULT_DB_PATH
            );
            String configuredOrigin = firstNonBlank(
                System.getenv("WAFERDB_ALLOWED_ORIGIN"),
                System.getProperty("WAFERDB_ALLOWED_ORIGIN"),
                context.getInitParameter("allowedOrigin"),
                DEFAULT_ALLOWED_ORIGIN
            );

            DatabaseConfig config = new DatabaseConfig(Paths.get(configuredPath), configuredOrigin);
            config.ensureSchema();
            context.setAttribute(CONTEXT_KEY, config);
            return config;
        }
    }

    Connection openConnection() throws SQLException {
        Connection connection = DriverManager.getConnection("jdbc:sqlite:" + databasePath);
        try (Statement statement = connection.createStatement()) {
            statement.execute("PRAGMA foreign_keys = ON");
        }
        connection.setAutoCommit(true);
        return connection;
    }

    String allowedOrigin() {
        return allowedOrigin;
    }

    String databasePath() {
        return databasePath.toString();
    }

    private void ensureSchema() throws SQLException {
        try (Connection connection = DriverManager.getConnection("jdbc:sqlite:" + databasePath)) {
            connection.setAutoCommit(false);
            try (Statement statement = connection.createStatement()) {
                statement.execute("PRAGMA foreign_keys = OFF");
                migrateWafersTable(connection);
                ensureWaferMetadataHistoryTable(statement);
                migrateWaferMetadataHistoryTable(connection);
                ensureWaferMetadataHistoryIndex(statement);
                ensureWaferStatusHistoryPhotoColumns(connection);
                ensureDefaultStatuses(connection);
                connection.commit();
            } catch (SQLException | RuntimeException exception) {
                connection.rollback();
                throw exception;
            } finally {
                try (Statement statement = connection.createStatement()) {
                    statement.execute("PRAGMA foreign_keys = ON");
                }
            }
        }
    }

    private void ensureWaferMetadataHistoryTable(Statement statement) throws SQLException {
        statement.executeUpdate(
            "CREATE TABLE IF NOT EXISTS wafer_metadata_history ("
                + "wafer_metadata_history_id INTEGER PRIMARY KEY, "
                + "wafer_id INTEGER NOT NULL REFERENCES wafers(wafer_id) ON DELETE CASCADE, "
                + "changed_at TEXT NOT NULL CHECK (datetime(changed_at) IS NOT NULL), "
                + "name TEXT NOT NULL, "
                + "acquired_date TEXT NOT NULL CHECK (date(acquired_date) IS NOT NULL), "
                + "reference_invoice TEXT, "
                + "roughness_nm REAL CHECK (roughness_nm IS NULL OR roughness_nm >= 0), "
                + "wafer_type TEXT NOT NULL, "
                + "wafer_size_in REAL CHECK (wafer_size_in IS NULL OR wafer_size_in > 0), "
                + "notes TEXT, "
                + "change_summary TEXT, "
                + "created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP"
                + ")"
        );
    }

    private void ensureWaferMetadataHistoryIndex(Statement statement) throws SQLException {
        statement.executeUpdate(
            "CREATE INDEX IF NOT EXISTS idx_wafer_metadata_history_wafer_changed_at "
                + "ON wafer_metadata_history ("
                + "wafer_id, changed_at DESC, wafer_metadata_history_id DESC"
                + ")"
        );
    }

    private void ensureWaferStatusHistoryPhotoColumns(Connection connection) throws SQLException {
        if (!tableHasColumn(connection, "wafer_status_history", "wafer_status_history_id")) {
            return;
        }

        if (!tableHasColumn(connection, "wafer_status_history", "photo_content_type")) {
            try (Statement statement = connection.createStatement()) {
                statement.executeUpdate("ALTER TABLE wafer_status_history ADD COLUMN photo_content_type TEXT");
            }
        }

        if (!tableHasColumn(connection, "wafer_status_history", "photo_blob")) {
            try (Statement statement = connection.createStatement()) {
                statement.executeUpdate("ALTER TABLE wafer_status_history ADD COLUMN photo_blob BLOB");
            }
        }
    }

    private void ensureDefaultStatuses(Connection connection) throws SQLException {
        if (!tableHasColumn(connection, "wafer_statuses", "status_id")) {
            return;
        }

        ensureStatus(
            connection,
            4,
            "darkfield_exposed_done",
            "Darkfield inspection done",
            "Darkfield inspection has been completed."
        );
        ensureStatus(
            connection,
            5,
            "darkfield_inspection_todo",
            "Darkfield inspection to be done",
            "Darkfield inspection has not been recorded yet."
        );
    }

    private void ensureStatus(
        Connection connection,
        int statusId,
        String code,
        String label,
        String description
    ) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
            "INSERT OR IGNORE INTO wafer_statuses (status_id, code, label, description) VALUES (?, ?, ?, ?)"
        )) {
            statement.setInt(1, statusId);
            statement.setString(2, code);
            statement.setString(3, label);
            statement.setString(4, description);
            statement.executeUpdate();
        }

        try (PreparedStatement statement = connection.prepareStatement(
            "UPDATE wafer_statuses SET label = ?, description = ? WHERE code = ?"
        )) {
            statement.setString(1, label);
            statement.setString(2, description);
            statement.setString(3, code);
            statement.executeUpdate();
        }
    }

    private void migrateWafersTable(Connection connection) throws SQLException {
        if (!tableHasColumn(connection, "wafers", "wafer_size_label")) {
            return;
        }

        try (Statement statement = connection.createStatement()) {
            statement.executeUpdate("DROP TABLE IF EXISTS wafers_migrated");
            statement.executeUpdate(
                "CREATE TABLE wafers_migrated ("
                    + "wafer_id INTEGER PRIMARY KEY, "
                    + "name TEXT NOT NULL UNIQUE, "
                    + "acquired_date TEXT NOT NULL CHECK (date(acquired_date) IS NOT NULL), "
                    + "reference_invoice TEXT, "
                    + "roughness_nm REAL CHECK (roughness_nm IS NULL OR roughness_nm >= 0), "
                    + "wafer_type TEXT NOT NULL, "
                    + "wafer_size_in REAL CHECK (wafer_size_in IS NULL OR wafer_size_in > 0), "
                    + "notes TEXT, "
                    + "created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP"
                    + ")"
            );
            statement.executeUpdate(
                "INSERT INTO wafers_migrated ("
                    + "wafer_id, name, acquired_date, reference_invoice, roughness_nm, "
                    + "wafer_type, wafer_size_in, notes, created_at"
                    + ") "
                    + "SELECT wafer_id, name, acquired_date, reference_invoice, roughness_nm, "
                    + "wafer_type, wafer_size_in, notes, created_at "
                    + "FROM wafers"
            );
            statement.executeUpdate("DROP TABLE wafers");
            statement.executeUpdate("ALTER TABLE wafers_migrated RENAME TO wafers");
        }
    }

    private void migrateWaferMetadataHistoryTable(Connection connection) throws SQLException {
        boolean needsNameColumn = !tableHasColumn(connection, "wafer_metadata_history", "name");
        boolean hasSizeLabelColumn = tableHasColumn(connection, "wafer_metadata_history", "wafer_size_label");
        if (!needsNameColumn && !hasSizeLabelColumn) {
            return;
        }

        try (Statement statement = connection.createStatement()) {
            statement.executeUpdate("DROP TABLE IF EXISTS wafer_metadata_history_migrated");
            statement.executeUpdate(
                "CREATE TABLE wafer_metadata_history_migrated ("
                    + "wafer_metadata_history_id INTEGER PRIMARY KEY, "
                    + "wafer_id INTEGER NOT NULL REFERENCES wafers(wafer_id) ON DELETE CASCADE, "
                    + "changed_at TEXT NOT NULL CHECK (datetime(changed_at) IS NOT NULL), "
                    + "name TEXT NOT NULL, "
                    + "acquired_date TEXT NOT NULL CHECK (date(acquired_date) IS NOT NULL), "
                    + "reference_invoice TEXT, "
                    + "roughness_nm REAL CHECK (roughness_nm IS NULL OR roughness_nm >= 0), "
                    + "wafer_type TEXT NOT NULL, "
                    + "wafer_size_in REAL CHECK (wafer_size_in IS NULL OR wafer_size_in > 0), "
                    + "notes TEXT, "
                    + "change_summary TEXT, "
                    + "created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP"
                    + ")"
            );
            statement.executeUpdate(
                "INSERT INTO wafer_metadata_history_migrated ("
                    + "wafer_metadata_history_id, wafer_id, changed_at, name, acquired_date, "
                    + "reference_invoice, roughness_nm, wafer_type, wafer_size_in, notes, "
                    + "change_summary, created_at"
                    + ") "
                    + "SELECT h.wafer_metadata_history_id, h.wafer_id, h.changed_at, w.name, h.acquired_date, "
                    + "h.reference_invoice, h.roughness_nm, h.wafer_type, h.wafer_size_in, h.notes, "
                    + "h.change_summary, h.created_at "
                    + "FROM wafer_metadata_history h "
                    + "JOIN wafers w ON w.wafer_id = h.wafer_id"
            );
            statement.executeUpdate("DROP TABLE wafer_metadata_history");
            statement.executeUpdate(
                "ALTER TABLE wafer_metadata_history_migrated RENAME TO wafer_metadata_history"
            );
        }
    }

    private boolean tableHasColumn(Connection connection, String tableName, String columnName) throws SQLException {
        try (Statement statement = connection.createStatement();
             ResultSet resultSet = statement.executeQuery("PRAGMA table_info(" + tableName + ")")) {
            while (resultSet.next()) {
                if (columnName.equalsIgnoreCase(resultSet.getString("name"))) {
                    return true;
                }
            }
            return false;
        }
    }

    private static String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) {
                return value.trim();
            }
        }
        return null;
    }
}
