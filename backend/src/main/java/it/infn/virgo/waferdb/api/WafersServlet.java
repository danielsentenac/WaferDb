package it.infn.virgo.waferdb.api;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class WafersServlet extends BaseApiServlet {
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try (Connection connection = openConnection()) {
            List<String> segments = RequestUtil.pathSegments(request);
            if (segments.isEmpty()) {
                sendOk(response, queryWaferList(connection, request));
                return;
            }

            if (segments.size() == 1) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                Map<String, Object> detail = queryWaferDetail(connection, waferId);
                if (detail == null) {
                    sendError(response, HttpServletResponse.SC_NOT_FOUND, "Wafer not found.");
                    return;
                }
                sendOk(response, detail);
                return;
            }

            sendError(response, HttpServletResponse.SC_NOT_FOUND, "Unsupported wafer API path.");
        } catch (IllegalArgumentException exception) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, exception.getMessage());
        } catch (SQLException exception) {
            sendError(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, exception.getMessage());
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try (Connection connection = openConnection()) {
            List<String> segments = RequestUtil.pathSegments(request);
            if (segments.isEmpty()) {
                sendCreated(response, createWafer(connection, request));
                return;
            }

            if (segments.size() == 2 && "statuses".equals(segments.get(1))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                sendCreated(response, createStatusHistory(connection, waferId, request));
                return;
            }

            if (segments.size() == 2 && "activities".equals(segments.get(1))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                sendCreated(response, createActivity(connection, waferId, request));
                return;
            }

            sendError(response, HttpServletResponse.SC_NOT_FOUND, "Unsupported wafer API path.");
        } catch (IllegalArgumentException exception) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, exception.getMessage());
        } catch (SQLException exception) {
            int status = isConstraintError(exception)
                ? HttpServletResponse.SC_BAD_REQUEST
                : HttpServletResponse.SC_INTERNAL_SERVER_ERROR;
            sendError(response, status, exception.getMessage());
        }
    }

    private Map<String, Object> queryWaferList(Connection connection, HttpServletRequest request) throws SQLException {
        String query = RequestUtil.optional(request, "q");
        String statusCode = RequestUtil.optional(request, "status");
        int limit = RequestUtil.optionalInteger(request, "limit", 50, 500);

        StringBuilder sql = new StringBuilder()
            .append("SELECT w.wafer_id, w.name, w.acquired_date, w.reference_invoice, w.roughness_nm, ")
            .append("w.wafer_type, w.wafer_size_in, w.wafer_size_label, w.notes, w.created_at, ")
            .append("cs.status_code, cs.status_label, cs.effective_at AS status_effective_at ")
            .append("FROM wafers w ")
            .append("LEFT JOIN wafer_current_status cs ON cs.wafer_id = w.wafer_id ");

        List<Object> parameters = new ArrayList<>();
        List<String> clauses = new ArrayList<>();
        if (query != null) {
            clauses.add("(LOWER(w.name) LIKE ? OR LOWER(COALESCE(w.reference_invoice, '')) LIKE ?)");
            String token = "%" + query.toLowerCase() + "%";
            parameters.add(token);
            parameters.add(token);
        }
        if (statusCode != null) {
            clauses.add("cs.status_code = ?");
            parameters.add(statusCode);
        }
        if (!clauses.isEmpty()) {
            sql.append("WHERE ").append(String.join(" AND ", clauses)).append(' ');
        }
        sql.append("ORDER BY w.name ASC LIMIT ?");
        parameters.add(limit);

        try (PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            bind(statement, parameters);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<Map<String, Object>> wafers = new ArrayList<>();
                while (resultSet.next()) {
                    wafers.add(mapWaferRow(resultSet));
                }
                Map<String, Object> payload = new LinkedHashMap<>();
                payload.put("ok", true);
                payload.put("items", wafers);
                payload.put("query", query);
                payload.put("statusFilter", statusCode);
                payload.put("limit", limit);
                return payload;
            }
        }
    }

    private Map<String, Object> queryWaferDetail(Connection connection, long waferId) throws SQLException {
        Map<String, Object> wafer = null;
        String waferSql = ""
            + "SELECT w.wafer_id, w.name, w.acquired_date, w.reference_invoice, w.roughness_nm, "
            + "w.wafer_type, w.wafer_size_in, w.wafer_size_label, w.notes, w.created_at, "
            + "cs.status_code, cs.status_label, cs.effective_at AS status_effective_at "
            + "FROM wafers w "
            + "LEFT JOIN wafer_current_status cs ON cs.wafer_id = w.wafer_id "
            + "WHERE w.wafer_id = ?";
        try (PreparedStatement statement = connection.prepareStatement(waferSql)) {
            statement.setLong(1, waferId);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    wafer = mapWaferRow(resultSet);
                }
            }
        }

        if (wafer == null) {
            return null;
        }

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("ok", true);
        payload.put("wafer", wafer);
        payload.put("statusHistory", queryStatusHistory(connection, waferId));
        payload.put("activities", queryActivities(connection, waferId));
        payload.put("darkfieldRuns", queryDarkfieldRuns(connection, waferId));
        return payload;
    }

    private List<Map<String, Object>> queryStatusHistory(Connection connection, long waferId) throws SQLException {
        String sql = ""
            + "SELECT h.wafer_status_history_id, s.code AS status_code, s.label AS status_label, "
            + "h.effective_at, h.cleared_at, h.notes "
            + "FROM wafer_status_history h "
            + "JOIN wafer_statuses s ON s.status_id = h.status_id "
            + "WHERE h.wafer_id = ? "
            + "ORDER BY datetime(h.effective_at) DESC, h.wafer_status_history_id DESC";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, waferId);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<Map<String, Object>> items = new ArrayList<>();
                while (resultSet.next()) {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("waferStatusHistoryId", resultSet.getLong("wafer_status_history_id"));
                    item.put("statusCode", resultSet.getString("status_code"));
                    item.put("statusLabel", resultSet.getString("status_label"));
                    item.put("effectiveAt", resultSet.getString("effective_at"));
                    item.put("clearedAt", resultSet.getString("cleared_at"));
                    item.put("notes", resultSet.getString("notes"));
                    items.add(item);
                }
                return items;
            }
        }
    }

    private List<Map<String, Object>> queryActivities(Connection connection, long waferId) throws SQLException {
        String sql = ""
            + "SELECT a.activity_id, p.code AS purpose_code, p.label AS purpose_label, "
            + "s.code AS status_code, s.label AS status_label, "
            + "l.code AS location_code, l.name AS location_name, "
            + "a.exposure_quantity, a.exposure_unit, a.started_at, a.ended_at, "
            + "a.observations, a.created_at "
            + "FROM wafer_activities a "
            + "JOIN usage_purposes p ON p.purpose_id = a.purpose_id "
            + "LEFT JOIN wafer_statuses s ON s.status_id = a.observed_status_id "
            + "JOIN locations l ON l.location_id = a.location_id "
            + "WHERE a.wafer_id = ? "
            + "ORDER BY COALESCE(datetime(a.ended_at), datetime(a.started_at), datetime(a.created_at)) DESC, a.activity_id DESC";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, waferId);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<Map<String, Object>> items = new ArrayList<>();
                while (resultSet.next()) {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("activityId", resultSet.getLong("activity_id"));
                    item.put("purposeCode", resultSet.getString("purpose_code"));
                    item.put("purposeLabel", resultSet.getString("purpose_label"));
                    item.put("statusCode", resultSet.getString("status_code"));
                    item.put("statusLabel", resultSet.getString("status_label"));
                    item.put("locationCode", resultSet.getString("location_code"));
                    item.put("locationName", resultSet.getString("location_name"));
                    item.put("exposureQuantity", resultSet.getDouble("exposure_quantity"));
                    item.put("exposureUnit", resultSet.getString("exposure_unit"));
                    item.put("startedAt", resultSet.getString("started_at"));
                    item.put("endedAt", resultSet.getString("ended_at"));
                    item.put("observations", resultSet.getString("observations"));
                    item.put("createdAt", resultSet.getString("created_at"));
                    items.add(item);
                }
                return items;
            }
        }
    }

    private List<Map<String, Object>> queryDarkfieldRuns(Connection connection, long waferId) throws SQLException {
        String sql = ""
            + "SELECT darkfield_run_id, activity_id, run_type, measured_at, summary_notes, data_path, created_at "
            + "FROM darkfield_runs WHERE wafer_id = ? "
            + "ORDER BY datetime(measured_at) DESC, darkfield_run_id DESC";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, waferId);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<Map<String, Object>> items = new ArrayList<>();
                while (resultSet.next()) {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("darkfieldRunId", resultSet.getLong("darkfield_run_id"));
                    item.put("activityId", resultSet.getObject("activity_id"));
                    item.put("runType", resultSet.getString("run_type"));
                    item.put("measuredAt", resultSet.getString("measured_at"));
                    item.put("summaryNotes", resultSet.getString("summary_notes"));
                    item.put("dataPath", resultSet.getString("data_path"));
                    item.put("createdAt", resultSet.getString("created_at"));
                    items.add(item);
                }
                return items;
            }
        }
    }

    private Map<String, Object> createWafer(Connection connection, HttpServletRequest request) throws SQLException {
        String sql = ""
            + "INSERT INTO wafers ("
            + "name, acquired_date, reference_invoice, roughness_nm, wafer_type, "
            + "wafer_size_in, wafer_size_label, notes"
            + ") VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            statement.setString(1, RequestUtil.required(request, "name"));
            statement.setString(2, RequestUtil.required(request, "acquiredDate"));
            statement.setString(3, RequestUtil.optional(request, "referenceInvoice"));
            bindNullableDouble(statement, 4, RequestUtil.optionalDouble(request, "roughnessNm"));
            statement.setString(5, RequestUtil.required(request, "waferType"));
            bindNullableDouble(statement, 6, RequestUtil.optionalDouble(request, "waferSizeIn"));
            statement.setString(7, RequestUtil.optional(request, "waferSizeLabel"));
            statement.setString(8, RequestUtil.optional(request, "notes"));
            statement.executeUpdate();

            long waferId;
            try (ResultSet keys = statement.getGeneratedKeys()) {
                if (!keys.next()) {
                    throw new SQLException("Failed to create wafer row.");
                }
                waferId = keys.getLong(1);
            }

            String initialStatusCode = RequestUtil.optional(request, "initialStatusCode");
            if (initialStatusCode != null) {
                insertStatusHistory(
                    connection,
                    waferId,
                    initialStatusCode,
                    RequestUtil.optional(request, "initialStatusEffectiveAt"),
                    null,
                    RequestUtil.optional(request, "initialStatusNotes")
                );
            }

            return queryWaferDetail(connection, waferId);
        }
    }

    private Map<String, Object> createStatusHistory(Connection connection, long waferId, HttpServletRequest request)
        throws SQLException {
        long rowId = insertStatusHistory(
            connection,
            waferId,
            RequestUtil.required(request, "statusCode"),
            RequestUtil.required(request, "effectiveAt"),
            RequestUtil.optional(request, "clearedAt"),
            RequestUtil.optional(request, "notes")
        );

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("ok", true);
        payload.put("waferId", waferId);
        payload.put("waferStatusHistoryId", rowId);
        payload.put("detail", queryWaferDetail(connection, waferId));
        return payload;
    }

    private long insertStatusHistory(
        Connection connection,
        long waferId,
        String statusCode,
        String effectiveAt,
        String clearedAt,
        String notes
    ) throws SQLException {
        String sql = ""
            + "INSERT INTO wafer_status_history (wafer_id, status_id, effective_at, cleared_at, notes) "
            + "SELECT ?, status_id, ?, ?, ? FROM wafer_statuses WHERE code = ?";
        try (PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            statement.setLong(1, waferId);
            statement.setString(2, effectiveAt);
            statement.setString(3, clearedAt);
            statement.setString(4, notes);
            statement.setString(5, statusCode);
            int updated = statement.executeUpdate();
            if (updated == 0) {
                throw new IllegalArgumentException("Unknown status code: " + statusCode);
            }
            try (ResultSet keys = statement.getGeneratedKeys()) {
                if (!keys.next()) {
                    throw new SQLException("Status row insert did not return a key.");
                }
                return keys.getLong(1);
            }
        }
    }

    private Map<String, Object> createActivity(Connection connection, long waferId, HttpServletRequest request)
        throws SQLException {
        String sql = ""
            + "INSERT INTO wafer_activities ("
            + "wafer_id, purpose_id, observed_status_id, location_id, exposure_quantity, "
            + "exposure_unit, started_at, ended_at, observations"
            + ") VALUES ("
            + "?, "
            + "(SELECT purpose_id FROM usage_purposes WHERE code = ?), "
            + "(SELECT status_id FROM wafer_statuses WHERE code = ?), "
            + "(SELECT location_id FROM locations WHERE code = ?), "
            + "?, ?, ?, ?, ?"
            + ")";

        try (PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            statement.setLong(1, waferId);
            statement.setString(2, RequestUtil.required(request, "purposeCode"));
            statement.setString(3, RequestUtil.optional(request, "observedStatusCode"));
            statement.setString(4, RequestUtil.required(request, "locationCode"));
            Double exposureQuantity = RequestUtil.optionalDouble(request, "exposureQuantity");
            if (exposureQuantity == null) {
                throw new IllegalArgumentException("Missing required parameter: exposureQuantity");
            }
            statement.setDouble(5, exposureQuantity);
            statement.setString(6, RequestUtil.required(request, "exposureUnit"));
            statement.setString(7, RequestUtil.optional(request, "startedAt"));
            statement.setString(8, RequestUtil.optional(request, "endedAt"));
            statement.setString(9, RequestUtil.optional(request, "observations"));

            statement.executeUpdate();
            long activityId;
            try (ResultSet keys = statement.getGeneratedKeys()) {
                if (!keys.next()) {
                    throw new SQLException("Activity row insert did not return a key.");
                }
                activityId = keys.getLong(1);
            }

            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("ok", true);
            payload.put("waferId", waferId);
            payload.put("activityId", activityId);
            payload.put("detail", queryWaferDetail(connection, waferId));
            return payload;
        }
    }

    private Map<String, Object> mapWaferRow(ResultSet resultSet) throws SQLException {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("waferId", resultSet.getLong("wafer_id"));
        row.put("name", resultSet.getString("name"));
        row.put("acquiredDate", resultSet.getString("acquired_date"));
        row.put("referenceInvoice", resultSet.getString("reference_invoice"));
        row.put("roughnessNm", resultSet.getObject("roughness_nm"));
        row.put("waferType", resultSet.getString("wafer_type"));
        row.put("waferSizeIn", resultSet.getObject("wafer_size_in"));
        row.put("waferSizeLabel", resultSet.getString("wafer_size_label"));
        row.put("notes", resultSet.getString("notes"));
        row.put("createdAt", resultSet.getString("created_at"));
        row.put("statusCode", resultSet.getString("status_code"));
        row.put("statusLabel", resultSet.getString("status_label"));
        row.put("statusEffectiveAt", resultSet.getString("status_effective_at"));
        return row;
    }

    private void bind(PreparedStatement statement, List<Object> values) throws SQLException {
        for (int index = 0; index < values.size(); index++) {
            statement.setObject(index + 1, values.get(index));
        }
    }

    private void bindNullableDouble(PreparedStatement statement, int index, Double value) throws SQLException {
        if (value == null) {
            statement.setObject(index, null);
        } else {
            statement.setDouble(index, value);
        }
    }
}
