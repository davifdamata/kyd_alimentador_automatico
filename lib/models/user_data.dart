class UserData {
  static String nome = "Usuário";
  static String email = "";
  static String? photoUrl;

  static void setUserData(String nome, String email, String? photoUrl) {
    UserData.nome = nome;
    UserData.email = email;
    UserData.photoUrl = photoUrl;
  }
}