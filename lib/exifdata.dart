import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// import 'dart:io';

class Exifdata extends StatefulWidget {
  final List<XFile> allimages;
  final int index;
  const Exifdata({super.key, required this.allimages, required this.index});

  @override
  State<Exifdata> createState() => _ExifdataState();
}

class _ExifdataState extends State<Exifdata> {
  static const platform = MethodChannel('dev.quervq.photoapp/swift');

  Future<String> getexif(List<XFile> allimages, int index) async {
    try {
      final pickedFile = allimages[index];
      final result = await platform.invokeMethod('getExifData', {
        'path': pickedFile.path,
      });

      if (result == null) {
        return 'No EXIF data found';
      }

      // 結果を整形して表示
      final exifData = result as Map<dynamic, dynamic>;
      final buffer = StringBuffer();

      exifData.forEach((key, value) {
        buffer.writeln('$key: $value');
      });

      debugPrint('EXIF Data: ${buffer.toString()}');
      return buffer.toString();
    } on PlatformException catch (e) {
      debugPrint('Failed to get EXIF data: ${e.message}');
      return 'Error: ${e.message}';
    } catch (e) {
      debugPrint('Unexpected error: $e');
      return 'Error: $e';
    }
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
