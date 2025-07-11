import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();
  runApp(const MyApp());
}

// Initialize notifications
Future<void> initializeNotifications() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

// Service classes for new features
class StorageService {
  static const String _bookmarksKey = 'bookmarks';
  static const String _readingHistoryKey = 'reading_history';
  static const String _readingProgressKey = 'reading_progress';
  static const String _userPreferencesKey = 'user_preferences';
  static const String _offlineArticlesKey = 'offline_articles';

  // Bookmark management
  static Future<List<String>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_bookmarksKey) ?? [];
  }

  static Future<void> addBookmark(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();
    if (!bookmarks.contains(articleId)) {
      bookmarks.add(articleId);
      await prefs.setStringList(_bookmarksKey, bookmarks);
    }
  }

  static Future<void> removeBookmark(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();
    bookmarks.remove(articleId);
    await prefs.setStringList(_bookmarksKey, bookmarks);
  }

  // Reading history
  static Future<List<String>> getReadingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_readingHistoryKey) ?? [];
  }

  static Future<void> addToHistory(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getReadingHistory();
    history.remove(articleId); // Remove if exists
    history.insert(0, articleId); // Add to beginning
    if (history.length > 100) history.removeLast(); // Keep only last 100
    await prefs.setStringList(_readingHistoryKey, history);
  }

  // Reading progress
  static Future<Map<String, ReadingProgress>> getReadingProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getString(_readingProgressKey);
    if (progressJson != null) {
      final Map<String, dynamic> data = json.decode(progressJson);
      return data.map(
        (key, value) => MapEntry(key, ReadingProgress.fromJson(value)),
      );
    }
    return {};
  }

  static Future<void> saveReadingProgress(ReadingProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final allProgress = await getReadingProgress();
    allProgress[progress.articleId] = progress;
    await prefs.setString(_readingProgressKey, json.encode(allProgress));
  }

  // User preferences
  static Future<UserPreferences> getUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsJson = prefs.getString(_userPreferencesKey);
    if (prefsJson != null) {
      return UserPreferences.fromJson(json.decode(prefsJson));
    }
    return UserPreferences();
  }

  static Future<void> saveUserPreferences(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userPreferencesKey,
      json.encode(preferences.toJson()),
    );
  }

  // Offline articles
  static Future<void> saveOfflineArticle(NewsArticle article) async {
    final prefs = await SharedPreferences.getInstance();
    final offlineArticles = await getOfflineArticles();
    offlineArticles[article.id] = article;
    await prefs.setString(_offlineArticlesKey, json.encode(offlineArticles));
  }

  static Future<Map<String, NewsArticle>> getOfflineArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final articlesJson = prefs.getString(_offlineArticlesKey);
    if (articlesJson != null) {
      final Map<String, dynamic> data = json.decode(articlesJson);
      return data.map(
        (key, value) => MapEntry(key, NewsArticle.fromJson(value)),
      );
    }
    return {};
  }

  static Future<void> clearReadingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_readingHistoryKey);
  }

  static Future<void> clearOfflineArticles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineArticlesKey);
  }
}

class TTSService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (!_isInitialized) {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _isInitialized = true;
    }
  }

  static Future<void> speak(String text) async {
    await initialize();
    await _tts.speak(text);
  }

  static Future<void> stop() async {
    await _tts.stop();
  }

  static Future<void> pause() async {
    await _tts.pause();
  }

  static Future<void> resume() async {
    await _tts.speak(""); // Flutter TTS doesn't have resume, so we restart
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> showBreakingNewsNotification(
    String title,
    String body,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'breaking_news',
          'Breaking News',
          channelDescription: 'Notifications for breaking news',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    await _notifications.show(0, title, body, details);
  }

  static Future<void> showReadingReminder() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'reading_reminder',
          'Reading Reminders',
          channelDescription: 'Reminders to continue reading',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    await _notifications.show(
      1,
      'Reading Reminder',
      'Continue reading your saved articles!',
      details,
    );
  }
}

// Multiple RSS feeds for diverse content
class RSSFeed {
  final String name;
  final String url;
  final IconData icon;
  final Color color;

  RSSFeed({
    required this.name,
    required this.url,
    required this.icon,
    required this.color,
  });
}

