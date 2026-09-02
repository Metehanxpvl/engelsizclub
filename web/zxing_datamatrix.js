/**
 * Live barcode decode for Flutter web (Ürün + İlaç).
 * Vendored @zxing/library (web/zxing_library.min.js) — not jsdelivr.
 *
 * Live path (~6 fps): BarcodeDetector first, then one 720px ZXing canvas
 * after a few misses. Still-image path may use multi-scale + invert.
 */
(function (global) {
  'use strict';

  var ZXING_LOCAL = 'zxing_library.min.js?v=20260902-k3';
  var ZXING_CDN = 'https://cdn.jsdelivr.net/npm/@zxing/library@0.21.3/umd/index.min.js';
  var ZXING_FALLBACK = 'https://unpkg.com/@zxing/library@0.21.3/umd/index.min.js';
  var loadStarted = false;
  var decoderStatus = 'loading';
  var dmReader = null;
  var qrReader = null;
  var oneDReader = null;
  var multiReader = null;
  var tryHarder = null;
  var cropCanvas = null;
  var cropCtx = null;
  var workCanvas = null;
  var workCtx = null;
  var blurCanvas = null;
  var blurCtx = null;
  var cropIndex = 0;
  var lastBlurry = false;
  var blurStreak = 0;
  var torchOn = false;
  var boostTimer1 = 0;
  var boostTimer2 = 0;
  var focusRestoreTimer = 0;
  var browserReader = null;
  var nativeDetector = null;
  var nativeDetectorFailed = false;
  var html5Instance = null;
  var liveDecodeBusy = false;
  var lastDecodeAt = 0;
  var nativeMissStreak = 0;
  var MIN_INTERVAL_MS = 160;

  function zx() {
    var lib = global.ZXing || global.ZXingBrowser || null;
    if (
      lib &&
      !lib.BrowserMultiFormatReader &&
      global.ZXingBrowser &&
      global.ZXingBrowser.BrowserMultiFormatReader
    ) {
      lib.BrowserMultiFormatReader = global.ZXingBrowser.BrowserMultiFormatReader;
    }
    return lib;
  }

  function html5Ctor() {
    if (typeof global.Html5Qrcode === 'function') return global.Html5Qrcode;
    var lib = global.__Html5QrcodeLibrary__;
    if (lib && typeof lib.Html5Qrcode === 'function') return lib.Html5Qrcode;
    return null;
  }

  function markReady() {
    decoderStatus = 'ready';
  }

  function markFailed() {
    if (zx() || html5Ctor() || typeof BarcodeDetector === 'function') {
      decoderStatus = 'ready';
      return;
    }
    decoderStatus = 'failed';
  }

  function ensureZxing(cb) {
    if (zx()) {
      markReady();
      if (cb) cb();
      return;
    }
    if (loadStarted) return;
    loadStarted = true;
    decoderStatus = 'loading';
    function inject(src, next) {
      var s = document.createElement('script');
      s.src = src;
      s.async = true;
      s.onload = function () {
        if (zx()) {
          markReady();
          if (cb) cb();
        } else if (next) next();
        else markFailed();
      };
      s.onerror = function () {
        if (next) next();
        else markFailed();
      };
      document.head.appendChild(s);
    }
    inject(ZXING_LOCAL, function () {
      inject(ZXING_CDN, function () {
        inject(ZXING_FALLBACK, function () {
          markFailed();
        });
      });
    });
  }

  function formatName(f) {
    if (f == null) return '';
    if (typeof f === 'string') return f.toLowerCase();
    var n = typeof f === 'number' ? f : Number(f);
    var names = {
      0: 'aztec',
      4: 'code_128',
      5: 'data_matrix',
      6: 'ean_8',
      7: 'ean_13',
      10: 'pdf417',
      11: 'qr_code',
      14: 'upc_a',
      15: 'upc_e',
    };
    if (names[n]) return names[n];
    return String(f).toLowerCase();
  }

  function hitFromResult(result) {
    if (!result) return null;
    var text =
      typeof result.getText === 'function' ? result.getText() : result.text;
    if (!text || !String(text).trim()) return null;
    var fmt =
      typeof result.getBarcodeFormat === 'function'
        ? result.getBarcodeFormat()
        : result.format;
    return { format: formatName(fmt), text: String(text).trim() };
  }

  function getReaders(includeMulti) {
    var Z = zx();
    if (!Z) return [];
    if (!tryHarder) {
      tryHarder = new Map();
      tryHarder.set(Z.DecodeHintType.TRY_HARDER, true);
      tryHarder.set(Z.DecodeHintType.CHARACTER_SET, 'ISO-8859-1');
    }
    if (!dmReader) dmReader = new Z.DataMatrixReader();
    if (!qrReader) qrReader = new Z.QRCodeReader();
    var list = [dmReader, qrReader];
    if (includeMulti !== false) {
      if (!oneDReader && Z.MultiFormatOneDReader) {
        try {
          oneDReader = new Z.MultiFormatOneDReader(tryHarder);
        } catch (_) {
          oneDReader = null;
        }
      }
      if (oneDReader) list.push(oneDReader);
      if (!multiReader) {
        multiReader = new Z.MultiFormatReader();
        var hints = new Map();
        hints.set(Z.DecodeHintType.TRY_HARDER, true);
        hints.set(Z.DecodeHintType.POSSIBLE_FORMATS, [
          Z.BarcodeFormat.DATA_MATRIX,
          Z.BarcodeFormat.QR_CODE,
          Z.BarcodeFormat.PDF_417,
          Z.BarcodeFormat.AZTEC,
          Z.BarcodeFormat.CODE_128,
          Z.BarcodeFormat.EAN_13,
          Z.BarcodeFormat.EAN_8,
          Z.BarcodeFormat.UPC_A,
          Z.BarcodeFormat.UPC_E,
        ]);
        multiReader.setHints(hints);
      }
      list.push(multiReader);
    }
    return list;
  }

  function decodeBitmap(bitmap, includeMulti) {
    var readers = getReaders(includeMulti);
    for (var i = 0; i < readers.length; i++) {
      try {
        var result = readers[i].decode(bitmap, tryHarder);
        var hit = hitFromResult(result);
        if (hit) return hit;
      } catch (_) {
        try {
          readers[i].reset();
        } catch (_2) {}
      }
    }
    return null;
  }

  function luminanceFromCanvas(canvas) {
    var Z = zx();
    if (Z.HTMLCanvasElementLuminanceSource) {
      return new Z.HTMLCanvasElementLuminanceSource(canvas, false);
    }
    var ctx = canvas.getContext('2d', { willReadFrequently: true });
    var imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    var src = imageData.data;
    var w = imageData.width;
    var h = imageData.height;
    var lum = new Uint8ClampedArray(w * h);
    for (var i = 0, j = 0; i < src.length; i += 4, j++) {
      lum[j] = (src[i] * 306 + src[i + 1] * 601 + src[i + 2] * 117) >> 10;
    }
    return new Z.RGBLuminanceSource(lum, w, h);
  }

  function decodeCanvas(canvas, includeMulti, thorough) {
    var Z = zx();
    if (!Z || !canvas || canvas.width < 16 || canvas.height < 16) return null;
    try {
      var source = luminanceFromCanvas(canvas);
      var hit = decodeBitmap(
        new Z.BinaryBitmap(new Z.HybridBinarizer(source)),
        includeMulti,
      );
      if (hit) return hit;
      try {
        var inverted =
          typeof source.invert === 'function'
            ? source.invert()
            : new Z.InvertedLuminanceSource(source);
        hit = decodeBitmap(
          new Z.BinaryBitmap(new Z.HybridBinarizer(inverted)),
          includeMulti,
        );
        if (hit) return hit;
      } catch (_) {}
      if (thorough !== false && Z.GlobalHistogramBinarizer) {
        hit = decodeBitmap(
          new Z.BinaryBitmap(new Z.GlobalHistogramBinarizer(source)),
          includeMulti,
        );
        if (hit) return hit;
      }
    } catch (_) {}
    return null;
  }

  function collectVideos(root, out) {
    if (!root) return;
    var nodes;
    var i;
    var el;
    try {
      nodes = root.querySelectorAll ? root.querySelectorAll('video') : [];
    } catch (_) {
      nodes = [];
    }
    for (i = 0; i < nodes.length; i++) out.push(nodes[i]);
    try {
      nodes = root.querySelectorAll ? root.querySelectorAll('*') : [];
    } catch (_) {
      return;
    }
    for (i = 0; i < nodes.length; i++) {
      el = nodes[i];
      if (el && el.shadowRoot) collectVideos(el.shadowRoot, out);
    }
  }

  function liveVideo() {
    var found = [];
    collectVideos(document, found);
    var pane =
      document.querySelector('flt-glass-pane') ||
      document.querySelector('flutter-view');
    if (pane && pane.shadowRoot) collectVideos(pane.shadowRoot, found);
    var best = null;
    var bestArea = 0;
    var i;
    for (i = 0; i < found.length; i++) {
      var v = found[i];
      var w = v.videoWidth || 0;
      var h = v.videoHeight || 0;
      if (w < 80 || h < 80) continue;
      var playing = !v.paused && v.readyState >= 2;
      var area = w * h + (playing ? 1e9 : 0);
      if (area > bestArea) {
        best = v;
        bestArea = area;
      }
    }
    return best;
  }

  function liveTrack() {
    var video = liveVideo();
    if (!video || !video.srcObject || !video.srcObject.getVideoTracks) {
      return null;
    }
    var tracks = video.srcObject.getVideoTracks();
    return tracks && tracks[0] ? tracks[0] : null;
  }

  function ensureCropCanvas() {
    if (!cropCanvas) {
      cropCanvas = document.createElement('canvas');
      cropCtx = cropCanvas.getContext('2d', { willReadFrequently: true });
    }
    return cropCtx;
  }

  function sourceSize(source) {
    return {
      w: source.videoWidth || source.width || 0,
      h: source.videoHeight || source.height || 0,
    };
  }

  /** Center crop as a fraction of the shorter side (0.71 ≈ 1.4×, 0.5 = 2×). */
  function drawCenterCrop(source, frac, out) {
    var sz = sourceSize(source);
    if (!sz.w || !sz.h) return null;
    var side = Math.max(32, Math.min(sz.w, sz.h) * frac);
    var sx = (sz.w - side) / 2;
    var sy = (sz.h - side) / 2;
    var ctx = ensureCropCanvas();
    var dest = Math.max(32, Math.round(out || side));
    cropCanvas.width = dest;
    cropCanvas.height = dest;
    ctx.imageSmoothingEnabled = dest > side;
    ctx.imageSmoothingQuality = dest > side ? 'high' : 'low';
    ctx.drawImage(source, sx, sy, side, side, 0, 0, dest, dest);
    return cropCanvas;
  }

  function drawFullFrame(source, maxSide) {
    var sz = sourceSize(source);
    if (!sz.w || !sz.h) return null;
    var limit = maxSide || 1280;
    var scale = Math.min(1, limit / Math.max(sz.w, sz.h));
    var w = Math.max(32, Math.round(sz.w * scale));
    var h = Math.max(32, Math.round(sz.h * scale));
    if (!workCanvas) {
      workCanvas = document.createElement('canvas');
      workCtx = workCanvas.getContext('2d', { willReadFrequently: true });
    }
    workCanvas.width = w;
    workCanvas.height = h;
    workCtx.imageSmoothingEnabled = scale < 1;
    workCtx.imageSmoothingQuality = 'medium';
    workCtx.drawImage(source, 0, 0, w, h);
    return workCanvas;
  }

  /**
   * Multi-scale live decode at arm's length:
   * full 1080p (capped 1280), 1.4× center (~71%), 2× center (50%).
   * Rotates the start index so one slow frame cannot starve a scale.
   */
  function decodeMultiScale(source, includeMulti, thorough) {
    var hit = decodeCanvas(drawFullFrame(source, 1280), includeMulti, thorough);
    if (hit) return hit;
    var sz = sourceSize(source);
    var side = Math.min(sz.w, sz.h) / 1.4;
    var out = Math.min(1024, Math.max(Math.round(side), 720));
    hit = decodeCanvas(
      drawCenterCrop(source, 1 / 1.4, out),
      includeMulti,
      thorough,
    );
    if (hit) return hit;
    side = Math.min(sz.w, sz.h) / 2;
    out = Math.min(960, Math.max(Math.round(side), 640));
    return decodeCanvas(
      drawCenterCrop(source, 0.5, out),
      includeMulti,
      thorough,
    );
  }

  function decodeCrops(source, includeMulti) {
    return decodeMultiScale(source, includeMulti, true);
  }

  /** Live: one downscaled canvas (max 720px), no extra crops. */
  function decodeLiveOnce(source) {
    var canvas = drawFullFrame(source, 720);
    return decodeCanvas(canvas, true, false);
  }

  function tooSoon() {
    var now = Date.now();
    if (now - lastDecodeAt < MIN_INTERVAL_MS) return true;
    lastDecodeAt = now;
    return false;
  }

  /** Cheap 96px Laplacian variance — skip-heavy path, used only as a hint. */
  function updateBlurHint(source) {
    try {
      var sz = sourceSize(source);
      if (!sz.w || !sz.h) return;
      var n = 96;
      if (!blurCanvas) {
        blurCanvas = document.createElement('canvas');
        blurCtx = blurCanvas.getContext('2d', { willReadFrequently: true });
      }
      blurCanvas.width = n;
      blurCanvas.height = n;
      var side = Math.min(sz.w, sz.h) * 0.72;
      var sx = (sz.w - side) / 2;
      var sy = (sz.h - side) / 2;
      blurCtx.drawImage(source, sx, sy, side, side, 0, 0, n, n);
      var src = blurCtx.getImageData(0, 0, n, n).data;
      var gray = new Float32Array(n * n);
      var p = 0;
      for (p = 0; p < n * n; p++) {
        var i = p * 4;
        gray[p] = src[i] * 0.299 + src[i + 1] * 0.587 + src[i + 2] * 0.114;
      }
      var sum = 0;
      var sum2 = 0;
      var count = 0;
      var y;
      var x;
      for (y = 1; y < n - 1; y++) {
        for (x = 1; x < n - 1; x++) {
          var c = y * n + x;
          var lap =
            gray[c - n] + gray[c + n] + gray[c - 1] + gray[c + 1] - 4 * gray[c];
          sum += lap;
          sum2 += lap * lap;
          count += 1;
        }
      }
      if (!count) return;
      var mean = sum / count;
      var variance = sum2 / count - mean * mean;
      if (variance < 18) blurStreak += 1;
      else blurStreak = 0;
      lastBlurry = blurStreak >= 2;
    } catch (_) {}
  }

  function capsOf(track) {
    try {
      if (track && typeof track.getCapabilities === 'function') {
        return track.getCapabilities() || {};
      }
    } catch (_) {}
    return {};
  }

  function minZoom(caps) {
    if (!caps || caps.zoom == null) return null;
    if (typeof caps.zoom.min === 'number') return caps.zoom.min;
    if (typeof caps.zoom === 'number') return 1;
    return 1;
  }

  function applyContinuousFocus(track) {
    if (!track) return;
    try {
      if (typeof ImageCapture === 'function') {
        var ic = new ImageCapture(track);
        if (ic && typeof ic.setOptions === 'function') {
          ic.setOptions({ focusMode: 'continuous' }).catch(function () {});
        }
      }
    } catch (_) {}
  }

  function applyMedicineConstraints(track) {
    if (!track || !track.applyConstraints) return Promise.resolve();
    var caps = capsOf(track);
    var advanced = { focusMode: 'continuous' };
    var z = minZoom(caps);
    if (z != null) advanced.zoom = z;
    var size = {
      facingMode: { ideal: 'environment' },
      width: { ideal: 1920 },
      height: { ideal: 1080 },
    };
    var full = {
      facingMode: { ideal: 'environment' },
      width: { ideal: 1920 },
      height: { ideal: 1080 },
      focusMode: 'continuous',
      advanced: [advanced],
    };
    return track
      .applyConstraints(full)
      .catch(function () {
        return track.applyConstraints({
          facingMode: { ideal: 'environment' },
          width: { ideal: 1920 },
          height: { ideal: 1080 },
          advanced: [advanced],
        });
      })
      .catch(function () {
        return track.applyConstraints({ advanced: [{ focusMode: 'continuous' }] });
      })
      .catch(function () {
        return track.applyConstraints(size);
      })
      .catch(function () {
        return track.applyConstraints({
          width: { ideal: 1280 },
          height: { ideal: 720 },
        });
      })
      .catch(function () {})
      .then(function () {
        applyContinuousFocus(track);
      });
  }

  function boostAllVideos() {
    var nodes = document.querySelectorAll('video');
    var i;
    for (i = 0; i < nodes.length; i++) {
      var v = nodes[i];
      v.setAttribute('playsinline', 'true');
      v.setAttribute('webkit-playsinline', 'true');
      v.muted = true;
      var stream = v.srcObject;
      if (!stream || !stream.getVideoTracks) continue;
      var track = stream.getVideoTracks()[0];
      if (!track) continue;
      applyMedicineConstraints(track);
    }
  }

  global.__engelsizBoostCamera = function () {
    boostAllVideos();
    if (boostTimer1) clearTimeout(boostTimer1);
    if (boostTimer2) clearTimeout(boostTimer2);
    boostTimer1 = setTimeout(boostAllVideos, 500);
    boostTimer2 = setTimeout(boostAllVideos, 1600);
  };

  global.__engelsizIsPreviewBlurry = function () {
    return !!lastBlurry;
  };

  global.__engelsizTorchAvailable = function () {
    var track = liveTrack();
    var caps = capsOf(track);
    return !!(caps && caps.torch);
  };

  global.__engelsizTorchOn = function () {
    return torchOn;
  };

  global.__engelsizToggleTorch = function (on) {
    var track = liveTrack();
    if (!track || !track.applyConstraints) return false;
    var caps = capsOf(track);
    if (!caps.torch) return false;
    var next = typeof on === 'boolean' ? on : !torchOn;
    track
      .applyConstraints({ advanced: [{ torch: next }] })
      .then(function () {
        torchOn = next;
      })
      .catch(function () {
        track
          .applyConstraints({ torch: next })
          .then(function () {
            torchOn = next;
          })
          .catch(function () {});
      });
    return true;
  };

  global.__engelsizTapFocus = function (nx, ny) {
    var track = liveTrack();
    if (!track) return false;
    var x = Math.max(0, Math.min(1, Number(nx) || 0.5));
    var y = Math.max(0, Math.min(1, Number(ny) || 0.5));
    var poi = [{ x: x, y: y }];
    var caps = capsOf(track);
    var modes = caps.focusMode;
    var hasSingle =
      modes &&
      (modes.indexOf
        ? modes.indexOf('single-shot') >= 0
        : String(modes).indexOf('single-shot') >= 0);
    var hasPoi = !!caps.pointsOfInterest;
    if (focusRestoreTimer) clearTimeout(focusRestoreTimer);

    function restore() {
      applyMedicineConstraints(track);
    }

    var applied = false;
    if (hasSingle && track.applyConstraints) {
      var adv = { focusMode: 'single-shot' };
      if (hasPoi) adv.pointsOfInterest = poi;
      track.applyConstraints({ advanced: [adv] }).catch(function () {});
      applied = true;
    }
    try {
      if (typeof ImageCapture === 'function') {
        var ic = new ImageCapture(track);
        if (ic && typeof ic.setOptions === 'function') {
          var opts = { focusMode: 'single-shot' };
          if (hasPoi) opts.pointsOfInterest = poi;
          ic.setOptions(opts).catch(function () {});
          applied = true;
        }
      }
    } catch (_) {}
    if (applied) {
      focusRestoreTimer = setTimeout(restore, 900);
    }
    return applied;
  };

  global.__engelsizDecoderStatus = function () {
    if (zx()) return 'ready';
    if (html5Ctor()) return 'ready';
    if (typeof BarcodeDetector === 'function') return 'ready';
    return decoderStatus;
  };

  function formatHints(Z) {
    var hints = new Map();
    hints.set(Z.DecodeHintType.TRY_HARDER, true);
    hints.set(Z.DecodeHintType.CHARACTER_SET, 'ISO-8859-1');
    hints.set(Z.DecodeHintType.POSSIBLE_FORMATS, [
      Z.BarcodeFormat.DATA_MATRIX,
      Z.BarcodeFormat.QR_CODE,
      Z.BarcodeFormat.PDF_417,
      Z.BarcodeFormat.AZTEC,
      Z.BarcodeFormat.CODE_128,
      Z.BarcodeFormat.EAN_13,
      Z.BarcodeFormat.EAN_8,
      Z.BarcodeFormat.UPC_A,
      Z.BarcodeFormat.UPC_E,
    ]);
    return hints;
  }

  function ensureBrowserReader() {
    var Z = zx();
    if (!Z || !Z.BrowserMultiFormatReader) return null;
    if (!browserReader) {
      try {
        browserReader = new Z.BrowserMultiFormatReader(formatHints(Z), 180);
      } catch (_) {
        try {
          browserReader = new Z.BrowserMultiFormatReader(formatHints(Z));
        } catch (_2) {
          browserReader = null;
        }
      }
    }
    return browserReader;
  }

  function detectNative(video) {
    if (nativeDetectorFailed) return Promise.resolve(null);
    if (typeof BarcodeDetector !== 'function') {
      nativeDetectorFailed = true;
      return Promise.resolve(null);
    }
    if (!nativeDetector) {
      try {
        nativeDetector = new BarcodeDetector({
          formats: [
            'aztec',
            'code_128',
            'data_matrix',
            'ean_13',
            'ean_8',
            'pdf417',
            'qr_code',
            'upc_a',
            'upc_e',
          ],
        });
      } catch (_) {
        try {
          nativeDetector = new BarcodeDetector();
        } catch (_2) {
          nativeDetectorFailed = true;
          return Promise.resolve(null);
        }
      }
    }
    return nativeDetector
      .detect(video)
      .then(function (codes) {
        if (!codes || !codes.length) return null;
        var c = codes[0];
        var text = String(c.rawValue || '').trim();
        if (!text) return null;
        return {
          format: String(c.format || '')
            .toLowerCase()
            .replace(/-/g, '_'),
          text: text,
        };
      })
      .catch(function () {
        return null;
      });
  }

  function decodeOnceVideo(video) {
    var reader = ensureBrowserReader();
    if (!reader || typeof reader.decodeOnce !== 'function') {
      return Promise.resolve(null);
    }
    return reader
      .decodeOnce(video, false, false, false)
      .then(hitFromResult)
      .catch(function () {
        return null;
      });
  }

  function html5DecodeCanvas(canvas) {
    var Ctor = html5Ctor();
    if (!Ctor || !canvas) return Promise.resolve(null);
    return new Promise(function (resolve) {
      try {
        canvas.toBlob(function (blob) {
          if (!blob) return resolve(null);
          var file;
          try {
            file = new File([blob], 'frame.png', {
              type: blob.type || 'image/png',
            });
          } catch (_) {
            file = blob;
          }
          try {
            if (!html5Instance) {
              var el = document.getElementById('engelsiz-html5qr');
              if (!el) {
                el = document.createElement('div');
                el.id = 'engelsiz-html5qr';
                el.style.cssText =
                  'position:absolute;left:-9999px;width:1px;height:1px;overflow:hidden';
                document.body.appendChild(el);
              }
              html5Instance = new Ctor('engelsiz-html5qr', { verbose: false });
            }
            var run = html5Instance.scanFileV2
              ? html5Instance.scanFileV2(file, false)
              : html5Instance.scanFile(file, false);
            Promise.resolve(run)
              .then(function (res) {
                if (!res) return resolve(null);
                var text =
                  (typeof res === 'string'
                    ? res
                    : res.decodedText || res.text || '') || '';
                text = String(text).trim();
                if (!text) return resolve(null);
                var fmt = '';
                try {
                  fmt = String(
                    (res.result &&
                      res.result.format &&
                      res.result.format.formatName) ||
                      res.format ||
                      '',
                  ).toLowerCase();
                } catch (_) {}
                resolve({ format: fmt, text: text });
              })
              .catch(function () {
                resolve(null);
              });
          } catch (_) {
            resolve(null);
          }
        }, 'image/png');
      } catch (_) {
        resolve(null);
      }
    });
  }

  /** Live frame fallback (sync): throttled, one 720px ZXing pass. */
  global.__engelsizDecodeMedicineFrame = function () {
    var Z = zx();
    if (!Z) {
      ensureZxing(function () {});
    } else {
      markReady();
    }
    var video = liveVideo();
    if (!video) return null;
    if (tooSoon()) return null;
    updateBlurHint(video);
    return decodeLiveOnce(video);
  };

  global.__engelsizDecodeLiveFrame = global.__engelsizDecodeMedicineFrame;

  /**
   * Live decode ~6 fps. BarcodeDetector every tick; ZXing on one 720px
   * canvas after 2–3 native misses (or immediately if native is missing).
   * First hit returns; remaining decoders in this cycle are skipped.
   */
  global.__engelsizDecodeLiveFrameAsync = function () {
    if (liveDecodeBusy) return Promise.resolve(null);
    if (tooSoon()) return Promise.resolve(null);
    var video = liveVideo();
    if (!video) {
      ensureZxing(function () {});
      return Promise.resolve(null);
    }
    liveDecodeBusy = true;
    updateBlurHint(video);
    if (zx()) markReady();
    return detectNative(video)
      .then(function (hit) {
        if (hit && hit.text) {
          nativeMissStreak = 0;
          return hit;
        }
        nativeMissStreak += 1;
        if (!nativeDetectorFailed && nativeMissStreak < 3) return null;
        if (!zx()) {
          ensureZxing(function () {});
          return null;
        }
        return decodeLiveOnce(video);
      })
      .catch(function () {
        return null;
      })
      .then(function (hit) {
        liveDecodeBusy = false;
        if (hit && hit.text) nativeMissStreak = 0;
        return hit;
      });
  };

  global.__engelsizDecodeImageBlob = function (blob) {
    if (!blob) return Promise.resolve(null);
    function run(bmp) {
      var canvas = document.createElement('canvas');
      canvas.width = bmp.width;
      canvas.height = bmp.height;
      var ctx = canvas.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(bmp, 0, 0);
      var hit = decodeCanvas(canvas, true);
      if (hit) return hit;
      hit = decodeCrops(canvas, true);
      if (hit) return hit;
      return html5DecodeCanvas(canvas);
    }
    var ready = new Promise(function (resolve) {
      ensureZxing(resolve);
    });
    return ready
      .then(function () {
        if (typeof createImageBitmap === 'function') {
          return createImageBitmap(blob).then(run);
        }
        return new Promise(function (resolve, reject) {
          var url = URL.createObjectURL(blob);
          var img = new Image();
          img.onload = function () {
            try {
              resolve(run(img));
            } finally {
              URL.revokeObjectURL(url);
            }
          };
          img.onerror = function () {
            URL.revokeObjectURL(url);
            reject(new Error('image'));
          };
          img.src = url;
        });
      })
      .catch(function () {
        return null;
      });
  };

  ensureZxing(function () {
    markReady();
    try {
      console.log('[Engelsiz] ZXing 1D+2D decoder ready (BrowserMultiFormatReader + html5-qrcode fallback)');
    } catch (_) {}
  });
  setTimeout(function () {
    if (!zx()) markFailed();
  }, 4000);
})(window);
