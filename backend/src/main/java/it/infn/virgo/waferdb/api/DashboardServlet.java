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

public final class DashboardServlet extends BaseApiServlet {
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try (Connection connection = openConnection()) {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("ok", true);
            payload.put("summary", querySummary(connection));
            payload.put("statusBreakdown", queryStatusBreakdown(connection));
            payload.put("recentActivities", queryRecentActivities(connection));
            sendOk(response, payload);
        } catch (SQLException exception) {
            sendError(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, exception.getMessage());
        }
    }

    private Map<String, Object> querySummary(Connection connection) throws SQLException {
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("wafers", singleCount(connection, "SELECT COUNT(*) FROM wafers"));
        summary.put("activities", singleCount(connection, "SELECT COUNT(*) FROM wafer_activities"));
        summary.put("darkfieldRuns", singleCount(connection, "SELECT COUNT(*) FROM darkfield_runs"));
        return summary;
    }

    private long singleCount(Connection connection, String sql) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            resultSet.next();
            return resultSet.getLong(1);
        }
    }

    private List<Map<String, Object>> queryStatusBreakdown(Connection connection) throws SQLException {
        String sql = ""
            + "SELECT COALESCE(status_code, 'unassigned') AS status_code, "
            + "COALESCE(status_label, 'Unassigned') AS status_label, COUNT(*) AS wafer_count "
            + "FROM wafer_current_status "
            + "GROUP BY COALESCE(status_code, 'unassigned'), COALESCE(status_label, 'Unassigned') "
            + "ORDER BY wafer_count DESC, status_code ASC";
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<Map<String, Object>> items = new ArrayList<>();
            while (resultSet.next()) {
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("statusCode", resultSet.getString("status_code"));
                item.put("statusLabel", resultSet.getString("status_label"));
                item.put("waferCount", resultSet.getLong("wafer_count"));
                items.add(item);
            }
            return items;
        }
    }

    private List<Map<String, Object>> queryRecentActivities(Connection connection) throws SQLException {
        String sql = ""
            + "SELECT activity_id, wafer_name, purpose_label, location_name, exposure_quantity, exposure_unit, "
            + "started_at, ended_at, created_at "
            + "FROM wafer_activity_timeline "
            + "ORDER BY COALESCE(datetime(ended_at), datetime(started_at), datetime(created_at)) DESC "
            + "LIMIT 8";
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<Map<String, Object>> items = new ArrayList<>();
            while (resultSet.next()) {
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("activityId", resultSet.getLong("activity_id"));
                item.put("waferName", resultSet.getString("wafer_name"));
                item.put("purposeLabel", resultSet.getString("purpose_label"));
                item.put("locationName", resultSet.getString("location_name"));
                item.put("exposureQuantity", resultSet.getDouble("exposure_quantity"));
                item.put("exposureUnit", resultSet.getString("exposure_unit"));
                item.put("startedAt", resultSet.getString("started_at"));
                item.put("endedAt", resultSet.getString("ended_at"));
                item.put("createdAt", resultSet.getString("created_at"));
                items.add(item);
            }
            return items;
        }
    }
}
