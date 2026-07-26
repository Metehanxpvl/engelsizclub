export type IlanReview = { author: string; avatar: string; avatarColor: string; rating: number; date: string; text: string };
export type IlanPoster = { name: string; avatar: string; avatarColor: string; rating: number; reviewCount: number; bio: string; tags: string[]; reviews: IlanReview[] };

export const uzmanIlanlar = [
  { id: 1, title: "Evde Fizyoterapist Arıyoruz", uzmanlik: "Fizyoterapist", tanı: "Serebral Palsi", city: "Ankara", district: "Çankaya", age: "6 yaş", frequency: "Haftada 3 seans", note: "Alt ekstremite odaklı çalışma yapılacak. Evde seans verebilecek deneyimli fizyoterapist.", budget: "₺400–600/seans", posted: "2 saat önce", views: 34, offers: 5, urgent: true,
    poster: { name: "Ayşe Y.", avatar: "AY", avatarColor: "#e07a5f", rating: 4.9, reviewCount: 12, bio: "SP tanılı 6 yaşında oğlum için evde fizyoterapist arıyoruz. Zamanında ödeme, güler yüzlü aile.", tags: ["Evde Seans", "SP Deneyimi", "Zamanında Ödeme"],
      reviews: [
        { author: "Emre F.", avatar: "EF", avatarColor: "#1a6b4a", rating: 5, date: "2 ay önce", text: "Çok anlayışlı ve organize bir aile. Seans zamanına tam uyuyorlar, teşekkürler." },
        { author: "Selin K.", avatar: "SK", avatarColor: "#9c6db3", rating: 5, date: "4 ay önce", text: "Her şeyi önceden hazırlıyorlar, çocukla iletişimleri mükemmel." },
        { author: "Murat D.", avatar: "MD", avatarColor: "#6b9ac4", rating: 4, date: "6 ay önce", text: "Güzel bir aile, sadece zaman zaman programa değişiklik olabiliyor." },
      ]
    }
  },
  { id: 2, title: "Dil ve Konuşma Terapisti Aranıyor", uzmanlik: "Dil Terapisti", tanı: "Otizm", city: "İstanbul", district: "Kadıköy", age: "4 yaş", frequency: "Haftada 4 seans", note: "Verbal olmayan çocuğumuz için AAC desteği verebilecek deneyimli terapist.", budget: "₺350–500/seans", posted: "5 saat önce", views: 61, offers: 9, urgent: false,
    poster: { name: "Mehmet S.", avatar: "MS", avatarColor: "#1a6b4a", rating: 4.7, reviewCount: 8, bio: "4 yaşında otizm spektrum tanılı oğlum için AAC konusunda uzman terapist arıyoruz. Ev ortamı müsait.", tags: ["AAC Deneyimi", "Esnek Saat", "Otizm"],
      reviews: [
        { author: "Pınar T.", avatar: "PT", avatarColor: "#e07a5f", rating: 5, date: "1 ay önce", text: "Harika bir aile, çocuğa karşı çok sabırlılar. Kesinlikle tavsiye ederim." },
        { author: "Burak A.", avatar: "BA", avatarColor: "#f4a832", rating: 4, date: "3 ay önce", text: "İyi niyetli, bazen iletişim gecikmesi olabiliyor ama genel olarak memnunum." },
      ]
    }
  },
  { id: 3, title: "Ergoterapist — Evde veya Merkezde", uzmanlik: "Ergoterapist", tanı: "Down Sendromu", city: "İzmir", district: "Bornova", age: "8 yaş", frequency: "Haftada 2 seans", note: "İnce motor beceri ve günlük yaşam aktiviteleri üzerine çalışma istiyoruz.", budget: "₺300–450/seans", posted: "1 gün önce", views: 28, offers: 3, urgent: false,
    poster: { name: "Fatma D.", avatar: "FD", avatarColor: "#9c6db3", rating: 5.0, reviewCount: 15, bio: "Down sendromlu kızımız için ergoterapist arıyoruz. Çok neşeli bir çocuk, terapistleri çok seviyor.", tags: ["Merkez veya Ev", "Down Sendromu", "5+ Yıl"],
      reviews: [
        { author: "Zeynep O.", avatar: "ZO", avatarColor: "#1a6b4a", rating: 5, date: "3 hafta önce", text: "Bu aileyle çalışmak tam anlamıyla keyifli. Çocukları çok tatlı, aile çok ilgili." },
        { author: "Can M.", avatar: "CM", avatarColor: "#6b9ac4", rating: 5, date: "2 ay önce", text: "3 yıldır çalışıyorum, hiç sorun yaşamadım. Önerilen en iyi aile." },
        { author: "Hande K.", avatar: "HK", avatarColor: "#e07a5f", rating: 5, date: "4 ay önce", text: "Her zaman zamanında ödeme, teşekkür mesajları. Harika aile." },
      ]
    }
  },
  { id: 4, title: "Özel Eğitim Öğretmeni Arıyoruz", uzmanlik: "Özel Eğitim Öğretmeni", tanı: "DEHB", city: "İstanbul", district: "Beşiktaş", age: "9 yaş", frequency: "Haftada 3 gün", note: "Okul uyumu ve akademik destek için bireysel çalışacak özel eğitim öğretmeni.", budget: "₺350–500/seans", posted: "3 gün önce", views: 47, offers: 7, urgent: false,
    poster: { name: "Hasan K.", avatar: "HK", avatarColor: "#6b9ac4", rating: 4.5, reviewCount: 6, bio: "DEHB tanılı oğlumuz için sabırlı ve deneyimli özel eğitim öğretmeni arıyoruz.", tags: ["DEHB", "Akademik Destek", "Beşiktaş"],
      reviews: [
        { author: "Nilüfer B.", avatar: "NB", avatarColor: "#9c6db3", rating: 5, date: "1 ay önce", text: "Çok anlayışlı bir baba, çocuğun gelişimi için her şeyi yapıyor." },
        { author: "Tarık S.", avatar: "TS", avatarColor: "#1a6b4a", rating: 4, date: "5 ay önce", text: "Genel olarak iyi, bazen program esnekliği istiyor." },
      ]
    }
  },
  { id: 5, title: "SP Deneyimli Fizyoterapist", uzmanlik: "Fizyoterapist", tanı: "Serebral Palsi", city: "Bursa", district: "Nilüfer", age: "5 yaş", frequency: "Haftada 4 seans", note: "NDT sertifikalı fizyoterapist tercih edilir. Üst ekstremite çalışması.", budget: "₺450–650/seans", posted: "4 saat önce", views: 19, offers: 2, urgent: true,
    poster: { name: "Leyla M.", avatar: "LM", avatarColor: "#f4a832", rating: 4.8, reviewCount: 9, bio: "SP tanılı kızımız için NDT eğitimli fizyoterapist arıyoruz. Evimiz geniş ve uygun.", tags: ["NDT Sertifika", "Üst Ekstremite", "Acil"],
      reviews: [
        { author: "Ozan F.", avatar: "OF", avatarColor: "#1a6b4a", rating: 5, date: "2 hafta önce", text: "Çok sıcak kanlı bir aile. Çocuklarının iyileşmesi için her şeyi yapıyorlar." },
        { author: "Dila K.", avatar: "DK", avatarColor: "#e07a5f", rating: 5, date: "3 ay önce", text: "Zamanında ödeme, seansa hazırlıklı geliyorlar. Takdire şayan." },
      ]
    }
  },
];

