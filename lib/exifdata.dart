import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:exif/exif.dart';

class Exifdata extends StatefulWidget {
  final List<XFile> allimages;
  final int index;
  const Exifdata({super.key, required this.allimages, required this.index});

  @override
  State<Exifdata> createState() => _ExifdataState();
}

class _ExifdataState extends State<Exifdata> {
  Future<String> getexif(List<XFile> allimages, int index) async {
    final pickedFile = allimages[index];
    final tags = await readExifFromBytes(
      await File(pickedFile.path).readAsBytes(),
    );
    return tags.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: FutureBuilder(
        future: getexif(widget.allimages, widget.index),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(snapshot.data ?? 'No EXIF data found'),
              ),
            );
          }
        },
      ),
    );
  }
}
