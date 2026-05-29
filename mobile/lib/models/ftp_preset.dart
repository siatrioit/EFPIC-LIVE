class FtpPreset {
  FtpPreset({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.remotePath,
    this.useFtps = false,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String remotePath;
  final bool useFtps;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'remotePath': remotePath,
        'useFtps': useFtps,
      };

  factory FtpPreset.fromJson(Map<String, dynamic> json) => FtpPreset(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        host: json['host'] as String? ?? '',
        port: (json['port'] as num?)?.toInt() ?? 21,
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        remotePath: json['remotePath'] as String? ?? '/',
        useFtps: json['useFtps'] as bool? ?? false,
      );
}

class OneOffFtpConfig {
  OneOffFtpConfig({
    this.host = '',
    this.port = 21,
    this.username = '',
    this.password = '',
    this.remotePath = '/',
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String remotePath;

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'remotePath': remotePath,
      };

  factory OneOffFtpConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OneOffFtpConfig();
    return OneOffFtpConfig(
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 21,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      remotePath: json['remotePath'] as String? ?? '/',
    );
  }
}
