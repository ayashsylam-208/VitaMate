import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../state/ai_meal_controller.dart';
import '../state/nutrition_controller.dart';
import '../widgets/nutrition_ui.dart';
import 'ai_meal_review_screen.dart';

class AiMealCaptureScreen extends StatefulWidget {
  const AiMealCaptureScreen({
    super.key,
    required this.nutritionController,
    this.controller,
  });

  final NutritionController nutritionController;
  final AiMealController? controller;

  @override
  State<AiMealCaptureScreen> createState() => _AiMealCaptureScreenState();
}

class _AiMealCaptureScreenState extends State<AiMealCaptureScreen> {
  late final AiMealController controller;
  late final bool _ownsController;
  final ImagePicker _picker = ImagePicker();
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? AiMealController();
    _ownsController = widget.controller == null;
  }

  @override
  void dispose() {
    if (_ownsController) controller.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    controller.beginCapture();
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (image == null || !mounted) return;
    setState(() => _imagePath = image.path);
    final analyzed = await controller.analyze(image.path);
    if (!mounted || !analyzed) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AiMealReviewScreen(
          controller: controller,
          nutritionController: widget.nutritionController,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VitaMateTheme.shellBackground,
    body: SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Stack(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              children: <Widget>[
                const NutritionPageHeader(
                  title: 'Scan your meal',
                  subtitle:
                      'The AI suggests. You review every ingredient and portion.',
                ),
                const SizedBox(height: 20),
                Container(
                  height: 280,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D1D56),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: VitaMateTheme.border),
                  ),
                  child: _imagePath == null
                      ? const _CaptureGuide()
                      : Image.file(File(_imagePath!), fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
                NutritionCard(
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.tips_and_updates_outlined,
                        color: VitaMateTheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Use natural light and keep the whole plate inside the frame. Weight estimates always need your confirmation.',
                          style: TextStyle(
                            color: VitaMateTheme.textMuted,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller.error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    controller.error!,
                    style: const TextStyle(
                      color: VitaMateTheme.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Take photo'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from gallery'),
                ),
              ],
            ),
            if (controller.busy)
              Positioned.fill(
                child: ColoredBox(
                  color: VitaMateTheme.primaryDeep.withValues(alpha: 0.72),
                  child: const Center(
                    child: NutritionCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Analyzing visible food...',
                            style: TextStyle(
                              color: VitaMateTheme.primaryDeep,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'No meal will be saved automatically.',
                            style: TextStyle(
                              color: VitaMateTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _CaptureGuide extends StatelessWidget {
  const _CaptureGuide();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: <Widget>[
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: <Color>[Color(0xFF5B3D9B), Color(0xFF21143F)],
            ),
          ),
        ),
      ),
      Container(
        width: 210,
        height: 210,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
      const Icon(Icons.restaurant_rounded, color: Colors.white, size: 58),
      const Positioned(
        bottom: 22,
        child: Text(
          'Keep the plate inside the circle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}
