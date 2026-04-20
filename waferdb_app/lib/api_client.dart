import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(String baseUrl)
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');

  final Uri _baseUri;
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 15);

  Future<LookupBundle> fetchLookups() async {
    final payload = await _request('GET', 'lookups');
    return LookupBundle.fromJson(payload);
  }

  Future<LookupBundle> createLocation(Map<String, String> values) async {
    final payload = await _request('POST', 'lookups', formFields: values);
    return LookupBundle.fromJson(payload);
  }

  Future<DashboardData> fetchDashboard() async {
    final payload = await _request('GET', 'dashboard');
    return DashboardData.fromJson(payload);
  }

  Future<List<WaferSummary>> fetchWafers({
    String query = '',
    String? statusCode,
    String? locationCode,
    int limit = 80,
  }) async {
    final payload = await _request(
      'GET',
      'wafers',
      queryParameters: <String, String?>{
        'q': query.isEmpty ? null : query,
        'status': statusCode,
        'location': locationCode,
        'limit': '$limit',
      },
    );
    final items = payload['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map>()
        .map(
          (item) => WaferSummary.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<WaferDetail> fetchWaferDetail(int waferId) async {
    final payload = await _request('GET', 'wafers/$waferId');
    return WaferDetail.fromJson(payload);
  }

  Future<WaferDetail> createWafer(Map<String, String> values) async {
    final payload = await _request('POST', 'wafers', formFields: values);
    return WaferDetail.fromJson(payload);
  }

  Future<WaferDetail> addStatus(int waferId, Map<String, String> values) async {
    final payload = await _request(
      'POST',
      'wafers/$waferId/statuses',
      formFields: values,
    );
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<Uint8List> fetchStatusPhoto(int waferId, int statusHistoryId) async {
    final uri = _baseUri.resolve('wafers/$waferId/statuses/$statusHistoryId/photo');
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );

    if (response.statusCode >= 400) {
      final body = utf8.decode(bytes, allowMalformed: true);
      String message = 'Request failed.';
      if (body.isNotEmpty) {
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            message = decoded['error']?.toString() ?? message;
          }
        } catch (_) {
          message = body;
        }
      }
      throw ApiException(message, statusCode: response.statusCode);
    }

    return Uint8List.fromList(bytes);
  }

  Future<WaferDetail> addWaferHistory(
    int waferId,
    Map<String, String> values,
  ) async {
    final payload = await _request(
      'POST',
      'wafers/$waferId/history',
      formFields: values,
    );
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<WaferDetail> addActivity(
    int waferId,
    Map<String, String> values,
  ) async {
    final payload = await _request(
      'POST',
      'wafers/$waferId/activities',
      formFields: values,
    );
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<WaferDetail> uploadStatusPhoto(
    int waferId,
    int statusHistoryId,
    Uint8List bytes,
    String contentType,
  ) async {
    final payload = await _request(
      'POST',
      'wafers/$waferId/statuses/$statusHistoryId/photo',
      formFields: {
        'photoBase64': base64Encode(bytes),
        'photoContentType': contentType,
      },
    );
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<Uint8List> fetchHistoryPhoto(int waferId, int historyId) async {
    final uri = _baseUri.resolve('wafers/$waferId/history/$historyId/photo');
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    if (response.statusCode >= 400) {
      final body = utf8.decode(bytes, allowMalformed: true);
      String message = 'Request failed.';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          message = decoded['error']?.toString() ?? message;
        }
      } catch (_) {
        message = body;
      }
      throw ApiException(message, statusCode: response.statusCode);
    }
    return Uint8List.fromList(bytes);
  }

  Future<WaferDetail> uploadHistoryPhoto(
    int waferId,
    int historyId,
    Uint8List bytes,
    String contentType,
  ) async {
    final payload = await _request(
      'POST',
      'wafers/$waferId/history/$historyId/photo',
      formFields: {
        'photoBase64': base64Encode(bytes),
        'photoContentType': contentType,
      },
    );
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<WaferDetail> updateStatus(
    int waferId,
    int statusHistoryId,
    Map<String, String> values,
  ) async {
    final payload = await _request(
      'PATCH',
      'wafers/$waferId/statuses/$statusHistoryId',
      formFields: values,
    );
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<WaferDetail> updateActivity(
    int waferId,
    int activityId,
    Map<String, String> values,
  ) async {
    final payload = await _request(
      'PATCH',
      'wafers/$waferId/activities/$activityId',
      formFields: values,
    );
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<WaferDetail> updateDarkfieldRun(
    int waferId,
    int runId,
    Map<String, String> values,
  ) async {
    final payload = await _request(
      'PATCH',
      'wafers/$waferId/darkfield-runs/$runId',
      formFields: values,
    );
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<WaferDetail> deleteMetadataHistory(int waferId, int historyId) async {
    final payload = await _request('DELETE', 'wafers/$waferId/history/$historyId');
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<WaferDetail> deleteStatus(int waferId, int statusHistoryId) async {
    final payload = await _request('DELETE', 'wafers/$waferId/statuses/$statusHistoryId');
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<WaferDetail> deleteActivity(int waferId, int activityId) async {
    final payload = await _request('DELETE', 'wafers/$waferId/activities/$activityId');
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<WaferDetail> deleteDarkfieldRun(int waferId, int runId) async {
    final payload = await _request('DELETE', 'wafers/$waferId/darkfield-runs/$runId');
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> importDarkfieldSummary(String path) async {
    return await _request(
      'GET',
      'darkfield-import',
      queryParameters: {'path': path},
    );
  }

  Future<WaferDetail> addDarkfieldRun(
    int waferId,
    Map<String, String> values,
  ) async {
    final payload = await _request(
      'POST',
      'wafers/$waferId/darkfield-runs',
      formFields: values,
    );
    return WaferDetail.fromJson(payload['detail'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String?>? queryParameters,
    Map<String, String>? formFields,
  }) async {
    final filteredQuery = <String, String>{};
    queryParameters?.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        filteredQuery[key] = value;
      }
    });

    final uri = _baseUri
        .resolve(path)
        .replace(queryParameters: filteredQuery.isEmpty ? null : filteredQuery);
    final request = await _httpClient.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    request.headers.set(HttpHeaders.connectionHeader, 'close');

    if (formFields != null) {
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(Uri(queryParameters: formFields).query);
    }

    final response = await request.close()
        .timeout(const Duration(seconds: 30));
    final body = await utf8.decoder.bind(response).join()
        .timeout(const Duration(seconds: 60));
    final dynamic decoded = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Unexpected response from $uri',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        decoded['error']?.toString() ?? 'Request failed.',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }
}
