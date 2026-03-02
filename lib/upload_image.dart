import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';

class UploadImage extends StatefulWidget {
  final String title;
  final Future<void> Function(List<String> newUploadedUrls) onUploaded;
  const UploadImage({super.key, required this.title, required this.onUploaded});

  @override
  State<UploadImage> createState() => _UploadImageState();
}

final supabase = Supabase.instance.client;

class _UploadImageState extends State<UploadImage> {
  Future<void> uploadCloud() async {
    debugPrint('uploadCloud start'); // ← 重要
    try {
      final picker = ImagePicker();
      final allimages = await picker.pickMultiImage();
      if (allimages.isEmpty) {
        return;
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        return;
      }

      final List<String> newUploadedUrls = [];

      for (var images in allimages) {
        final ctype = lookupMimeType(images.path);
        debugPrint(ctype);
        final fileName =
            '$userId/${DateTime.now().millisecondsSinceEpoch}_${images.name}';
        final bytes = await File(images.path).readAsBytes();
        final String fullpath = await supabase.storage
            .from('photos')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(contentType: ctype),
            );

        debugPrint(fullpath);
        final signedUrl = await supabase.storage
            .from('photos')
            .createSignedUrl(fileName, 60 * 60);
        newUploadedUrls.add(signedUrl);
      }

      await widget.onUploaded(newUploadedUrls);
    } catch (e, st) {
      debugPrint('Upload failed: $e\n$st');

      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      color: Colors.blue,
      borderRadius: BorderRadius.circular(30),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      onPressed: () {
        debugPrint('button pressed');
        uploadCloud();
      },
      child: Text("upload cloud"),
    );
  }
}
