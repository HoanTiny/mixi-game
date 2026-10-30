// Normalize Tripo's +X-facing mesh to +Z before humanoid auto-rigging.
const fs = require('fs');
const src = fs.readFileSync('assets/characters/an/an-tripo-v1.glb');
const jsonSize = src.readUInt32LE(12);
const gltf = JSON.parse(src.subarray(20, 20 + jsonSize).toString());
const bin = Buffer.from(src.subarray(28 + jsonSize));
for (const primitive of gltf.meshes.flatMap(m => m.primitives)) {
  for (const kind of ['POSITION', 'NORMAL']) {
    const accessor = gltf.accessors[primitive.attributes[kind]];
    const view = gltf.bufferViews[accessor.bufferView];
    const base = (view.byteOffset || 0) + (accessor.byteOffset || 0);
    const stride = view.byteStride || 12;
    const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
    for (let i = 0; i < accessor.count; i++) {
      const offset = base + i * stride;
      const x = bin.readFloatLE(offset), y = bin.readFloatLE(offset + 4), z = bin.readFloatLE(offset + 8);
      const v = kind === 'POSITION' ? [-z * 1.75, (y + 0.5) * 1.75, x * 1.75] : [-z, y, x];
      v.forEach((n, k) => { bin.writeFloatLE(n, offset + k * 4); min[k] = Math.min(min[k], n); max[k] = Math.max(max[k], n); });
    }
    accessor.min = min; accessor.max = max;
  }
}
const raw = Buffer.from(JSON.stringify(gltf));
const json = Buffer.alloc(Math.ceil(raw.length / 4) * 4, 32); raw.copy(json);
const out = Buffer.alloc(28 + json.length + bin.length);
out.write('glTF'); out.writeUInt32LE(2,4); out.writeUInt32LE(out.length,8);
out.writeUInt32LE(json.length,12); out.writeUInt32LE(0x4e4f534a,16); json.copy(out,20);
out.writeUInt32LE(bin.length,20+json.length); out.writeUInt32LE(0x004e4942,24+json.length); bin.copy(out,28+json.length);
fs.writeFileSync('assets/characters/an/an-rig-input.glb',out);
console.log('Normalized An: feet at zero, 1.75m, faces +Z');
