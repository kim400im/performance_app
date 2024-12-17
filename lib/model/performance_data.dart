import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:flutter_gpt/secrets.dart';
import 'package:http/http.dart' as http;

class PerformanceData {
  final String apiKey = Secrets.openaiApiKey; // GPT API Key

  List<Map<String, String>> _performances = [];
  List<List<double>> _performanceVectors = []; // 벡터 저장

  // CSV 파일 로드
  Future<void> loadCSV() async {
    final rawData = await rootBundle.loadString('assets/performances.csv');
    List<List<dynamic>> csvData = const CsvToListConverter().convert(rawData);

    _performances = csvData
        .skip(1) // 첫 번째 행은 헤더
        .map((row) => {
      "performance_start_date": row[0].toString(),
      "performance_end_date": row[1].toString(),
      "performance_serial_number": row[2].toString(),
      "performance_genre": row[3].toString(),
      "performance_name": row[4].toString(),
      "performance_place": row[5].toString(),
      "performance_runningtime": row[6].toString(),
      "performance_intermission": row[7].toString(),
      "performance_age": row[8].toString(),
      "performance_synopsis": row[11].toString(),
      "performance_work_description": row[12].toString(),
      "performance_discount_info": row[15].toString(),
      "performance_seat_info": row[16].toString(),
    })
        .toList();

    // 벡터 생성 (임베딩)
    for (var performance in _performances) {
      String text = "${performance['performance_name']} ${performance['performance_synopsis']}";
      if (text.isNotEmpty) {
        try {
          List<double> vector = await _getEmbedding(text);
          _performanceVectors.add(vector);
        } catch (e) {
          print("Error generating embedding for $text: $e");
          _performanceVectors.add([]); // 기본 빈 벡터 추가
        }
      } else {
        print("Skipping empty performance text: $performance");
        _performanceVectors.add([]); // 기본 빈 벡터 추가
      }
    }

    print("_performanceVectors: $_performanceVectors");
  }

  // OpenAI 임베딩 API 호출
  Future<List<double>> _getEmbedding(String text) async {
    final url = Uri.https("api.openai.com", "/v1/embeddings");
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "text-embedding-ada-002",
        "input": text,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<double>.from(data["data"][0]["embedding"]);
    } else {
      throw Exception("Failed to fetch embedding: ${response.body}");
    }
  }

  // 코사인 유사도 계산
  double _cosineSimilarity(List<double> a, List<double> b) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    normA = sqrt(normA);
    normB = sqrt(normB);

    if (normA == 0 || normB == 0) return 0.0;

    if (a.isEmpty || b.isEmpty || a.length != b.length) {
      return 0.0;
    }

    return dotProduct / (normA * normB);
  }

  // 벡터 기반 검색
  Future<List<Map<String, String>>> search(String query) async {
    List<double> queryVector = await _getEmbedding(query);

    List<Map<String, String>> results = [];
    List<double> scores = [];

    for (int i = 0; i < _performanceVectors.length; i++) {
      if (_performanceVectors[i].isEmpty) {
        print("Skipping empty vector for performance at index $i");
        continue; // 빈 벡터는 건너뜀
      }

      double similarity = _cosineSimilarity(queryVector, _performanceVectors[i]);
      if (similarity > 0.5) {
        results.add(_performances[i]);
        scores.add(similarity);
      }
    }

    results.sort((a, b) {
      int indexA = _performances.indexOf(a);
      int indexB = _performances.indexOf(b);
      return scores[indexB].compareTo(scores[indexA]);
    });

    print("Search results: $results");
    return results;
  }
}
