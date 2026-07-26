/// Uygulama moderatör / admin e-postaları.
const kAppAdminEmails = <String>{
  'sakir.caykara@gmail.com',
};

bool isAppAdmin(String? email) {
  final e = (email ?? '').trim().toLowerCase();
  return e.isNotEmpty && kAppAdminEmails.contains(e);
}
