import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:photoapp/imagedetail.dart';
import 'upload_image.dart';

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

  Future<List<XFile>> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    return images;
  }

  Future<void> _importImage() async {
    final images = await _pickImages();

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
              onPressed: _importImage,
              child: Text("Import Images"),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: UploadImage(importImage: _pickImages, title: widget.title),
          ),
        ],
      ),
    );
  }
}
