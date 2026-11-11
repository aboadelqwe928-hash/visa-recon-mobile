import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  Dio? _dio;
  String? _baseUrl;
  String? _token;

  String? get baseUrl => _baseUrl;
  String? get token => _token;
  bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;

  void configure(String baseUrl, {String? token}) {
    _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    _token = token;
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl!,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        if (kDebugMode) {
          print('API Error: ${e.message} | ${e.response?.data}');
        }
        return handler.next(e);
      },
    ));
  }

  void setToken(String? token) {
    _token = token;
  }

  void clear() {
    _token = null;
    _baseUrl = null;
    _dio = null;
  }

  /// Calls the VisaRecon API style: POST /api/{method}
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async {
    if (_dio == null) {
      throw ApiException('السيرفر مش مضبوط. ادخل عنوان السيرفر الأول.');
    }

    try {
      final response = await _dio!.post(
        '/api/$method',
        data: params ?? {},
      );

      final data = response.data;
      if (data is Map && data.containsKey('error')) {
        throw ApiException(
          data['error']?.toString() ?? 'خطأ غير معروف',
          code: data['code'] is int ? data['code'] : null,
        );
      }

      // The server returns { ok: <result> }
      if (data is Map && data.containsKey('ok')) {
        return data['ok'];
      }
      return data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw ApiException('مفيش اتصال بالسيرفر. تأكد إنك على نفس الشبكة.');
      }
      if (e.response?.statusCode == 401) {
        throw ApiException('انتهت الجلسة، سجّل دخول تاني', code: 401);
      }
      if (e.response?.statusCode == 403) {
        throw ApiException('مش مسموحلك بالعملية دي', code: 403);
      }
      final msg = e.response?.data is Map
          ? (e.response!.data['error']?.toString() ?? e.message)
          : e.message;
      throw ApiException(msg ?? 'حصل خطأ في الاتصال');
    }
  }

  Future<bool> ping() async {
    try {
      await call('auth.status');
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? code;
  ApiException(this.message, {this.code});
  @override
  String toString() => message;
}
