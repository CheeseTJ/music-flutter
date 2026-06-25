class ProviderConfig {
  final String source;
  final String baseUrl;
  final String type;

  const ProviderConfig({
    required this.source,
    required this.baseUrl,
    required this.type,
  });

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      source: json['source'] as String,
      baseUrl: json['base_url'] as String,
      type: json['type'] as String,
    );
  }
}