final List<RSSFeed> rssFeeds = [
  RSSFeed(
    name: 'World News',
    url: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml',
    icon: Icons.public,
    color: Colors.blue,
  ),
  RSSFeed(
    name: 'Technology',
    url: 'https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml',
    icon: Icons.computer,
    color: Colors.green,
  ),
  RSSFeed(
    name: 'Business',
    url: 'https://rss.nytimes.com/services/xml/rss/nyt/Business.xml',
    icon: Icons.business,
    color: Colors.orange,
  ),
  RSSFeed(
    name: 'Science',
    url: 'https://rss.nytimes.com/services/xml/rss/nyt/Science.xml',
    icon: Icons.science,
    color: Colors.purple,
  ),
  RSSFeed(
    name: 'Health',
    url: 'https://rss.nytimes.com/services/xml/rss/nyt/Health.xml',
    icon: Icons.health_and_safety,
    color: Colors.red,
  ),
  RSSFeed(
    name: 'Sports',
    url: 'https://rss.nytimes.com/services/xml/rss/nyt/Sports.xml',
    icon: Icons.sports_soccer,
    color: Colors.teal,
  ),
];

class NewsArticle {
  final String title;
  final String summary;
  final String imageUrl;
  final String content;
  final List<String> categories;
  final String link;
  final DateTime? pubDate;
  final String source;
  final String author;
  final int readTime; // Estimated read time in minutes
  final String id; // Unique identifier for the article

  NewsArticle({
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.content,
    required this.categories,
    required this.link,
    required this.pubDate,
    required this.source,
    required this.author,
    required this.readTime,
  }) : id = '${source}_${title.hashCode}';

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'summary': summary,
      'imageUrl': imageUrl,
      'content': content,
      'categories': categories,
      'link': link,
      'pubDate': pubDate?.toIso8601String(),
      'source': source,
      'author': author,
      'readTime': readTime,
      'id': id,
    };
  }

  // Create from JSON
  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      content: json['content'] ?? '',
      categories: List<String>.from(json['categories'] ?? []),
      link: json['link'] ?? '',
      pubDate: json['pubDate'] != null ? DateTime.parse(json['pubDate']) : null,
      source: json['source'] ?? '',
      author: json['author'] ?? '',
      readTime: json['readTime'] ?? 1,
    );
  }
}

// User preferences and settings
class UserPreferences {
  final bool isDarkMode;
  final double fontSize;
  final bool enableNotifications;
  final bool enableTTS;
  final List<String> favoriteCategories;

  UserPreferences({
    this.isDarkMode = false,
    this.fontSize = 16.0,
    this.enableNotifications = true,
    this.enableTTS = false,
    this.favoriteCategories = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'isDarkMode': isDarkMode,
      'fontSize': fontSize,
      'enableNotifications': enableNotifications,
      'enableTTS': enableTTS,
      'favoriteCategories': favoriteCategories,
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      isDarkMode: json['isDarkMode'] ?? false,
      fontSize: json['fontSize']?.toDouble() ?? 16.0,
      enableNotifications: json['enableNotifications'] ?? true,
      enableTTS: json['enableTTS'] ?? false,
      favoriteCategories: List<String>.from(json['favoriteCategories'] ?? []),
    );
  }

  UserPreferences copyWith({
    bool? isDarkMode,
    double? fontSize,
    bool? enableNotifications,
    bool? enableTTS,
    List<String>? favoriteCategories,
  }) {
    return UserPreferences(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      fontSize: fontSize ?? this.fontSize,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableTTS: enableTTS ?? this.enableTTS,
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
    );
  }
}

// Reading progress tracking
class ReadingProgress {
  final String articleId;
  final double progress; // 0.0 to 1.0
  final DateTime lastRead;
  final int timeSpent; // in seconds

  ReadingProgress({
    required this.articleId,
    required this.progress,
    required this.lastRead,
    required this.timeSpent,
  });

  Map<String, dynamic> toJson() {
    return {
      'articleId': articleId,
      'progress': progress,
      'lastRead': lastRead.toIso8601String(),
      'timeSpent': timeSpent,
    };
  }

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      articleId: json['articleId'] ?? '',
      progress: json['progress']?.toDouble() ?? 0.0,
      lastRead: DateTime.parse(json['lastRead']),
      timeSpent: json['timeSpent'] ?? 0,
    );
  }
}

class Advertisement {
  final String title;
  final String description;
  final String imageUrl;
  final String ctaText;
  final Color color;

