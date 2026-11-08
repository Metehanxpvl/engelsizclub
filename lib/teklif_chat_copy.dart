/// İletişime geç / teklif sohbetinin ilk otomatik mesajı.
String teklifChatBody(String listingTitle) {
  final title = listingTitle.trim();
  final about = title.isEmpty ? 'ilanınızla' : '$title ilanınızla';
  return 'Merhaba, $about ilgili görüşmek istiyorum.';
}

/// Eski ve yeni otomatik teklif metni (çift zil / yedek tetikleyici).
bool isAutoOfferChatBody(String body) {
  final t = body.toLowerCase();
  return t.contains('teklif verdim') ||
      t.contains('görüşmek istiyorum') ||
      t.contains('gorusmek istiyorum');
}
