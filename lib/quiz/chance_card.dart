class ChanceCard {
  final String title;
  final String description;
  final String type;
  final String action;

  ChanceCard({
    required this.title,
    required this.description,
    required this.type,
    required this.action,
  });

  factory ChanceCard.fromMap(Map<String, dynamic> data) {
    return ChanceCard(
      title: data['title'],
      description: data['description'],
      type: data['type'],
      action: data['action'],
    );
  }
}
