package it.infn.virgo.waferdb.api;

import javax.servlet.ServletContext;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

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
            context.setAttribute(CONTEXT_KEY, config);
            return config;
        }
    }

    Connection openConnection() throws SQLException {
        Connection connection = DriverManager.getConnection("jdbc:sqlite:" + databasePath);
        connection.setAutoCommit(true);
        return connection;
    }

    String allowedOrigin() {
        return allowedOrigin;
    }

    String databasePath() {
        return databasePath.toString();
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
