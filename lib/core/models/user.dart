class User {
  final int id;
  final String username;
  final String? name;
  final String role;
  final List<String> branches;
  final bool active;

  User({
    required this.id,
    required this.username,
    this.name,
    required this.role,
    this.branches = const [],
    this.active = true,
  });

  factory User.fromJson(Map<String, dynamic> j) {
    return User(
      id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
      username: j['username']?.toString() ?? '',
      name: j['name']?.toString(),
      role: j['role']?.toString() ?? 'viewer',
      branches: (j['branches'] is List)
          ? (j['branches'] as List).map((e) => e.toString()).toList()
          : [],
      active: j['active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'role': role,
        'branches': branches,
        'active': active,
      };

  bool get isAdmin => role == 'admin';
  bool get isBranch => role == 'branch';
  String get displayName => (name != null && name!.isNotEmpty) ? name! : username;
}
