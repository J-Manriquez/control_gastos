enum SubscriptionType {
  free,
  proMonthly,
  proAnnual,
}

class SubscriptionPlan {
  final SubscriptionType type;
  final String name;
  final int price;
  final String description;
  final int durationDays;

  const SubscriptionPlan({
    required this.type,
    required this.name,
    required this.price,
    required this.description,
    required this.durationDays,
  });

  static const List<SubscriptionPlan> availablePlans = [
    SubscriptionPlan(
      type: SubscriptionType.proMonthly,
      name: 'Pro Mensual',
      price: 2000,
      description: 'Acceso completo por 30 días',
      durationDays: 30,
    ),
    SubscriptionPlan(
      type: SubscriptionType.proAnnual,
      name: 'Pro Anual',
      price: 10000,
      description: 'Acceso completo por 365 días - ¡Ahorra 14,000!',
      durationDays: 365,
    ),
  ];
}