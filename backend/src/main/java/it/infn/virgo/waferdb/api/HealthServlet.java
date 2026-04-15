package it.infn.virgo.waferdb.api;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

public final class HealthServlet extends BaseApiServlet {
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try (Connection connection = openConnection();
             PreparedStatement statement = connection.prepareStatement("SELECT COUNT(*) FROM wafers");
             ResultSet resultSet = statement.executeQuery()) {
            resultSet.next();

            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("ok", true);
            payload.put("databasePath", config().databasePath());
            payload.put("waferCount", resultSet.getInt(1));
            sendOk(response, payload);
        } catch (SQLException exception) {
            sendError(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, exception.getMessage());
        }
    }
}
