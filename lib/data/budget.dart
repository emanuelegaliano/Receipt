/// Limiti mensili per categoria: a che punto sei e quando avvisare.
library;

enum BudgetLevel { ok, near, reached }

/// Da questa quota del limite in su la categoria è "quasi esaurita".
const nearBudget = 0.8;

BudgetLevel budgetLevel(int spent, int limit) {
  if (limit <= 0) return BudgetLevel.ok;
  if (spent >= limit) return BudgetLevel.reached;
  if (spent >= limit * nearBudget) return BudgetLevel.near;
  return BudgetLevel.ok;
}

/// Avviso da mostrare dopo aver salvato una spesa, o null se non serve.
class BudgetAlert {
  final BudgetLevel level;
  final String category;
  final int spent, limit;
  /// true se è questa spesa a far passare la soglia (avviso in evidenza);
  /// false se il limite era già superato prima (solo un promemoria).
  final bool crossed;
  const BudgetAlert(this.level, this.category, this.spent, this.limit, {required this.crossed});

  int get over => spent - limit;
  int get left => limit - spent;
}

/// Confronta lo speso prima e dopo una spesa. Avvisa quando si entra in
/// una fascia più alta (80% o 100%) e ricorda ogni nuova spesa oltre il limite.
BudgetAlert? budgetAlert({
  required String category,
  required int? limit,
  required int before,
  required int after,
}) {
  if (limit == null || limit <= 0 || after <= before) return null;
  final from = budgetLevel(before, limit), to = budgetLevel(after, limit);
  if (to.index > from.index) return BudgetAlert(to, category, after, limit, crossed: true);
  if (to == BudgetLevel.reached) return BudgetAlert(to, category, after, limit, crossed: false);
  return null;
}
