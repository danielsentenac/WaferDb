import 'dart:convert';
import 'dart:io';

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
  final HttpClient _httpClient = HttpClient();

  Future<LookupBundle> fetchLookups() async {
    final payload = await _request('GET', 'lookups');
    return LookupBundle.fromJson(payload);
  }

  Future<DashboardData> fetchDashboard() async {
    final payload = await _request('GET', 'dashboard');
    return DashboardData.fromJson(payload);
  }

  Future<List<WaferSummary>> fetchWafers({
    String query = '',
    String? statusCode,
    int limit = 80,
  }) async {
    final payload = await _request(
      'GET',
      'wafers',
      queryParameters: <String, String?>{
        'q': query.isEmpty ? null : query,
        'status': statusCode,
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

    if (formFields != null) {
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(Uri(queryParameters: formFields).query);
    }

    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
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
