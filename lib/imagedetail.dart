import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:photoapp/exifdata.dart';

class Imagedetail extends StatelessWidget {
  final int index;
  final List<XFile> allimages;
  final XFile images;
  const Imagedetail({
    super.key,
    required this.index,
    required this.allimages,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: allimages.length,
            itemBuilder: (context, index) {
              return Image.file(
                File(allimages[index].path),
                fit: BoxFit.contain,
              );
            },
          ),
          Container(
            alignment: Alignment.bottomCenter,
            child: ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (BuildContext context) {
                    return Exifdata(allimages: allimages, index: index);
                  },
                );
              },
              child: Icon(CupertinoIcons.info),
            ),
          ),
        ],
      ),
    );
  }
}
