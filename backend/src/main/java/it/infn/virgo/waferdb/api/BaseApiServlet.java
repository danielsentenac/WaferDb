package it.infn.virgo.waferdb.api;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

abstract class BaseApiServlet extends HttpServlet {
    @Override
    protected void service(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
        try {
            DatabaseConfig config = config();
            response.setCharacterEncoding("UTF-8");
            response.setContentType("application/json");
            response.setHeader("Access-Control-Allow-Origin", config.allowedOrigin());
            response.setHeader("Access-Control-Allow-Headers", "Content-Type");
            response.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");

            if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
                response.setStatus(HttpServletResponse.SC_NO_CONTENT);
                return;
            }
            super.service(request, response);
        } catch (SQLException exception) {
            throw new ServletException(exception);
        }
    }

    protected DatabaseConfig config() throws SQLException {
        return DatabaseConfig.from(getServletContext());
    }

    protected Connection openConnection() throws SQLException {
        return config().openConnection();
    }

    protected void sendJson(HttpServletResponse response, int status, Object payload) throws IOException {
        response.setStatus(status);
        response.getWriter().write(JsonUtil.stringify(payload));
    }

    protected void sendError(HttpServletResponse response, int status, String message) throws IOException {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("ok", false);
        payload.put("error", message);
        sendJson(response, status, payload);
    }

    protected void sendOk(HttpServletResponse response, Object payload) throws IOException {
        sendJson(response, HttpServletResponse.SC_OK, payload);
    }

    protected void sendCreated(HttpServletResponse response, Object payload) throws IOException {
        sendJson(response, HttpServletResponse.SC_CREATED, payload);
    }

    protected boolean isConstraintError(SQLException exception) {
        String message = exception.getMessage();
        return message != null && message.contains("SQLITE_CONSTRAINT");
    }
}
