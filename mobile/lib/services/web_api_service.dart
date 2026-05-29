/// Placeholder client for `web/` PHP API (configure before production use).
class WebApiService {
  WebApiService({
    this.baseUrl = 'https://www.edgarsfoto.lv',
    this.apiToken = '',
  });

  final String baseUrl;
  final String apiToken;

  bool get isConfigured => apiToken.isNotEmpty;

  Uri healthUri() => Uri.parse('$baseUrl/api/health');

  Uri createGalleryUri() => Uri.parse('$baseUrl/api/galleries');

  Uri galleryUri(String slug) => Uri.parse('$baseUrl/api/galleries/$slug');

  Uri uploadImageUri(String slug) =>
      Uri.parse('$baseUrl/api/galleries/$slug/images');

  // TODO: http package — POST create gallery, multipart upload when Web mode is enabled
}
