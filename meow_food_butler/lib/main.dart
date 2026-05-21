import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ==========================================================================
// 1. STATE MANAGEMENT / PROVIDERS (Equivalent to React Contexts)
// ==========================================================================

class Experience {
  final String id;
  final String title;
  Experience({required this.id, required this.title});
}

class AppStore extends ChangeNotifier {
  String? _activeFoodCardId;
  String? _activeExperienceId;
  final List<String> _savedRestaurants = [];

  String? get activeFoodCardId => _activeFoodCardId;
  String? get activeExperienceId => _activeExperienceId;
  List<String> get savedRestaurants => _savedRestaurants;

  void openFoodCard(String id) {
    _activeFoodCardId = id;
    notifyListeners();
  }

  void closeFoodCard() {
    _activeFoodCardId = null;
    notifyListeners();
  }

  void openExperience(String id) {
    _activeExperienceId = id;
    notifyListeners();
  }

  void closeExperience() {
    _activeExperienceId = null;
    notifyListeners();
  }

  void saveRestaurant(String id) {
    if (!_savedRestaurants.contains(id)) {
      _savedRestaurants.add(id);
      notifyListeners();
    }
  }
}

class SettingsProvider extends ChangeNotifier {
  // Add global configuration states here if necessary
}

// ==========================================================================
// 2. TYPES & MODELS
// ==========================================================================

enum AppMode { instagram, map, chat, saved }
enum ToastStatus { idle, reading, saved, hidden }

class RatingContext {
  final String? lockedRestaurantId;
  final String? lockedPlaceTitle;
  final Experience? editingExperience;

  RatingContext({
    this.lockedRestaurantId,
    this.lockedPlaceTitle,
    this.editingExperience,
  });
}

// ==========================================================================
// 3. MAIN ENTRY POINT
// ==========================================================================

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppStore()),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext WidgetContext) {
    return MaterialApp(
      title: 'Food Butler',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const Scaffold(
        body: AppShell(),
      ),
    );
  }
}

