import assert from "node:assert/strict";
import { test } from "node:test";
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { mkdir, readFile } from "node:fs/promises";
import { extname, join } from "node:path";
import puppeteer from "puppeteer-core";

const ENTRY = "/index.html?v=10";
const AUTH_KEY = "sb-yjjdzugecimjwgwtkwyw-auth-token";
const CLOSET_KEY = "closetiq-closet-marker";
const EMAIL = "heather@example.com";

test("build check and pages do not register a service worker or sign out", () => {
  const index = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  const shop = readFileSync(new URL("../shop.html", import.meta.url), "utf8");
  const version = JSON.parse(readFileSync(new URL("../version.json", import.meta.url), "utf8"));
  assert.equal(index.includes("serviceWorker"), false);
  assert.equal(shop.includes("serviceWorker"), false);
  assert.equal(index.includes("localStorage.clear"), false);
  assert.equal(version.version, "11");
  assert.match(index, /window\.BUILD = "11"/);
  const check = index.slice(index.indexOf("async function checkBuild"), index.indexOf("checkBuild();"));
  assert.equal(check.includes("signOut"), false);
  assert.equal(check.includes("localStorage"), false);
  assert.match(check, /if \(!remote \|\| remote === String\(window\.BUILD\)\)/);
  assert.match(check, /params\.get\("v"\) === remote/);
  assert.match(check, /location\.replace/);
  const history = index.slice(index.indexOf("function applyHistoryState"), index.indexOf('window.addEventListener("popstate"'));
  assert.equal(history.includes("signOut"), false);
  assert.equal(history.includes("localStorage"), false);
  assert.match(shop, /index\.html\?v=/);
  assert.match(index, /signOut\(\{ scope: "local" \}\)/);
  assert.match(index, /resetPasswordForEmail/);
});

function startServer() {
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, "http://127.0.0.1");
    const file = url.pathname === "/" ? "/index.html" : url.pathname;
    try {
      const body = await readFile(join(process.cwd(), file));
      const type = { ".html": "text/html", ".js": "text/javascript", ".json": "application/json", ".png": "image/png" }[extname(file)] || "application/octet-stream";
      res.writeHead(200, { "content-type": type });
      res.end(body);
    } catch {
      res.writeHead(404);
      res.end("missing");
    }
  });
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(server)));
}

function corsHeaders() {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "*",
    "access-control-allow-methods": "GET,POST,PATCH,PUT,DELETE,OPTIONS",
    "content-type": "application/json",
  };
}

function installSupabaseBlock(page, hits, versionBody) {
  return page.setRequestInterception(true).then(() => {
    page.on("request", (req) => {
      const u = req.url();
      if (versionBody && u.includes("version.json")) {
        hits.push("VERSION " + versionBody);
        req.respond({ status: 200, contentType: "application/json", body: versionBody });
        return;
      }
      if (!u.includes("supabase.co")) {
        req.continue().catch(() => {});
        return;
      }
      const path = u.split("?")[0];
      hits.push(req.method() + " " + path);
      const headers = corsHeaders();
      if (req.method() === "OPTIONS") {
        req.respond({ status: 204, headers });
        return;
      }
      if (path.includes("/auth/v1/logout")) {
        hits.push("LOGOUT");
        req.respond({ status: 500, headers, body: JSON.stringify({ error: "logout blocked by test" }) });
        return;
      }
      if (path.includes("/recover")) {
        hits.push("RECOVER");
        req.respond({ status: 500, headers, body: JSON.stringify({ error: "recover blocked by test", msg: "recover blocked by test" }) });
        return;
      }
      if (path.endsWith("/me")) {
        req.respond({
          status: 200, headers,
          body: JSON.stringify({
            user_id: "user-1", email: EMAIL, daily_cap: 20, tz: "America/Chicago", used_today: 1,
            presets: { max_balanced_1k: { label: "Balanced 1K", credits: 2 } },
            actions: { bgremove: 1 },
          }),
        });
        return;
      }
      if (path.includes("/functions/v1/flux-vto")) {
        req.respond({ status: 200, headers, body: JSON.stringify({ ok: false, configured: false }) });
        return;
      }
      const accept = req.headers().accept || "";
      req.respond({ status: 200, headers, body: accept.includes("vnd.pgrst.object") ? "null" : "[]" });
    });
  });
}

