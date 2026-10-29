import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/auth/view_models/auth_view_model.dart';
import 'package:saff_core/saff_core.dart';

/// State of the plant flow.
class PlantState extends ActionState {
  /// Creates the state.
  const PlantState({
    super.running,
    super.failure,
    this.left,
    this.sent = false,
  });

  /// Plants left tonight after the last send.
  final int? left;

  /// Whether the last plant succeeded.
  final bool sent;
}

/// Sends a planted card.
class PlantViewModel extends Notifier<PlantState> {
  @override
  PlantState build() => const PlantState();

  /// Plants a card.
  Future<void> plant({
    required String saffId,
    required String template,
    required String question,
    String? answer,
    List<String>? options,
    int? correctIndex,
  }) async {
    state = const PlantState(running: true);
    final r = await ref
        .read(plantRepositoryProvider)
        .plant(
          saffId: saffId,
          template: template,
          question: question,
          answer: answer,
          options: options,
          correctIndex: correctIndex,
        );
    state = switch (r) {
      Ok(:final value) => PlantState(left: value, sent: true),
      Err(:final failure) => PlantState(failure: failure),
    };
  }
}

/// Provider of [PlantViewModel].
final plantViewModelProvider =
    NotifierProvider.autoDispose<PlantViewModel, PlantState>(
      PlantViewModel.new,
    );
