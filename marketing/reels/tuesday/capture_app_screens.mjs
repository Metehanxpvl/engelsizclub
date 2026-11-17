import puppeteer from "/tmp/reel-tools/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";
import {mkdir} from "node:fs/promises";

const outputDir = new URL("./assets/", import.meta.url).pathname;
await mkdir(outputDir, {recursive: true});

const browser = await puppeteer.launch({
  executablePath: "/usr/local/bin/google-chrome",
  headless: true,
  args: [
    "--no-sandbox",
    "--disable-setuid-sandbox",
    "--lang=tr-TR",
    "--disable-features=Translate,TranslateUI",
    "--hide-scrollbars",
  ],
});

const page = await browser.newPage();
await page.setViewport({
  width: 430,
  height: 932,
  deviceScaleFactor: 3,
  isMobile: true,
  hasTouch: true,
});
await page.setExtraHTTPHeaders({
  "Accept-Language": "tr-TR,tr;q=0.9",
});
await page.evaluateOnNewDocument(() => {
  localStorage.setItem("flutter.app_ui_lang_v1", "tr");
  localStorage.setItem("app_ui_lang_v1", "tr");
  localStorage.setItem("flutter.tibbi_hosgeldin_kabul_v1", "true");
  localStorage.setItem("tibbi_hosgeldin_kabul_v1", "true");
  localStorage.setItem("flutter.nav_feature_tour_v2", "true");
  localStorage.setItem("flutter.info_dismiss_home_disclaimer_v1", "true");
  localStorage.setItem("flutter.info_dismiss_pubmed_v1", "true");
  localStorage.setItem("flutter.info_dismiss_library_v1", "true");
  Object.defineProperty(navigator, "language", {get: () => "tr-TR"});
  Object.defineProperty(navigator, "languages", {get: () => ["tr-TR", "tr"]});
});

await page.goto("https://engelsizclub.com", {
  waitUntil: "networkidle2",
  timeout: 90000,
});
await new Promise((resolve) => setTimeout(resolve, 12000));

// First visit: continue as guest.
await page.touchscreen.tap(215, 884);
await new Promise((resolve) => setTimeout(resolve, 7000));

async function shot(name) {
  await page.screenshot({
    path: `${outputDir}${name}`,
    type: "png",
    fullPage: false,
    captureBeyondViewport: false,
  });
  console.log(`captured ${name}`);
}

async function scroll(deltaY) {
  await page.mouse.move(220, 500);
  await page.mouse.wheel({deltaY});
  await new Promise((resolve) => setTimeout(resolve, 1600));
}

await shot("01-home-top.png");
await scroll(520);
await shot("02-home-search-news.png");
await scroll(650);
await shot("03-library-top.png");
await scroll(650);
await shot("04-library-more.png");

await browser.close();
