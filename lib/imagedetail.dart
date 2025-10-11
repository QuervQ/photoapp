import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:photoapp/exifdata.dart';
import 'package:flutter/services.dart';

class Imagedetail extends StatefulWidget {
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
  State<Imagedetail> createState() => _ImagedetailState();
}

class _ImagedetailState extends State<Imagedetail> {
  static const platform = MethodChannel('com.QuervQ.photoapp/swift');

  Future<void> openARView() async {
    try {
      await platform.invokeMethod('switchArMode', {
        'path': widget.allimages[widget.index].path,
      });
      debugPrint(
        "Image path sent to native: ${widget.allimages[widget.index].path}",
      );
    } on PlatformException catch (e) {
      debugPrint("Failed to open AR view: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: widget.index),
            itemCount: widget.allimages.length,
            itemBuilder: (context, index) {
              return Image.file(
                File(widget.allimages[index].path),
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
                    return Exifdata(
                      allimages: widget.allimages,
                      index: widget.index,
                    );
                  },
                );
              },
              child: Icon(CupertinoIcons.info),
            ),
          ),
          Container(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: openARView,
              child: Icon(CupertinoIcons.camera),
            ),
          ),
        ],
      ),
    );
  }
}
