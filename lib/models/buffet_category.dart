// lib/models/buffet_category.dart

class BuffetCategory {
  String id;
  String name;
  String emoji;  // ايموجي القسم (مثال: 🔥 ❄️ 🍟)
  int sortOrder;

  BuffetCategory({
    required this.id,
    required this.name,
    this.emoji = '🍽',
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'sort_order': sortOrder,
  };

  factory BuffetCategory.fromJson(Map<String, dynamic> j) => BuffetCategory(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    emoji: j['emoji']?.toString() ?? '🍽',
    sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
  );

  // ─── الأقسام الافتراضية ───────────────────────────────────────────────────
  static List<BuffetCategory> get defaults => [
    BuffetCategory(id: 'hot',   name: 'سخن',   emoji: '🔥', sortOrder: 0),
    BuffetCategory(id: 'cold',  name: 'بارد',  emoji: '❄️', sortOrder: 1),
    BuffetCategory(id: 'snack', name: 'سناكس', emoji: '🍟', sortOrder: 2),
    BuffetCategory(id: 'drink', name: 'مشروبات', emoji: '🥤', sortOrder: 3),
    BuffetCategory(id: 'other', name: 'أخرى',  emoji: '🍽', sortOrder: 4),
  ];
}
