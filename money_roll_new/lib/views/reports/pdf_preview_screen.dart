import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../../utils/app_constants.dart';
import '../../utils/app_utils.dart';

class PdfPreviewScreen extends StatefulWidget {
  final String title;
  final String filename;
  final Uint8List bytes;

  const PdfPreviewScreen({
    super.key,
    required this.title,
    required this.filename,
    required this.bytes,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _saving = false;
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D21),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              widget.filename,
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          _AppBarButton(
            icon: Icons.save_alt_outlined,
            label: 'Save',
            loading: _saving,
            onTap: _save,
          ),
          const SizedBox(width: 4),
          _AppBarButton(
            icon: Icons.share_outlined,
            label: 'Share',
            loading: _sharing,
            onTap: _share,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Thin gold accent line under AppBar
          Container(height: 1, color: AppColors.gold.withOpacity(0.4)),
          Expanded(
            child: PdfPreview(
              build: (_) => widget.bytes,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: false,
              pdfFileName: widget.filename,
              scrollViewDecoration: const BoxDecoration(
                color: Color(0xFF2A2D31),
              ),
              pdfPreviewPageDecoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom action bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D21),
          border: Border(
            top: BorderSide(color: AppColors.gold.withOpacity(0.2), width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _BottomButton(
                    icon: Icons.save_alt_outlined,
                    label: _saving ? 'Saving...' : 'Save to Device',
                    loading: _saving,
                    filled: false,
                    onTap: _save,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BottomButton(
                    icon: Icons.share_outlined,
                    label: _sharing ? 'Sharing...' : 'Share',
                    loading: _sharing,
                    filled: true,
                    onTap: _share,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await Printing.sharePdf(
        bytes: widget.bytes,
        filename: widget.filename,
      );
    } catch (e) {
      AppUtils.showError('Share Failed', e.toString());
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await FilePicker.saveFile(
        dialogTitle: 'Save PDF',
        fileName: widget.filename,
        allowedExtensions: ['pdf'],
        bytes: widget.bytes,
      );
      if (result != null) {
        AppUtils.showSuccess('Saved', 'PDF saved to device');
      }
    } catch (e) {
      AppUtils.showError('Save Failed', e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _AppBarButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  )
                : Icon(icon, size: 18, color: AppColors.gold),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final bool filled;
  final VoidCallback onTap;

  const _BottomButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled ? AppColors.gold : AppColors.gold.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: filled ? Colors.white : AppColors.gold,
                ),
              )
            else
              Icon(icon,
                  size: 16, color: filled ? Colors.white : AppColors.gold),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : AppColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
