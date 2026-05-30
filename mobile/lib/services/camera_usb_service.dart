import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CameraProbeResult {
  CameraProbeResult({
    required this.connected,
    this.needsPermission = false,
    this.productName,
    this.manufacturer,
    this.imageCount = 0,
    this.storageCount = 0,
    this.sampleFiles = const [],
    this.error,
  });

  factory CameraProbeResult.fromMap(Map<dynamic, dynamic> map) {
    return CameraProbeResult(
      connected: map['connected'] as bool? ?? false,
      needsPermission: map['needsPermission'] as bool? ?? false,
      productName: map['productName'] as String?,
      manufacturer: map['manufacturer'] as String?,
      imageCount: (map['imageCount'] as num?)?.toInt() ?? 0,
      storageCount: (map['storageCount'] as num?)?.toInt() ?? 0,
      sampleFiles: (map['sampleFiles'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      error: map['error'] as String?,
    );
  }

  final bool connected;
  final bool needsPermission;
  final String? productName;
  final String? manufacturer;
  final int imageCount;
  final int storageCount;
  final List<String> sampleFiles;
  final String? error;
}

class CameraRemoteImage {
  CameraRemoteImage({
    required this.handle,
    required this.name,
    required this.size,
    required this.modified,
  });

  factory CameraRemoteImage.fromMap(Map<dynamic, dynamic> map) {
    return CameraRemoteImage(
      handle: (map['handle'] as num).toInt(),
      name: map['name'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      modified: (map['modified'] as num?)?.toInt() ?? 0,
    );
  }

  final int handle;
  final String name;
  final int size;
  final int modified;
}

class CameraDownloadResult {
  CameraDownloadResult({
    required this.destPath,
    required this.ok,
    this.error,
  });

  factory CameraDownloadResult.fromMap(Map<dynamic, dynamic> map) {
    return CameraDownloadResult(
      destPath: map['destPath'] as String? ?? '',
      ok: map['ok'] as bool? ?? false,
      error: map['error'] as String?,
    );
  }

  final String destPath;
  final bool ok;
  final String? error;
}

class UsbCameraEvent {
  UsbCameraEvent(this.type, {this.source});

  factory UsbCameraEvent.fromMap(Map<dynamic, dynamic> map) {
    return UsbCameraEvent(
      map['event'] as String? ?? '',
      source: map['source'] as String?,
    );
  }

  final String type;
  final String? source;

  bool get isAttached => type == 'attached';
  bool get isPermissionGranted => type == 'permission_granted';
}

class CameraUsbService {
  CameraUsbService._();
  static final CameraUsbService instance = CameraUsbService._();

  static const _channel = MethodChannel('lv.edgarsfoto.efpic_live/camera_usb');
  static const _events =
      EventChannel('lv.edgarsfoto.efpic_live/camera_usb_events');

  Stream<UsbCameraEvent>? _eventStream;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Stream<UsbCameraEvent> get events {
    if (!isAndroid) return const Stream.empty();
    _eventStream ??= _events.receiveBroadcastStream().map(
          (dynamic e) =>
              UsbCameraEvent.fromMap(e as Map<dynamic, dynamic>),
        );
    return _eventStream!;
  }

  Future<CameraProbeResult> probe() async {
    if (!isAndroid) {
      return CameraProbeResult(
        connected: false,
        error: 'USB kamera tikai Android',
      );
    }
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('probe');
    return CameraProbeResult.fromMap(map ?? {});
  }

  Future<void> requestPermission() async {
    if (!isAndroid) return;
    await _channel.invokeMethod<void>('requestPermission');
  }

  Future<({List<CameraRemoteImage> images, String? error})> listImages() async {
    if (!isAndroid) {
      return (images: <CameraRemoteImage>[], error: 'Tikai Android');
    }
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('listImages');
    if (map == null) {
      return (images: <CameraRemoteImage>[], error: 'Nav atbildes');
    }
    if (map['ok'] != true) {
      return (
        images: <CameraRemoteImage>[],
        error: map['error'] as String? ?? 'Kļūda',
      );
    }
    final list = (map['images'] as List<dynamic>? ?? [])
        .map((e) => CameraRemoteImage.fromMap(e as Map<dynamic, dynamic>))
        .toList();
    return (images: list, error: null);
  }

  Future<({List<CameraDownloadResult> results, String? error})> downloadBatch(
    List<({int handle, String destPath, int size})> items,
  ) async {
    if (!isAndroid) {
      return (results: <CameraDownloadResult>[], error: 'Tikai Android');
    }
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'downloadBatch',
      {
        'items': items
            .map(
              (i) => {
                'handle': i.handle,
                'destPath': i.destPath,
                'size': i.size,
              },
            )
            .toList(),
      },
    );
    if (map == null) {
      return (results: <CameraDownloadResult>[], error: 'Nav atbildes');
    }
    if (map['ok'] != true) {
      return (
        results: <CameraDownloadResult>[],
        error: map['error'] as String? ?? 'Kļūda',
      );
    }
    final results = (map['results'] as List<dynamic>? ?? [])
        .map((e) => CameraDownloadResult.fromMap(e as Map<dynamic, dynamic>))
        .toList();
    return (results: results, error: null);
  }
}
