import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

import 'package:photoapp/imagedetail.dart';
// import 'imagedetail.dart';

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<XFile> allimages = [];

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    setState(() {
      for (var image in images) {
        // ファイル名で重複チェック（パスは毎回変わる可能性があるため）
        String fileName = image.name;

        bool alreadyExists = allimages.any((img) => img.name == fileName);

        if (!alreadyExists) {
          allimages.add(image);
          debugPrint('追加: $fileName');
        } else {
          debugPrint('重複のためスキップ: $fileName');
        }
      }
    });
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
                          (context) =>
                              (Imagedetail(index: index, allimages: allimages)),
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
