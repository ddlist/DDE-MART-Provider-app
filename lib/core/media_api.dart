// DDE-Mart provider app — uploads + stories API (parity).
//
// POST /provider/uploads (multipart `file` field, optional `folder`) and
// GET /stories (public showcase rail).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// Image uploads for the provider audience (avatars, documents, chat).
class ProviderUploadsApi {
  ProviderUploadsApi(this._dio);

  final Dio _dio;

  /// Uploads the file at [path] and returns the public URL
  /// (falls back to the storage path when the backend omits it).
  Future<String> uploadFile(String path, {String? folder}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path,
          filename: path.split('/').last.split('\\').last),
      if (folder != null && folder.isNotEmpty) 'folder': folder,
    });
    final response = await _dio.post('/provider/uploads', data: form);
    final data =
        Map<String, dynamic>.from((response.data as Map)['data'] as Map);
    final url = '${data['url'] ?? ''}';
    if (url.isNotEmpty) return url;
    return '${data['path'] ?? ''}';
  }
}

final providerUploadsApiProvider = Provider<ProviderUploadsApi>(
  (ref) => ProviderUploadsApi(ref.watch(dioProvider)),
);

/// Public showcase stories rail.
class StoriesApi {
  StoriesApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchStories() async {
    final response = await _dio.get('/stories');
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

final storiesApiProvider = Provider<StoriesApi>(
  (ref) => StoriesApi(ref.watch(dioProvider)),
);

final storiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(storiesApiProvider).fetchStories();
});
