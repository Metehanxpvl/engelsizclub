# GitHub'a bağlama ve güncel kod gönderme

Repo zaten tanımlı: `https://github.com/Metehanxpvl/engelsizclub.git`  
(Uzakta `main` silinmiş görünebilir; ilk push yeniden oluşturur.)

## PowerShell (tek seferlik)

```powershell
cd c:\engelsizclub

# 1) Upstream takibini temizle (origin/main gone ise)
git branch --unset-upstream

# 2) Tüm proje dosyalarını ekle (.gitignore junk'ı dışarıda bırakır)
git add -A

# 3) Durumu kontrol et (secret / build klasörü olmamalı)
git status

# 4) Commit
git commit -m "Engelsiz Club: guncel uygulama, dinamik katalog ve Places entegrasyonu"

# 5) GitHub'a gonder
git push -u origin main
```

GitHub giriş isterse tarayıcı/login penceresini `Metehanxpvl` hesabıyla tamamla.

## Sonraki güncellemelerde (kısa)

```powershell
cd c:\engelsizclub
git add -A
git commit -m "Aciklama: ne degisti"
git push
```

## Hızlı script

Aynı klasördeki `push-github.ps1` dosyasını çalıştırabilirsin:

```powershell
cd c:\engelsizclub
.\push-github.ps1 "Aciklama mesaji"
```

## Kontrol

```powershell
git status
# Your branch is up to date with 'origin/main' görmelisin
```

Tarayıcı: https://github.com/Metehanxpvl/engelsizclub
