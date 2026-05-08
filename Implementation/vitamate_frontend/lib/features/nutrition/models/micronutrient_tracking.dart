class MicronutrientOverview {
  const MicronutrientOverview({
    required this.date,
    required this.items,
    required this.disclaimer,
  });

  final String date;
  final List<MicronutrientItem> items;
  final String disclaimer;

  factory MicronutrientOverview.empty() => const MicronutrientOverview(
    date: '',
    items: <MicronutrientItem>[],
    disclaimer: '',
  );

  factory MicronutrientOverview.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return MicronutrientOverview(
      date: json['date']?.toString() ?? '',
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      MicronutrientItem.fromJson(item.cast<String, dynamic>()),
                )
                .toList(growable: false)
          : const <MicronutrientItem>[],
      disclaimer: json['disclaimer']?.toString() ?? '',
    );
  }

  List<MicronutrientItem> get vitamins =>
      items.where((item) => item.category == 'vitamin').toList(growable: false);

  List<MicronutrientItem> get minerals =>
      items.where((item) => item.category == 'mineral').toList(growable: false);

  List<MicronutrientItem> get deficiencyTracked =>
      items.where((item) => item.deficiencyTracked).toList(growable: false);
}

class MicronutrientItem {
  const MicronutrientItem({
    required this.code,
    required this.name,
    required this.unit,
    required this.category,
    required this.foodConsumed,
    required this.supplementConsumed,
    required this.totalConsumed,
    required this.targetValue,
    required this.progressPercent,
    required this.targetSource,
    required this.sourceLabel,
    required this.deficiencyTracked,
    required this.status,
    required this.note,
    this.labContext,
    this.labRange,
    this.minValue,
    this.maxValue,
    this.linkedMedication,
  });

  final String code;
  final String name;
  final String unit;
  final String category;
  final double foodConsumed;
  final double supplementConsumed;
  final double totalConsumed;
  final double? minValue;
  final double targetValue;
  final double? maxValue;
  final double progressPercent;
  final String targetSource;
  final String sourceLabel;
  final bool deficiencyTracked;
  final String status;
  final String note;
  final MicronutrientLabContext? labContext;
  final MicronutrientLabRange? labRange;
  final MicronutrientLinkedMedication? linkedMedication;

  factory MicronutrientItem.fromJson(Map<String, dynamic> json) {
    return MicronutrientItem(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      foodConsumed: _toDouble(json['food_consumed']),
      supplementConsumed: _toDouble(json['supplement_consumed']),
      totalConsumed: _toDouble(json['total_consumed']),
      minValue: _nullableDouble(json['min_value']),
      targetValue: _toDouble(json['target_value']),
      maxValue: _nullableDouble(json['max_value']),
      progressPercent: _toDouble(json['progress_percent']),
      targetSource: json['target_source']?.toString() ?? '',
      sourceLabel: json['source_label']?.toString() ?? '',
      deficiencyTracked: json['deficiency_tracked'] == true,
      status: json['status']?.toString() ?? 'in_progress',
      note: json['note']?.toString() ?? '',
      labContext: _labContext(json['lab_context']),
      labRange: _labRange(json['lab_range']),
      linkedMedication: _linkedMedication(json['linked_medication']),
    );
  }

  double get progressFraction {
    if (targetValue <= 0) {
      return 0;
    }
    return (progressPercent / 100).clamp(0.0, 1.0).toDouble();
  }

  String get consumedLabel =>
      '${_formatNumber(totalConsumed)} / ${_formatNumber(targetValue)} $unit';

  String get foodLabel => '${_formatNumber(foodConsumed)} $unit from food';

  String get supplementLabel =>
      '${_formatNumber(supplementConsumed)} $unit from supplements';
}

class MicronutrientLabContext {
  const MicronutrientLabContext({
    required this.testName,
    required this.unit,
    required this.testDate,
    required this.calculationBasis,
    required this.suggestedTargetReason,
    required this.currentMedicationName,
    required this.currentMedicationDose,
    this.improvementPlan,
    this.value,
    this.referenceMin,
    this.referenceMax,
    this.clinicianRecommendedValue,
    this.suggestedTargetValue,
  });

  final String testName;
  final double? value;
  final String unit;
  final double? referenceMin;
  final double? referenceMax;
  final String testDate;
  final double? clinicianRecommendedValue;
  final String calculationBasis;
  final double? suggestedTargetValue;
  final String suggestedTargetReason;
  final String currentMedicationName;
  final String currentMedicationDose;
  final MicronutrientImprovementPlan? improvementPlan;

  factory MicronutrientLabContext.fromJson(Map<String, dynamic> json) {
    return MicronutrientLabContext(
      testName: json['test_name']?.toString() ?? '',
      value: _nullableDouble(json['value']),
      unit: json['unit']?.toString() ?? '',
      referenceMin: _nullableDouble(json['reference_min']),
      referenceMax: _nullableDouble(json['reference_max']),
      testDate: json['test_date']?.toString() ?? '',
      clinicianRecommendedValue: _nullableDouble(
        json['clinician_recommended_value'],
      ),
      calculationBasis: json['calculation_basis']?.toString() ?? '',
      suggestedTargetValue: _nullableDouble(json['suggested_target_value']),
      suggestedTargetReason: json['suggested_target_reason']?.toString() ?? '',
      currentMedicationName: json['current_medication_name']?.toString() ?? '',
      currentMedicationDose: json['current_medication_dose']?.toString() ?? '',
      improvementPlan: _improvementPlan(json['improvement_plan']),
    );
  }

