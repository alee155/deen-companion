/// Every UmmahAPI response shares this envelope shape:
/// { success, service, data, timestamp, api_info }
/// This unwraps `data` generically so no datasource repeats that logic.
class UmmahApiResponse<T> {
  final bool success;
  final String service;
  final T data;

  const UmmahApiResponse({
    required this.success,
    required this.service,
    required this.data,
  });

  factory UmmahApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) dataParser,
  ) {
    return UmmahApiResponse(
      success: json['success'] as bool? ?? false,
      service: json['service'] as String? ?? '',
      data: dataParser(json['data'] as Map<String, dynamic>),
    );
  }
}
