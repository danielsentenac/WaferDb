package it.infn.virgo.waferdb.api;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public final class DarkfieldImportServlet extends BaseApiServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        String pathParam = request.getParameter("path");
        if (pathParam == null || pathParam.trim().isEmpty()) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, "path parameter is required.");
            return;
        }

        try {
            Path requested = Paths.get(pathParam.trim()).toAbsolutePath().normalize();
            Path summaryFile = findSummaryFile(requested);

            if (summaryFile == null) {
                sendError(response, HttpServletResponse.SC_NOT_FOUND,
                    "No summary_stats.txt found under " + requested + ".");
                return;
            }

            byte[] content = Files.readAllBytes(summaryFile);
            String encodedContent = Base64.getEncoder().encodeToString(content);

            Map<String, Double> particleAreas = readParticleAreas(summaryFile.getParent());

            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("ok", true);
            payload.put("path", summaryFile.toString());
            payload.put("content", encodedContent);
            if (!particleAreas.isEmpty()) {
                payload.put("particleAreas", particleAreas);
            }
            sendOk(response, payload);

        } catch (IllegalArgumentException exception) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, exception.getMessage());
        } catch (SecurityException exception) {
            sendError(response, HttpServletResponse.SC_FORBIDDEN, exception.getMessage());
        }
    }

    private Path findSummaryFile(Path requested) throws IOException {
        String[] names = {"summary_stats.txt", "summary_stat.txt"};

        if (Files.isRegularFile(requested)) {
            String filename = requested.getFileName().toString();
            for (String name : names) {
                if (filename.equals(name)) return requested;
            }
            return null;
        }

        if (!Files.isDirectory(requested)) {
            return null;
        }

        for (String name : names) {
            Path direct = requested.resolve(name);
            if (Files.isRegularFile(direct)) return direct;
        }

        List<Path> found = new ArrayList<>();
        for (String name : names) {
            try (Stream<Path> walk = Files.walk(requested)) {
                walk.filter(p -> p.getFileName().toString().equals(name))
                    .sorted()
                    .forEach(found::add);
            }
        }

        if (found.size() == 1) return found.get(0);
        if (found.size() > 1) {
            String preview = found.stream().limit(10)
                .map(Path::toString).collect(Collectors.joining("\n"));
            throw new IllegalArgumentException(
                "Multiple summary_stats.txt files found. Use a more specific path.\n" + preview);
        }

        return null;
    }

    private Map<String, Double> readParticleAreas(Path directory) {
        Map<String, Double> areas = new LinkedHashMap<>();
        try {
            List<Path> csvFiles = new ArrayList<>();
            try (Stream<Path> list = Files.list(directory)) {
                list.filter(p -> p.getFileName().toString().endsWith("_particles.csv"))
                    .sorted()
                    .forEach(csvFiles::add);
            }
            for (Path csv : csvFiles) {
                try (BufferedReader reader = Files.newBufferedReader(csv, StandardCharsets.UTF_8)) {
                    String header = reader.readLine();
                    if (header == null) continue;
                    String[] headers = header.split(",");
                    int binCol = -1, diamCol = -1;
                    for (int i = 0; i < headers.length; i++) {
                        if (headers[i].trim().equals("bin")) binCol = i;
                        if (headers[i].trim().equals("diameter_um")) diamCol = i;
                    }
                    if (binCol < 0 || diamCol < 0) continue;
                    String line;
                    while ((line = reader.readLine()) != null) {
                        String[] cols = line.split(",");
                        if (cols.length <= Math.max(binCol, diamCol)) continue;
                        try {
                            int bin = Integer.parseInt(cols[binCol].trim());
                            double diameter = Double.parseDouble(cols[diamCol].trim());
                            double area = Math.PI * (diameter / 2.0) * (diameter / 2.0);
                            areas.merge(String.valueOf(bin), area, Double::sum);
                        } catch (NumberFormatException ignored) {}
                    }
                }
            }
        } catch (Exception ignored) {}
        return areas;
    }
}
