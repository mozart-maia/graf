enum SurfaceType {
  verticalWall,
  horizontalFloor,
  horizontalCeiling,
}

extension SurfaceTypeExtension on SurfaceType {
  String toValue() {
    switch (this) {
      case SurfaceType.verticalWall:
        return 'vertical_wall';
      case SurfaceType.horizontalFloor:
        return 'horizontal_floor';
      case SurfaceType.horizontalCeiling:
        return 'horizontal_ceiling';
    }
  }

  String toDisplayName() {
    switch (this) {
      case SurfaceType.verticalWall:
        return 'Parede Vertical';
      case SurfaceType.horizontalFloor:
        return 'Piso / Chão';
      case SurfaceType.horizontalCeiling:
        return 'Teto';
    }
  }

  static SurfaceType fromValue(String value) {
    switch (value) {
      case 'vertical_wall':
        return SurfaceType.verticalWall;
      case 'horizontal_floor':
        return SurfaceType.horizontalFloor;
      case 'horizontal_ceiling':
        return SurfaceType.horizontalCeiling;
      default:
        return SurfaceType.verticalWall;
    }
  }
}

class Graffiti {
  final String id;
  final String userId;
  final String mediaUrl;
  final String mediaType; // png, jpg, gif
  final double latitude;
  final double longitude;
  final SurfaceType surfaceType;
  final String status;
  final DateTime createdAt;
  final DateTime protectionUntil;
  final DateTime expiresAt;
  final bool isProtected;
  final double? distanceMeters;

  Graffiti({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    required this.latitude,
    required this.longitude,
    required this.surfaceType,
    required this.status,
    required this.createdAt,
    required this.protectionUntil,
    required this.expiresAt,
    required this.isProtected,
    this.distanceMeters,
  });

  factory Graffiti.fromJson(Map<String, dynamic> json) {
    return Graffiti(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      mediaType: json['media_type'] ?? 'png',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      surfaceType: SurfaceTypeExtension.fromValue(json['surface_type'] ?? 'vertical_wall'),
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at']),
      protectionUntil: DateTime.parse(json['protection_until']),
      expiresAt: DateTime.parse(json['expires_at']),
      isProtected: json['is_protected'] ?? false,
      distanceMeters: json['distance_meters'] != null
          ? (json['distance_meters'] as num).toDouble()
          : null,
    );
  }
}
