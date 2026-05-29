import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;

import '../data/app_repository.dart';
import '../models/delivery_target.dart';
import '../models/event_config.dart';
import '../models/file_format.dart';
import '../models/gallery.dart';
import '../models/gallery_image.dart';
import 'jpg_processor.dart';

class FtpCredentials {
  FtpCredentials({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.remotePath,
    required this.useFtps,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String remotePath;
  final bool useFtps;
}

class FtpUploadResult {
  FtpUploadResult.success(this.remotePath)
      : ok = true,
        error = null;

  FtpUploadResult.failure(this.error)
      : ok = false,
        remotePath = null;

  final bool ok;
  final String? error;
  final String? remotePath;
}

class FtpUploadService {
  FtpUploadService._();
  static final FtpUploadService instance = FtpUploadService._();

  Future<FtpCredentials?> resolveCredentials(EventConfig config) async {
    if (config.deliveryTarget != DeliveryTargetType.ftp) {
      return null;
    }
    if (config.ftpPresetId != null) {
      final presets = await AppRepository.instance.loadFtpPresets();
      final preset = presets
          .where((p) => p.id == config.ftpPresetId)
          .firstOrNull;
      if (preset == null) return null;
      return FtpCredentials(
        host: preset.host,
        port: preset.port,
        username: preset.username,
        password: preset.password,
        remotePath: preset.remotePath,
        useFtps: preset.useFtps,
      );
    }
    final oneOff = config.oneOffFtp;
    if (oneOff == null || oneOff.host.trim().isEmpty) {
      return null;
    }
    return FtpCredentials(
      host: oneOff.host.trim(),
      port: oneOff.port,
      username: oneOff.username,
      password: oneOff.password,
      remotePath: oneOff.remotePath,
      useFtps: false,
    );
  }

  bool shouldUploadFile(EventConfig config, String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    final isRaw = _rawExtensions.contains(ext);
    final isJpg = JpgProcessor.isJpegPath(filePath);

    switch (config.ftpUploadFormat) {
      case FtpUploadFormat.raw:
        return isRaw;
      case FtpUploadFormat.jpg:
        return isJpg;
      case FtpUploadFormat.both:
        return isRaw || isJpg;
    }
  }

  static const _rawExtensions = {
    '.cr2',
    '.cr3',
    '.nef',
    '.arw',
    '.orf',
    '.rw2',
    '.dng',
    '.raf',
  };

  Future<FtpUploadResult> uploadImage({
    required Gallery gallery,
    required GalleryImage image,
  }) async {
    final config = gallery.config;
    if (config.deliveryTarget != DeliveryTargetType.ftp) {
      return FtpUploadResult.failure('Nav FTP režīms');
    }
    if (image.uploadStatus == UploadStatus.excluded) {
      return FtpUploadResult.failure('Bilde izslēgta');
    }
    final localPath = image.localPath;
    if (localPath == null || !File(localPath).existsSync()) {
      return FtpUploadResult.failure('Nav lokālā faila');
    }

    final creds = await resolveCredentials(config);
    if (creds == null) {
      return FtpUploadResult.failure('FTP konfigurācija nav pilna');
    }

    if (!shouldUploadFile(config, localPath)) {
      return FtpUploadResult.failure('Formāts neatbilst FTP iestatījumiem');
    }

    File uploadFile = File(localPath);
    File? tempFile;
    if (JpgProcessor.isJpegPath(localPath)) {
      final processedDir = p.join(
        gallery.folderPath ?? p.dirname(localPath),
        '_processed',
      );
      tempFile = await JpgProcessor.processForFtp(
        source: uploadFile,
        quality: config.jpgQuality,
        maxLongEdge: config.jpgMaxLongEdge,
        outputDir: processedDir,
      );
      uploadFile = tempFile;
    }

    final remoteName = _remoteFileName(creds.remotePath, image.fileName);
    FTPConnect? ftp;
    try {
      ftp = FTPConnect(
        creds.host,
        user: creds.username,
        pass: creds.password,
        port: creds.port,
        securityType:
            creds.useFtps ? SecurityType.ftps : SecurityType.ftp,
      );
      await ftp.connect();
      final ok = await ftp.uploadFile(
        uploadFile,
        sRemoteName: remoteName,
      );
      await ftp.disconnect();
      if (!ok) {
        return FtpUploadResult.failure('FTP upload atteikts');
      }
      return FtpUploadResult.success(remoteName);
    } catch (e) {
      try {
        await ftp?.disconnect();
      } catch (_) {}
      return FtpUploadResult.failure(e.toString());
    } finally {
      if (tempFile != null &&
          tempFile.path != localPath &&
          await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  String _remoteFileName(String remotePath, String fileName) {
    var dir = remotePath.trim();
    if (dir.isEmpty) dir = '/';
    if (!dir.endsWith('/')) dir = '$dir/';
    return '$dir$fileName';
  }
}
