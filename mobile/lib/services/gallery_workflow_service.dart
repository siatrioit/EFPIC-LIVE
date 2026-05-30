import 'dart:async';

import '../data/app_repository.dart';
import '../models/delivery_target.dart';
import '../models/gallery.dart';
import '../models/gallery_image.dart';
import 'alert_service.dart';
import 'camera_import_service.dart';
import 'ftp_upload_service.dart';

class GalleryWorkflowService {
  GalleryWorkflowService(this.gallery);

  Gallery gallery;

  Future<Gallery> importCandidates(List<ImportCandidate> candidates) async {
    final added =
        await CameraImportService.instance.commitCandidates(gallery, candidates);
    if (added.isEmpty) return gallery;

    var updated = gallery.copyWith(
      images: [...gallery.images, ...added],
    );
    await AppRepository.instance.updateGallery(updated);
    gallery = updated;

    if (gallery.config.autoSendToFtp &&
        gallery.config.deliveryTarget == DeliveryTargetType.ftp) {
      unawaited(_autoFtpAdded(added));
    }
    return updated;
  }

  Future<void> _autoFtpAdded(List<GalleryImage> added) async {
    var working = gallery;
    for (final img in added) {
      if (img.uploadStatus == UploadStatus.excluded) continue;
      working = await uploadImage(working, img.id);
    }
  }

  Future<Gallery> uploadImage(Gallery current, String imageId) async {
    final index = current.images.indexWhere((i) => i.id == imageId);
    if (index < 0) return current;

    var img = current.images[index];
    if (img.uploadStatus == UploadStatus.excluded ||
        img.uploadStatus == UploadStatus.sent) {
      return current;
    }

    final images = List<GalleryImage>.from(current.images);
    images[index] = img.copyWith(uploadStatus: UploadStatus.uploading);
    var working = current.copyWith(images: images);
    await AppRepository.instance.updateGallery(working);

    final result = await FtpUploadService.instance.uploadImage(
      gallery: working,
      image: img,
    );

    images[index] = img.copyWith(
      uploadStatus: result.ok ? UploadStatus.sent : UploadStatus.pending,
    );
    working = working.copyWith(images: images);
    await AppRepository.instance.updateGallery(working);
    gallery = working;

    if (result.ok) {
      await _notifyIfAllUploadsDone(working);
    }
    return working;
  }

  Future<Gallery> uploadAllPending(Gallery current) async {
    var working = current;
    for (final img in current.images) {
      if (img.uploadStatus == UploadStatus.pending) {
        working = await uploadImage(working, img.id);
      }
    }
    return working;
  }

  Future<void> _notifyIfAllUploadsDone(Gallery g) async {
    if (g.config.deliveryTarget != DeliveryTargetType.ftp) return;
    final pending = g.images.where(
      (i) =>
          i.uploadStatus == UploadStatus.pending ||
          i.uploadStatus == UploadStatus.uploading,
    );
    if (g.images.isNotEmpty && pending.isEmpty) {
      await AlertService.instance.notifyUploadsComplete(g.config.name);
    }
  }
}
