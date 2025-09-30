import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<XFile> _images = [];

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    setState(() {
      _images.addAll(images);
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
            itemCount: _images.length,
            itemBuilder: (BuildContext context, int index) {
              return ClipRRect(
                child: Image.file(File(_images[index].path), fit: BoxFit.cover),
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
