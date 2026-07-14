/**
 * Encrypt plaintext password the same way DevEco/hvigor DecipherUtil.decryptPwd expects.
 * materialDir should be the parent of "material/" (project signing/ or ~/.ohos/config/...).
 */
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const COMPONENT = Buffer.from([
  49, 243, 9, 115, 214, 175, 91, 184, 211, 190, 177, 88, 101, 131, 192, 119,
]);

function readDirBytes(dir) {
  const files = fs.readdirSync(dir).filter((n) => n !== ".DS_Store");
  if (files.length !== 1) throw new Error("expected 1 file in " + dir);
  return fs.readFileSync(path.join(dir, files[0]));
}

function xor(a, b) {
  if (a.length !== b.length) throw new Error("xor length mismatch");
  const out = Buffer.alloc(a.length);
  for (let i = 0; i < a.length; i++) out[i] = a[i] ^ b[i];
  return out;
}

function getWorkKey(materialRoot) {
  const material = path.join(materialRoot, "material");
  const fd = path.join(material, "fd");
  const ac = path.join(material, "ac");
  const ce = path.join(material, "ce");
  const fdParts = fs
    .readdirSync(fd)
    .filter((n) => n !== ".DS_Store")
    .sort()
    .map((n) => readDirBytes(path.join(fd, n)));
  if (fdParts.length !== 3) throw new Error("fd must have 3 parts");
  const salt = readDirBytes(ac);
  const workMat = readDirBytes(ce);

  const components = fdParts.concat([COMPONENT]);
  let x = xor(components[0], components[1]);
  for (let i = 2; i < components.length; i++) x = xor(x, components[i]);
  const rootKey = crypto.pbkdf2Sync(x.toString(), salt, 10000, 16, "sha256");

  // decrypt work material with rootKey (same as DecipherUtil.decrypt)
  const r = workMat;
  const e = (r[0] << 24) | (r[1] << 16) | (r[2] << 8) | r[3];
  const i = r.length - 4 - e;
  const iv = r.slice(4, 4 + i);
  const tag = r.slice(r.length - 16);
  const data = r.slice(4 + i, r.length - 16);
  const decipher = crypto.createDecipheriv("aes-128-gcm", rootKey, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(data), decipher.final()]);
}

function encryptPwd(materialRoot, plain) {
  const key = getWorkKey(materialRoot);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-128-gcm", key, iv);
  const enc = Buffer.concat([cipher.update(Buffer.from(plain, "utf-8")), cipher.final()]);
  const tag = cipher.getAuthTag();
  // e = cipherLen + tagLen
  const e = enc.length + 16;
  const header = Buffer.alloc(4);
  header.writeUInt32BE(e >>> 0, 0);
  return Buffer.concat([header, iv, enc, tag]).toString("hex");
}

const materialRoot = process.argv[2];
const plain = process.argv[3];
if (!materialRoot || !plain) {
  console.error("usage: node _encrypt_pwd.js <materialParentDir> <plaintext>");
  process.exit(1);
}
const hex = encryptPwd(materialRoot, plain);
if (hex.length < 32 || hex.length % 2 !== 0) {
  console.error("bad hex length", hex.length);
  process.exit(1);
}
// verify roundtrip via same decrypt rules
function decryptPwd(materialRoot, hexStr) {
  const key = getWorkKey(materialRoot);
  const r = Buffer.from(hexStr, "hex");
  const e = r.readUInt32BE(0);
  const i = r.length - 4 - e;
  const iv = r.slice(4, 4 + i);
  const tag = r.slice(r.length - 16);
  const data = r.slice(4 + i, r.length - 16);
  const decipher = crypto.createDecipheriv("aes-128-gcm", key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(data), decipher.final()]).toString("utf-8");
}
const back = decryptPwd(materialRoot, hex);
if (back !== plain) {
  console.error("roundtrip failed", back);
  process.exit(1);
}
process.stdout.write(hex);
