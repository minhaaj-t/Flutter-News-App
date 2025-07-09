import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

const Map<String, String> rssFeeds = {
  'World': 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml',
  'Asia Pacific':
      'https://rss.nytimes.com/services/xml/rss/nyt/AsiaPacific.xml',
  'Business': 'https://rss.nytimes.com/services/xml/rss/nyt/Business.xml',
  'Energy & Environment':
      'https://rss.nytimes.com/services/xml/rss/nyt/EnergyEnvironment.xml',
  'Sports': 'https://rss.nytimes.com/services/xml/rss/nyt/Sports.xml',
  'Personal Tech':
      'https://rss.nytimes.com/services/xml/rss/nyt/PersonalTech.xml',
};

class NewsArticle {
  final String title;
  final String summary;
  final String imageUrl;
  final String content;
  final List<String> categories;
  final String link;
  final DateTime? pubDate;

  NewsArticle({
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.content,
    required this.categories,
    required this.link,
    required this.pubDate,
  });
}

Future<List<NewsArticle>> fetchNews(String feedUrl) async {
  final response = await http.get(Uri.parse(feedUrl));
  if (response.statusCode != 200) throw Exception('Failed to load news');
  final document = xml.XmlDocument.parse(response.body);
  final items = document.findAllElements('item');
  return items.map((item) {
    final title = item.getElement('title')?.text ?? '';
    final description = item.getElement('description')?.text ?? '';
    final content = item.getElement('content:encoded')?.text ?? description;
    final enclosure = item.getElement('enclosure');
    final imageUrl = enclosure?.getAttribute('url') ?? '';
    final link = item.getElement('link')?.text ?? '';
    final pubDateStr = item.getElement('pubDate')?.text;
    DateTime? pubDate;
    if (pubDateStr != null) {
      try {
        pubDate = DateTime.parse(pubDateStr);
      } catch (_) {
        pubDate = null;
      }
    }
    final categories = item
        .findElements('category')
        .map((c) => c.text)
        .toList();
    return NewsArticle(
      title: title,
      summary: description,
      imageUrl: imageUrl,
      content: content,
      categories: categories,
      link: link,
      pubDate: pubDate,
    );
  }).toList();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NYT News',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'NotoSansMalayalam',
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const NewsHome()),
      );
    });
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.article, size: 80, color: Colors.white),
            SizedBox(height: 24),
            Text(
              'NYT News',
              style: TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Powered by The New York Times',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
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

class _NewsHomeState extends State<NewsHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, List<NewsArticle>> _articles = {};
  final Map<String, bool> _loading = {};
  final Map<String, String> _searchQuery = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: rssFeeds.length, vsync: this);
    for (final key in rssFeeds.keys) {
      _loading[key] = true;
      _searchQuery[key] = '';
      fetchNews(rssFeeds[key]!)
          .then((list) {
            setState(() {
              _articles[key] = list;
              _loading[key] = false;
            });
          })
          .catchError((_) {
            setState(() {
              _articles[key] = [];
              _loading[key] = false;
            });
          });
    }
  }

  void _refreshTab(String key) async {
    setState(() => _loading[key] = true);
    final list = await fetchNews(rssFeeds[key]!);
    setState(() {
      _articles[key] = list;
      _loading[key] = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: rssFeeds.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'NYT News',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                final key = rssFeeds.keys.elementAt(_tabController.index);
                showSearch(
                  context: context,
                  delegate: NewsSearchDelegate(_articles[key] ?? [], (query) {
                    setState(() => _searchQuery[key] = query);
                  }),
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: [for (final key in rssFeeds.keys) Tab(text: key)],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            for (final key in rssFeeds.keys)
              RefreshIndicator(
                onRefresh: () async => _refreshTab(key),
                child: _loading[key] == true
                    ? const Center(child: CircularProgressIndicator())
                    : NewsList(
                        articles: (_searchQuery[key] ?? '').isEmpty
                            ? (_articles[key] ?? [])
                            : (_articles[key] ?? [])
                                  .where(
                                    (a) =>
                                        a.title.toLowerCase().contains(
                                          _searchQuery[key]!.toLowerCase(),
                                        ) ||
                                        a.categories.any(
                                          (c) => c.toLowerCase().contains(
                                            _searchQuery[key]!.toLowerCase(),
                                          ),
                                        ),
                                  )
                                  .toList(),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class NewsList extends StatelessWidget {
  final List<NewsArticle> articles;
  const NewsList({super.key, required this.articles});
  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return const Center(child: Text('No news found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: articles.length,
      itemBuilder: (context, i) {
        final article = articles[i];
        return NewsCard(article: article);
      },
    );
  }
}

class NewsCard extends StatelessWidget {
  final NewsArticle article;
  const NewsCard({super.key, required this.article});
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
          MaterialPageRoute(builder: (_) => NewsDetailPage(article: article)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  if (article.categories.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final cat in article.categories)
                          Chip(
                            label: Text(
                              cat,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
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
                      child: Text(
                        '${article.pubDate}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
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
  const NewsDetailPage({super.key, required this.article});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (article.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                article.imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  height: 220,
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
          if (article.categories.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final cat in article.categories) Chip(label: Text(cat)),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            article.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (article.pubDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${article.pubDate}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 16),
          Text(article.content, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Read original'),
            onPressed: () async {
              final url = Uri.parse(article.link);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}

class NewsSearchDelegate extends SearchDelegate {
  final List<NewsArticle> articles;
  final void Function(String) onQueryUpdate;
  NewsSearchDelegate(this.articles, this.onQueryUpdate);
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
    final results = articles
        .where(
          (a) =>
              a.title.toLowerCase().contains(query.toLowerCase()) ||
              a.categories.any(
                (c) => c.toLowerCase().contains(query.toLowerCase()),
              ),
        )
        .toList();
    return NewsList(articles: results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    onQueryUpdate(query);
    final results = articles
        .where(
          (a) =>
              a.title.toLowerCase().contains(query.toLowerCase()) ||
              a.categories.any(
                (c) => c.toLowerCase().contains(query.toLowerCase()),
              ),
        )
        .toList();
    return NewsList(articles: results);
  }
}
