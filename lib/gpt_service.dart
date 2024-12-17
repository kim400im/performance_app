import 'dart:convert';
import 'package:flutter_gpt/secrets.dart';
import 'package:http/http.dart' as http;

class GptService {
  final String apiKey = Secrets.openaiApiKey; // GPT API 키

  // 프롬프트 생성
  String generatePrompt(String userQuery, List<Map<String, String>> searchResults) {
    if (searchResults.isEmpty) {
      print("wrong input, it is empty!!");
      return "User asked: \"$userQuery\"\nNo relevant show performance found.";
    }

    StringBuffer prompt = StringBuffer();
    prompt.writeln("You are a helpful assistant. Here is the performance information:");
    for (var performance in searchResults) {
      prompt.writeln(
          "- Start Date: ${performance['performance_start_date']}, "
              "End Date: ${performance['performance_end_date']}, "
              "Serial Number: ${performance['performance_serial_number']}, "
              "Genre: ${performance['performance_genre']}, "
              "Name: ${performance['performance_name']}, "
              "Place: ${performance['performance_place']}, "
              "Running Time: ${performance['performance_runningtime']}, "
              "Intermission: ${performance['performance_intermission']}, "
              "Age Restriction: ${performance['performance_age']}, "
              "Synopsis: ${performance['performance_synopsis']}, "
              "Work Description: ${performance['performance_work_description']}, "
              "Discount Info: ${performance['performance_discount_info']}, "
              "Seat Info: ${performance['performance_seat_info']}");
    }

    prompt.writeln("\nBased on the information, answer the following question:");
    prompt.writeln(userQuery);

    return prompt.toString();
  }

  // GPT 호출
  Future<String> requestChat(String prompt) async {
    final url = Uri.https("api.openai.com", "/v1/chat/completions");
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-4o",
        "messages": [
          {"role": "system", "content": "You are a helpful assistant."},
          {"role": "user", "content": prompt},
        ],
        "stream": false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["choices"][0]["message"]["content"];
    } else {
      throw Exception("Failed to fetch GPT response: ${response.body}");
    }
  }
}