// ==========================================================================
// 4. APP SHELL CONTAINER (Handles Layout Frame & Navigation States)
// ==========================================================================

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppMode _mode = AppMode.instagram;
  ToastStatus _toastStatus = ToastStatus.idle;
  RatingContext? _ratingContext;
  bool _showSettings = false;

  void _openRating([RatingContext? ctx]) {
    setState(() => _ratingContext = ctx ?? RatingContext());
  }

  void _closeRating() => setState(() => _ratingContext = null);

  // Handles the simulated pipeline flow when clicking share on the IG layer
  void _handleShareToApp() {
    setState(() => _toastStatus = ToastStatus.reading);

    Timer(const Duration(milliseconds: 1500), () {
      // Auto-save the imported IG ramen mock ID
      Provider.of<AppStore>(context, listen: false).saveRestaurant("ippudo-tokyo");
      setState(() => _toastStatus = ToastStatus.saved);

      Timer(const Duration(milliseconds: 800), () {
        setState(() => _mode = AppMode.map);
        Timer(const Duration(milliseconds: 500), () {
          setState(() => _toastStatus = ToastStatus.hidden);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<AppStore>(context);

    return Container(
      color: Colors.grey[200], // Background simulating web wrapper
      alignment: Alignment.center,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: 400,
            height: 850,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(48),
              border: Border.all(color: Colors.black, width: 8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  offset: Offset(0, 10),
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // ----------------------------------------------------------
                // Core App Pages Switcher (AnimatePresence substitute)
                // ----------------------------------------------------------
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    // Custom mapping of matching transition directions to look like the React app
                    if (child.key == const ValueKey(AppMode.instagram)) {
                      return FadeTransition(opacity: animation, child: child);
                    } else if (child.key == const ValueKey(AppMode.map)) {
                      return ScaleTransition(
                        scale: Tween<double>(begin: 1.05, end: 1.0).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    } else {
                      // Slide-out/in treatment for standard Chat/Saved subviews
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                        child: child,
                      );
                    }
                  },
                  child: _buildCurrentModeWidget(),
                ),

                // ----------------------------------------------------------
                // Global Dynamic Island Layer
                // ----------------------------------------------------------
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DynamicIslandToast(status: _toastStatus),
                  ),
                ),

                // ----------------------------------------------------------
                // Overlay Modal Sheets (Equivalent to bottom overlay blocks)
                // ----------------------------------------------------------
                if (store.activeFoodCardId != null)
                  FoodCard(
                    restaurantId: store.activeFoodCardId!,
                    onClose: store.closeFoodCard,
                    onAddExperience: (restId, title) => _openRating(
                      RatingContext(lockedRestaurantId: restId, lockedPlaceTitle: title),
                    ),
                  ),

                if (_ratingContext != null)
                  RatingPage(
                    onClose: _closeRating,
                    lockedRestaurantId: _ratingContext!.lockedRestaurantId,
                    lockedPlaceTitle: _ratingContext!.lockedPlaceTitle,
                    editingExperience: _ratingContext!.editingExperience,
                  ),

                if (store.activeExperienceId != null)
                  ExperienceDetailView(
                    experienceId: store.activeExperienceId!,
                    onClose: store.closeExperience,
                    onEdit: (exp) => _openRating(RatingContext(editingExperience: exp)),
                  ),

                if (_showSettings)
                  SettingsPage(onClose: () => setState(() => _showSettings = false)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentModeWidget() {
    switch (_mode) {
      case AppMode.instagram:
        return InstagramMode(
          key: const ValueKey(AppMode.instagram),
          onShareToApp: _handleShareToApp,
        );
      case AppMode.map:
        return MapMode(
          key: const ValueKey(AppMode.map),
          onChatClick: () => setState(() => _mode = AppMode.chat),
          onSavedClick: () => setState(() => _mode = AppMode.saved),
          onPlusClick: () => _openRating(),
          onSettingsClick: () => setState(() => _showSettings = true),
        );
      case AppMode.chat:
        return ChatMode(
          key: const ValueKey(AppMode.chat),
          onBack: () => setState(() => _mode = AppMode.map),
        );
      case AppMode.saved:
        return SavedMode(
          key: const ValueKey(AppMode.saved),
          onMap: () => setState(() => _mode = AppMode.map),
          onChat: () => setState(() => _mode = AppMode.chat),
          onPlusClick: () => _openRating(),
        );
    }
  }
}

// ==========================================================================
// 5. MOCK VIEW PLACEHOLDERS (Replace with your actual UI layouts)
// ==========================================================================

class DynamicIslandToast extends StatelessWidget {
  final ToastStatus status;
  const DynamicIslandToast({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == ToastStatus.hidden) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "Status: ${status.name}",
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class InstagramMode extends StatelessWidget {
  final VoidCallback onShareToApp;
  const InstagramMode({super.key, required this.onShareToApp});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[900],
      body: Center(
        child: ElevatedButton(
          onPressed: onShareToApp,
          child: const Text("Share Post to Food Butler"),
        ),
      ),
    );
  }
}

class MapMode extends StatelessWidget {
  final VoidCallback onChatClick;
  final VoidCallback onSavedClick;
  final VoidCallback onPlusClick;
  final VoidCallback onSettingsClick;

  const MapMode({
    super.key,
    required this.onChatClick,
    required this.onSavedClick,
    required this.onPlusClick,
    required this.onSettingsClick,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[800],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Map Workspace View"),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chat), onPressed: onChatClick),
                IconButton(icon: const Icon(Icons.bookmark), onPressed: onSavedClick),
                IconButton(icon: const Icon(Icons.add), onPressed: onPlusClick),
                IconButton(icon: const Icon(Icons.settings), onPressed: onSettingsClick),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class ChatMode extends StatelessWidget {
  final VoidCallback onBack;
  const ChatMode({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)),
      body: const Center(child: Text("AI Assistant Channel")),
    );
  }
}

class SavedMode extends StatelessWidget {
  final VoidCallback onMap;
  final VoidCallback onChat;
  final VoidCallback onPlusClick;

  const SavedMode({
    super.key,
    required this.onMap,
    required this.onChat,
    required this.onPlusClick,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Saved Places List"),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.map), onPressed: onMap),
                IconButton(icon: const Icon(Icons.chat), onPressed: onChat),
                IconButton(icon: const Icon(Icons.add), onPressed: onPlusClick),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class FoodCard extends StatelessWidget {
  final String restaurantId;
  final VoidCallback onClose;
  final Function(String, String) onAddExperience;

  const FoodCard({
    super.key,
    required this.restaurantId,
    required this.onClose,
    required this.onAddExperience,
  });

  @override
  Widget build(BuildContext context) {
    return CardOverlay(
      onClose: onClose,
      title: "Restaurant detail card: $restaurantId",
      child: ElevatedButton(
        onPressed: () => onAddExperience(restaurantId, "Mock Place Title"),
        child: const Text("Add Visit Experience"),
      ),
    );
  }
}

class RatingPage extends StatelessWidget {
  final VoidCallback onClose;
  final String? lockedRestaurantId;
  final String? lockedPlaceTitle;
  final Experience? editingExperience;

  const RatingPage({
    super.key,
    required this.onClose,
    this.lockedRestaurantId,
    this.lockedPlaceTitle,
    this.editingExperience,
  });

  @override
  Widget build(BuildContext context) {
    return CardOverlay(
      onClose: onClose,
      title: editingExperience != null ? "Edit Journal Entry" : "Log New Experience",
      child: Text("Target: ${lockedPlaceTitle ?? editingExperience?.title ?? 'Unspecified Selection'}"),
    );
  }
}

class ExperienceDetailView extends StatelessWidget {
  final String experienceId;
  final VoidCallback onClose;
  final Function(Experience) onEdit;

  const ExperienceDetailView({
    super.key,
    required this.experienceId,
    required this.onClose,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return CardOverlay(
      onClose: onClose,
      title: "Reviewing Experience Details",
      child: ElevatedButton(
        onPressed: () => onEdit(Experience(id: experienceId, title: "Historical Log Entry")),
        child: const Text("Edit This Record"),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final VoidCallback onClose;
  const SettingsPage({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return CardOverlay(
      onClose: onClose,
      title: "Configuration Settings",
      child: const Text("App adjustments panel"),
    );
  }
}

// Helper container widget simulating popup stack mechanics
class CardOverlay extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onClose;

  const CardOverlay({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: onClose),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}