  Advertisement({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.ctaText,
    required this.color,
  });
}

// Dummy advertisements
final List<Advertisement> advertisements = [
  Advertisement(
    title: 'Premium News Subscription',
    description:
        'Get unlimited access to all premium content and exclusive articles',
    imageUrl: 'https://picsum.photos/300/200?random=1',
    ctaText: 'Subscribe Now',
    color: Colors.deepPurple,
  ),
  Advertisement(
    title: 'Breaking News Alerts',
    description: 'Stay updated with real-time notifications for breaking news',
    imageUrl: 'https://picsum.photos/300/200?random=2',
    ctaText: 'Enable Alerts',
    color: Colors.blue,
  ),
  Advertisement(
    title: 'News App Premium',
    description: 'Ad-free experience with offline reading and custom themes',
    imageUrl: 'https://picsum.photos/300/200?random=3',
    ctaText: 'Upgrade Now',
    color: Colors.green,
  ),
  Advertisement(
    title: 'Weekly Newsletter',
    description: 'Get the best stories delivered to your inbox every week',
    imageUrl: 'https://picsum.photos/300/200?random=4',
    ctaText: 'Sign Up Free',
    color: Colors.orange,
  ),
];

Future<List<NewsArticle>> fetchNews(String feedUrl, String source) async {
  try {
    final response = await http.get(Uri.parse(feedUrl));
    if (response.statusCode != 200) throw Exception('Failed to load news');

    final document = xml.XmlDocument.parse(response.body);
    final items = document.findAllElements('item');

    return items.map((item) {
      final title = item.getElement('title')?.text ?? '';
      final description = item.getElement('description')?.text ?? '';
      final content = item.getElement('content:encoded')?.text ?? description;
      final enclosure = item.getElement('enclosure');
      final imageUrl =
          enclosure?.getAttribute('url') ??
          'https://picsum.photos/400/250?random=${Random().nextInt(1000)}';
      final link = item.getElement('link')?.text ?? '';
      final pubDateStr = item.getElement('pubDate')?.text;
      final author = item.getElement('dc:creator')?.text ?? 'Staff Reporter';

      DateTime? pubDate;
      if (pubDateStr != null) {
        try {
          pubDate = DateTime.parse(pubDateStr);
        } catch (_) {
          pubDate = DateTime.now();
        }
      } else {
        pubDate = DateTime.now();
      }

      final categories = item
          .findElements('category')
          .map((c) => c.text)
          .toList();

      // Calculate estimated read time based on content length
      final wordCount = content.split(' ').length;
      final readTime = (wordCount / 200).ceil(); // Average reading speed

      return NewsArticle(
        title: title,
        summary: description,
        imageUrl: imageUrl,
        content: content,
        categories: categories,
        link: link,
        pubDate: pubDate,
        source: source,
        author: author,
        readTime: readTime > 0 ? readTime : 1,
      );
    }).toList();
  } catch (e) {
    // Return dummy data if RSS feed fails
    return List.generate(
      5,
      (index) => NewsArticle(
        title: 'Sample News Article ${index + 1}',
        summary:
            'This is a sample news article with interesting content that demonstrates the app\'s capabilities.',
        imageUrl:
            'https://picsum.photos/400/250?random=${Random().nextInt(1000)}',
        content:
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
        categories: ['Sample', 'News', 'Demo'],
        link: 'https://example.com',
        pubDate: DateTime.now().subtract(Duration(hours: index)),
        source: source,
        author: 'Demo Author',
        readTime: Random().nextInt(5) + 1,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Premium News App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const NewsHome(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.article,
                  size: 80,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Premium News',
                style: TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your Gateway to World News',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewsHome extends StatefulWidget {
  const NewsHome({super.key});

  @override
  State<NewsHome> createState() => _NewsHomeState();
}

class _NewsHomeState extends State<NewsHome> with TickerProviderStateMixin {
  late TabController _tabController;
  late List<Future<List<NewsArticle>>> _newsFutures;
  String _searchQuery = '';
  int _currentAdIndex = 0;
  bool _isPremium = false;
  int _currentIndex = 0; // For bottom navigation
  UserPreferences _userPreferences = UserPreferences();
  List<String> _bookmarks = [];
  List<String> _readingHistory = [];
  Map<String, NewsArticle> _offlineArticles = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: rssFeeds.length, vsync: this);
    _newsFutures = rssFeeds
        .map((feed) => fetchNews(feed.url, feed.name))
        .toList();

    _loadUserData();

    // Rotate advertisements
    Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() {
          _currentAdIndex = (_currentAdIndex + 1) % advertisements.length;
        });
      }
    });

    // Show reading reminder notification
    Timer.periodic(const Duration(hours: 6), (timer) {
      if (_userPreferences.enableNotifications) {
        NotificationService.showReadingReminder();
      }
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await StorageService.getUserPreferences();
    final bookmarks = await StorageService.getBookmarks();
    final history = await StorageService.getReadingHistory();
    final offline = await StorageService.getOfflineArticles();

    setState(() {
      _userPreferences = prefs;
      _bookmarks = bookmarks;
      _readingHistory = history;
      _offlineArticles = offline;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _newsFutures = rssFeeds
          .map((feed) => fetchNews(feed.url, feed.name))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Premium News',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final result = await showSearch<String?>(
                context: context,
                delegate: NewsSearchDelegate(_newsFutures, (query) {
                  setState(() => _searchQuery = query);
                }),
              );
              if (result != null) setState(() => _searchQuery = result);
            },
          ),
          IconButton(
            icon: Icon(_isPremium ? Icons.star : Icons.star_border),
            onPressed: () {
              setState(() => _isPremium = !_isPremium);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isPremium
                        ? 'Premium mode activated!'
                        : 'Premium mode deactivated',
                  ),
                  backgroundColor: _isPremium ? Colors.green : Colors.orange,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
        bottom: _currentIndex == 0
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: rssFeeds
                    .map((feed) => Tab(icon: Icon(feed.icon), text: feed.name))
                    .toList(),
              )
            : null,
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'News'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookmarks',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.download), label: 'Offline'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _refresh,
              child: const Icon(Icons.refresh),
            )
          : null,
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return TabBarView(
          controller: _tabController,
          children: rssFeeds.asMap().entries.map((entry) {
            final index = entry.key;
            final feed = entry.value;
            return _buildNewsTab(index, feed);
          }).toList(),
        );
      case 1:
        return _buildBookmarksPage();
      case 2:
        return _buildHistoryPage();
      case 3:
        return _buildOfflinePage();
      case 4:
        return _buildProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNewsTab(int index, RSSFeed feed) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<NewsArticle>>(
        future: _newsFutures[index],
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading news...'),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Failed to load news: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No news found.'),
                ],
              ),
            );
          }

          final articles = _searchQuery.isEmpty
              ? snapshot.data!
              : snapshot.data!
                    .where(
                      (a) =>
                          a.title.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          a.categories.any(
                            (c) => c.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                          ),
                    )
                    .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount:
                articles.length +
                (articles.length ~/ 3), // Add ads every 3 articles
            itemBuilder: (context, i) {
              // Insert advertisement every 3 articles
              if (i > 0 && i % 4 == 0) {
                final adIndex =
                    (_currentAdIndex + (i ~/ 4)) % advertisements.length;
                return _buildAdvertisement(advertisements[adIndex]);
              }

              final articleIndex = i - (i ~/ 4);
              if (articleIndex >= articles.length)
                return const SizedBox.shrink();

              final article = articles[articleIndex];
              return NewsCard(
                article: article,
                feedColor: feed.color,
                isPremium: _isPremium,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAdvertisement(Advertisement ad) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ad.color.withOpacity(0.1), ad.color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ad.color.withOpacity(0.3)),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.ads_click, color: ad.color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Sponsored',
                    style: TextStyle(
                      color: ad.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  ad.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: Icon(Icons.image, color: Colors.grey[400]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ad.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ad.description,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${ad.ctaText} clicked!'),
                        backgroundColor: ad.color,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ad.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(ad.ctaText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Settings Dialog
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Toggle dark/light theme'),
                  value: _userPreferences.isDarkMode,
                  onChanged: (value) {
                    setDialogState(() {
                      _userPreferences = _userPreferences.copyWith(
                        isDarkMode: value,
                      );
                    });
                  },
                ),
                ListTile(
                  title: const Text('Font Size'),
                  subtitle: Text('${_userPreferences.fontSize.round()}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          setDialogState(() {
                            _userPreferences = _userPreferences.copyWith(
                              fontSize: (_userPreferences.fontSize - 1).clamp(
                                12.0,
                                24.0,
                              ),
                            );
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setDialogState(() {
                            _userPreferences = _userPreferences.copyWith(
                              fontSize: (_userPreferences.fontSize + 1).clamp(
                                12.0,
                                24.0,
                              ),
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('Notifications'),
                  subtitle: const Text('Enable push notifications'),
                  value: _userPreferences.enableNotifications,
                  onChanged: (value) {
                    setDialogState(() {
                      _userPreferences = _userPreferences.copyWith(
                        enableNotifications: value,
                      );
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Text-to-Speech'),
                  subtitle: const Text('Enable TTS for articles'),
                  value: _userPreferences.enableTTS,
                  onChanged: (value) {
                    setDialogState(() {
                      _userPreferences = _userPreferences.copyWith(
                        enableTTS: value,
                      );
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await StorageService.saveUserPreferences(_userPreferences);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings saved!')),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Bookmarks Page
  Widget _buildBookmarksPage() {
    return FutureBuilder<List<NewsArticle>>(
      future: _getBookmarkedArticles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final articles = snapshot.data ?? [];
        if (articles.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No bookmarked articles yet'),
                SizedBox(height: 8),
                Text('Tap the bookmark icon on any article to save it here'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: articles.length,
          itemBuilder: (context, i) {
            final article = articles[i];
            return NewsCard(
              article: article,
              feedColor: rssFeeds
                  .firstWhere((f) => f.name == article.source)
                  .color,
              isPremium: _isPremium,
            );
          },
        );
      },
    );
  }

  // History Page
  Widget _buildHistoryPage() {
    return FutureBuilder<List<NewsArticle>>(
      future: _getHistoryArticles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final articles = snapshot.data ?? [];
        if (articles.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No reading history yet'),
                SizedBox(height: 8),
                Text('Your reading history will appear here'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: articles.length,
          itemBuilder: (context, i) {
            final article = articles[i];
            return NewsCard(
              article: article,
              feedColor: rssFeeds
                  .firstWhere((f) => f.name == article.source)
                  .color,
              isPremium: _isPremium,
            );
          },
        );
      },
    );
  }

  // Offline Page
  Widget _buildOfflinePage() {
    return FutureBuilder<Map<String, NewsArticle>>(
      future: StorageService.getOfflineArticles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final articles = snapshot.data?.values.toList() ?? [];
        if (articles.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No offline articles'),
                SizedBox(height: 8),
                Text('Download articles to read offline'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: articles.length,
          itemBuilder: (context, i) {
            final article = articles[i];
            return NewsCard(
              article: article,
              feedColor: rssFeeds
                  .firstWhere((f) => f.name == article.source)
                  .color,
              isPremium: _isPremium,
            );
          },
        );
      },
    );
  }

  // Profile Page
  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.deepPurple,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'News Reader',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _isPremium ? 'Premium Member' : 'Free User',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isPremium ? Colors.amber : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reading Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStatItem(
                    'Bookmarked Articles',
                    _bookmarks.length.toString(),
                  ),
                  _buildStatItem(
                    'Reading History',
                    _readingHistory.length.toString(),
                  ),
                  _buildStatItem(
                    'Offline Articles',
                    _offlineArticles.length.toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: _showSettingsDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.clear_all),
                    title: const Text('Clear History'),
                    onTap: _clearHistory,
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep),
                    title: const Text('Clear Offline Articles'),
                    onTap: _clearOfflineArticles,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<List<NewsArticle>> _getBookmarkedArticles() async {
    final allArticles = await Future.wait(_newsFutures);
    final flatArticles = allArticles.expand((articles) => articles).toList();
    return flatArticles
        .where((article) => _bookmarks.contains(article.id))
        .toList();
  }

  Future<List<NewsArticle>> _getHistoryArticles() async {
    final allArticles = await Future.wait(_newsFutures);
    final flatArticles = allArticles.expand((articles) => articles).toList();
    return flatArticles
        .where((article) => _readingHistory.contains(article.id))
        .toList();
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to clear your reading history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await StorageService.clearReadingHistory();
              setState(() {
                _readingHistory.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('History cleared!')));
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _clearOfflineArticles() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Offline Articles'),
        content: const Text(
          'Are you sure you want to clear all offline articles?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await StorageService.clearOfflineArticles();
              setState(() {
                _offlineArticles.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offline articles cleared!')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final NewsArticle article;
  final Color feedColor;
  final bool isPremium;

  const NewsCard({
    super.key,
    required this.article,
    required this.feedColor,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailPage(
              article: article,
              feedColor: feedColor,
              isPremium: isPremium,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (article.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.network(
                      article.imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.broken_image,
                          size: 60,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                if (isPremium)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'PREMIUM',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${article.readTime} min read',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          article.source,
                          style: TextStyle(
                            fontSize: 12,
                            color: feedColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By ${article.author}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (article.categories.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: article.categories
                          .take(3)
                          .map(
                            (cat) => Chip(
                              label: Text(
                                cat,
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: feedColor.withOpacity(0.1),
                              labelStyle: TextStyle(color: feedColor),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    article.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                  if (article.pubDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat(
                              'MMM dd, yyyy • HH:mm',
                            ).format(article.pubDate!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsDetailPage extends StatelessWidget {
  final NewsArticle article;
  final Color feedColor;
  final bool isPremium;

  const NewsDetailPage({
    super.key,
    required this.article,
    required this.feedColor,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          article.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () async {
              await TTSService.speak(article.content);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Text-to-Speech started')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              await Share.share(
                '${article.title}\n\n${article.summary}\n\nRead more: ${article.link}',
                subject: article.title,
              );
            },
          ),
          FutureBuilder<bool>(
            future: StorageService.getBookmarks().then(
              (bookmarks) => bookmarks.contains(article.id),
            ),
            builder: (context, snapshot) {
              final isBookmarked = snapshot.data ?? false;
              return IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                onPressed: () async {
                  if (isBookmarked) {
                    await StorageService.removeBookmark(article.id);
                  } else {
                    await StorageService.addBookmark(article.id);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isBookmarked
                            ? 'Bookmark removed!'
                            : 'Article bookmarked!',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (article.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                article.imageUrl,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.broken_image,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Article metadata
          Row(
            children: [
              CircleAvatar(
                backgroundColor: feedColor.withOpacity(0.1),
                child: Icon(Icons.person, color: feedColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.author,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      article.source,
                      style: TextStyle(
                        fontSize: 14,
                        color: feedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'PREMIUM',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Categories
          if (article.categories.isNotEmpty)
            Wrap(
              spacing: 8,
              children: article.categories
                  .map(
                    (cat) => Chip(
                      label: Text(cat),
                      backgroundColor: feedColor.withOpacity(0.1),
                      labelStyle: TextStyle(color: feedColor),
                    ),
                  )
                  .toList(),
            ),

          const SizedBox(height: 16),

          // Title
          Text(
            article.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          // Publication date and read time
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM dd, yyyy • HH:mm').format(article.pubDate!),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${article.readTime} min read',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Content
          Text(
            article.content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Read Original'),
                  onPressed: () async {
                    final url = Uri.parse(article.link);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: feedColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  onPressed: () async {
                    await StorageService.saveOfflineArticle(article);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Article saved for offline reading!'),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: feedColor,
                    side: BorderSide(color: feedColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Related articles placeholder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Related Articles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: feedColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'More articles from this category will appear here.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewsSearchDelegate extends SearchDelegate<String?> {
  final List<Future<List<NewsArticle>>> newsFutures;
  final void Function(String) onQueryUpdate;

  NewsSearchDelegate(this.newsFutures, this.onQueryUpdate);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear),
      onPressed: () {
        query = '';
        onQueryUpdate(query);
      },
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    onQueryUpdate(query);
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<List<NewsArticle>>>(
      future: Future.wait(newsFutures),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allArticles = snapshot.data!
            .expand((articles) => articles)
            .toList();
        final results = allArticles
            .where(
              (a) =>
                  a.title.toLowerCase().contains(query.toLowerCase()) ||
                  a.categories.any(
                    (c) => c.toLowerCase().contains(query.toLowerCase()),
                  ),
            )
            .toList();

        if (results.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No articles found matching your search.'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, i) {
            final article = results[i];
            return NewsCard(
              article: article,
              feedColor: rssFeeds
                  .firstWhere((f) => f.name == article.source)
                  .color,
              isPremium: false,
            );
          },
        );
      },
    );
  }
}