function plantSession() {
  if (sessionStorage.getItem("closetiq-planted")) return;
  sessionStorage.setItem("closetiq-planted", "1");
  localStorage.setItem("sb-yjjdzugecimjwgwtkwyw-auth-token", JSON.stringify({
    access_token: "test-access-token",
    refresh_token: "test-refresh-token",
    token_type: "bearer",
    expires_in: 86400,
    expires_at: Math.floor(Date.now() / 1000) + 86400,
    user: { id: "user-1", email: "heather@example.com", aud: "authenticated", role: "authenticated" },
  }));
  localStorage.setItem("closetiq-closet-marker", "keep");
}

function inView(box, label) {
  assert.ok(box.height >= 44, label + " shorter than 44: " + JSON.stringify(box));
  assert.ok(box.top >= 0 && box.left >= 0, label + " off the top/left: " + JSON.stringify(box));
  assert.ok(box.bottom <= box.vh + 1 && box.right <= box.vw + 1, label + " outside the viewport: " + JSON.stringify(box));
  assert.notEqual(box.display, "none", label);
}

test("entry index.html?v=10 keeps a session, and logout is visible", async () => {
  const server = await startServer();
  const port = server.address().port;
  const browser = await puppeteer.launch({
    executablePath: "/usr/local/bin/google-chrome",
    headless: true,
    args: ["--no-sandbox", "--disable-dev-shm-usage"],
  });
  const shots = "/opt/cursor/artifacts";
  await mkdir(shots, { recursive: true });
  try {
    const signedOutHits = [];
    const signedOut = await browser.newPage();
    await signedOut.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
    await installSupabaseBlock(signedOut, signedOutHits);
    await signedOut.goto(`http://127.0.0.1:${port}${ENTRY}`, { waitUntil: "networkidle0" });
    await signedOut.waitForFunction(() => window.__studio && document.getElementById("forgotPw"));
    await new Promise((r) => setTimeout(r, 400));
    const signedOutState = await signedOut.evaluate(async () => ({
      url: location.pathname + location.search,
      login: getComputedStyle(document.getElementById("login")).display,
      account: getComputedStyle(document.getElementById("accountBtn")).display,
      hasSession: document.documentElement.classList.contains("has-session"),
      workers: navigator.serviceWorker ? (await navigator.serviceWorker.getRegistrations()).length : 0,
      build: String(window.BUILD),
      swSource: document.documentElement.innerHTML.includes("serviceWorker"),
    }));
    assert.equal(signedOutState.url, "/index.html?v=10");
    assert.notEqual(signedOutState.login, "none");
    assert.equal(signedOutState.account, "none");
    assert.equal(signedOutState.hasSession, false);
    assert.equal(signedOutState.workers, 0);
    assert.equal(signedOutState.swSource, false);
    assert.equal(signedOutState.build, "11");
    assert.equal(signedOutHits.some((h) => h === "LOGOUT" || h === "RECOVER"), false);
    const forgotBox = await signedOut.$eval("#forgotPw", (el) => {
      const r = el.getBoundingClientRect();
      return { top: r.top, bottom: r.bottom, left: r.left, right: r.right, height: r.height, display: getComputedStyle(el).display, vh: innerHeight, vw: innerWidth, text: el.textContent.trim() };
    });
    assert.equal(forgotBox.text, "Forgot password?");
    inView(forgotBox, "forgot password");
    await signedOut.screenshot({ path: join(shots, "auth-signed-out-mobile.png") });

    const forgot = await signedOut.evaluate(async (build) => {
      const calls = [];
      document.getElementById("forgotPw").click();
      const empty = document.getElementById("forgotMsg").textContent;
      document.getElementById("email").value = "heather@example.com";
      window.__studio.sb.auth.resetPasswordForEmail = async (email, opts) => {
        calls.push({ email, redirectTo: opts && opts.redirectTo, keys: Object.keys(opts || {}) });
        return { data: {}, error: null };
      };
      document.getElementById("forgotPw").click();
      await new Promise((r) => setTimeout(r, 30));
      const ok = document.getElementById("forgotMsg").textContent;
      window.__studio.sb.auth.resetPasswordForEmail = async () => ({ data: null, error: { message: "Error sending recovery email" } });
      document.getElementById("forgotPw").click();
      await new Promise((r) => setTimeout(r, 30));
      const bad = document.getElementById("forgotMsg").textContent;
      window.__studio.sb.auth.updateUser = async (body) => {
        calls.push({ update: body });
        return { data: { user: {} }, error: null };
      };
      window.__studio.showRecovery();
      document.getElementById("recoveryForm").noValidate = true;
      document.getElementById("recoveryPw").value = "short";
      document.getElementById("recoveryForm").requestSubmit();
      await new Promise((r) => setTimeout(r, 30));
      const shortMsg = document.getElementById("recoveryMsg").textContent;
      document.getElementById("recoveryPw").value = "test-password-1";
      document.getElementById("recoveryForm").requestSubmit();
      await new Promise((r) => setTimeout(r, 30));
      const updated = {
        msg: document.getElementById("recoveryMsg").textContent,
        open: !document.getElementById("recovery").classList.contains("hidden"),
        skip: document.getElementById("recoverySkip").textContent.trim(),
      };
      return { empty, ok, bad, calls, shortMsg, updated, build };
    }, "11");
    assert.match(forgot.empty, /Enter the account email/);
    assert.equal(forgot.ok, "If an account exists for that email, a reset link is on its way. Check your inbox.");
    assert.match(forgot.bad, /Could not send a reset email/);
    assert.equal(forgot.bad.includes("on its way"), false);
    assert.equal(forgot.calls[0].email, EMAIL);
    assert.equal(forgot.calls[0].redirectTo, `http://127.0.0.1:${port}/index.html?v=11`);
    assert.deepEqual(forgot.calls[0].keys, ["redirectTo"]);
    assert.match(forgot.shortMsg, /12\+ characters/);
    assert.equal(forgot.updated.msg, "Password updated.");
    assert.equal(forgot.updated.open, true);
    assert.equal(forgot.updated.skip, "Continue");
    assert.deepEqual(forgot.calls[1].update, { password: "test-password-1" });
    assert.equal(signedOutHits.some((h) => h === "LOGOUT" || h === "RECOVER"), false);
    await signedOut.close();

    const hits = [];
    const page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
    await page.evaluateOnNewDocument(plantSession);
    await page.evaluateOnNewDocument(() => {
      const real = window.matchMedia.bind(window);
      window.matchMedia = (q) => String(q).includes("display-mode: standalone")
        ? { matches: true, media: q, addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {}, dispatchEvent() { return false; } }
        : real(q);
      try { Object.defineProperty(navigator, "standalone", { configurable: true, get: () => true }); } catch {}
    });
    await installSupabaseBlock(page, hits);
    await page.goto(`http://127.0.0.1:${port}${ENTRY}`, { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => document.getElementById("accountEmail")?.textContent?.includes("heather@example.com"));
    await new Promise((r) => setTimeout(r, 400));
    const saved = await page.evaluate(async () => ({
      url: location.pathname + location.search,
      login: getComputedStyle(document.getElementById("login")).display,
      email: document.getElementById("accountEmail").textContent,
      label: document.getElementById("accountBtn").getAttribute("aria-label"),
      token: localStorage.getItem("sb-yjjdzugecimjwgwtkwyw-auth-token"),
      closet: localStorage.getItem("closetiq-closet-marker"),
      standalone: window.__standalone === true,
      workers: (await navigator.serviceWorker.getRegistrations()).length,
    }));
    assert.equal(saved.url, "/index.html?v=10");
    assert.equal(saved.login, "none");
    assert.equal(saved.email, EMAIL);
    assert.equal(saved.label, "Account, signed in as heather@example.com");
    assert.match(saved.token, /test-access-token/);
    assert.equal(saved.closet, "keep");
    assert.equal(saved.standalone, true);
    assert.equal(saved.workers, 0);
    assert.equal(hits.includes("LOGOUT"), false);
    const accountBox = await page.$eval("#accountBtn", (el) => {
      const r = el.getBoundingClientRect();
      return { top: r.top, bottom: r.bottom, left: r.left, right: r.right, height: r.height, display: getComputedStyle(el).display, vh: innerHeight, vw: innerWidth };
    });
    inView(accountBox, "account button");
    assert.ok(accountBox.top < 120, "account button should sit in the sticky header");
    await page.screenshot({ path: join(shots, "auth-account-mobile.png") });

    await page.evaluate(() => document.dispatchEvent(new Event("visibilitychange")));
    await page.evaluate(() => window.__studio.showTab("clothing"));
    assert.equal(await page.$eval(".tab.on", (el) => el.dataset.tab), "clothing");
    await page.goBack();
    assert.equal(await page.$eval(".tab.on", (el) => el.dataset.tab), "models");
    const afterBack = await page.evaluate(() => ({
      url: location.pathname + location.search,
      login: getComputedStyle(document.getElementById("login")).display,
      token: localStorage.getItem("sb-yjjdzugecimjwgwtkwyw-auth-token"),
      closet: localStorage.getItem("closetiq-closet-marker"),
    }));
    assert.equal(afterBack.url, "/index.html?v=10");
    assert.equal(afterBack.login, "none");
    assert.match(afterBack.token, /test-access-token/);
    assert.equal(afterBack.closet, "keep");
    assert.equal(hits.includes("LOGOUT"), false);

    await page.setViewport({ width: 1280, height: 800, deviceScaleFactor: 1 });
    const desktopBox = await page.$eval("#accountBtn", (el) => {
      const r = el.getBoundingClientRect();
      return { top: r.top, bottom: r.bottom, left: r.left, right: r.right, height: r.height, display: getComputedStyle(el).display, vh: innerHeight, vw: innerWidth, email: document.getElementById("accountEmail").textContent };
    });
    inView(desktopBox, "desktop account button");
    assert.equal(desktopBox.email, EMAIL);
    await page.screenshot({ path: join(shots, "auth-account-desktop.png") });

    await page.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
    await page.click("#accountBtn");
    await page.waitForSelector("#logout");
    const logoutBox = await page.$eval("#logout", (el) => {
      const r = el.getBoundingClientRect();
      return {
        text: el.textContent.trim(),
        top: r.top, bottom: r.bottom, left: r.left, right: r.right, height: r.height,
        display: getComputedStyle(el).display, vh: innerHeight, vw: innerWidth,
        count: document.querySelectorAll("#logout").length,
        sheetEmail: document.getElementById("accountSheetEmail").textContent,
      };
    });
    assert.equal(logoutBox.text, "Sign out");
    assert.equal(logoutBox.count, 1);
    assert.equal(logoutBox.sheetEmail, EMAIL);
    inView(logoutBox, "sign out");
    assert.ok(logoutBox.bottom < 844 * 0.72, "sign out should be in the top of the phone sheet: " + JSON.stringify(logoutBox));
    await page.screenshot({ path: join(shots, "auth-signout-mobile.png") });
    await page.goBack();
    await page.waitForFunction(() => !document.getElementById("sheet").classList.contains("open"));
    assert.equal(await page.evaluate(() => getComputedStyle(document.getElementById("login")).display), "none");
    assert.match(await page.evaluate(() => localStorage.getItem("sb-yjjdzugecimjwgwtkwyw-auth-token")), /test-access-token/);

    await page.click("#accountBtn");
    await page.waitForSelector("#logout");
    await page.evaluate(() => {
      window.__removed = [];
      window.__cleared = false;
      const origRemove = localStorage.removeItem.bind(localStorage);
      const origClear = localStorage.clear.bind(localStorage);
      localStorage.removeItem = (k) => { window.__removed.push(String(k)); return origRemove(k); };
      localStorage.clear = () => { window.__cleared = true; return origClear(); };
      window.__signOutCalls = [];
      window.__studio.sb.auth.signOut = async (opts) => {
        window.__signOutCalls.push(opts || null);
        return { error: { message: "Network unavailable" } };
      };
    });
    await page.click("#logout");
    await page.waitForFunction(() => document.getElementById("logoutMsg")?.textContent?.includes("still signed in"));
    const failed = await page.evaluate(() => ({
      msg: document.getElementById("logoutMsg").textContent,
      login: getComputedStyle(document.getElementById("login")).display,
      disabled: document.getElementById("logout").disabled,
      token: localStorage.getItem("sb-yjjdzugecimjwgwtkwyw-auth-token"),
      closet: localStorage.getItem("closetiq-closet-marker"),
      cleared: window.__cleared,
      calls: window.__signOutCalls,
    }));
    assert.match(failed.msg, /Network unavailable/);
    assert.match(failed.msg, /still signed in/);
    assert.equal(failed.login, "none");
    assert.equal(failed.disabled, false);
    assert.match(failed.token, /test-access-token/);
    assert.equal(failed.closet, "keep");
    assert.equal(failed.cleared, false);
    assert.deepEqual(failed.calls, [{ scope: "local" }]);
    await page.screenshot({ path: join(shots, "auth-logout-error-mobile.png") });

    await page.evaluate(() => {
      window.__studio.sb.auth.signOut = async (opts) => {
        window.__signOutCalls.push(opts || null);
        localStorage.removeItem("sb-yjjdzugecimjwgwtkwyw-auth-token");
        return { error: null };
      };
    });
    await page.click("#logout");
    await page.waitForFunction(() => document.getElementById("loginMsg")?.textContent?.includes("Signed out on this browser"));
    const signedOutAfter = await page.evaluate(() => ({
      msg: document.getElementById("loginMsg").textContent,
      login: getComputedStyle(document.getElementById("login")).display,
      app: getComputedStyle(document.getElementById("app")).display,
      account: getComputedStyle(document.getElementById("accountBtn")).display,
      hasSession: document.documentElement.classList.contains("has-session"),
      token: localStorage.getItem("sb-yjjdzugecimjwgwtkwyw-auth-token"),
      closet: localStorage.getItem("closetiq-closet-marker"),
      cleared: window.__cleared,
      removed: window.__removed,
      calls: window.__signOutCalls,
    }));
    assert.equal(signedOutAfter.msg, "Signed out on this browser. Other devices stay signed in.");
    assert.notEqual(signedOutAfter.login, "none");
    assert.equal(signedOutAfter.app, "none");
    assert.equal(signedOutAfter.account, "none");
    assert.equal(signedOutAfter.hasSession, false);
    assert.equal(signedOutAfter.token, null);
    assert.equal(signedOutAfter.closet, "keep");
    assert.equal(signedOutAfter.cleared, false);
    assert.deepEqual(signedOutAfter.removed, [AUTH_KEY]);
    assert.equal(signedOutAfter.calls.length, 2);
    assert.deepEqual(signedOutAfter.calls[1], { scope: "local" });
    assert.equal(hits.includes("LOGOUT"), false);
    await page.screenshot({ path: join(shots, "auth-signed-out-after-logout.png") });
    await page.close();

    const bumpHits = [];
    const bump = await browser.newPage();
    await bump.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
    await bump.evaluateOnNewDocument(plantSession);
    await installSupabaseBlock(bump, bumpHits, JSON.stringify({ version: "99" }));
    await bump.goto(`http://127.0.0.1:${port}${ENTRY}`, { waitUntil: "domcontentloaded" });
    await bump.waitForFunction(() => new URLSearchParams(location.search).get("v") === "99");
    await new Promise((r) => setTimeout(r, 500));
    const bumped = await bump.evaluate(() => ({
      url: location.pathname + location.search,
      token: localStorage.getItem("sb-yjjdzugecimjwgwtkwyw-auth-token"),
      closet: localStorage.getItem("closetiq-closet-marker"),
      login: getComputedStyle(document.getElementById("login")).display,
    }));
    assert.equal(bumped.url, "/index.html?v=99");
    assert.match(bumped.token, /test-access-token/);
    assert.equal(bumped.closet, "keep");
    assert.equal(bumped.login, "none");
    assert.equal(bumpHits.includes("LOGOUT"), false);
    await bump.close();
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
});
