import 'package:saff_app/data/services/firebase_services.dart';
import 'package:saff_core/saff_core.dart';

/// Planting cards for the other member of a pair (`docs/PRODUCT.md` §5.2).
abstract interface class PlantRepository {
  /// Plants a card; returns how many plants are left tonight.
  Future<Result<int>> plant({
    required String saffId,
    required String template,
    required String question,
    String? answer,
    List<String>? options,
    int? correctIndex,
  });
}

/// [PlantRepository] over the `plantCard` callable.
final class PlantRepositoryImpl implements PlantRepository {
  /// Creates the repository.
  const PlantRepositoryImpl(this._fn, this._mapper);

  final FunctionsService _fn;
  final FailureMapper _mapper;

  @override
  Future<Result<int>> plant({
    required String saffId,
    required String template,
    required String question,
    String? answer,
    List<String>? options,
    int? correctIndex,
  }) => Result.guard(
    () async {
      final r = await _fn.call('plantCard', {
        'saffId': saffId,
        'template': template,
        'question': question,
        if (answer != null) 'answer': answer,
        if (options != null) 'options': options,
        if (correctIndex != null) 'correctIndex': correctIndex,
      });
      return (r['left'] as num?)?.toInt() ?? 0;
    },
    _mapper,
    context: const {'op': 'plantCard'},
  );
}
