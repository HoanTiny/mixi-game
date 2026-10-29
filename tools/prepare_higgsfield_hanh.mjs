// Normalize the approved neutral mesh BEFORE auto-rigging. Tripo's align_image
// output faces +X; Meshy's walking rig and this game require a +Z facing figure.
import {NodeIO} from '../build/asset-tools/node_modules/@gltf-transform/core/dist/index.js';
const io=new NodeIO(), doc=await io.read('art/higgsfield/source-3d/hanh-static.glb');
const root=doc.getRoot(), nodes=root.listNodes();
if(nodes.length!==1 || root.listSkins().length)throw Error('Expected one unrigged mesh');
const node=nodes[0];
if(node.getTranslation().some(v=>Math.abs(v)>1e-5)||node.getScale().some(v=>Math.abs(v-1)>1e-5))throw Error('Inspect unexpected scale/translation first');
// align_image added a presentation yaw; remove it before applying the game axis.
node.setRotation([0,0,0,1]);
const primitives=node.getMesh().listPrimitives(), accessors=[...new Set(primitives.map(p=>p.getAttribute('POSITION')))];
const min=[Infinity,Infinity,Infinity],max=[-Infinity,-Infinity,-Infinity];
for(const acc of accessors){const a=acc.getArray();for(let i=0;i<a.length;i++){min[i%3]=Math.min(min[i%3],a[i]);max[i%3]=Math.max(max[i%3],a[i]);}}
const scale=1.58/(max[1]-min[1]), center=[(min[0]+max[0])/2,min[1],(min[2]+max[2])/2];
for(const acc of accessors){const a=acc.getArray().slice();for(let i=0;i<a.length;i+=3){const x=(a[i]-center[0])*scale,z=(a[i+2]-center[2])*scale;a[i]=-z;a[i+1]=(a[i+1]-center[1])*scale;a[i+2]=x;}acc.setArray(a);}
for(const semantic of ['NORMAL','TANGENT'])for(const acc of new Set(primitives.map(p=>p.getAttribute(semantic)).filter(Boolean))){const a=acc.getArray().slice(),stride=acc.getElementSize();for(let i=0;i<a.length;i+=stride){const x=a[i],z=a[i+2];a[i]=-z;a[i+2]=x;}acc.setArray(a);}
node.setName('Hanh_Neutral_FrontZ');node.setExtras({height_m:1.58,forward:'+Z',source:'Original Higgsfield concept / Tripo H3.1',purpose:'Normalized input to Meshy rigging'});
await io.write('art/higgsfield/source-3d/hanh-neutral-front.glb',doc);
console.log(JSON.stringify({height_m:1.58,forward:'+Z',scale}));
