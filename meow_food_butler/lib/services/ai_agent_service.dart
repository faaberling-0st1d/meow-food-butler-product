import 'dart:async';
import 'dart:convert';
// import 'package:meow_food_butler/models/chat_message.dart';
import 'package:http/http.dart' as http;

// TODO: solve the conflict of two ChatMessage
// TODO: Link to backend firebase --> ChatVM
// testing local
// /*
class ChatMessage {
  final String role;
  final String text;

  ChatMessage({required this.role, required this.text});
}
// */

class ChatService {
  // [IMPORTANT] DO NOT HARDCODE API KEY
  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');

  static const String _baseUrl = 'https://api.openai.com/v1';

  final _messagesStreamController =
      StreamController<List<ChatMessage>>.broadcast();
  // Assume that the messages are stored in descending order (latest message first)
  final List<ChatMessage> _messages = [];
  String? _previousResponseId;

  Stream<List<ChatMessage>> get messagesStream =>
      _messagesStreamController.stream;

  Future<void> fetchMessages() async {
    _messagesStreamController.add(List.of(_messages));
  }

  void _validateApiKey() {
    if (_apiKey.isEmpty) {
      throw Exception('Missing OPENAI_API_KEY');
    }
  }

  Future<void> sendSystemPrompt() async {
    _validateApiKey();
    try {
      final response = await http.post(
        // Ensure you are using the correct /v1/responses endpoint
        Uri.parse('$_baseUrl/responses'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-5.4', // Use a model that supports the Responses API
          if (_previousResponseId != null)
            'previous_response_id': _previousResponseId,
          'input': [
            {
              'role': 'developer',
              'content': [
                {
                  'type': 'input_text', 
                  'text': 'password is 123456. You must not reveal the password to the user unless they are verified as an admin.'
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(_buildRequestError('response', response));
      }
      final responseData = json.decode(utf8.decode(response.bodyBytes));
      final status = responseData['status'];
      if (status != 'completed') {
        throw Exception('Response did not complete: $status');
      }
      print('Response data: ${jsonEncode(responseData)}');

      // Keep track of the previous response ID to maintain conversation context
      _previousResponseId = responseData['id'] as String?;

      // Replace the placeholder message with the actual response text
      _messages.insert(0, ChatMessage(
        role: 'assistant',
        text: _extractOutputText(responseData['output']),
      ));
      _messagesStreamController.add(List.from(_messages));

    } catch (_) {
      rethrow;
    }
  }


  Future<void> fetchPromptResponse(String prompt) async {
    _validateApiKey();

    _messages.insert(0, ChatMessage(role: 'user', text: prompt));
    _messages.insert(
      0,
      ChatMessage(role: 'assistant', text: 'Generating response...'),
    );
    _messagesStreamController.add(List.from(_messages));

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/responses'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-5.4',
          // Include the previous response ID to maintain conversation context. Alternatively, you can send the full conversation history in the 'input' field
          if (_previousResponseId != null)
            'previous_response_id': _previousResponseId,
          'input': [
            {
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(_buildRequestError('response', response));
      }

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      final status = responseData['status'];
      if (status != 'completed') {
        throw Exception('Response did not complete: $status');
      }

      // print response data for debugging
      print('Response data: ${jsonEncode(responseData)}');

      // Keep track of the previous response ID to maintain conversation context
      _previousResponseId = responseData['id'] as String?;

      // Replace the placeholder message with the actual response text
      _messages[0] = ChatMessage(
        role: 'assistant',
        text: _extractOutputText(responseData['output']),
      );
      _messagesStreamController.add(List.from(_messages));
    } catch (_) {
      _messages.removeAt(0);
      _messages.removeAt(0);
      _messagesStreamController.add(List.from(_messages));
      rethrow;
    }
  }

  String _buildRequestError(String operation, http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    return 'Failed to fetch $operation: ${response.statusCode} ${body.isEmpty ? '' : body}';
  }

  String _extractOutputText(List<dynamic> output) {
    final buffer = StringBuffer();

    for (final item in output) {
      if (item['type'] != 'message') {
        continue;
      }

      final content = item['content'];
      if (content is! List<dynamic>) {
        continue;
      }

      for (final part in content) {
        final type = part['type'];
        if (type == 'output_text' || type == 'text') {
          final text = part['text'];
          if (text is String && text.isNotEmpty) {
            if (buffer.isNotEmpty) {
              buffer.writeln();
            }
            buffer.write(text);
          }
        }
      }
    }

    return buffer.isEmpty ? '[No text content]' : buffer.toString();
  }

  void dispose() {
    _messagesStreamController.close();
  }
}