  bool get hasLabResult => value != null;

  bool get hasMedication =>
      currentMedicationName.trim().isNotEmpty ||
      currentMedicationDose.trim().isNotEmpty;

  String get labValueLabel {
    if (value == null) {
      return '';
    }
    final unitPart = unit.trim().isEmpty ? '' : ' $unit';
    return '${_formatNumber(value!)}$unitPart';
  }

  String get referenceLabel {
    final unitPart = unit.trim().isEmpty ? '' : ' $unit';
    if (referenceMin != null && referenceMax != null) {
      return '${_formatNumber(referenceMin!)}-${_formatNumber(referenceMax!)}$unitPart';
    }
    if (referenceMin != null) {
      return '>= ${_formatNumber(referenceMin!)}$unitPart';
    }
    if (referenceMax != null) {
      return '<= ${_formatNumber(referenceMax!)}$unitPart';
    }
    return '';
  }
}

class MicronutrientLabRange {
  const MicronutrientLabRange({
    required this.testName,
    required this.unit,
    this.referenceMin,
    this.referenceMax,
  });

  final String testName;
  final String unit;
  final double? referenceMin;
  final double? referenceMax;

  factory MicronutrientLabRange.fromJson(Map<String, dynamic> json) {
    return MicronutrientLabRange(
      testName: json['test_name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      referenceMin: _nullableDouble(json['reference_min']),
      referenceMax: _nullableDouble(json['reference_max']),
    );
  }

  String get referenceLabel {
    final unitPart = unit.trim().isEmpty ? '' : ' $unit';
    if (referenceMin != null && referenceMax != null) {
      return '${_formatNumber(referenceMin!)}-${_formatNumber(referenceMax!)}$unitPart';
    }
    if (referenceMin != null) {
      return '>= ${_formatNumber(referenceMin!)}$unitPart';
    }
    if (referenceMax != null) {
      return '<= ${_formatNumber(referenceMax!)}$unitPart';
    }
    return '';
  }
}

class MicronutrientImprovementPlan {
  const MicronutrientImprovementPlan({
    required this.status,
    required this.reviewAfterWeeks,
    required this.dailyFoodTarget,
    required this.supplementGap,
    required this.message,
  });

  final String status;
  final int reviewAfterWeeks;
  final double dailyFoodTarget;
  final double supplementGap;
  final String message;

  factory MicronutrientImprovementPlan.fromJson(Map<String, dynamic> json) {
    return MicronutrientImprovementPlan(
      status: json['status']?.toString() ?? '',
      reviewAfterWeeks: _toInt(json['review_after_weeks']),
      dailyFoodTarget: _toDouble(json['daily_food_target']),
      supplementGap: _toDouble(json['supplement_gap']),
      message: json['message']?.toString() ?? '',
    );
  }
}

class MicronutrientLinkedMedication {
  const MicronutrientLinkedMedication({
    required this.id,
    required this.displayName,
    required this.doseAmount,
    required this.doseUnit,
    required this.isActive,
  });

  final int id;
  final String displayName;
  final String doseAmount;
  final String doseUnit;
  final bool isActive;

  factory MicronutrientLinkedMedication.fromJson(Map<String, dynamic> json) {
    return MicronutrientLinkedMedication(
      id: _toInt(json['id']),
      displayName: json['display_name']?.toString() ?? '',
      doseAmount: json['dose_amount']?.toString() ?? '',
      doseUnit: json['dose_unit']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }

  String get doseLabel {
    final text = '$doseAmount $doseUnit'.trim();
    return text.isEmpty ? displayName : text;
  }
}

MicronutrientLinkedMedication? _linkedMedication(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MicronutrientLinkedMedication.fromJson(value);
  }
  if (value is Map) {
    return MicronutrientLinkedMedication.fromJson(
      value.cast<String, dynamic>(),
    );
  }
  return null;
}

MicronutrientLabContext? _labContext(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MicronutrientLabContext.fromJson(value);
  }
  if (value is Map) {
    return MicronutrientLabContext.fromJson(value.cast<String, dynamic>());
  }
  return null;
}

MicronutrientLabRange? _labRange(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MicronutrientLabRange.fromJson(value);
  }
  if (value is Map) {
    return MicronutrientLabRange.fromJson(value.cast<String, dynamic>());
  }
  return null;
}

MicronutrientImprovementPlan? _improvementPlan(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MicronutrientImprovementPlan.fromJson(value);
  }
  if (value is Map) {
    return MicronutrientImprovementPlan.fromJson(value.cast<String, dynamic>());
  }
  return null;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _nullableDouble(dynamic value) {
  if (value == null || value == '') {
    return null;
  }
  return _toDouble(value);
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(value.abs() < 10 ? 1 : 0);
}
