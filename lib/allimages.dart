import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:photoapp/imagedetail.dart';

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<XFile> allimages = [];
  final Set<String> imagehashes = {};
  Future<String> _calculateImageHash(XFile image) async {
    final bytes = await image.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    for (var image in images) {
      String hash = await _calculateImageHash(image);

      if (!imagehashes.contains(hash)) {
        setState(() {
          allimages.add(image);
          imagehashes.add(hash);
        });
        debugPrint('追加: ${image.name}');
      } else {
        debugPrint('重複のためスキップ: ${image.name} (同じ画像が既に存在)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),

            itemCount: allimages.length,
            itemBuilder: (BuildContext context, int index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder:
                          (context) => (Imagedetail(
                            index: index,
                            allimages: allimages,
                            images: allimages[index],
                          )),
                    ),
                  );
                },
                child: Image.file(
                  File(allimages[index].path),
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: CupertinoButton(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(30),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              onPressed: _pickImages,
              child: Text("Import Images"),
            ),
          ),
        ],
      ),
    );
  }
}
