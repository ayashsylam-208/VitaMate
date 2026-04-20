import '../models/medication_adherence_summary.dart';
import '../models/medication_dose_log.dart';
import '../models/medication_item.dart';

class MedicationsState {
  final bool isLoading;
  final bool isSaving;
  final bool reminderSyncInProgress;
  final List<MedicationItem> medications;
  final List<MedicationDoseLog> todayPlan;
  final MedicationItem? selectedMedication;
  final MedicationAdherenceSummary? selectedMedicationAdherence;
  final MedicationAdherenceSummary overallAdherence;
  final String? errorMessage;
  final String? successMessage;

  const MedicationsState({
    required this.isLoading,
    required this.isSaving,
    required this.reminderSyncInProgress,
    required this.medications,
    required this.todayPlan,
    required this.selectedMedication,
    required this.selectedMedicationAdherence,
    required this.overallAdherence,
    required this.errorMessage,
    required this.successMessage,
  });

  factory MedicationsState.initial() {
    return MedicationsState(
      isLoading: false,
      isSaving: false,
      reminderSyncInProgress: false,
      medications: const [],
      todayPlan: const [],
      selectedMedication: null,
      selectedMedicationAdherence: null,
      overallAdherence: MedicationAdherenceSummary.empty(),
      errorMessage: null,
      successMessage: null,
    );
  }

  MedicationsState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? reminderSyncInProgress,
    List<MedicationItem>? medications,
    List<MedicationDoseLog>? todayPlan,
    MedicationItem? selectedMedication,
    bool clearSelectedMedication = false,
    MedicationAdherenceSummary? selectedMedicationAdherence,
    bool clearSelectedMedicationAdherence = false,
    MedicationAdherenceSummary? overallAdherence,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return MedicationsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      reminderSyncInProgress:
          reminderSyncInProgress ?? this.reminderSyncInProgress,
      medications: medications ?? this.medications,
      todayPlan: todayPlan ?? this.todayPlan,
      selectedMedication: clearSelectedMedication
          ? null
          : selectedMedication ?? this.selectedMedication,
      selectedMedicationAdherence: clearSelectedMedicationAdherence
          ? null
          : selectedMedicationAdherence ?? this.selectedMedicationAdherence,
      overallAdherence: overallAdherence ?? this.overallAdherence,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}
