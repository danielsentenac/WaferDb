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
import java.util.Base64;
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

            if (segments.size() == 4
                && "statuses".equals(segments.get(1))
                && "photo".equals(segments.get(3))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                long statusHistoryId = RequestUtil.requiredLongPathSegment(segments.get(2), "status history id");
                sendStatusPhoto(response, connection, waferId, statusHistoryId);
                return;
            }

            if (segments.size() == 4
                && "history".equals(segments.get(1))
                && "photo".equals(segments.get(3))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                long historyId = RequestUtil.requiredLongPathSegment(segments.get(2), "history id");
                sendHistoryPhoto(response, connection, waferId, historyId);
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

            if (segments.size() == 2 && "history".equals(segments.get(1))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                sendCreated(response, createMetadataHistory(connection, waferId, request));
                return;
            }

            if (segments.size() == 2 && "activities".equals(segments.get(1))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                sendCreated(response, createActivity(connection, waferId, request));
                return;
            }

            if (segments.size() == 2 && "darkfield-runs".equals(segments.get(1))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                sendCreated(response, createDarkfieldRun(connection, waferId, request));
                return;
            }

            if (segments.size() == 4
                && "statuses".equals(segments.get(1))
                && "photo".equals(segments.get(3))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                long statusHistoryId = RequestUtil.requiredLongPathSegment(segments.get(2), "status history id");
                sendOk(response, attachStatusPhoto(connection, waferId, statusHistoryId, request));
                return;
            }

            if (segments.size() == 4
                && "history".equals(segments.get(1))
                && "photo".equals(segments.get(3))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                long historyId = RequestUtil.requiredLongPathSegment(segments.get(2), "history id");
                sendOk(response, attachHistoryPhoto(connection, waferId, historyId, request));
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

    @Override
    protected void doDelete(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try (Connection connection = openConnection()) {
            List<String> segments = RequestUtil.pathSegments(request);

            if (segments.size() == 3 && "history".equals(segments.get(1))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                long historyId = RequestUtil.requiredLongPathSegment(segments.get(2), "history id");
                sendOk(response, deleteRow(connection, waferId,
                    "DELETE FROM wafer_metadata_history WHERE wafer_id = ? AND wafer_metadata_history_id = ?",
                    historyId));
                return;
            }

            if (segments.size() == 3 && "statuses".equals(segments.get(1))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                long statusHistoryId = RequestUtil.requiredLongPathSegment(segments.get(2), "status history id");
                sendOk(response, deleteRow(connection, waferId,
                    "DELETE FROM wafer_status_history WHERE wafer_id = ? AND wafer_status_history_id = ?",
                    statusHistoryId));
                return;
            }

            if (segments.size() == 3 && "activities".equals(segments.get(1))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                long activityId = RequestUtil.requiredLongPathSegment(segments.get(2), "activity id");
                sendOk(response, deleteRow(connection, waferId,
                    "DELETE FROM wafer_activities WHERE wafer_id = ? AND activity_id = ?",
                    activityId));
                return;
            }

            if (segments.size() == 3 && "darkfield-runs".equals(segments.get(1))) {
                long waferId = RequestUtil.requiredLongPathSegment(segments.get(0), "wafer id");
                long runId = RequestUtil.requiredLongPathSegment(segments.get(2), "darkfield run id");
                sendOk(response, deleteRow(connection, waferId,
                    "DELETE FROM darkfield_runs WHERE wafer_id = ? AND darkfield_run_id = ?",
                    runId));
                return;
            }

            sendError(response, HttpServletResponse.SC_NOT_FOUND, "Unsupported wafer API path.");
        } catch (IllegalArgumentException exception) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, exception.getMessage());
        } catch (SQLException exception) {
            sendError(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, exception.getMessage());
        }
    }

    private Map<String, Object> deleteRow(
        Connection connection,
        long waferId,
        String sql,
        long rowId
    ) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, waferId);
            statement.setLong(2, rowId);
            if (statement.executeUpdate() == 0) {
                throw new IllegalArgumentException("Record not found.");
            }
        }
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("ok", true);
        payload.put("detail", queryWaferDetail(connection, waferId));
        return payload;
    }

    private Map<String, Object> queryWaferList(Connection connection, HttpServletRequest request) throws SQLException {
        String query = RequestUtil.optional(request, "q");
        String statusCode = RequestUtil.optional(request, "status");
        int limit = RequestUtil.optionalInteger(request, "limit", 50, 500);

        StringBuilder sql = new StringBuilder()
            .append("SELECT w.wafer_id, w.name, w.acquired_date, w.reference_invoice, w.roughness_nm, ")
            .append("w.wafer_type, w.wafer_size_in, w.notes, w.created_at, ")
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
            + "w.wafer_type, w.wafer_size_in, w.notes, w.created_at, "
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
        payload.put("metadataHistory", queryMetadataHistory(connection, waferId));
        payload.put("statusHistory", queryStatusHistory(connection, waferId));
        payload.put("activities", queryActivities(connection, waferId));
        payload.put("darkfieldRuns", queryDarkfieldRuns(connection, waferId));
        return payload;
    }

    private List<Map<String, Object>> queryMetadataHistory(Connection connection, long waferId) throws SQLException {
        String sql = ""
            + "SELECT wafer_metadata_history_id, changed_at, name, acquired_date, reference_invoice, roughness_nm, "
            + "wafer_type, wafer_size_in, notes, change_summary, created_at, "
            + "CASE WHEN photo_blob IS NULL THEN 0 ELSE 1 END AS has_photo "
            + "FROM wafer_metadata_history WHERE wafer_id = ? "
            + "ORDER BY datetime(changed_at) DESC, wafer_metadata_history_id DESC";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, waferId);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<Map<String, Object>> items = new ArrayList<>();
                while (resultSet.next()) {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("waferMetadataHistoryId", resultSet.getLong("wafer_metadata_history_id"));
                    item.put("changedAt", resultSet.getString("changed_at"));
                    item.put("name", resultSet.getString("name"));
                    item.put("acquiredDate", resultSet.getString("acquired_date"));
                    item.put("referenceInvoice", resultSet.getString("reference_invoice"));
                    item.put("roughnessNm", resultSet.getObject("roughness_nm"));
                    item.put("waferType", resultSet.getString("wafer_type"));
                    item.put("waferSizeIn", resultSet.getObject("wafer_size_in"));
                    item.put("notes", resultSet.getString("notes"));
                    item.put("changeSummary", resultSet.getString("change_summary"));
                    item.put("createdAt", resultSet.getString("created_at"));
                    item.put("hasPhoto", resultSet.getInt("has_photo") == 1);
                    items.add(item);
                }
                return items;
            }
        }
    }

    private List<Map<String, Object>> queryStatusHistory(Connection connection, long waferId) throws SQLException {
        String sql = ""
            + "SELECT h.wafer_status_history_id, s.code AS status_code, s.label AS status_label, "
            + "h.effective_at, h.cleared_at, h.notes, "
            + "CASE WHEN h.photo_blob IS NULL THEN 0 ELSE 1 END AS has_photo "
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
                    item.put("hasPhoto", resultSet.getInt("has_photo") == 1);
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
                    long darkfieldRunId = resultSet.getLong("darkfield_run_id");
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("darkfieldRunId", darkfieldRunId);
                    item.put("activityId", resultSet.getObject("activity_id"));
                    item.put("runType", resultSet.getString("run_type"));
                    item.put("measuredAt", resultSet.getString("measured_at"));
                    item.put("summaryNotes", resultSet.getString("summary_notes"));
                    item.put("dataPath", resultSet.getString("data_path"));
                    item.put("createdAt", resultSet.getString("created_at"));
                    item.put("binSummaries", queryDarkfieldBinSummaries(connection, darkfieldRunId));
                    items.add(item);
                }
                return items;
            }
        }
    }

    private List<Map<String, Object>> queryDarkfieldBinSummaries(Connection connection, long darkfieldRunId)
        throws SQLException {
        String sql = ""
            + "SELECT bin_summary_id, bin_order, bin_label, min_size_um, max_size_um, particle_count, "
            + "total_area_um2, particle_density_cm2, notes "
            + "FROM darkfield_bin_summaries WHERE darkfield_run_id = ? "
            + "ORDER BY bin_order ASC, bin_summary_id ASC";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, darkfieldRunId);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<Map<String, Object>> items = new ArrayList<>();
                while (resultSet.next()) {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("binSummaryId", resultSet.getLong("bin_summary_id"));
                    item.put("binOrder", resultSet.getInt("bin_order"));
                    item.put("binLabel", resultSet.getString("bin_label"));
                    item.put("minSizeUm", resultSet.getObject("min_size_um"));
                    item.put("maxSizeUm", resultSet.getObject("max_size_um"));
                    item.put("particleCount", resultSet.getInt("particle_count"));
                    item.put("totalAreaUm2", resultSet.getObject("total_area_um2"));
                    item.put("particleDensityCm2", resultSet.getObject("particle_density_cm2"));
                    item.put("notes", resultSet.getString("notes"));
                    items.add(item);
                }
                return items;
            }
        }
    }

    private Map<String, Object> createWafer(Connection connection, HttpServletRequest request) throws SQLException {
        String sql = ""
            + "INSERT INTO wafers ("
            + "name, acquired_date, reference_invoice, roughness_nm, wafer_type, wafer_size_in, notes"
            + ") VALUES (?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            statement.setString(1, RequestUtil.required(request, "name"));
            statement.setString(2, RequestUtil.required(request, "acquiredDate"));
            statement.setString(3, RequestUtil.optional(request, "referenceInvoice"));
            bindNullableDouble(statement, 4, RequestUtil.optionalDouble(request, "roughnessNm"));
            statement.setString(5, RequestUtil.required(request, "waferType"));
            bindNullableDouble(statement, 6, RequestUtil.optionalDouble(request, "waferSizeIn"));
            statement.setString(7, RequestUtil.optional(request, "notes"));
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
                    RequestUtil.optional(request, "initialStatusNotes"),
                    null,
                    null
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
            RequestUtil.optional(request, "notes"),
            null,
            null
        );

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("ok", true);
        payload.put("waferId", waferId);
        payload.put("waferStatusHistoryId", rowId);
        payload.put("detail", queryWaferDetail(connection, waferId));
        return payload;
    }

    private Map<String, Object> createMetadataHistory(Connection connection, long waferId, HttpServletRequest request)
        throws SQLException {
        boolean originalAutoCommit = connection.getAutoCommit();
        connection.setAutoCommit(false);

        try {
            String name = RequestUtil.required(request, "name");
            String acquiredDate = RequestUtil.required(request, "acquiredDate");
            String referenceInvoice = RequestUtil.optional(request, "referenceInvoice");
            Double roughnessNm = RequestUtil.optionalDouble(request, "roughnessNm");
            String waferType = RequestUtil.required(request, "waferType");
            Double waferSizeIn = RequestUtil.optionalDouble(request, "waferSizeIn");
            String notes = RequestUtil.optional(request, "notes");

            updateWaferMetadata(
                connection,
                waferId,
                name,
                acquiredDate,
                referenceInvoice,
                roughnessNm,
                waferType,
                waferSizeIn,
                notes
            );

            StatusPhoto photo = extractStatusPhoto(request);

            long rowId = insertMetadataHistory(
                connection,
                waferId,
                RequestUtil.required(request, "changedAt"),
                name,
                acquiredDate,
                referenceInvoice,
                roughnessNm,
                waferType,
                waferSizeIn,
                notes,
                RequestUtil.optional(request, "changeSummary"),
                photo.contentType,
                photo.bytes
            );

            connection.commit();

            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("ok", true);
            payload.put("waferId", waferId);
            payload.put("waferMetadataHistoryId", rowId);
            payload.put("detail", queryWaferDetail(connection, waferId));
            return payload;
        } catch (SQLException exception) {
            connection.rollback();
            throw exception;
        } catch (RuntimeException exception) {
            connection.rollback();
            throw exception;
        } finally {
            connection.setAutoCommit(originalAutoCommit);
        }
    }

    private long insertStatusHistory(
        Connection connection,
        long waferId,
        String statusCode,
        String effectiveAt,
        String clearedAt,
        String notes,
        String photoContentType,
        byte[] photoBytes
    ) throws SQLException {
        String sql = ""
            + "INSERT INTO wafer_status_history ("
            + "wafer_id, status_id, effective_at, cleared_at, notes, photo_content_type, photo_blob"
            + ") "
            + "SELECT ?, status_id, ?, ?, ?, ?, ? FROM wafer_statuses WHERE code = ?";
        try (PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            statement.setLong(1, waferId);
            statement.setString(2, effectiveAt);
            statement.setString(3, clearedAt);
            statement.setString(4, notes);
            statement.setString(5, photoContentType);
            statement.setBytes(6, photoBytes);
            statement.setString(7, statusCode);
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

    private void updateWaferMetadata(
        Connection connection,
        long waferId,
        String name,
        String acquiredDate,
        String referenceInvoice,
        Double roughnessNm,
        String waferType,
        Double waferSizeIn,
        String notes
    ) throws SQLException {
        String sql = ""
            + "UPDATE wafers SET "
            + "name = ?, acquired_date = ?, reference_invoice = ?, roughness_nm = ?, wafer_type = ?, "
            + "wafer_size_in = ?, notes = ? "
            + "WHERE wafer_id = ?";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, name);
            statement.setString(2, acquiredDate);
            statement.setString(3, referenceInvoice);
            bindNullableDouble(statement, 4, roughnessNm);
            statement.setString(5, waferType);
            bindNullableDouble(statement, 6, waferSizeIn);
            statement.setString(7, notes);
            statement.setLong(8, waferId);
            if (statement.executeUpdate() == 0) {
                throw new IllegalArgumentException("Wafer not found.");
            }
        }
    }

    private long insertMetadataHistory(
        Connection connection,
        long waferId,
        String changedAt,
        String name,
        String acquiredDate,
        String referenceInvoice,
        Double roughnessNm,
        String waferType,
        Double waferSizeIn,
        String notes,
        String changeSummary,
        String photoContentType,
        byte[] photoBytes
    ) throws SQLException {
        String sql = ""
            + "INSERT INTO wafer_metadata_history ("
            + "wafer_id, changed_at, name, acquired_date, reference_invoice, roughness_nm, "
            + "wafer_type, wafer_size_in, notes, change_summary, photo_content_type, photo_blob"
            + ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            statement.setLong(1, waferId);
            statement.setString(2, changedAt);
            statement.setString(3, name);
            statement.setString(4, acquiredDate);
            statement.setString(5, referenceInvoice);
            bindNullableDouble(statement, 6, roughnessNm);
            statement.setString(7, waferType);
            bindNullableDouble(statement, 8, waferSizeIn);
            statement.setString(9, notes);
            statement.setString(10, changeSummary);
            statement.setString(11, photoContentType);
            statement.setBytes(12, photoBytes);
            statement.executeUpdate();
            try (ResultSet keys = statement.getGeneratedKeys()) {
                if (!keys.next()) {
                    throw new SQLException("Wafer metadata history insert did not return a key.");
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

    private Map<String, Object> createDarkfieldRun(Connection connection, long waferId, HttpServletRequest request)
        throws SQLException {
        boolean originalAutoCommit = connection.getAutoCommit();
        connection.setAutoCommit(false);

        try {
            Long activityId = RequestUtil.optionalLong(request, "activityId");
            if (activityId != null && !activityBelongsToWafer(connection, waferId, activityId.longValue())) {
                throw new IllegalArgumentException(
                    "Activity " + activityId + " does not belong to wafer " + waferId + '.'
                );
            }

            long darkfieldRunId;
            String sql = ""
                + "INSERT INTO darkfield_runs ("
                + "wafer_id, activity_id, run_type, measured_at, summary_notes, data_path"
                + ") VALUES (?, ?, ?, ?, ?, ?)";
            try (PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
                statement.setLong(1, waferId);
                statement.setObject(2, activityId);
                statement.setString(3, RequestUtil.required(request, "runType"));
                statement.setString(4, RequestUtil.required(request, "measuredAt"));
                statement.setString(5, RequestUtil.optional(request, "summaryNotes"));
                statement.setString(6, RequestUtil.required(request, "dataPath"));
                statement.executeUpdate();

                try (ResultSet keys = statement.getGeneratedKeys()) {
                    if (!keys.next()) {
                        throw new SQLException("Darkfield run insert did not return a key.");
                    }
                    darkfieldRunId = keys.getLong(1);
                }
            }

            int binCount = RequestUtil.optionalInteger(request, "binCount", 0, 200);
            for (int index = 0; index < binCount; index++) {
                insertDarkfieldBinSummary(connection, darkfieldRunId, index + 1, request, "bin" + index + "_");
            }

            connection.commit();

            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("ok", true);
            payload.put("waferId", waferId);
            payload.put("darkfieldRunId", darkfieldRunId);
            payload.put("detail", queryWaferDetail(connection, waferId));
            return payload;
        } catch (SQLException exception) {
            connection.rollback();
            throw exception;
        } catch (RuntimeException exception) {
            connection.rollback();
            throw exception;
        } finally {
            connection.setAutoCommit(originalAutoCommit);
        }
    }

    private boolean activityBelongsToWafer(Connection connection, long waferId, long activityId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM wafer_activities WHERE wafer_id = ? AND activity_id = ?";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, waferId);
            statement.setLong(2, activityId);
            try (ResultSet resultSet = statement.executeQuery()) {
                resultSet.next();
                return resultSet.getLong(1) == 1;
            }
        }
    }

    private void insertDarkfieldBinSummary(
        Connection connection,
        long darkfieldRunId,
        int binOrder,
        HttpServletRequest request,
        String prefix
    ) throws SQLException {
        String sql = ""
            + "INSERT INTO darkfield_bin_summaries ("
            + "darkfield_run_id, bin_order, bin_label, min_size_um, max_size_um, particle_count, "
            + "total_area_um2, particle_density_cm2, notes"
            + ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, darkfieldRunId);
            statement.setInt(2, binOrder);
            statement.setString(3, RequestUtil.optional(request, prefix + "label"));
            bindNullableDouble(statement, 4, RequestUtil.optionalDouble(request, prefix + "minSizeUm"));
            bindNullableDouble(statement, 5, RequestUtil.optionalDouble(request, prefix + "maxSizeUm"));
            statement.setInt(6, RequestUtil.requiredInteger(request, prefix + "particleCount"));
            bindNullableDouble(statement, 7, RequestUtil.optionalDouble(request, prefix + "totalAreaUm2"));
            bindNullableDouble(statement, 8, RequestUtil.optionalDouble(request, prefix + "particleDensityCm2"));
            statement.setString(9, RequestUtil.optional(request, prefix + "notes"));
            statement.executeUpdate();
        }
    }

    private Map<String, Object> attachStatusPhoto(
        Connection connection,
        long waferId,
        long statusHistoryId,
        HttpServletRequest request
    ) throws SQLException {
        StatusPhoto photo = extractStatusPhoto(request);
        if (photo.bytes == null || photo.bytes.length == 0) {
            throw new IllegalArgumentException("No photo data provided.");
        }

        String sql = ""
            + "UPDATE wafer_status_history "
            + "SET photo_content_type = ?, photo_blob = ? "
            + "WHERE wafer_id = ? AND wafer_status_history_id = ?";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, photo.contentType);
            statement.setBytes(2, photo.bytes);
            statement.setLong(3, waferId);
            statement.setLong(4, statusHistoryId);
            if (statement.executeUpdate() == 0) {
                throw new IllegalArgumentException("Status history record not found.");
            }
        }

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("ok", true);
        payload.put("waferId", waferId);
        payload.put("waferStatusHistoryId", statusHistoryId);
        payload.put("detail", queryWaferDetail(connection, waferId));
        return payload;
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

    private StatusPhoto extractStatusPhoto(HttpServletRequest request) {
        String photoBase64 = RequestUtil.optional(request, "photoBase64");
        if (photoBase64 == null) {
            return StatusPhoto.empty();
        }

        String contentType = RequestUtil.optional(request, "photoContentType");
        if (contentType == null) {
            contentType = "image/jpeg";
        }
        if (!contentType.startsWith("image/")) {
            throw new IllegalArgumentException("Invalid photo content type: " + contentType);
        }

        byte[] bytes;
        try {
            bytes = Base64.getDecoder().decode(photoBase64);
        } catch (IllegalArgumentException exception) {
            throw new IllegalArgumentException("Invalid base64 photo payload.");
        }
        if (bytes.length == 0) {
            return StatusPhoto.empty();
        }
        if (bytes.length > 8 * 1024 * 1024) {
            throw new IllegalArgumentException("Photo is too large. Limit is 8 MB.");
        }
        return new StatusPhoto(contentType, bytes);
    }

    private void sendStatusPhoto(
        HttpServletResponse response,
        Connection connection,
        long waferId,
        long statusHistoryId
    ) throws SQLException, IOException {
        String sql = ""
            + "SELECT photo_content_type, photo_blob "
            + "FROM wafer_status_history "
            + "WHERE wafer_id = ? AND wafer_status_history_id = ?";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, waferId);
            statement.setLong(2, statusHistoryId);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (!resultSet.next()) {
                    sendError(response, HttpServletResponse.SC_NOT_FOUND, "Status photo not found.");
                    return;
                }

                byte[] bytes = resultSet.getBytes("photo_blob");
                if (bytes == null || bytes.length == 0) {
                    sendError(response, HttpServletResponse.SC_NOT_FOUND, "Status photo not found.");
                    return;
                }

                String contentType = resultSet.getString("photo_content_type");
                response.setStatus(HttpServletResponse.SC_OK);
                response.setContentType(contentType == null ? "image/jpeg" : contentType);
                response.getOutputStream().write(bytes);
            }
        }
    }

    private Map<String, Object> attachHistoryPhoto(
        Connection connection,
        long waferId,
        long historyId,
        HttpServletRequest request
    ) throws SQLException {
        StatusPhoto photo = extractStatusPhoto(request);
        if (photo.bytes == null || photo.bytes.length == 0) {
            throw new IllegalArgumentException("No photo data provided.");
        }
        String sql = ""
            + "UPDATE wafer_metadata_history "
            + "SET photo_content_type = ?, photo_blob = ? "
            + "WHERE wafer_id = ? AND wafer_metadata_history_id = ?";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, photo.contentType);
            statement.setBytes(2, photo.bytes);
            statement.setLong(3, waferId);
            statement.setLong(4, historyId);
            if (statement.executeUpdate() == 0) {
                throw new IllegalArgumentException("History record not found.");
            }
        }
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("ok", true);
        payload.put("waferId", waferId);
        payload.put("waferMetadataHistoryId", historyId);
        payload.put("detail", queryWaferDetail(connection, waferId));
        return payload;
    }

    private void sendHistoryPhoto(
        HttpServletResponse response,
        Connection connection,
        long waferId,
        long historyId
    ) throws SQLException, IOException {
        String sql = ""
            + "SELECT photo_content_type, photo_blob "
            + "FROM wafer_metadata_history "
            + "WHERE wafer_id = ? AND wafer_metadata_history_id = ?";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, waferId);
            statement.setLong(2, historyId);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (!resultSet.next()) {
                    sendError(response, HttpServletResponse.SC_NOT_FOUND, "History photo not found.");
                    return;
                }
                byte[] bytes = resultSet.getBytes("photo_blob");
                if (bytes == null || bytes.length == 0) {
                    sendError(response, HttpServletResponse.SC_NOT_FOUND, "History photo not found.");
                    return;
                }
                String contentType = resultSet.getString("photo_content_type");
                response.setStatus(HttpServletResponse.SC_OK);
                response.setContentType(contentType == null ? "image/jpeg" : contentType);
                response.getOutputStream().write(bytes);
            }
        }
    }

    private static final class StatusPhoto {
        private static final StatusPhoto EMPTY = new StatusPhoto(null, null);

        private final String contentType;
        private final byte[] bytes;

        private StatusPhoto(String contentType, byte[] bytes) {
            this.contentType = contentType;
            this.bytes = bytes;
        }

        private static StatusPhoto empty() {
            return EMPTY;
        }
    }
}
