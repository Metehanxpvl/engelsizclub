import '../uzman_kosesi_profiles_store.dart';
import 'expert_cv_models.dart';

const kUzmanKoseBolumKurum = 'kurum_is';
const kUzmanKoseBolumSaglik = 'saglik';
const kUzmanKoseBolumBakim = 'bakim';
const kUzmanKoseBolumEv = 'ev';

const kUzmanKoseBolumKurumBaslik = 'Kurum İş İlanları';
const kUzmanKoseBolumSaglikBaslik = 'Sağlık Uzmanları';
const kUzmanKoseBolumBakimBaslik = 'Bakım Desteği';
const kUzmanKoseBolumEvBaslik = 'Ev Desteği';

const kUzmanKoseBolumSirasi = <String>[
  kUzmanKoseBolumSaglik,
  kUzmanKoseBolumKurum,
  kUzmanKoseBolumBakim,
  kUzmanKoseBolumEv,
];

const kUzmanKoseBolumBasliklari = <String, String>{
  kUzmanKoseBolumKurum: kUzmanKoseBolumKurumBaslik,
  kUzmanKoseBolumSaglik: kUzmanKoseBolumSaglikBaslik,
  kUzmanKoseBolumBakim: kUzmanKoseBolumBakimBaslik,
  kUzmanKoseBolumEv: kUzmanKoseBolumEvBaslik,
};

bool uzmanKoseEvMeslegi(String meslek) {
  final m = uzmanKosesNormYer(meslek);
  return m == 'ev yardimi' || m == 'temizlik gorevlisi';
}

bool uzmanKoseBakimMeslegi(String meslek, {String ustGrup = ''}) {
  if (uzmanKoseEvMeslegi(meslek)) return false;
  if (ustGrup == kMeslekUstBakim) return true;
  return uzmanKosesNormYer(meslek) == 'bakici';
}

String uzmanKoseBolumFromProfil(UzmanKosesProfil p) {
  if (uzmanKoseEvMeslegi(p.meslek)) return kUzmanKoseBolumEv;
  if (uzmanKoseBakimMeslegi(p.meslek, ustGrup: p.ustGrup)) {
    return kUzmanKoseBolumBakim;
  }
  return kUzmanKoseBolumSaglik;
}

List<UzmanKosesProfil> uzmanKosesBolumProfilleri(
  Iterable<UzmanKosesProfil> profiles,
  String bolum, {
  String meslek = '',
  String il = '',
  String ilce = '',
}) {
  return uzmanKosesFiltrele(
    [
      for (final p in profiles)
        if (uzmanKoseBolumFromProfil(p) == bolum) p,
    ],
    meslek: meslek,
    il: il,
    ilce: ilce,
  );
}
