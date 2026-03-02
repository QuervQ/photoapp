import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:photoapp/imagedetail.dart';
import 'upload_image.dart';

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<String> allImageUrls = [];
  bool isInitialLoading = true;
  final supabase = Supabase.instance.client;

  Future<void> _openImageDetail(int index) async {
    if (index < 0 || index >= allImageUrls.length) {
      return;
    }

    final imageUrlsSnapshot = List<String>.from(allImageUrls);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) =>
                  Imagedetail(index: index, imageUrls: imageUrlsSnapshot),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('詳細画面を開けませんでした: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUploadedImages();
  }

  Future<void> _handleUploaded(List<String> newUploadedUrls) async {
    if (newUploadedUrls.isNotEmpty) {
      setState(() {
        allImageUrls.insertAll(0, newUploadedUrls);
      });
    }
    _loadUploadedImages(showLoading: false);
  }

  Future<void> _loadUploadedImages({bool showLoading = true}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        allImageUrls.clear();
        isInitialLoading = false;
      });
      return;
    }

    if (showLoading && isInitialLoading) {
      setState(() {
        isInitialLoading = true;
      });
    }

    try {
      final files = await supabase.storage.from('photos').list(path: userId);
      final urls = await Future.wait(
        files.map((file) {
          final filePath = '$userId/${file.name}';
          return supabase.storage
              .from('photos')
              .createSignedUrl(filePath, 60 * 60);
        }),
      );

      if (!mounted) return;
      setState(() {
        allImageUrls
          ..clear()
          ..addAll(urls);
        isInitialLoading = false;
      });
    } catch (e, st) {
      debugPrint('画像一覧の取得に失敗: $e\n$st');
      if (!mounted) return;
      setState(() {
        isInitialLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () async {
              await supabase.auth.signOut();
            },
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (isInitialLoading && allImageUrls.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemCount: allImageUrls.length,
              itemBuilder: (BuildContext context, int index) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openImageDetail(index),
                    child: Image.network(
                      allImageUrls[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          Positioned(
            bottom: 16,
            left: 16,
            child: UploadImage(
              title: widget.title,
              onUploaded: _handleUploaded,
            ),
          ),
        ],
      ),
    );
  }
}
