import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class Imagedetail extends StatelessWidget {
  final int index;
  final List<XFile> allimages;
  const Imagedetail({super.key, required this.index, required this.allimages});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: PageController(initialPage: index),
        itemCount: allimages.length,
        itemBuilder: (context, index) {
          return Image.file(File(allimages[index].path), fit: BoxFit.contain);
        },
      ),
    );
  }
}
