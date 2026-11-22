class PeaceUser {
  final String userId;
  final String name;
  final String username;
  final String email;
  final String password;
  final bool isGuest;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastSyncedAt;
  final List<String> downloadedSongIds;

  PeaceUser({
    required this.userId,
    required this.name,
    this.username = '',
    required this.email,
    this.password = '',
    required this.isGuest,
    this.photoUrl,
    required this.createdAt,
    this.lastSyncedAt,
    this.downloadedSongIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'username': username,
      'email': email,
      'password': password,
      'isGuest': isGuest,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'downloadedSongIds': downloadedSongIds,
    };
  }

  factory PeaceUser.fromJson(Map<dynamic, dynamic> json) {
    return PeaceUser(
      userId: json['userId'] ?? '',
      name: json['name'] ?? 'User',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      isGuest: json['isGuest'] ?? false,
      photoUrl: json['photoUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.tryParse(json['lastSyncedAt'])
          : null,
      downloadedSongIds: (json['downloadedSongIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  PeaceUser copyWith({
    String? userId,
    String? name,
    String? username,
    String? email,
    String? password,
    bool? isGuest,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastSyncedAt,
    List<String>? downloadedSongIds,
  }) {
    return PeaceUser(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      isGuest: isGuest ?? this.isGuest,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      downloadedSongIds: downloadedSongIds ?? this.downloadedSongIds,
    );
  }
}
