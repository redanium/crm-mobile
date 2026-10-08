class AppUser {
  final String id;
  final String name;
  final String email;
  final String? role;
  final String? image;
  final String? wilaya;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.image,
    this.wilaya,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Délégué Médical',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'rep',
      image: json['image'] as String?,
      wilaya: json['wilaya'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'image': image,
      'wilaya': wilaya,
    };
  }
}
