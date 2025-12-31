class ChanceCard {
  final String title;
  final String description;
  final String type;
  final String action;
  final String? imageKey;

  ChanceCard({
    required this.title,
    required this.description,
    required this.type,
    required this.action,
    this.imageKey,
  });

  factory ChanceCard.fromMap(Map<String, dynamic> data) {
    return ChanceCard(
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'benefit',
      action: data['action'] ?? '',
      imageKey: data['imageKey'],
    );
  }
}