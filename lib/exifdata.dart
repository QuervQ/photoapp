import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
    String imageWidth = tags['Image ImageWidth'].toString();
    String imageLength = tags['Image ImageLength'].toString();
    String exifOffset = tags['Image ExifOffset'].toString();
    String dateTime = tags['Image DateTime'].toString();
    String imageModel = tags['Image Model'].toString();
    String imageMake = tags['Image Make'].toString();
    String imageOrientation = tags['Image Orientation'].toString();
    String whiteBalance = tags['EXIF WhiteBalance'].toString();
    String gpsLatitude = tags['GPS GPSLatitude'].toString();
    String gpsLongitude = tags['GPS GPSLongitude'].toString();
    String gpsAltitude = tags['GPS GPSAltitude'].toString();
    String gpsLatitudeRef = tags['GPS GPSLatitudeRef'].toString();
    String gpsLongitudeRef = tags['GPS GPSLongitudeRef'].toString();
    String gpsAltitudeRef = tags['GPS GPSAltitudeRef'].toString();
    debugPrint(
      '画像の幅: $imageWidth'
      '画像の高さ: $imageLength'
      'Exifオフセット: $exifOffset'
      '撮影日時: $dateTime'
      'カメラモデル: $imageModel'
      'カメラメーカー: $imageMake'
      '画像の向き: $imageOrientation'
      'ホワイトバランス: $whiteBalance'
      '緯度: $gpsLatitude $gpsLatitudeRef'
      '経度: $gpsLongitude $gpsLongitudeRef'
      '高度: $gpsAltitude $gpsAltitudeRef',
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
