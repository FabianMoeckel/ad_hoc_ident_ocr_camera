import 'dart:async';
import 'dart:io';

import 'package:ad_hoc_ident_ocr/ad_hoc_ident_ocr.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as flutter_svc;

/// A basic camera view to produce OcrImages.
class CameraView extends StatefulWidget {
  /// Builds an empty container as the default placeholder.
  static Widget containerPlaceholderBuilder(BuildContext context) =>
      Container();

  /// Builds a Text widget containing the stringified error.
  static Widget textErrorBuilder(BuildContext context, Object error) =>
      Text(error.toString());

  /// Creates no overly by returning null.
  static Widget? noOverlayBuilder(BuildContext context) => null;

  /// The builder to use when the camera is not yet ready.
  final Widget Function(BuildContext context) placeholderBuilder;

  /// The builder to use when the camera encountered an
  /// error during initialization.
  final Widget Function(BuildContext context, Object error) errorBuilder;

  /// The builder to use to create an overlay stacked on top
  /// of the camera preview.
  final Widget? Function(BuildContext context) overlayBuilder;

  /// The name of the [ImageFormatGroup] to use.
  ///
  /// Valid values are: unknown, yuv420, nv21, bgra8888, jpeg.
  /// Unkown will default to nv21 for android and bgra8888 for iOS and web.
  /// Some versions of the camera_android_camerax plugin ignore the image
  /// format. As a workaround you can use the camera_android plugin.
  final String imageFormatGroupName;

  /// The callback to invoke when an image was detected.
  final FutureOr<void> Function(OcrImage ocrImage)? onImage;

  /// Creates a camera preview that converts the [CameraImage] stream
  /// to [OcrImage].
  const CameraView({
    super.key,
    this.imageFormatGroupName = 'unknown',
    this.onImage,
    this.placeholderBuilder = containerPlaceholderBuilder,
    this.errorBuilder = textErrorBuilder,
    this.overlayBuilder = noOverlayBuilder,
  });

  @override
  State<StatefulWidget> createState() {
    return _CameraViewState();
  }
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  static OcrImage _convert(
      CameraImage image, flutter_svc.DeviceOrientation orientation) {
    // final flipLandscape = !kIsWeb && Platform.isAndroid;
    final orientationEnum = switch (orientation) {
      flutter_svc.DeviceOrientation.portraitUp => DeviceOrientation.portraitUp,
      flutter_svc.DeviceOrientation.landscapeLeft =>
        DeviceOrientation.landscapeLeft,
      flutter_svc.DeviceOrientation.portraitDown =>
        DeviceOrientation.portraitUp,
      flutter_svc.DeviceOrientation.landscapeRight =>
        DeviceOrientation.landscapeRight,
    };

    final ocrImage = OcrImage(
        // only single plane images are supported (nv21 or bgra8888)
        singlePlaneBytes: image.planes[0].bytes,
        singlePlaneBytesPerRow: image.planes[0].bytesPerRow,
        width: image.width,
        height: image.height,
        cameraSensorOrientation: orientationEnum,
        rawImageFormat: image.format.raw);

    return ocrImage;
  }

  late final ImageFormatGroup _imageFormat;

  CameraController? _controller;
  Object? _cameraException;

  @override
  void initState() {
    WidgetsFlutterBinding.ensureInitialized();

    _setupController();

    // If we received an invalid format, we default to nv21/bgra8888
    final widgetImageFormat = ImageFormatGroup.values.firstWhere(
        (element) => element.name == widget.imageFormatGroupName,
        orElse: () => ImageFormatGroup.unknown);
    _imageFormat = widgetImageFormat != ImageFormatGroup.unknown
        ? widgetImageFormat
        : (!kIsWeb && Platform.isAndroid
            ? ImageFormatGroup.nv21 // for Android
            : ImageFormatGroup.bgra8888); // for iOs and web

    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  Future<void> _setupController([CameraDescription? cameraDescription]) async {
    if (cameraDescription == null) {
      final cameraDescriptions = await availableCameras();
      cameraDescription =
          cameraDescriptions.cast<CameraDescription?>().firstWhere(
                (description) =>
                    description?.lensDirection == CameraLensDirection.back,
                orElse: () => cameraDescriptions.firstOrNull,
              );
    }
    if (cameraDescription == null) {
      if (mounted) {
        setState(() {
          _cameraException =
              CameraException('cameraNotFound', 'No device camera available.');
        });
      }
      return;
    }

    final controller = CameraController(
        cameraDescription, ResolutionPreset.medium,
        enableAudio: false, fps: 30, imageFormatGroup: _imageFormat);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.startImageStream(_onImage(controller));
      if (mounted) {
        setState(() {
          _cameraException = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _cameraException = error;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      await controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera
      await _setupController(controller.description);
    }

    super.didChangeAppLifecycleState(state);
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return _cameraException != null
        ? widget.errorBuilder(
            context, _cameraException ?? Exception('An unknown error occurred'))
        : controller == null || !controller.value.isInitialized
            ? widget.placeholderBuilder(context)
            : _buildCameraPreview(context, controller);
  }

  Widget _buildCameraPreview(
      BuildContext context, CameraController controller) {
    return AspectRatio(
      aspectRatio: 1 / controller.value.aspectRatio,
      child: CameraPreview(
        controller,
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown:
                    _adjustFocusAndExposureOnTap(controller, constraints),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                onPressed: _toggleTorch(controller),
                icon: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(controller.value.flashMode == FlashMode.torch
                      ? Icons.flashlight_off
                      : Icons.flashlight_on),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> Function() _toggleTorch(CameraController controller) {
    final initialFlashMode = controller.value.flashMode;
    final torchWasEnabled = initialFlashMode == FlashMode.torch;
    final modeToSwitchTo = torchWasEnabled ? FlashMode.off : FlashMode.torch;
    return () async {
      final currentFlashMode = controller.value.flashMode;
      final flashModeIsChanged = currentFlashMode != initialFlashMode;

      await controller.setFlashMode(
        flashModeIsChanged ? initialFlashMode : modeToSwitchTo,
      );
      setState(() {}); // refresh torch button state
    };
  }

  void Function(TapDownDetails details) _adjustFocusAndExposureOnTap(
      CameraController controller, BoxConstraints constraints) {
    return (TapDownDetails details) {
      final offset = Offset(
        details.localPosition.dx / constraints.maxWidth,
        details.localPosition.dy / constraints.maxHeight,
      );
      controller.setExposurePoint(offset);
      controller.setFocusPoint(offset);
    };
  }

  Future<void> Function(CameraImage cameraImage) _onImage(
      CameraController controller) {
    return (CameraImage cameraImage) async {
      final orientation = controller.value.deviceOrientation;
      final ocrImage = _convert(cameraImage, orientation);
      await widget.onImage?.call(ocrImage);
    };
  }
}
