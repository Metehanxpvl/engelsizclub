<?php
/**
 * includes/menu.php — "Daha Fazlası" dropdown parçası
 *
 * ============================================================
 * NEREVE EKLENECEK?
 * ------------------------------------------------------------
 * header.php veya ana navigasyon dosyanızda, "Daha Fazlası"
 * butonunun <ul>/<div> içine şunu ekleyin:
 *
 *   <?php include __DIR__ . '/menu.php'; ?>
 *
 * Örnek (header.php içinde):
 *
 *   <div class="dropdown">
 *     <button type="button">Daha Fazlası</button>
 *     <ul class="dropdown-menu">
 *       <?php include __DIR__ . '/menu.php'; ?>   <!-- ← BURAYA -->
 *     </ul>
 *   </div>
 *
 * JSON yolu: admin/daha_fazlasi_menu.json
 * (gerekirse aşağıdaki $menuJsonPath'i kendi dizin yapınıza göre değiştirin)
 * ============================================================
 */

declare(strict_types=1);

$menuJsonPath = dirname(__DIR__) . '/admin/daha_fazlasi_menu.json';

$dahaFazlasiMenu = [];
if (is_file($menuJsonPath)) {
    $decoded = json_decode((string)file_get_contents($menuJsonPath), true);
    if (is_array($decoded)) {
        $dahaFazlasiMenu = $decoded;
    }
}

foreach ($dahaFazlasiMenu as $menuItem) {
    if ((int)($menuItem['aktif'] ?? 0) !== 1) {
        continue;
    }
    $isim = htmlspecialchars((string)($menuItem['isim'] ?? ''), ENT_QUOTES, 'UTF-8');
    $link = htmlspecialchars((string)($menuItem['link'] ?? '#'), ENT_QUOTES, 'UTF-8');
    if ($isim === '') {
        continue;
    }
    echo '<li><a href="' . $link . '">' . $isim . '</a></li>' . "\n";
}
