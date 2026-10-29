// Prepare an existing gh-pages tree with a newly exported Godot 4.7.2 Web PCK.
// Preserve engine files and the previous Windows download; publish separately.
import { readFile, writeFile, copyFile, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve, join } from 'node:path';
import assert from 'node:assert/strict';

const [siteArg, packArg, revision, version = '1.11', windowsVersion = '1.6'] = process.argv.slice(2);
assert(siteArg && packArg && /^[a-f0-9]{40}$/.test(revision ?? ''),
  'Usage: node tools/prepare_web_release.mjs SITE_DIR WEB_PCK SOURCE_SHA [VERSION] [WINDOWS_VERSION]');
assert(/^\d+\.\d+(?:\.\d+)?$/.test(version) && /^\d+\.\d+(?:\.\d+)?$/.test(windowsVersion), 'Invalid release version');
const site = resolve(siteArg);
const pack = await readFile(resolve(packArg));
assert(pack.subarray(0, 4).toString() === 'GDPC', 'Not a Godot resource pack');
assert(pack.readUInt32LE(8) === 4 && pack.readUInt32LE(12) === 7 && pack.readUInt32LE(16) === 2,
  'The deployed Web engine requires a Godot 4.7.2 pack');
assert(pack.length < 100 * 1024 * 1024, 'Pack exceeds GitHub single-file limit');
const hash = createHash('sha256').update(pack).digest('hex');
const packName = `index-${hash.slice(0, 12)}.pck`;
const wasmSize = (await stat(join(site, 'index.wasm'))).size;
const config = { args: [], canvasResizePolicy: 2, emscriptenPoolSize: 8,
  ensureCrossOriginIsolationHeaders: true, executable: 'index', experimentalVK: false,
  mainPack: packName, fileSizes: { [packName]: pack.length, 'index.wasm': wasmSize },
  focusCanvas: true, gdextensionLibs: [], godotPoolSize: 4 };
let shell = await readFile(new URL('../web/shell.html', import.meta.url), 'utf8');
assert(shell.includes('__GODOT_CONFIG__') && shell.includes('__BUILD_REVISION__'));
shell = shell.replace('__GODOT_CONFIG__', JSON.stringify(config)).replace('__BUILD_REVISION__', revision);
await copyFile(resolve(packArg), join(site, packName));
await writeFile(join(site, 'index.html'), shell);
await writeFile(join(site, 'version.json'), JSON.stringify({ version, revision,
  engine: '4.7.2', pack: packName, bytes: pack.length, sha256: hash,
  builtAt: new Date().toISOString(), preview: '?neighborhood-demo', windowsDownload: windowsVersion }, null, 2) + '\n');
console.log(JSON.stringify({ revision, pack: packName, bytes: pack.length, sha256: hash }));
