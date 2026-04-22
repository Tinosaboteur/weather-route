class UserAuthData {
  final String token;
  final String email;
  final String fullName;

  UserAuthData({required this.token, required this.email, required this.fullName});

  factory UserAuthData.fromJson(Map<String, dynamic> json) {
    return UserAuthData(
      token: json['token'],
      email: json['email'],
      fullName: json['fullName'],
    );
  }
}