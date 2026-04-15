package it.infn.virgo.waferdb.api;

import java.lang.reflect.Array;
import java.util.Iterator;
import java.util.Map;

final class JsonUtil {
    private JsonUtil() {
    }

    static String stringify(Object value) {
        StringBuilder builder = new StringBuilder();
        appendValue(builder, value);
        return builder.toString();
    }

    @SuppressWarnings("unchecked")
    private static void appendValue(StringBuilder builder, Object value) {
        if (value == null) {
            builder.append("null");
            return;
        }

        if (value instanceof String) {
            appendString(builder, (String) value);
            return;
        }

        if (value instanceof Number || value instanceof Boolean) {
            builder.append(value);
            return;
        }

        if (value instanceof Map) {
            builder.append('{');
            Iterator<Map.Entry<Object, Object>> iterator = ((Map<Object, Object>) value).entrySet().iterator();
            while (iterator.hasNext()) {
                Map.Entry<Object, Object> entry = iterator.next();
                appendString(builder, String.valueOf(entry.getKey()));
                builder.append(':');
                appendValue(builder, entry.getValue());
                if (iterator.hasNext()) {
                    builder.append(',');
                }
            }
            builder.append('}');
            return;
        }

        if (value instanceof Iterable) {
            builder.append('[');
            Iterator<?> iterator = ((Iterable<?>) value).iterator();
            while (iterator.hasNext()) {
                appendValue(builder, iterator.next());
                if (iterator.hasNext()) {
                    builder.append(',');
                }
            }
            builder.append(']');
            return;
        }

        if (value.getClass().isArray()) {
            builder.append('[');
            int length = Array.getLength(value);
            for (int index = 0; index < length; index++) {
                appendValue(builder, Array.get(value, index));
                if (index + 1 < length) {
                    builder.append(',');
                }
            }
            builder.append(']');
            return;
        }

        appendString(builder, String.valueOf(value));
    }

    private static void appendString(StringBuilder builder, String value) {
        builder.append('"');
        for (int index = 0; index < value.length(); index++) {
            char current = value.charAt(index);
            switch (current) {
                case '"':
                    builder.append("\\\"");
                    break;
                case '\\':
                    builder.append("\\\\");
                    break;
                case '\b':
                    builder.append("\\b");
                    break;
                case '\f':
                    builder.append("\\f");
                    break;
                case '\n':
                    builder.append("\\n");
                    break;
                case '\r':
                    builder.append("\\r");
                    break;
                case '\t':
                    builder.append("\\t");
                    break;
                default:
                    if (current < 0x20) {
                        builder.append(String.format("\\u%04x", (int) current));
                    } else {
                        builder.append(current);
                    }
            }
        }
        builder.append('"');
    }
}
