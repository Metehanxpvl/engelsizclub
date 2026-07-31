-- Nadir hastalıklar detay içerikleri
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.nadir_hastaliklar (
  id text primary key,
  name text not null,
  icon text not null default '',
  short_desc text not null default '',
  definition text not null default '',
  effects text not null default '',
  sort_order int not null default 0,
  updated_at timestamptz not null default now()
);

create index if not exists nadir_hastaliklar_sort_idx
  on public.nadir_hastaliklar (sort_order);

alter table public.nadir_hastaliklar enable row level security;

drop policy if exists "nadir_select_auth" on public.nadir_hastaliklar;
create policy "nadir_select_auth"
  on public.nadir_hastaliklar for select
  to authenticated
  using (true);

drop policy if exists "nadir_write_admin" on public.nadir_hastaliklar;
create policy "nadir_write_admin"
  on public.nadir_hastaliklar for all
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Varsayılan kayıtları ekle (yoksa); mevcut satırları bozmaz
insert into public.nadir_hastaliklar
  (id, name, icon, short_desc, definition, effects, sort_order)
values
  (
    'spina_bifida',
    'Spina Bifida',
    '🧠',
    'Omurilik ve omurga gelişim bozukluğu.',
    'Omurganın ve omuriliğin anne karnındaki gelişim sürecinde (gebeliğin ilk haftalarında) tam olarak kapanmaması sonucu ortaya çıkan konjenital (doğuştan) bir nöral tüp defektidir.',
    'Omuriliğin dışarıya kesecik şeklinde çıkmasına veya açık kalmasına neden olabilir. Etkilenen bölgeye bağlı olarak bacaklarda kısmi veya tam felç, idrar ve dışkı kontrolü sorunları gibi fiziksel engellerle seyredebilir.',
    0
  ),
  (
    'rett',
    'Rett Sendromu',
    '🌸',
    'Ağırlıklı olarak kız çocuklarında görülen nörolojik gelişim bozukluğu.',
    'Genellikle MECP2 genindeki mutasyonlardan kaynaklanan, nadir görülen ve ilerleyici nörogelişimsel bir bozukluktur. Ağırlıklı olarak kız çocuklarını etkiler.',
    'Bebek ilk aylarında normal bir gelişim gösterdikten sonra; el becerilerini (amaçlı el hareketlerini) kaybeder, konuşma yeteneği geriler, yürüme bozuklukları ve karakteristik el ovuşturma/bükme hareketleri başlar.',
    1
  ),
  (
    'angelman',
    'Angelman Sendromu',
    '😊',
    'Mutluluk davranışı ve gelişim geriliğiyle karakterize genetik hastalık.',
    '15 numaralı kromozomdaki genetik bir bozukluktan (genellikle anneden gelen kopyanın eksikliği veya işlevsizliği) kaynaklanan nörogelişimsel bir sendromdur.',
    'Şiddetli zihinsel yetersizlik, konuşma yokluğu veya ciddi derecede kısıtlı konuşma, denge ve yürüme bozuklukları (ataksik/marazi yürüyüş) görülür. En belirgin özelliklerinden biri, sık gülme, neşeli görünüm, el çırpma gibi davranışlar ve aşırı heyecan halidir.',
    2
  ),
  (
    'prader_willi',
    'Prader-Willi Sendromu',
    '🧬',
    'Hipotoni, obezite eğilimi ve gelişim geriliğiyle seyreden genetik durum.',
    '15 numaralı kromozomun babadan gelen kısmındaki bir eksiklikten kaynaklanan karmaşık bir genetik hastalıktır.',
    'Bebeklik döneminde derin kas gevşekliği (hipotoni) ve beslenme güçlükleri ile başlar. Çocukluk dönemine geçişle birlikte doyum noktası olmama (sürekli açlık hissi - hiperfaji) durumu baş gösterir; bu da kontrol edilmezse aşırı obeziteye ve buna bağlı metabolik sorunlara yol açabilir.',
    3
  ),
  (
    'pku',
    'PKU (Fenilketonüri)',
    '🔴',
    'Fenilalanin metabolizmasındaki enzim eksikliğinden kaynaklanan metabolik hastalık.',
    'Karaciğerde fenilalanin amino asidini parçalayan enzimin eksikliği veya çalışmaması nedeniyle ortaya çıkan kalıtsal bir metabolik hastalıktır.',
    'Vücutta biriken fenilalanin ve türevleri beyin dokusuna zarar vererek tedavi edilmediği takdirde kalıcı zihinsel geriliğe yol açar. Doğan her bebeğe rutin olarak topuk kanı testi ile taranır ve ömür boyu düşük fenilalaninli diyetle kontrol altında tutulur.',
    4
  ),
  (
    'fragile_x',
    'Fragile X (Kırılgan X Sendromu)',
    '🔬',
    'En yaygın kalıtsal zihinsel engel nedeni olan genetik bozukluk.',
    'X kromozomu üzerinde bulunan FMR1 genindeki mutasyon sonucu gelişen, en sık rastlanan kalıtsal zihinsel engel nedenlerinden biridir.',
    'Öğrenme güçlükleri, dikkat eksikliği, hiperaktivite, sosyal kaygı ve otizm benzeri davranışsal özellikler görülebilir. Erkeklerde genellikle kızlara kıyasla daha ağır tablolara yol açar.',
    5
  ),
  (
    'tuberous',
    'Tuberous Sclerosis (Tüberoskleroz)',
    '🔵',
    'Beyin, cilt ve organlarda iyi huylu tümörlere yol açan genetik hastalık.',
    'Vücudun farklı organlarında (özellikle beyin, böbrek, kalp, akciğer ve cilt) iyi huylu tümörlerin (hamartom) oluşmasına neden olan genetik bir hastalıktır.',
    'Beyindeki lezyonlara bağlı olarak epilepsi (nöbetler), öğrenme güçlükleri veya otizm spektrum bozuklukları görülebilir. Ciltte karakteristik lekeler ve kabarıklıklar eşlik edebilir.',
    6
  ),
  (
    'dmd',
    'Duchenne Müsküler Distrofi (DMD)',
    '💪',
    'Kas gücünün ilerleyici kaybıyla seyreden genetik kas hastalığı.',
    'Kasların yapısını koruyan distrofin proteininin eksikliğinden kaynaklanan, X kromozomuna bağlı geçiş gösteren ilerleyici bir genetik kas hastalığıdır. Genellikle erkek çocuklarında görülür.',
    'Çocukluk çağında yürüme zorlukları, sık düşme ve merdiven çıkmada güçlükle başlar. Zamanla tüm iskelet kaslarını ve solunum/kalp kaslarını zayıflatarak hastanın tekerlekli sandalyeye bağımlı hale gelmesine yol açar.',
    7
  ),
  (
    'williams',
    'Williams Sendromu',
    '🎵',
    'Sosyal kişilik, müzikal yetenek ve kardiyovasküler sorunlarla karakterize durum.',
    '7 numaralı kromozomun belirli bir bölgesindeki genlerin eksilmesi (mikrodelesyon) sonucu oluşan nadir bir genetik sendromdur.',
    'Hastalar genellikle aşırı sosyal, dışa dönük, empatik ve müzik kulağı gelişmiş kişilik yapılarıyla bilinirler. Buna karşın yüz hatlarında belirgin özellikler (elf benzeri yüz), böbrek anomalileri ve ilerleyici kardiyovasküler (kalp-damar) sorunlar barındırabilir.',
    8
  ),
  (
    'cdkl5',
    'CDKL5 Eksikliği',
    '⚡',
    'Erken başlangıçlı nöbetler ve ciddi gelişimsel gecikmeye yol açan genetik bozukluk.',
    'X kromozomu üzerindeki CDKL5 geninin mutasyonu veya eksikliğinden kaynaklanan, erken çocukluk döneminde ortaya çıkan ağır bir genetik nörolojik bozukluktur.',
    'Yaşamın ilk aylarından itibaren başlayan, kontrol edilmesi zor ve dirençli epilepsi nöbetleri (erken başlangıçlı nöbetler), ağır motor ve zihinsel gelişim gerilikleri, konuşma yokluğu ve ellerde tekrarlayan stereotipik hareketlerle karakterizedir.',
    9
  )
on conflict (id) do nothing;

notify pgrst, 'reload schema';