export const bakiciIlanlar = [
  { id: 10, title: "Gündüz Bakıcı Arıyoruz", city: "İstanbul", district: "Ataşehir", tanı: "Otizm", age: "7 yaş", hours: "Hafta içi 08:00–17:00", note: "Otizm konusunda deneyimli, sabırlı bakıcı arıyoruz. Temel ABA bilgisi artı.", budget: "₺15.000–20.000/ay", posted: "3 saat önce", views: 52, urgent: true,
    poster: { name: "Canan B.", avatar: "CB", avatarColor: "#5b8dd9", rating: 4.8, reviewCount: 7, bio: "İki çocuklu bir aileyiz. Otizm konusunda bilinçliyiz, bakıcımızla sürekli iletişim halinde oluruz.", tags: ["Güvenli Ev", "Düzenli Ödeme", "Esnek"],
      reviews: [
        { author: "Sema T.", avatar: "ST", avatarColor: "#1a6b4a", rating: 5, date: "1 ay önce", text: "Çok anlayışlı bir aile. Bakıcının refahını önemsiyorlar, yemek ve ulaşım sağlıyorlar." },
        { author: "Reyhan K.", avatar: "RK", avatarColor: "#9c6db3", rating: 5, date: "3 ay önce", text: "Otizm konusunda bilgili aile, bakıcıya yol gösteriyorlar." },
        { author: "Alev D.", avatar: "AD", avatarColor: "#e07a5f", rating: 4, date: "6 ay önce", text: "İyi bir aile, bazen mesai uzayabiliyor ama ödemesini eksiksiz yapıyorlar." },
      ]
    }
  },
  { id: 11, title: "Yarı Zamanlı Bakıcı — Öğleden Sonra", city: "Ankara", district: "Yenimahalle", tanı: "Serebral Palsi", age: "10 yaş", hours: "Hafta içi 13:00–18:00", note: "Tekerlekli sandalye kullanan kızımız için fiziksel engelli deneyimi olan bakıcı.", budget: "₺8.000–10.000/ay", posted: "1 gün önce", views: 38, urgent: false,
    poster: { name: "Kemal Y.", avatar: "KY", avatarColor: "#1a6b4a", rating: 4.6, reviewCount: 4, bio: "SP tanılı kızımız için öğle sonrası bakıcı arıyoruz. Sakin bir ev ortamımız var.", tags: ["Sakin Ortam", "SP Deneyimi", "Yenimahalle"],
      reviews: [
        { author: "Filiz A.", avatar: "FA", avatarColor: "#f4a832", rating: 5, date: "2 ay önce", text: "Düzenli ve güvenilir bir aile, çok memnun kaldım." },
        { author: "Meral T.", avatar: "MT", avatarColor: "#6b9ac4", rating: 4, date: "5 ay önce", text: "İyi niyetli, bazen program değişikliği olabiliyor." },
      ]
    }
  },
  { id: 12, title: "Hafta Sonu Bakıcı", city: "İzmir", district: "Karşıyaka", tanı: "Down Sendromu", age: "5 yaş", hours: "Cumartesi–Pazar 09:00–18:00", note: "Hafta sonları ailece çalıştığımız için güvenilir bir bakıcıya ihtiyacımız var.", budget: "₺3.000–4.000/hafta sonu", posted: "2 gün önce", views: 21, urgent: false,
    poster: { name: "Yıldız G.", avatar: "YG", avatarColor: "#9c6db3", rating: 5.0, reviewCount: 11, bio: "Down sendromlu oğlumuz çok neşeli bir çocuk. Hafta sonları güvenebileceğimiz bakıcı arıyoruz.", tags: ["Neşeli Çocuk", "Down Sendromu", "Karşıyaka"],
      reviews: [
        { author: "Oya K.", avatar: "OK", avatarColor: "#1a6b4a", rating: 5, date: "3 hafta önce", text: "Harika aile! Çocukları gerçekten çok tatlı, bakıcıya karşı çok nazikler." },
        { author: "Hüseyin B.", avatar: "HB", avatarColor: "#e07a5f", rating: 5, date: "2 ay önce", text: "Yıllardır bu aileyle çalışıyorum, hiç sorun yaşamadım." },
      ]
    }
  },
  { id: 13, title: "Tam Zamanlı Bakıcı / Refakatçi", city: "İstanbul", district: "Sarıyer", tanı: "DEHB + Gelişim Geriliği", age: "12 yaş", hours: "Pzt–Cum 07:30–18:30", note: "İki tanısı olan oğlumuz için deneyimli, sabırlı ve taşıt kullanabilen bakıcı.", budget: "₺18.000–25.000/ay", posted: "5 saat önce", views: 67, urgent: true,
    poster: { name: "Oğuz T.", avatar: "OT", avatarColor: "#e07a5f", rating: 4.4, reviewCount: 5, bio: "DEHB ve gelişim geriliği tanılı oğlumuz için güvenilir refakatçi/bakıcı arıyoruz. Araç sağlanır.", tags: ["Araç Sağlanır", "Yüksek Bütçe", "Sarıyer"],
      reviews: [
        { author: "Nalan S.", avatar: "NS", avatarColor: "#1a6b4a", rating: 5, date: "6 hafta önce", text: "Ciddi ve güvenilir bir aile. Çocuğun ihtiyaçlarını çok iyi biliyorlar." },
        { author: "Coşkun Y.", avatar: "CY", avatarColor: "#6b9ac4", rating: 4, date: "4 ay önce", text: "Yoğun bir tempolu bir iş ama aile çok anlayışlı, iyi ödeme yapıyorlar." },
      ]
    }
  },
];

