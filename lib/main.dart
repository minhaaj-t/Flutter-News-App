import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Newsly',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'NotoSansMalayalam',
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Start timer to navigate to home after 2 seconds
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MyHomePage(title: 'News Home'),
        ),
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
              'Newsly',
              style: TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// Mock news data
class NewsArticle {
  final String title;
  final String summary;
  final String imageUrl;
  final String content;
  final List<String> categories;

  NewsArticle({
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.content,
    required this.categories,
  });
}

Future<List<NewsArticle>> fetchNews() async {
  const rssUrl = 'https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml';
  final response = await http.get(Uri.parse(rssUrl));
  if (response.statusCode != 200) throw Exception('Failed to load news');
  final document = xml.XmlDocument.parse(response.body);
  final items = document.findAllElements('item');
  return items.map((item) {
    final title = item.getElement('title')?.text ?? '';
    final description = item.getElement('description')?.text ?? '';
    final content = item.getElement('content:encoded')?.text ?? description;
    final enclosure = item.getElement('enclosure');
    final imageUrl = enclosure?.getAttribute('url') ?? '';
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
    );
  }).toList();
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<List<NewsArticle>> _newsFuture;

  @override
  void initState() {
    super.initState();
    _newsFuture = fetchNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D5DF6), Color(0xFF46A0FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
          title: Text(
            widget.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: Column(
        children: [
          // Category chips (mock)
          Container(
            height: 48,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Chip(
                  label: Text('All', style: TextStyle(color: Colors.white)),
                  backgroundColor: Color(0xFF6D5DF6),
                ),
                SizedBox(width: 8),
                Chip(label: Text('Tech'), backgroundColor: Colors.grey[200]),
                SizedBox(width: 8),
                Chip(label: Text('Mobile'), backgroundColor: Colors.grey[200]),
                SizedBox(width: 8),
                Chip(label: Text('Flutter'), backgroundColor: Colors.grey[200]),
                SizedBox(width: 8),
                Chip(label: Text('Dart'), backgroundColor: Colors.grey[200]),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<NewsArticle>>(
              future: _newsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load news: ${snapshot.error}'),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No news available.'));
                }
                final news = snapshot.data!;
                return ListView.builder(
                  itemCount: news.length,
                  itemBuilder: (context, index) {
                    final article = news[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReadPage(article: article),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (article.imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                ),
                                child: Image.network(
                                  article.imageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 180,
                                        width: double.infinity,
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
                                      color: Color(0xFF222B45),
                                      fontFamily: 'NotoSansMalayalam',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    article.summary,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF8F9BB3),
                                      fontFamily: 'NotoSansMalayalam',
                                    ),
                                  ),
                                  if (article.categories.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children: article.categories
                                          .map(
                                            (cat) => Chip(
                                              label: Text(
                                                cat,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              backgroundColor: Colors.blue[50],
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ReadPage extends StatelessWidget {
  final NewsArticle article;
  const ReadPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D5DF6), Color(0xFF46A0FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
          title: Text(
            article.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
              fontFamily: 'NotoSansMalayalam',
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                article.imageUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: 220,
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.broken_image,
                    size: 80,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              article.title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222B45),
                fontFamily: 'NotoSansMalayalam',
              ),
            ),
            if (article.categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: article.categories
                    .map(
                      (cat) => Chip(
                        label: Text(cat, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.blue[50],
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              article.content,
              style: const TextStyle(
                fontSize: 17,
                color: Color(0xFF444E5E),
                height: 1.5,
                fontFamily: 'NotoSansMalayalam',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
