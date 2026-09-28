// DDE-Mart provider app — uploads + stories parity tests.

import 'dart:io';

import 'package:dde_provider/core/media_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Dio _stubDio({
  required Future<Response<dynamic>> Function(RequestOptions options) onRequest,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        handler.resolve(await onRequest(options));
      },
    ),
  );
  return dio;
}

void main() {
  group('ProviderUploadsApi.uploadFile', () {
    test('posts multipart file field and returns the url', () async {
      final file = File(
          '${Directory.systemTemp.path}/dde_provider_upload_test.png');
      await file.writeAsBytes(List<int>.filled(16, 1));

      RequestOptions? captured;
      final dio = _stubDio(
        onRequest: (options) async {
          captured = options;
          return Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'data': {'path': 'avatars/a.png', 'url': 'https://cdn/a.png'},
            },
          );
        },
      );

      final url =
          await ProviderUploadsApi(dio).uploadFile(file.path);
      expect(url, 'https://cdn/a.png');
      expect(captured?.path, '/provider/uploads');
      final data = captured?.data as FormData;
      expect(data.files.single.key, 'file');
    });

    test('falls back to path and forwards folder', () async {
      final file = File(
          '${Directory.systemTemp.path}/dde_provider_upload_doc_test.png');
      await file.writeAsBytes(List<int>.filled(16, 2));

      RequestOptions? captured;
      final dio = _stubDio(
        onRequest: (options) async {
          captured = options;
          return Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'data': {'path': 'documents/d.png', 'url': ''},
            },
          );
        },
      );

      final result = await ProviderUploadsApi(dio)
          .uploadFile(file.path, folder: 'documents');
      expect(result, 'documents/d.png');
      final data = captured?.data as FormData;
      expect(
        data.fields.any(
            (f) => f.key == 'folder' && f.value == 'documents'),
        isTrue,
      );
    });
  });

  group('StoriesApi.fetchStories', () {
    test('gets /stories and unwraps the data list', () async {
      RequestOptions? captured;
      final dio = _stubDio(
        onRequest: (options) async {
          captured = options;
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': [
                {
                  'id': 7,
                  'store': {'id': 3, 'name': 'Fresh Mart'},
                  'video_url': 'https://cdn/s.mp4',
                  'thumbnail': '/storage/s.jpg',
                },
              ],
            },
          );
        },
      );

      final stories = await StoriesApi(dio).fetchStories();
      expect(captured?.path, '/stories');
      expect(stories, hasLength(1));
      expect(stories.single['id'], 7);
      expect((stories.single['store'] as Map)['name'], 'Fresh Mart');
    });

    test('empty data degrades to an empty list', () async {
      final dio = _stubDio(
        onRequest: (options) async => Response(
          requestOptions: options,
          statusCode: 200,
          data: {'data': []},
        ),
      );
      expect(await StoriesApi(dio).fetchStories(), isEmpty);
    });
  });
}
