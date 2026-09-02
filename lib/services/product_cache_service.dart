import 'product_repository.dart';

export 'product_repository.dart';

/// Eski ad — [ProductRepository] kullanın (findByBarcode / save / insertIfAbsent).
/// Eksik kayıt (yalnız ad) tam isabet sayılmaz; [ProductRepository.save] UPDATE eder.
typedef ProductCacheService = ProductRepository;
