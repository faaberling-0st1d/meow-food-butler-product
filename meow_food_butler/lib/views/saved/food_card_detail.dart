import 'package:flutter/material.dart';
import '../../models/food_card.dart';
import '../../models/experience_card.dart';

class FoodCardDetail extends StatefulWidget {
  final FoodCard foodCard;
  final List<ExperienceCard> experiences;
  final bool isSaved;
  final VoidCallback onClose;
  final VoidCallback onToggleSave;
  final VoidCallback onAddExperience;

  const FoodCardDetail({
    super.key,
    required this.foodCard,
    required this.experiences,
    required this.isSaved,
    required this.onClose,
    required this.onToggleSave,
    required this.onAddExperience,
  });

  @override
  State<FoodCardDetail> createState() => _FoodCardDetailState();
}

class _FoodCardDetailState extends State<FoodCardDetail> {
  int _currentTabIndex = 0; // 0 = Online Info, 1 = Yours
  final TextEditingController _tagController = TextEditingController();
  
  final List<String> _mockPros = ['環境乾淨', '出餐快', '食材新鮮', '分量足'];
  final List<String> _mockCons = ['不好停車', '排隊久'];
  
  final List<String> _suggestedTags = ['口袋名單', '週末愛店', '平價美食', '適合聚餐', '高CP值'];

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeroImage(),
              
              _buildHeader(),
              
              _buildTabs(),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _currentTabIndex == 0 
                        ? _buildOnlineTab() 
                        : _buildYoursTab(),
                  ),
                ),
              ),
            ],
          ),
          
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return Stack(
      children: [
        Container(
          height: 220,
          width: double.infinity,
          color: Colors.grey[100],
          child: widget.foodCard.originalURL != null
              ? Image.network(widget.foodCard.originalURL!, fit: BoxFit.cover)
              : const Center(child: Icon(Icons.restaurant, size: 48, color: Colors.grey)),
        ),
        Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.25), Colors.transparent],
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.black87, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.foodCard.primaryTitle,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text("附近 • ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text("暫無電話", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Icon(Icons.assignment_outlined, color: Colors.black54, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(child: _buildTabButton("線上資訊", 0)),
            Expanded(child: _buildTabButton("我的評分", 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isActive = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? const [BoxShadow(color: Colors.black12, blurRadius: 2)] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.black87 : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineTab() {
    return Column(
      key: const ValueKey('online'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
              child: const Text("美食餐廳", style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    widget.foodCard.rating?.toStringAsFixed(1) ?? "4.5",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ..._mockPros.map((tag) => _buildStatusTag(tag, true)),
            ..._mockCons.map((tag) => _buildStatusTag(tag, false)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: Colors.deepOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.foodCard.formattedAddress ?? "這是一間位於大安區的高人氣美食餐廳，店內提供多樣化的特色料理，非常推薦前往品嚐。",
                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusTag(String text, bool isPro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPro ? Colors.green[50] : Colors.red[50],
        border: Border.all(color: isPro ? Colors.green[100]! : Colors.red[100]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isPro ? Colors.green[700] : Colors.red[700]),
      ),
    );
  }

  Widget _buildYoursTab() {
    final visitCount = widget.experiences.length;
    final avgRating = visitCount > 0 
        ? widget.experiences.fold(0.0, (sum, exp) => sum + exp.personalRating) / visitCount 
        : 0.0;

    return Column(
      key: const ValueKey('yours'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.amber[50]!, Colors.orange[50]!]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[100]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("你的平均評分", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
              visitCount > 0 ? Row(
                children: [
                  Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  const SizedBox(width: 8),
                  Text("$visitCount 次造訪記錄", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange)),
                ],
              ) : const Text("尚未寫過用餐體驗", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("我的用餐紀錄", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            GestureDetector(
              onTap: widget.onAddExperience,
              child: Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        if (visitCount == 0)
          GestureDetector(
            onTap: widget.onAddExperience,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.add_circle_outline, size: 28, color: Colors.deepOrange),
                  const SizedBox(height: 8),
                  Text("新增你的第一筆體驗", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text("記錄下你在這裡吃過的菜色與心得吧！", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ...widget.experiences.map((exp) => _buildExperienceItem(exp)),
        const SizedBox(height: 24),
        const Text("自訂美食標籤", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              const Text("#", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(border: InputBorder.none, hintText: "建立新標籤", hintStyle: TextStyle(fontSize: 13)),
                  onSubmitted: (val) => _handleAddNewTag(),
                ),
              ),
              GestureDetector(
                onTap: _handleAddNewTag,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_upward, color: Colors.white, size: 12),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _suggestedTags.map((tag) => GestureDetector(
            onTap: () {
              setState(() {
                if (!_suggestedTags.contains(tag)) _suggestedTags.add(tag);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("+ #$tag", style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildExperienceItem(ExperienceCard exp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.star, 
                  size: 14, 
                  color: i < exp.personalRating ? Colors.orange : Colors.grey[300]
                )),
              ),
              Text(
                _formatRelative(exp.createdTime.toDate()),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          if (exp.personalNote != null && exp.personalNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(exp.personalNote!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ]
        ],
      ),
    );
  }

  void _handleAddNewTag() {
    if (_tagController.text.trim().isNotEmpty) {
      setState(() {
        _suggestedTags.insert(0, _tagController.text.trim());
        _tagController.clear();
      });
    }
  }

  String _formatRelative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "剛剛";
    if (diff.inHours < 24) return "${diff.inHours}小時前";
    return "${diff.inDays}天前";
  }

  Widget _buildBottomActionBar() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[100]!)),
        ),
        child: GestureDetector(
          onTap: widget.onToggleSave,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: widget.isSaved ? Colors.orange[50] : Colors.deepOrange,
              borderRadius: BorderRadius.circular(24),
              border: widget.isSaved ? Border.all(color: Colors.orange[200]!) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: widget.isSaved ? Colors.deepOrange : Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isSaved ? "已收藏至我的美食地圖" : "收藏這家餐廳",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.isSaved ? Colors.deepOrange : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}