import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Imagedetail extends StatefulWidget {
  final int index;
  final List<String> imageUrls;
  const Imagedetail({super.key, required this.index, required this.imageUrls});
  @override
  State<Imagedetail> createState() => _ImagedetailState();
}

class _ImagedetailState extends State<Imagedetail> {
  static const platform = MethodChannel('dev.quervq.photoapp/swift');
  late final PageController _pageController;
  int _currentIndex = 0;
  final Map<int, String> _localPathCache = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _pageController = PageController(initialPage: widget.index);
  }

  Future<String> _resolveCurrentImagePath() async {
    final cachedPath = _localPathCache[_currentIndex];
    if (cachedPath != null && await File(cachedPath).exists()) {
      return cachedPath;
    }

    final imageUrl = widget.imageUrls[_currentIndex];
    final uri = Uri.parse(imageUrl);
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('download failed: ${response.statusCode}');
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      final tempDir = await Directory.systemTemp.createTemp('photoapp_');
      final filePath =
          '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      _localPathCache[_currentIndex] = filePath;
      return filePath;
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<void> _openARView() async {
    try {
      final imagePath = await _resolveCurrentImagePath();
      await platform.invokeMethod('switchArMode', {'path': imagePath});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AR表示に失敗しました: $e')));
    }
  }

  Future<void> _showExifData() async {
    try {
      final imagePath = await _resolveCurrentImagePath();
      final result = await platform.invokeMethod('getExifData', {
        'path': imagePath,
      });

      if (!mounted) return;
      final exifText = _formatExifData(result);
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(exifText),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('EXIF取得に失敗しました: $e')));
    }
  }

  String _formatExifData(dynamic result) {
    if (result == null) return 'No EXIF data found';
    if (result is! Map<dynamic, dynamic>) return result.toString();

    final buffer = StringBuffer();
    result.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    final text = buffer.toString();
    return text.isEmpty ? 'No EXIF data found' : text;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Image.network(
                widget.imageUrls[index],
                fit: BoxFit.contain,
              );
            },
          ),
          Positioned(
            top: 48,
            left: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(CupertinoIcons.back),
            ),
          ),
          Container(
            alignment: Alignment.bottomCenter,
            child: ElevatedButton(
              onPressed: _showExifData,
              child: const Icon(CupertinoIcons.info),
            ),
          ),
          Container(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: _openARView,
              child: const Icon(CupertinoIcons.camera),
            ),
          ),
        ],
      ),
    );
  }
}