export const ikincielIlanlar = [
  { id: 20, title: "Çocuk Tekerlekli Sandalye", category: "Tekerlekli Sandalye", city: "İstanbul", district: "Pendik", condition: "İyi", brand: "Ottobock", note: "2 yıl kullanıldı, temiz ve bakımlı. Oğlum büyüdüğü için satıyoruz.", price: "₺4.500", originalPrice: "₺12.000", posted: "1 saat önce", views: 43, emoji: "🦽", photos: ["#dce8f5","#c8ddf0","#b8d3ed"],
    poster: { name: "Tuba A.", avatar: "TA", avatarColor: "#e07a5f", rating: 5.0, reviewCount: 8, bio: "3 yıldır özel eğitim malzemesi alıp satıyorum. Her ürünü temiz ve bakımlı teslim ederim.", tags: ["Hızlı Teslimat", "Fatura Var", "Güvenilir"],
      reviews: [
        { author: "Sercan B.", avatar: "SB", avatarColor: "#1a6b4a", rating: 5, date: "1 ay önce", text: "Tam tanımlandığı gibi, sıfır sorun. Tekrar alırım." },
        { author: "Gülşen M.", avatar: "GM", avatarColor: "#9c6db3", rating: 5, date: "3 ay önce", text: "Çok dürüst bir satıcı, ürün gerçekten temizdi." },
      ]
    }
  },
  { id: 21, title: "Duyu Bütünleme Salıncağı", category: "Terapi Ekipmanı", city: "Ankara", district: "Çankaya", condition: "Çok İyi", brand: "Southpaw", note: "Ergoterapi için kullandık, taşınmamız nedeniyle satılıktır. Tavan kancası dahil.", price: "₺2.800", originalPrice: "₺7.500", posted: "3 saat önce", views: 29, emoji: "🎡", photos: ["#e8f0dc","#d8e8c8"],
    poster: { name: "Berk D.", avatar: "BD", avatarColor: "#6b9ac4", rating: 4.7, reviewCount: 5, bio: "Ailemizin kullandığı terapi ekipmanlarını temiz tutarak satıyoruz. Birebir görüşmeye açığız.", tags: ["Ankara", "Kurulum Yardımı", "Pazarlık Yok"],
      reviews: [
        { author: "Aslı T.", avatar: "AT", avatarColor: "#1a6b4a", rating: 5, date: "2 ay önce", text: "Çok temiz ürün, fotoğraflarla birebir aynıydı." },
        { author: "Volkan E.", avatar: "VE", avatarColor: "#e07a5f", rating: 4, date: "5 ay önce", text: "İyi satıcı, teslimat biraz gecikmeli oldu ama ürün mükemmeldi." },
      ]
    }
  },
  { id: 22, title: "Adaptif Bisiklet", category: "Adaptif Araç", city: "İzmir", district: "Bornova", condition: "İyi", brand: "Rifton", note: "SP tanılı çocuklar için üretilmiş denge bisikleti. Az kullanıldı.", price: "₺6.200", originalPrice: "₺18.000", posted: "2 gün önce", views: 55, emoji: "🚲", photos: ["#f5e8dc","#f0d8c8","#edd0ba","#e8c8aa"],
    poster: { name: "Nesrin K.", avatar: "NK", avatarColor: "#9c6db3", rating: 4.9, reviewCount: 13, bio: "Özel gereksinimli çocuklara yönelik adaptif araçlar satıyorum. Her şey çalışır durumda.", tags: ["Adaptif Araç", "Az Kullanılmış", "Rifton Uzmanı"],
      reviews: [
        { author: "Taner M.", avatar: "TM", avatarColor: "#1a6b4a", rating: 5, date: "3 hafta önce", text: "Mükemmel satıcı! Ürün hakkında çok bilgili, montajda yardımcı oldu." },
        { author: "Ece S.", avatar: "ES", avatarColor: "#f4a832", rating: 5, date: "1 ay önce", text: "Çocuğumuz çok sevdi. Her şey %100 doğru tanımlanmıştı." },
        { author: "Kaan B.", avatar: "KB", avatarColor: "#6b9ac4", rating: 5, date: "3 ay önce", text: "Güvenilir ve hızlı. Tekrar bu satıcıdan alırım." },
      ]
    }
  },
  { id: 23, title: "AAC İletişim Tableti + Yazılım", category: "İletişim Cihazı", city: "İstanbul", district: "Beşiktaş", condition: "Çok İyi", brand: "Tobii Dynavox", note: "Proloquo2Go lisanslı iPad. Çocuğumuz artık konuşabildiği için satıyoruz.", price: "₺9.500", originalPrice: "₺22.000", posted: "1 gün önce", views: 88, emoji: "📱", photos: ["#dce5f5","#ccd8f0"],
    poster: { name: "İpek Y.", avatar: "İY", avatarColor: "#1a6b4a", rating: 5.0, reviewCount: 4, bio: "Çocuğumuz Proloquo2Go ile konuşmaya başladı, artık ihtiyacımız yok. Cihaz sıfır gibi.", tags: ["Lisanslı Yazılım", "iPad", "AAC"],
      reviews: [
        { author: "Sibel A.", avatar: "SA", avatarColor: "#9c6db3", rating: 5, date: "6 ay önce", text: "Çocuğumuzun hayatını değiştiren ürünü aldık. Satıcı çok bilgiliydi." },
      ]
    }
  },
  { id: 24, title: "Önden Destekli Yürüteç", category: "Yürüteç", city: "Bursa", district: "Nilüfer", condition: "İyi", brand: "Kaye Products", note: "Ayarlanabilir boy. Temiz tutulmuştur.", price: "₺1.800", originalPrice: "₺5.500", posted: "4 saat önce", views: 31, emoji: "🦯", photos: ["#e8f5ee","#d8ede4"],
    poster: { name: "Orhan S.", avatar: "OS", avatarColor: "#f4a832", rating: 4.6, reviewCount: 6, bio: "Özel gereksinimli çocuklar için çeşitli yardımcı araçlarım var. Kargo veya elden teslim.", tags: ["Kargo Var", "Bursa", "Uygun Fiyat"],
      reviews: [
        { author: "Pelin K.", avatar: "PK", avatarColor: "#1a6b4a", rating: 5, date: "1 ay önce", text: "Tam beklediğim gibi. Çok hızlı kargo, teşekkürler." },
        { author: "Barış T.", avatar: "BT", avatarColor: "#e07a5f", rating: 4, date: "3 ay önce", text: "Ürün iyi durumda, fiyat uygun. Tavsiye ederim." },
      ]
    }
  },
];

export const uzmanRenk: Record<string, { color: string; bg: string; emoji: string }> = {
  "Fizyoterapist":           { color: "#1a6b4a", bg: "#e8f5ee", emoji: "🏃" },
  "Ergoterapist":            { color: "#9c6db3", bg: "#f5eefb", emoji: "✋" },
  "Özel Eğitim Öğretmeni":  { color: "#6b9ac4", bg: "#eef5fb", emoji: "📚" },
  "Dil Terapisti":           { color: "#e07a5f", bg: "#fdf0ec", emoji: "💬" },
};
