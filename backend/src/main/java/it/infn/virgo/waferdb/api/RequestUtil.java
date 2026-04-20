package it.infn.virgo.waferdb.api;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

final class RequestUtil {
    private RequestUtil() {
    }

    static HttpServletRequest withParsedBody(HttpServletRequest request) throws IOException {
        String body = request.getReader().lines().collect(Collectors.joining());
        if (body == null || body.isEmpty()) {
            return request;
        }
        Map<String, String[]> bodyParams = new HashMap<>();
        for (String pair : body.split("&")) {
            int eq = pair.indexOf('=');
            if (eq < 0) continue;
            try {
                String key = URLDecoder.decode(pair.substring(0, eq), "UTF-8");
                String val = URLDecoder.decode(pair.substring(eq + 1), "UTF-8");
                bodyParams.put(key, new String[]{val});
            } catch (UnsupportedEncodingException ignored) {
            }
        }
        return new HttpServletRequestWrapper(request) {
            @Override
            public String getParameter(String name) {
                String[] vals = bodyParams.get(name);
                return (vals != null && vals.length > 0) ? vals[0] : super.getParameter(name);
            }
            @Override
            public Map<String, String[]> getParameterMap() {
                Map<String, String[]> merged = new HashMap<>(super.getParameterMap());
                merged.putAll(bodyParams);
                return merged;
            }
            @Override
            public Enumeration<String> getParameterNames() {
                Set<String> names = new HashSet<>(Collections.list(super.getParameterNames()));
                names.addAll(bodyParams.keySet());
                return Collections.enumeration(names);
            }
            @Override
            public String[] getParameterValues(String name) {
                String[] vals = bodyParams.get(name);
                return vals != null ? vals : super.getParameterValues(name);
            }
        };
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

    static int requiredInteger(HttpServletRequest request, String parameter) {
        String value = required(request, parameter);
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("Invalid integer value for " + parameter + ": " + value);
        }
    }

    static Long optionalLong(HttpServletRequest request, String parameter) {
        String value = optional(request, parameter);
        if (value == null) {
            return null;
        }
        try {
            return Long.parseLong(value);
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
