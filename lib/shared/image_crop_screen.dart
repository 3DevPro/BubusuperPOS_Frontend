import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Pushes onto the navigator and pops with the cropped image bytes, or null
/// if the user backs out. Fixed to the same aspect ratio as the POS product
/// card (see pos_screen.dart's childAspectRatio) so a portrait photo doesn't
/// leave a slab of empty space beside it once it's shown with BoxFit.contain.
class ImageCropScreen extends StatefulWidget {
  const ImageCropScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _controller = CropController();
  bool _cropping = false;

  void _confirm() {
    setState(() => _cropping = true);
    _controller.crop();
  }

  void _onCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ครอบรูปไม่สำเร็จ ลองใหม่อีกครั้ง')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ครอบรูปสินค้า'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _cropping ? null : _confirm,
            child: _cropping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('ตกลง', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Crop(
        image: widget.imageBytes,
        controller: _controller,
        aspectRatio: 1.1,
        baseColor: Colors.black,
        maskColor: Colors.black.withAlpha(180),
        onCropped: _onCropped,
      ),
    );
  }
}
