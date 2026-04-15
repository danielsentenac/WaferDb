package it.infn.virgo.waferdb.api;

import javax.servlet.http.HttpServletRequest;
import java.util.ArrayList;
import java.util.List;

final class RequestUtil {
    private RequestUtil() {
    }

    static String required(HttpServletRequest request, String parameter) {
        String value = optional(request, parameter);
        if (value == null) {
            throw new IllegalArgumentException("Missing required parameter: " + parameter);
        }
        return value;
    }

    static String optional(HttpServletRequest request, String parameter) {
        String value = request.getParameter(parameter);
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    static Double optionalDouble(HttpServletRequest request, String parameter) {
        String value = optional(request, parameter);
        if (value == null) {
            return null;
        }
        try {
            return Double.parseDouble(value);
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("Invalid decimal value for " + parameter + ": " + value);
        }
    }

    static Integer optionalInteger(HttpServletRequest request, String parameter, int defaultValue, int maxValue) {
        String value = optional(request, parameter);
        if (value == null) {
            return defaultValue;
        }
        try {
            int parsed = Integer.parseInt(value);
            if (parsed <= 0) {
                throw new IllegalArgumentException("Parameter " + parameter + " must be positive.");
            }
            return Math.min(parsed, maxValue);
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("Invalid integer value for " + parameter + ": " + value);
        }
    }

    static long requiredLongPathSegment(String segment, String description) {
        try {
            return Long.parseLong(segment);
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("Invalid " + description + ": " + segment);
        }
    }

    static List<String> pathSegments(HttpServletRequest request) {
        String pathInfo = request.getPathInfo();
        List<String> segments = new ArrayList<>();
        if (pathInfo == null || pathInfo.trim().isEmpty()) {
            return segments;
        }
        for (String rawSegment : pathInfo.split("/")) {
            if (!rawSegment.trim().isEmpty()) {
                segments.add(rawSegment);
            }
        }
        return segments;
    }
}
