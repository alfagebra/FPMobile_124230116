import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? 'http://localhost:3333';

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(baseUrl + path).replace(queryParameters: query);
  }

  Future<dynamic> getMateri() async {
    final res = await http.get(_uri('/materi'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw HttpException('getMateri failed: ${res.statusCode}');
  }

  Future<dynamic> getTopics() async {
    final res = await http.get(_uri('/topics'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw HttpException('getTopics failed: ${res.statusCode}');
  }

  Future<dynamic> search(String q) async {
    final res = await http.get(_uri('/search', {'q': q}));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw HttpException('search failed: ${res.statusCode}');
  }

  Future<dynamic> getTopicById(String id) async {
    final res = await http.get(_uri('/topic/$id'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw HttpException('getTopicById failed: ${res.statusCode}');
  }

  Future<dynamic> health() async {
    final res = await http.get(_uri('/health'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw HttpException('health failed: ${res.statusCode}');
  }

  Future<dynamic> uploadFile(File file, {String? field = 'file', String? secret}) async {
    final uri = _uri('/upload');
    final request = http.MultipartRequest('POST', uri);
    if (secret != null) request.fields['secret'] = secret;

    // Use MultipartFile.fromPath which handles opening the file and headers
    final filename = p.basename(file.path);
    final multipartFile = await http.MultipartFile.fromPath(field ?? 'file', file.path, filename: filename);
    request.files.add(multipartFile);

    final resp = await request.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode == 200) return jsonDecode(body);
    throw HttpException('uploadFile failed: ${resp.statusCode} ${body}');
  }
}
