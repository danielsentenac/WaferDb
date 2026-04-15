package it.infn.virgo.waferdb.api;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class LookupServlet extends BaseApiServlet {
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try (Connection connection = openConnection()) {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("ok", true);
            payload.put("statuses", queryStatuses(connection));
            payload.put("purposes", queryPurposes(connection));
            payload.put("locations", queryLocations(connection));
            sendOk(response, payload);
        } catch (SQLException exception) {
            sendError(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, exception.getMessage());
        }
    }

    private List<Map<String, Object>> queryStatuses(Connection connection) throws SQLException {
        String sql = "SELECT status_id, code, label, description FROM wafer_statuses ORDER BY status_id";
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<Map<String, Object>> items = new ArrayList<>();
            while (resultSet.next()) {
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("statusId", resultSet.getLong("status_id"));
                item.put("code", resultSet.getString("code"));
                item.put("label", resultSet.getString("label"));
                item.put("description", resultSet.getString("description"));
                items.add(item);
            }
            return items;
        }
    }

    private List<Map<String, Object>> queryPurposes(Connection connection) throws SQLException {
        String sql = "SELECT purpose_id, code, label FROM usage_purposes ORDER BY purpose_id";
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<Map<String, Object>> items = new ArrayList<>();
            while (resultSet.next()) {
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("purposeId", resultSet.getLong("purpose_id"));
                item.put("code", resultSet.getString("code"));
                item.put("label", resultSet.getString("label"));
                items.add(item);
            }
            return items;
        }
    }

    private List<Map<String, Object>> queryLocations(Connection connection) throws SQLException {
        String sql = ""
            + "SELECT l.location_id, l.code, l.name, l.parent_location_id, l.is_active, "
            + "lt.code AS location_type_code, lt.label AS location_type_label "
            + "FROM locations l "
            + "JOIN location_types lt ON lt.location_type_id = l.location_type_id "
            + "ORDER BY l.code";
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<Map<String, Object>> items = new ArrayList<>();
            while (resultSet.next()) {
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("locationId", resultSet.getLong("location_id"));
                item.put("code", resultSet.getString("code"));
                item.put("name", resultSet.getString("name"));
                item.put("parentLocationId", resultSet.getObject("parent_location_id"));
                item.put("active", resultSet.getInt("is_active") == 1);
                item.put("locationTypeCode", resultSet.getString("location_type_code"));
                item.put("locationTypeLabel", resultSet.getString("location_type_label"));
                items.add(item);
            }
            return items;
        }
    }
}
