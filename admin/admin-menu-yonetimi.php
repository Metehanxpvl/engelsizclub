<?php
/**
 * Admin: Daha Fazlası menü yönetimi
 * Dosya: admin/admin-menu-yonetimi.php
 * Veri:  admin/daha_fazlasi_menu.json
 *
 * Not: Firebase Hosting PHP çalıştırmaz. Bu dosyayı PHP destekleyen
 * bir hosta (veya reverse-proxy'ye) koyun. JSON yolunu buna göre ayarlayın.
 */
declare(strict_types=1);

session_start();

$jsonPath = __DIR__ . '/daha_fazlasi_menu.json';

function load_menu(string $path): array
{
    if (!is_file($path)) {
        return [];
    }
    $raw = file_get_contents($path);
    $data = json_decode($raw ?: '[]', true);
    return is_array($data) ? $data : [];
}

function save_menu(string $path, array $items): bool
{
    $json = json_encode(array_values($items), JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    return $json !== false && file_put_contents($path, $json . "\n") !== false;
}

function next_id(array $items): int
{
    $max = 0;
    foreach ($items as $it) {
        $max = max($max, (int)($it['id'] ?? 0));
    }
    return $max + 1;
}

$flash = '';
$items = load_menu($jsonPath);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';

    if ($action === 'save_row') {
        $id = (int)($_POST['id'] ?? 0);
        $isim = trim((string)($_POST['isim'] ?? ''));
        $link = trim((string)($_POST['link'] ?? ''));
        $aktif = isset($_POST['aktif']) ? 1 : 0;

        foreach ($items as &$it) {
            if ((int)($it['id'] ?? 0) === $id) {
                if ($isim !== '') {
                    $it['isim'] = $isim;
                }
                if ($link !== '') {
                    $it['link'] = $link;
                }
                $it['aktif'] = $aktif;
                break;
            }
        }
        unset($it);

        if (save_menu($jsonPath, $items)) {
            $flash = 'Kayıt güncellendi.';
        } else {
            $flash = 'Kayıt yazılamadı (dosya izni?).';
        }
    }

    if ($action === 'add') {
        $isim = trim((string)($_POST['yeni_isim'] ?? ''));
        $link = trim((string)($_POST['yeni_link'] ?? ''));
        if ($isim === '' || $link === '') {
            $flash = 'Yeni link için isim ve URL gerekli.';
        } else {
            $items[] = [
                'id' => next_id($items),
                'isim' => $isim,
                'link' => $link,
                'aktif' => 1,
            ];
            if (save_menu($jsonPath, $items)) {
                $flash = 'Yeni link eklendi.';
            } else {
                $flash = 'Yeni link yazılamadı.';
            }
        }
    }

    if ($action === 'delete') {
        $id = (int)($_POST['id'] ?? 0);
        $items = array_values(array_filter(
            $items,
            static fn($it) => (int)($it['id'] ?? 0) !== $id
        ));
        save_menu($jsonPath, $items);
        $flash = 'Silindi.';
    }

    $items = load_menu($jsonPath);
}
?>
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Daha Fazlası Menü Yönetimi</title>
  <style>
    :root { --fg:#0d2b1f; --muted:#4d7a62; --bg:#f2f7f4; --card:#fff; --accent:#1a6b4a; --border:rgba(26,107,74,.18); }
    * { box-sizing: border-box; }
    body { margin:0; font-family: system-ui, sans-serif; background:var(--bg); color:var(--fg); }
    main { max-width: 920px; margin: 0 auto; padding: 24px 16px 48px; }
    h1 { margin: 0 0 8px; font-size: 1.5rem; }
    .sub { color: var(--muted); margin-bottom: 18px; }
    .flash { background:#e8f5ee; border:1px solid var(--border); padding:10px 12px; border-radius:10px; margin-bottom:16px; font-weight:700; }
    .row {
      display:grid;
      grid-template-columns: 1fr 1.2fr auto auto auto;
      gap:8px;
      align-items:center;
      background:var(--card);
      border:1px solid var(--border);
      border-radius:12px;
      padding:12px;
      margin-bottom:10px;
    }
    @media (max-width:720px) {
      .row { grid-template-columns: 1fr; }
    }
    input[type=text] {
      width:100%; padding:10px 12px; border:1px solid var(--border); border-radius:8px; font:inherit;
    }
    .toggle { display:flex; align-items:center; gap:8px; font-weight:600; white-space:nowrap; }
    button, .btn {
      background:var(--accent); color:#fff; border:0; border-radius:8px; padding:10px 14px;
      font-weight:800; cursor:pointer;
    }
    button.secondary { background:#fff; color:var(--accent); border:1px solid var(--border); }
    .add {
      margin-top:20px; background:var(--card); border:1px dashed var(--border);
      border-radius:12px; padding:16px; display:grid; gap:10px; grid-template-columns:1fr 1fr auto;
    }
    @media (max-width:720px) { .add { grid-template-columns:1fr; } }
    code { background:#e8f5ee; padding:2px 6px; border-radius:6px; }
  </style>
</head>
<body>
<main>
  <h1>Daha Fazlası — Menü Yönetimi</h1>
  <p class="sub">Kaynak: <code>daha_fazlasi_menu.json</code> · Sadece <code>aktif:1</code> olanlar sitede görünür.</p>

  <?php if ($flash !== ''): ?>
    <div class="flash"><?= htmlspecialchars($flash, ENT_QUOTES, 'UTF-8') ?></div>
  <?php endif; ?>

  <?php foreach ($items as $it): ?>
    <form class="row" method="post">
      <input type="hidden" name="action" value="save_row" />
      <input type="hidden" name="id" value="<?= (int)$it['id'] ?>" />
      <input type="text" name="isim" value="<?= htmlspecialchars((string)$it['isim'], ENT_QUOTES, 'UTF-8') ?>" placeholder="İsim" />
      <input type="text" name="link" value="<?= htmlspecialchars((string)$it['link'], ENT_QUOTES, 'UTF-8') ?>" placeholder="/bilgi-kutuphanesi/..." />
      <label class="toggle">
        <input type="checkbox" name="aktif" value="1" <?= !empty($it['aktif']) ? 'checked' : '' ?> />
        Aktif
      </label>
      <button type="submit">Kaydet</button>
      <button class="secondary" type="submit" name="action" value="delete" onclick="return confirm('Silinsin mi?')">Sil</button>
    </form>
  <?php endforeach; ?>

  <form class="add" method="post">
    <input type="hidden" name="action" value="add" />
    <input type="text" name="yeni_isim" placeholder="Yeni menü adı" required />
    <input type="text" name="yeni_link" placeholder="/bilgi-kutuphanesi/..." required />
    <button type="submit">Yeni Link Ekle</button>
  </form>
</main>
</body>
</html>
