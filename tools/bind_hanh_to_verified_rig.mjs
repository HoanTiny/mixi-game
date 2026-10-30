// Rebind the normalized original Hanh mesh to this project's verified An rig.
// No network dependency: pose-fit arms before transferring four skin weights.
// Keep the rejected automatic rig in art/ for provenance, never ship it.
import {NodeIO} from '../build/asset-tools/node_modules/@gltf-transform/core/dist/index.js';
import {copyToDocument,prune,dedup,unpartition,weld,resample,textureCompress} from '../build/asset-tools/node_modules/@gltf-transform/functions/dist/index.js';
import sharp from '../build/asset-tools/node_modules/sharp/dist/index.mjs';
import {writeFile} from 'node:fs/promises';
const mul=(a,b)=>{const c=new Array(16).fill(0);for(let r=0;r<4;r++)for(let k=0;k<4;k++)for(let col=0;col<4;col++)c[col*4+r]+=a[k*4+r]*b[col*4+k];return c;};
function inverse(a){const rows=Array.from({length:4},(_,r)=>[...Array.from({length:4},(_,c)=>a[c*4+r]),...Array.from({length:4},(_,c)=>r===c?1:0)]);for(let c=0;c<4;c++){let pivot=c;for(let r=c+1;r<4;r++)if(Math.abs(rows[r][c])>Math.abs(rows[pivot][c]))pivot=r;[rows[c],rows[pivot]]=[rows[pivot],rows[c]];const v=rows[c][c];if(Math.abs(v)<1e-10)throw Error('Singular transform');rows[c]=rows[c].map(x=>x/v);for(let r=0;r<4;r++)if(r!==c){const f=rows[r][c];rows[r]=rows[r].map((x,k)=>x-f*rows[c][k]);}}return Array.from({length:16},(_,i)=>rows[i%4][4+Math.floor(i/4)]);}
const point=(m,p)=>[0,1,2].map(r=>m[r]*p[0]+m[4+r]*p[1]+m[8+r]*p[2]+m[12+r]);
const io=new NodeIO(),doc=await io.read('assets/characters/an/an-rigged.glb'),source=await io.read('art/higgsfield/source-3d/hanh-neutral-front.glb');
const root=doc.getRoot(),skin=root.listSkins()[0], joints=skin.listJoints(),meshNode=root.listNodes().find(n=>n.getSkin()===skin), oldMesh=meshNode.getMesh(),donor=oldMesh.listPrimitives()[0];
const oldWorld=joints.map(n=>n.getWorldMatrix());
for(const [name,angle] of [['LeftArm',.29],['RightArm',-.29]]){
 const n=joints.find(n=>n.getName()===name),g=n.getWorldMatrix(),c=Math.cos(angle),s=Math.sin(angle),r=[c,s,0,0,-s,c,0,0,0,0,1,0,0,0,0,1];
 const posed=mul(r,g);posed[12]=g[12];posed[13]=g[13];posed[14]=g[14];
 n.setMatrix(mul(inverse(n.getParentNode().getWorldMatrix()),posed));
}
const newWorld=joints.map(n=>n.getWorldMatrix()),deltas=newWorld.map((m,i)=>mul(m,inverse(oldWorld[i]))),bind=skin.getInverseBindMatrices(),bindArray=bind.getArray().slice();
for(let i=0;i<joints.length;i++)bindArray.set(mul(mul(inverse(newWorld[i]),oldWorld[i]),Array.from(bindArray.slice(i*16,i*16+16))),i*16);
bind.setArray(bindArray);
const dp=donor.getAttribute('POSITION').getArray(),dj=donor.getAttribute('JOINTS_0').getArray(),dw=donor.getAttribute('WEIGHTS_0').getArray();
const cell=.045,buckets=new Map(),posed=[];
const key=(x,y,z)=>`${x},${y},${z}`;
for(let i=0;i<dp.length/3;i++){
 const v=Array.from(dp.slice(i*3,i*3+3)),p=[0,0,0];
 for(let j=0;j<4;j++){const q=point(deltas[dj[i*4+j]],v);for(let k=0;k<3;k++)p[k]+=q[k]*dw[i*4+j];}
 posed.push(p);const bucket=key(...p.map(v=>Math.floor(v/cell)));if(!buckets.has(bucket))buckets.set(bucket,[]);buckets.get(bucket).push(i);
}
const original=source.getRoot().listMeshes()[0],map=copyToDocument(doc,source,[original]),replacement=map.get(original),height=1.7500001192092896,fit=height/1.58,hips=joints.findIndex(n=>n.getName()==='Hips');
let maxDistance=0,apronVertices=0;
for(const p of replacement.listPrimitives()){
 const positions=p.getAttribute('POSITION'),vertices=positions.getArray().slice();
 const weights=new Float32Array(vertices.length/3*4),indices=new Uint16Array(weights.length);
 for(let i=0;i<vertices.length/3;i++){
  const local=Array.from(vertices.slice(i*3,i*3+3)),v=local.map(x=>x*fit);vertices.set(v,i*3);
  const coords=v.map(x=>Math.floor(x/cell));let neighbors=[];
  for(let r=1;r<=5;r++){
   neighbors=[];for(let x=-r;x<=r;x++)for(let y=-r;y<=r;y++)for(let z=-r;z<=r;z++)for(const j of buckets.get(key(coords[0]+x,coords[1]+y,coords[2]+z))??[]){
    const d=posed[j];if(Math.abs(v[0])>.08&&Math.sign(d[0])!==Math.sign(v[0]))continue;
    neighbors.push([j,Math.hypot(...v.map((a,k)=>a-d[k]))]);
   }
   neighbors.sort((a,b)=>a[1]-b[1]);if(neighbors.length>=4&&neighbors[3][1]<(r-1)*cell)break;
  }
  if(!neighbors.length)throw Error('No donor influence');
  maxDistance=Math.max(maxDistance,neighbors[0][1]);const influence=new Map();
  for(const [j,distance] of neighbors.slice(0,4))for(let k=0;k<4;k++){const b=dj[j*4+k];influence.set(b,(influence.get(b)??0)+dw[j*4+k]/Math.max(distance*distance,1e-6));}
  // Keep the entire apron and upper-thigh envelope on the pelvis. A texture
  // colour mask would miss shadowed folds and split coincident UV-seam vertices.
  // The smooth transition lies below the hem; A-pose hands are outside this box.
  const blend=Math.max(0,Math.min(1,(local[1]-.55)/.07));
  const total=[...influence.values()].reduce((sum,w)=>sum+w,0);
  const armWeight=[...influence].reduce((sum,[bone,w])=>sum+(/Arm|Hand/.test(joints[bone].getName())?w/total:0),0);
  if(local[1]<1.0&&local[1]>.55&&Math.abs(local[0])<.235&&armWeight<.05){
    for(const [bone,w] of influence)influence.set(bone,w/total*(1-blend));
    influence.set(hips,(influence.get(hips)??0)+blend);apronVertices++;
  }
  const top=[...influence].sort((a,b)=>b[1]-a[1]).slice(0,4),sum=top.reduce((s,x)=>s+x[1],0);
  for(let k=0;k<top.length;k++){indices[i*4+k]=top[k][0];weights[i*4+k]=top[k][1]/sum;}
 }
 positions.setArray(vertices);
 p.setAttribute('JOINTS_0',doc.createAccessor('HanhJoints',root.listBuffers()[0]).setType('VEC4').setArray(indices));
 p.setAttribute('WEIGHTS_0',doc.createAccessor('HanhWeights',root.listBuffers()[0]).setType('VEC4').setArray(weights));
}
meshNode.setMesh(replacement).setName('HanhSkin');replacement.setName('HanhOriginalGeometry');
const rigRoot=meshNode.getParentNode();rigRoot.setScale(rigRoot.getScale().map(x=>x/fit));
for(const animation of root.listAnimations())animation.setName('Hanh_Walk');
oldMesh.dispose();
await doc.transform(prune(),dedup(),unpartition());
await io.write('art/higgsfield/source-3d/hanh-rebound.glb',doc);
await doc.transform(weld(),resample(),prune(),textureCompress({encoder:sharp,resize:[2048,2048]}));
await io.write('assets/characters/hanh/hanh.glb',doc);
const report={method:'pose-fitted transfer from project An rig',forward:'+Z',height_m:1.58,bones:joints.length,max_donor_distance_m:maxDistance,apron_vertices_pinned:apronVertices,source_mesh:'hanh-neutral-front.glb',rig_template:'assets/characters/an/an-rigged.glb',automatic_rig_rejected:'Side-facing Tripo input produced mismatched joints; replacement generation blocked by credit balance'};
await writeFile('art/higgsfield/source-3d/hanh-rebind.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
