#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import https from "node:https";
import os from "node:os";

const keyId = process.env.ASC_KEY_ID || "N89CARWD2R";
const issuerId = process.env.ASC_ISSUER_ID || "69a6de77-108b-47e3-e053-5b8c7c11a4d1";
const keyPath = process.env.ASC_KEY_PATH || `${os.homedir()}/.env/ashcode/apple/AuthKey_${keyId}.p8`;
const bundleId = process.env.ASC_BUNDLE_ID || "party.bandmusicgames.app";
const buildNumber = process.env.ASC_BUILD_NUMBER || process.argv[2];
const waitSeconds = Number(process.env.ASC_WAIT_SECONDS || 900);
const pollSeconds = Number(process.env.ASC_POLL_SECONDS || 30);
const setExportCompliance = process.env.ASC_SET_EXPORT_COMPLIANCE !== "0";

if (!buildNumber) {
  console.error("Missing build number. Pass it as argv[2] or ASC_BUILD_NUMBER.");
  process.exit(2);
}

if (!fs.existsSync(keyPath)) {
  console.error(`Missing App Store Connect key: ${keyPath}`);
  process.exit(2);
}

function base64url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function token() {
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }));
  const payload = base64url(JSON.stringify({
    iss: issuerId,
    exp: Math.floor(Date.now() / 1000) + 20 * 60,
    aud: "appstoreconnect-v1",
  }));
  const data = `${header}.${payload}`;
  const signature = crypto.sign("sha256", Buffer.from(data), {
    key: fs.readFileSync(keyPath, "utf8"),
    dsaEncoding: "ieee-p1363",
  });
  return `${data}.${base64url(signature)}`;
}

function request(method, path, body) {
  const payload = body ? JSON.stringify(body) : undefined;
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: "api.appstoreconnect.apple.com",
      method,
      path,
      headers: {
        Authorization: `Bearer ${token()}`,
        "Content-Type": "application/json",
        ...(payload ? { "Content-Length": Buffer.byteLength(payload) } : {}),
      },
    }, (res) => {
      let raw = "";
      res.setEncoding("utf8");
      res.on("data", chunk => { raw += chunk; });
      res.on("end", () => {
        let parsed = null;
        try {
          parsed = raw ? JSON.parse(raw) : null;
        } catch {
          parsed = raw;
        }
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(parsed);
        } else {
          reject(new Error(`${method} ${path} -> ${res.statusCode}: ${raw}`));
        }
      });
    });
    req.on("error", reject);
    if (payload) req.write(payload);
    req.end();
  });
}

const sleep = seconds => new Promise(resolve => setTimeout(resolve, seconds * 1000));
const enc = encodeURIComponent;

async function findApp() {
  const appResponse = await request("GET", `/v1/apps?filter%5BbundleId%5D=${enc(bundleId)}&limit=1`);
  const app = appResponse.data?.[0];
  if (!app) {
    throw new Error(`No App Store Connect app found for ${bundleId}`);
  }
  return app;
}

async function findBuild(appId) {
  return request(
    "GET",
    `/v1/builds?filter%5Bapp%5D=${enc(appId)}&filter%5Bversion%5D=${enc(buildNumber)}&include=buildBetaDetail&limit=1`
  );
}

function summarize(appId, response, patchedEncryption) {
  const build = response.data?.[0];
  const detail = response.included?.find(item => item.type === "buildBetaDetails");
  if (!build) {
    return { found: false, appId, buildNumber };
  }
  return {
    found: true,
    patchedEncryption,
    appId,
    buildId: build.id,
    buildNumber,
    processingState: build.attributes?.processingState,
    uploadedDate: build.attributes?.uploadedDate,
    usesNonExemptEncryption: build.attributes?.usesNonExemptEncryption,
    internalBuildState: detail?.attributes?.internalBuildState,
    externalBuildState: detail?.attributes?.externalBuildState,
  };
}

async function maybePatchExportCompliance(response) {
  const build = response.data?.[0];
  if (!build || !setExportCompliance) return false;

  const detail = response.included?.find(item => item.type === "buildBetaDetails");
  const missingCompliance = detail?.attributes?.internalBuildState === "MISSING_EXPORT_COMPLIANCE";
  const unsetEncryption = build.attributes?.usesNonExemptEncryption == null;
  if (!missingCompliance && !unsetEncryption) return false;

  await request("PATCH", `/v1/builds/${build.id}`, {
    data: {
      type: "builds",
      id: build.id,
      attributes: { usesNonExemptEncryption: false },
    },
  });
  return true;
}

const app = await findApp();
let patchedEncryption = false;
const deadline = Date.now() + waitSeconds * 1000;

while (true) {
  const response = await findBuild(app.id);
  patchedEncryption = await maybePatchExportCompliance(response) || patchedEncryption;
  const refreshed = patchedEncryption ? await findBuild(app.id) : response;
  const summary = summarize(app.id, refreshed, patchedEncryption);

  console.log(JSON.stringify(summary, null, 2));

  if (summary.found
      && summary.processingState === "VALID"
      && summary.internalBuildState !== "PROCESSING"
      && summary.internalBuildState !== "MISSING_EXPORT_COMPLIANCE") {
    process.exit(0);
  }

  if (Date.now() >= deadline) {
    process.exit(summary.found ? 3 : 2);
  }

  console.error(`Waiting ${pollSeconds}s for TestFlight readiness...`);
  await sleep(pollSeconds);
}
