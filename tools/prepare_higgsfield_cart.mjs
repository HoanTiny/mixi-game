// Reproducible, geometry-only cleanup of the approved generated cart.
// Original source and embedded photographs stay untouched in art/. No runtime decoder extension.
import {NodeIO} from '../build/asset-tools/node_modules/@gltf-transform/core/dist/index.js';
import {prune, dedup} from '../build/asset-tools/node_modules/@gltf-transform/functions/dist/index.js';
import {mkdir, writeFile} from 'node:fs/promises';
const io=new NodeIO();
const doc=await io.read('art/higgsfield/source-3d/street_food_cart-web.glb');
const root=doc.getRoot(), node=root.listNodes()[0], mesh=node.getMesh(), primitive=mesh.listPrimitives()[0];
if(root.listSkins().length || root.listNodes().length!==1 || mesh.listPrimitives().length!==1) throw Error('Inspect changed input before cleanup');
const positions=primitive.getAttribute('POSITION').getArray(), indices=primitive.getIndices().getArray();
const kept=[], removed={wheel:0,glass:0};
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const sub=(a,b)=>a.map((v,i)=>v-b[i]);
for(let i=0;i<indices.length;i+=3){
  const tri=Array.from(indices.slice(i,i+3));
  const vs=tri.map(j=>Array.from(positions.slice(j*3,j*3+3)));
  const c=[0,1,2].map(k=>vs.reduce((s,v)=>s+v[k],0)/3);
  const n=cross(sub(vs[1],vs[0]),sub(vs[2],vs[0]));
  const wheel=Math.abs(c[0])>.31 && Math.hypot(c[1]-.295,c[2]-.445)<.33;
  // Both sides of the hallucinated opaque glass slab are removed. Keep the metal frame.
  const glassFront=c[2]>.729 && c[2]<.756 && c[1]>.965 && c[1]<1.455 && Math.abs(c[0])<.153 && Math.abs(n[2])>Math.abs(n[0])+Math.abs(n[1]);
  const glassSide=c[0]>-.18 && c[0]<-.151 && c[1]>.965 && c[1]<1.448 && c[2]>.001 && c[2]<.727 && Math.abs(n[0])>Math.abs(n[1])+Math.abs(n[2]);
  if(wheel) removed.wheel++;
  else if(glassFront||glassSide) removed.glass++;
  else kept.push(...tri);
}
primitive.getIndices().setArray(new Uint32Array(kept));
node.setName('CartBody');mesh.setName('CartBody_PBR');
const buffer=root.listBuffers()[0];
const rubber=doc.createMaterial('WheelRubber').setBaseColorFactor([.075,.082,.076,1]).setRoughnessFactor(.92).setMetallicFactor(0);
const steel=doc.createMaterial('GalvanizedRimAndSpokes').setBaseColorFactor([.39,.40,.36,1]).setRoughnessFactor(.48).setMetallicFactor(.72);
const glass=doc.createMaterial('DisplayGlass').setBaseColorFactor([.67,.79,.75,.09]).setAlphaMode('BLEND').setDoubleSided(true).setRoughnessFactor(.12).setMetallicFactor(0);
class Geometry {
  p=[]; n=[];
  triangle(a,b,c,na,nb=na,nc=na){
    if(cross(sub(b,a),sub(c,a)).reduce((s,v,i)=>s+v*na[i],0)<0) [b,c,nb,nc]=[c,b,nc,nb];
    this.p.push(...a,...b,...c);this.n.push(...na,...nb,...nc);
  }
  quad(a,b,c,d,n){this.triangle(a,b,c,n);this.triangle(a,c,d,n);}
  torus(major,minor,segments=24,sides=6){
    const vertex=(i,j)=>{const u=i/segments*Math.PI*2,v=j/sides*Math.PI*2;return {p:[minor*Math.sin(v),(major+minor*Math.cos(v))*Math.cos(u),(major+minor*Math.cos(v))*Math.sin(u)],n:[Math.sin(v),Math.cos(v)*Math.cos(u),Math.cos(v)*Math.sin(u)]};};
    for(let i=0;i<segments;i++)for(let j=0;j<sides;j++){
      const a=vertex(i,j),b=vertex(i+1,j),c=vertex(i+1,j+1),d=vertex(i,j+1);
      this.triangle(a.p,b.p,c.p,a.n,b.n,c.n);this.triangle(a.p,c.p,d.p,a.n,c.n,d.n);
    }
  }
  rod(a,b,r,sides=6){
    const axis=sub(b,a),length=Math.hypot(...axis),w=axis.map(x=>x/length);
    let u=cross(w,Math.abs(w[0])>.9?[0,1,0]:[1,0,0]);const ul=Math.hypot(...u);u=u.map(x=>x/ul);const v=cross(w,u);
    for(let i=0;i<sides;i++){
      const n0=u.map((x,k)=>x*Math.cos(i/sides*Math.PI*2)+v[k]*Math.sin(i/sides*Math.PI*2));
      const n1=u.map((x,k)=>x*Math.cos((i+1)/sides*Math.PI*2)+v[k]*Math.sin((i+1)/sides*Math.PI*2));
      const p0=a.map((x,k)=>x+n0[k]*r),p1=a.map((x,k)=>x+n1[k]*r),p2=b.map((x,k)=>x+n1[k]*r),p3=b.map((x,k)=>x+n0[k]*r);
      this.triangle(p0,p1,p2,n0,n1,n1);this.triangle(p0,p2,p3,n0,n1,n0);
      this.triangle(a,p1,p0,w.map(x=>-x));this.triangle(b,p3,p2,w);
    }
  }
  primitive(name,mat){
    return doc.createPrimitive().setAttribute('POSITION',doc.createAccessor(name+'_positions',buffer).setType('VEC3').setArray(new Float32Array(this.p)))
      .setAttribute('NORMAL',doc.createAccessor(name+'_normals',buffer).setType('VEC3').setArray(new Float32Array(this.n))).setMaterial(mat);
  }
}
const tire=new Geometry();tire.torus(.266,.028);
const metal=new Geometry();metal.torus(.235,.009,24,6);metal.rod([-.047,0,0],[.047,0,0],.026,12);
for(let i=0;i<24;i++){const a=i/24*Math.PI*2;metal.rod([i%2?.022:-.022,0,0],[0,Math.cos(a)*.235,Math.sin(a)*.235],.0024,4);}
const wheels=doc.createMesh('SharedSpokedWheel').addPrimitive(tire.primitive('Tire',rubber)).addPrimitive(metal.primitive('Rim',steel));
const scene=root.listScenes()[0];
for(const [side,x] of [['Left',-.385],['Right',.385]]){
  scene.addChild(doc.createNode('Wheel'+side).setMesh(wheels).setTranslation([x,.295,.445]).setExtras({rotation_axis:'X',radius_m:.294}));
}
const panes=new Geometry();
panes.quad([-.148,.968,.741],[.148,.968,.741],[.148,1.452,.741],[-.148,1.452,.741],[0,0,1]);
panes.quad([-.165,.968,.007],[-.165,.968,.73],[-.165,1.45,.73],[-.165,1.45,.007],[-1,0,0]);
scene.addChild(doc.createNode('TransparentDisplay').setMesh(doc.createMesh('DisplayPanes').addPrimitive(panes.primitive('Panes',glass))));
node.setExtras({height_m:1.8,ground_y:0,source:'Higgsfield / Tripo H3.1',status:'runtime_pilot',moving_parts_separated:true,collider:'separate Godot box proxy'});
await doc.transform(prune(),dedup());
await mkdir('assets/higgsfield/street_food_cart',{recursive:true});
await io.write('assets/higgsfield/street_food_cart/cart.glb',doc);
const triangles=root.listMeshes().reduce((s,m)=>s+m.listPrimitives().reduce((n,p)=>n+(p.getIndices()?.getCount()??p.getAttribute('POSITION').getCount())/3,0),0);
const report={source:'art/higgsfield/source-3d/street_food_cart-web.glb',output:'assets/higgsfield/street_food_cart/cart.glb',removed_triangles:removed,unique_mesh_triangles:triangles,instanced_triangles:triangles+ (tire.p.length+metal.p.length)/9,wheel_radius_m:.294,wheel_axis:'X',height_m:1.8,textures_max_px:1024,limitations:['Static pot lid remains part of body','Glass uses alpha blend; no refraction in Compatibility renderer']};
await writeFile('assets/higgsfield/street_food_cart/asset.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
