import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experience_card.dart'; // 確保路徑指向你的 ExperienceCard
import '../services/apify_service.dart';
import '../services/ai_agent_service.dart';
import '../services/outscraper_service.dart';

class InstagramImportViewModel extends ChangeNotifier {
  // final ApifyService _apify = ApifyService();
  final AiAgentService _aiAgent = AiAgentService();
  // final OutscraperService _outscraper = OutscraperService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _loadingMessage = "";
  String get loadingMessage => _loadingMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<ExperienceCard?> pipelineImportAndBuildCard(String igUrl) async {
    _errorMessage = null;
    _isLoading = true;
    _loadingMessage = "正在分析 IG 貼文...";
    notifyListeners();

    try {
      print("[DEBUG] pipelineImportAndBuildCard url: $igUrl");
      final result = await _aiAgent.importInstagram(igUrl);

      if (result['ok'] != true) {
        throw result['error'] as String? ?? '未知錯誤';
      }

      final d = result['data'] as Map<String, dynamic>;

      _loadingMessage = "正在產生餐廳小卡...";
      notifyListeners();

      final newCard = ExperienceCard(
        id: null,
        foodCardId: null,
        placeId: d['placeId'] as String,
        placeTitle: d['placeTitle'] as String,
        placeAddress: d['placeAddress'] as String,
        latitude: d['latitude'] as double?,
        longitude: d['longitude'] as double?,
        originalURL: igUrl,
        photoPaths: const [],
        photoUrls: List<String>.from(d['photoUrls'] as List),
        personalTags: _extractHashtags(d['personalNote'] as String? ?? ''),
        personalRating: 0.0,
        personalNote: d['personalNote'] as String? ?? '',
        isDone: false,
        createdTime: Timestamp.now(),
      );

      _isLoading = false;
      _loadingMessage = "";
      notifyListeners();
      return newCard;

    } catch (e) {
      _isLoading = false;
      _loadingMessage = "";
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// 輔助函式：用正則表達式把內文中的 # 標籤自動抓出來
  List<String> _extractHashtags(String text) {
    final RegExp exp = RegExp(r"#(\w+)");
    final matches = exp.allMatches(text);
    return matches.map((m) => m.group(1)!).toList();
  }
}