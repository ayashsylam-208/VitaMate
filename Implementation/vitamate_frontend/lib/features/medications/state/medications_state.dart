import '../models/medication_adherence_summary.dart';
import '../models/medication_dose_log.dart';
import '../models/medication_history.dart';
import '../models/medication_item.dart';
import '../models/medication_today_plan.dart';

class MedicationsState {
  final bool isLoading;
  final bool isSaving;
  final List<MedicationItem> medications;
  final List<MedicationDoseLog> todayPlan;
  final MedicationItem? selectedMedication;
  final MedicationAdherenceSummary? selectedMedicationAdherence;
  final MedicationAdherenceSummary overallAdherence;
  final MedicationTodaySummary todayAdherence;
  final MedicationDoseLog? nextDose;
  final int streak;
  final Map<String, dynamic> shortcutCounts;
  final Map<String, dynamic>? motivationStrip;
  final MedicationHistoryPage history;
  final MedicationDoseLog? lastDoseAction;
  final String? errorMessage;
  final String? successMessage;

  const MedicationsState({
    required this.isLoading,
    required this.isSaving,
    required this.medications,
    required this.todayPlan,
    required this.selectedMedication,
    required this.selectedMedicationAdherence,
    required this.overallAdherence,
    required this.todayAdherence,
    required this.nextDose,
    required this.streak,
    required this.shortcutCounts,
    required this.motivationStrip,
    required this.history,
    required this.lastDoseAction,
    required this.errorMessage,
    required this.successMessage,
  });

  factory MedicationsState.initial() {
    return MedicationsState(
      isLoading: false,
      isSaving: false,
      medications: const [],
      todayPlan: const [],
      selectedMedication: null,
      selectedMedicationAdherence: null,
      overallAdherence: MedicationAdherenceSummary.empty(),
      todayAdherence: MedicationTodaySummary.empty(),
      nextDose: null,
      streak: 0,
      shortcutCounts: const {},
      motivationStrip: null,
      history: MedicationHistoryPage.empty(),
      lastDoseAction: null,
      errorMessage: null,
      successMessage: null,
    );
  }

  MedicationsState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<MedicationItem>? medications,
    List<MedicationDoseLog>? todayPlan,
    MedicationItem? selectedMedication,
    bool clearSelectedMedication = false,
    MedicationAdherenceSummary? selectedMedicationAdherence,
    bool clearSelectedMedicationAdherence = false,
    MedicationAdherenceSummary? overallAdherence,
    MedicationTodaySummary? todayAdherence,
    MedicationDoseLog? nextDose,
    bool clearNextDose = false,
    int? streak,
    Map<String, dynamic>? shortcutCounts,
    Map<String, dynamic>? motivationStrip,
    bool clearMotivationStrip = false,
    MedicationHistoryPage? history,
    MedicationDoseLog? lastDoseAction,
    bool clearLastDoseAction = false,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return MedicationsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      medications: medications ?? this.medications,
      todayPlan: todayPlan ?? this.todayPlan,
      selectedMedication: clearSelectedMedication
          ? null
          : selectedMedication ?? this.selectedMedication,
      selectedMedicationAdherence: clearSelectedMedicationAdherence
          ? null
          : selectedMedicationAdherence ?? this.selectedMedicationAdherence,
      overallAdherence: overallAdherence ?? this.overallAdherence,
      todayAdherence: todayAdherence ?? this.todayAdherence,
      nextDose: clearNextDose ? null : nextDose ?? this.nextDose,
      streak: streak ?? this.streak,
      shortcutCounts: shortcutCounts ?? this.shortcutCounts,
      motivationStrip: clearMotivationStrip
          ? null
          : motivationStrip ?? this.motivationStrip,
      history: history ?? this.history,
      lastDoseAction: clearLastDoseAction
          ? null
          : lastDoseAction ?? this.lastDoseAction,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}
