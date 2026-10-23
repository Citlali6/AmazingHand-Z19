/* Browser CPU: visible acrylic-grid crossings; no generated lattice or robot commands. */
'use strict';
// User-confirmed board definition, 2026-10-23; not an inferred pixel scale.
const PRINTED_BOARD={width_mm:400,height_mm:300,minor_pitch_mm:20,major_pitch_mm:100,origin:'P1_top_left',scale_source:'user_confirmed_1_to_1',orientation_source:'user_confirmed_top_left_origin'};
function boardCoordinateText(point){
 const cm=!document.getElementById('coordinate-unit')||document.getElementById('coordinate-unit').value==='cm';
 return '('+(cm?point.X/10:point.X)+','+(cm?point.Y/10:point.Y)+') '+(cm?'cm':'mm');
}
function detectPhysicalGrid(rgba,width,height){
 const gray=new Float32Array(width*height),vertical=new Float32Array(width*height),horizontal=new Float32Array(width*height);
 for(let i=0;i<gray.length;i++)gray[i]=(rgba[4*i]*77+rgba[4*i+1]*150+rgba[4*i+2]*29)/256;
 for(let y=5;y<height-5;y++)for(let x=5;x<width-5;x++){
  const i=y*width+x;
  const smooth=(d)=>(gray[i+d-1]+2*gray[i+d]+gray[i+d+1])/4;
  vertical[i]=Math.max(0,(smooth(-4)+smooth(4))/2-smooth(0));
  const smoothY=(d)=>(gray[i+(d-1)*width]+2*gray[i+d*width]+gray[i+(d+1)*width])/4;
  horizontal[i]=Math.max(0,(smoothY(-4)+smoothY(4))/2-smoothY(0));
 }
 function families(scores,isVertical){
  const across=isVertical?width:height,along=isVertical?height:width;
  const at=(u,v)=>scores[isVertical?v*width+u:u*width+v];
  const ridges=[];
  for(let v=5;v<along-5;v+=2)for(let u=5;u<across-5;u++){
   const value=at(u,v);
   if(value>=1.8&&value>=at(u-1,v)&&value>at(u+1,v))ridges.push([u,v,Math.min(value,10)]);
  }
  const pad=Math.ceil(along*.22)+2,bins=across+2*pad,candidates=[];
  for(let a=-20;a<=20;a++){
   const slope=a/100,acc=new Float32Array(bins);
   for(const [u,v,value] of ridges){const b=Math.round(u-slope*v)+pad;if(b>=0&&b<bins)acc[b]+=value;}
   for(let b=1;b<bins-1;b++)if(acc[b]>along*.55&&acc[b]>=acc[b-1]&&acc[b]>acc[b+1])candidates.push({b:b-pad,m:slope,score:acc[b]});
  }
  candidates.sort((a,b)=>b.score-a.score);
  const lines=[];
  for(const candidate of candidates){
   const middle=candidate.b+candidate.m*along/2;
   if(lines.some(l=>Math.abs(l.b+l.m*along/2-middle)<12))continue;
   let count=0,weight=0,sumV=0,sumU=0,sumVV=0,sumVU=0,energy=0;
   const blocks=new Set();
   for(let v=5;v<along-5;v+=2){
    const guess=candidate.b+candidate.m*v;let best=0,uBest=0;
    for(let u=Math.max(5,Math.round(guess)-4);u<=Math.min(across-6,Math.round(guess)+4);u++)if(at(u,v)>best){best=at(u,v);uBest=u;}
    if(best<1.8)continue;
    count++;energy+=best;blocks.add(Math.floor(v/along*12));
    const w=Math.min(best,10);weight+=w;sumV+=w*v;sumU+=w*uBest;sumVV+=w*v*v;sumVU+=w*v*uBest;
   }
   if(count<(along-10)/2*.55||blocks.size<8||energy/count<2.7)continue;
   const denominator=weight*sumVV-sumV*sumV;
   if(Math.abs(denominator)<1e-6)continue;
   const m=(weight*sumVU-sumV*sumU)/denominator,b=(sumU-m*sumV)/weight;
   if(Math.abs(m)>.25||lines.some(l=>Math.abs(l.b+l.m*along/2-b-m*along/2)<12))continue;
   lines.push({b,m,support:count,contrast:energy/count});
   if(lines.length>=24)break;
  }
  return lines.sort((a,b)=>a.b+a.m*along/2-b.b-b.m*along/2);
 }
 const columns=families(vertical,true),rows=families(horizontal,false),points=[];
 function visibleArm(scores,x,y,dx,dy){
  let count=0,total=0;
  // Local evidence must exist away from the other line's central crossing.
  for(const side of [-1,1])for(let distance=4;distance<=12;distance+=2){
   const px=Math.round(x+side*distance*dx),py=Math.round(y+side*distance*dy);
   if(px<5||py<5||px>=width-5||py>=height-5)continue;
   let best=0;
   for(let delta=-2;delta<=2;delta++){
    const sx=dx===1?px:Math.max(0,Math.min(width-1,px+delta));
    const sy=dx===1?Math.max(0,Math.min(height-1,py+delta)):py;
    best=Math.max(best,scores[sy*width+sx]);
   }
   total++;if(best>=1.8)count++;
  }
  return total>=6&&count/total>=.6;
 }
 for(const col of columns)for(const row of rows){
  const divisor=1-col.m*row.m;if(Math.abs(divisor)<.1)continue;
  let x=(col.b+col.m*row.b)/divisor,y=row.b+row.m*x;
  if(x<6||y<6||x>=width-6||y>=height-6)continue;
  // Snap the line-model crossing to a locally observed two-direction dark ridge.
  let strength=-Infinity,bestX=x,bestY=y;
  for(let py=Math.max(6,Math.round(y)-5);py<=Math.min(height-7,Math.round(y)+5);py++)
   for(let px=Math.max(6,Math.round(x)-5);px<=Math.min(width-7,Math.round(x)+5);px++){
    const index=py*width+px;
    const value=Math.min(12,vertical[index])*Math.min(12,horizontal[index])-.08*((px-x)**2+(py-y)**2);
    if(value>strength){strength=value;bestX=px;bestY=py;}
   }
  x=bestX;y=bestY;
  if(visibleArm(vertical,x,y,0,1)&&visibleArm(horizontal,x,y,1,0))points.push({x,y});
 }
 return {points,columns:columns.length,rows:rows.length,columnLines:columns,rowLines:rows,gray,vertical,horizontal};
}
function boardMarkerHints(gray,width,height,guides=null){
 // Partial circular markers establish grid phase only; never enter the metric fit.
 const stride=width+1,integral=new Float64Array(stride*(height+1));
 for(let y=0;y<height;y++){let row=0;for(let x=0;x<width;x++){row+=gray[y*width+x];integral[(y+1)*stride+x+1]=integral[y*stride+x+1]+row;}}
 const mask=new Uint8Array(gray.length),seen=new Uint8Array(gray.length),components=[];
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  const l=Math.max(0,x-9),r=Math.min(width,x+10),t=Math.max(0,y-9),b=Math.min(height,y+10);
  const mean=(integral[b*stride+r]-integral[t*stride+r]-integral[b*stride+l]+integral[t*stride+l])/((b-t)*(r-l));
  if(mean-gray[y*width+x]>12)mask[y*width+x]=1;
 }
 for(let index=0;index<mask.length;index++)if(mask[index]&&!seen[index]){
  const queue=[index];seen[index]=1;let sumX=0,sumY=0,minX=width,minY=height,maxX=0,maxY=0;
  for(let k=0;k<queue.length;k++){
   const i=queue[k],x=i%width,y=Math.floor(i/width);sumX+=x;sumY+=y;minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);
   for(const j of [x>0?i-1:-1,x<width-1?i+1:-1,y>0?i-width:-1,y<height-1?i+width:-1])if(j>=0&&mask[j]&&!seen[j]){seen[j]=1;queue.push(j);}
  }
  const w=maxX-minX+1,h=maxY-minY+1;
  if(queue.length>=9&&w>=4&&h>=4&&w<=25&&h<=25&&w/h>.4&&w/h<2.5)components.push({x:sumX/queue.length,y:sumY/queue.length,area:queue.length});
 }
 return [[0,0],[1,0],[1,1],[0,1]].map(([right,bottom])=>components.filter(p=>{
  if(!(right?p.x>width*.6:p.x<width*.4)||!(bottom?p.y>height*.65:p.y<height*.35))return false;
  const edge=guides?(right?guides.right:guides.left):null;
  return !edge||Math.abs(p.x-edge.b-edge.m*p.y)<guides.pitch*.15;
 }).sort((a,b)=>b.area-a.area)[0]||null);
}
function fitGridHomography(pairs,width,height){
 const ata=Array.from({length:8},()=>new Float64Array(8)),atb=new Float64Array(8);
 for(const p of pairs){
  const u=p.x/width,v=p.y/height,X=p.X/400,Y=p.Y/300;
  for(const [a,b] of [[[u,v,1,0,0,0,-X*u,-X*v],X],[[0,0,0,u,v,1,-Y*u,-Y*v],Y]])
   for(let i=0;i<8;i++){atb[i]+=a[i]*b;for(let j=0;j<8;j++)ata[i][j]+=a[i]*a[j];}
 }
 const matrix=ata.map((r,i)=>[...r,atb[i]]);
 for(let c=0;c<8;c++){
  let pivot=c;for(let r=c+1;r<8;r++)if(Math.abs(matrix[r][c])>Math.abs(matrix[pivot][c]))pivot=r;
  if(Math.abs(matrix[pivot][c])<1e-10)return null;
  [matrix[c],matrix[pivot]]=[matrix[pivot],matrix[c]];
  const divisor=matrix[c][c];for(let j=c;j<=8;j++)matrix[c][j]/=divisor;
  for(let r=0;r<8;r++)if(r!==c){const value=matrix[r][c];for(let j=c;j<=8;j++)matrix[r][j]-=value*matrix[c][j];}
 }
 return [...matrix.map(r=>r[8]),1];
}
function gridMm(matrix,x,y,width,height){
 const u=x/width,v=y/height,d=matrix[6]*u+matrix[7]*v+1;
 if(Math.abs(d)<1e-8)return null;
 return {X:400*(matrix[0]*u+matrix[1]*v+matrix[2])/d,Y:300*(matrix[3]*u+matrix[4]*v+matrix[5])/d};
}
function gridPixel(matrix,X,Y,width,height){
 const xx=X/400,yy=Y/300;
 const a=matrix[0]-xx*matrix[6],b=matrix[1]-xx*matrix[7],c=xx-matrix[2];
 const d=matrix[3]-yy*matrix[6],e=matrix[4]-yy*matrix[7],f=yy-matrix[5],det=a*e-b*d;
 return Math.abs(det)<1e-8?null:{x:width*(c*e-b*f)/det,y:height*(a*f-c*d)/det};
}
function calibratePrintedGrid(d,width,height){
 const position=l=>l.b+l.m*height/2;
 let cols=null,best=Infinity;
 for(let i=0;i<=d.columnLines.length-5;i++){
  const group=d.columnLines.slice(i,i+5),p=group.map(position),pitch=(p[4]-p[0])/4;
  const variation=Math.max(...p.slice(1).map((x,j)=>Math.abs((x-p[j])/pitch-1)));
  if(pitch>30&&p[4]-p[0]>width*.4&&variation<.18&&variation<best){cols=group;best=variation;}
 }
 if(!cols)return {valid:false,reason:'粗网格列与图纸不匹配'};
 const pitch=(position(cols[4])-position(cols[0]))/4;
 const hints=boardMarkerHints(d.gray,width,height,{left:cols[0],right:cols[4],pitch});
 if(hints.some(p=>!p))return {valid:false,reason:'未找到四角标记，暂不显示毫米'};
 const top=(hints[0].y+hints[1].y)/2,bottom=(hints[2].y+hints[3].y)/2;
 if(bottom-top<height*.4)return {valid:false,reason:'板面范围不足'};
 const rows=d.rowLines.map(line=>{
  const y=line.b+line.m*width/2,t=(y-top)/(bottom-top)*3,Y=Math.round(t)*100;
  return {line,Y,phaseError:Math.abs(t-Math.round(t))};
 }).filter(r=>r.Y>=0&&r.Y<=300&&r.phaseError<.15);
 const sample=(field,x,y)=>field[Math.round(y)*width+Math.round(x)]||0;
 function observe(x,y,radius,threshold,boundary){
  if(x<5||y<5||x>=width-5||y>=height-5)return null;
  let chosen=null,strength=-Infinity;
  for(let py=Math.max(5,Math.round(y)-radius);py<=Math.min(height-6,Math.round(y)+radius);py++)for(let px=Math.max(5,Math.round(x)-radius);px<=Math.min(width-6,Math.round(x)+radius);px++){
   const value=Math.min(12,sample(d.vertical,px,py))*Math.min(12,sample(d.horizontal,px,py))-.12*((px-x)**2+(py-y)**2);
   if(value>strength){strength=value;chosen={x:px,y:py};}
  }
  if(!chosen||sample(d.vertical,chosen.x,chosen.y)<threshold||sample(d.horizontal,chosen.x,chosen.y)<threshold)return null;
  for(const [field,dx,dy] of [[d.vertical,0,1],[d.horizontal,1,0]]){
   const sides=[];
   for(const side of [-1,1]){
    let count=0,n=0;
    for(let dist=4;dist<=10;dist+=2){
     const px=Math.round(chosen.x+side*dist*dx),py=Math.round(chosen.y+side*dist*dy);
     if(px<3||py<3||px>=width-3||py>=height-3)continue;
     let peak=0;for(let k=-1;k<=1;k++)peak=Math.max(peak,sample(field,px+(dy?k:0),py+(dx?k:0)));
     n++;if(peak>=threshold)count++;
    }
    sides.push(n>=3?count/n:0);
   }
   if(boundary?Math.max(...sides)<.75:(sides[0]+sides[1])/2<.65)return null;
  }
  return chosen;
 }
 const pairs=[];
 for(let c=0;c<5;c++)for(const row of rows){
  const col=cols[c],r=row.line,den=1-col.m*r.m,x=(col.b+col.m*r.b)/den,y=r.b+r.m*x;
  const observed=observe(x,y,4,1.8,c===0||c===4||row.Y===0||row.Y===300);
  if(observed)pairs.push({...observed,X:c*100,Y:row.Y});
 }
 if(pairs.length<10)return {valid:false,reason:'独立粗网格交点不足10个',count:pairs.length};
 // Separate five spatially spread check points; they never enter the fit.
 const desired=[[200,150],[0,100],[400,100],[0,300],[400,300]],checks=[],training=[...pairs];
 for(const [X,Y] of desired){
  let index=0;for(let i=1;i<training.length;i++)if(Math.hypot(training[i].X-X,training[i].Y-Y)<Math.hypot(training[index].X-X,training[index].Y-Y))index=i;
  checks.push(training.splice(index,1)[0]);
 }
 const matrix=fitGridHomography(training,width,height);
 if(!matrix)return {valid:false,reason:'拟合点布局退化，请调整板面'};
 const errors=checks.map(p=>{const m=gridMm(matrix,p.x,p.y,width,height);return m?Math.hypot(m.X-p.X,m.Y-p.Y):Infinity;});
 const mean=errors.reduce((a,b)=>a+b,0)/errors.length,maximum=Math.max(...errors);
 if(mean>3||maximum>6)return {valid:false,reason:'内部检查偏差过大',mean,maximum};
 const points=[];
 for(let Y=0;Y<=300;Y+=20)for(let X=0;X<=400;X+=20){
  const predicted=gridPixel(matrix,X,Y,width,height);if(!predicted)continue;
  const observed=observe(predicted.x,predicted.y,3,1.2,X===0||X===400||Y===0||Y===300);
  if(observed){const mm=gridMm(matrix,observed.x,observed.y,width,height);if(mm&&Math.hypot(mm.X-X,mm.Y-Y)<4)points.push({...observed,X,Y});}
 }
 const rms=Math.sqrt(errors.reduce((sum,e)=>sum+e*e,0)/errors.length);
 // Observed corner markers may be clipped: use them only for display/phase, never fitting.
 for(let i=0;i<4;i++){
  const [X,Y]=[[0,0],[400,0],[400,300],[0,300]][i],p=hints[i],predicted=gridPixel(matrix,X,Y,width,height);
  if(predicted&&Math.hypot(predicted.x-p.x,predicted.y-p.y)<6){
   const existing=points.findIndex(q=>q.X===X&&q.Y===Y);if(existing>=0)points.splice(existing,1);
   points.push({...p,X,Y,corner:'P'+(i+1)});
  }
 }
 return {valid:true,points,matrix,mean,rms,maximum,checks:checks.map((p,i)=>({...p,error_mm:errors[i]})),training:training.length};
}
let physicalGrid={points:[],columns:0,rows:0},gridSource=null;
let speechOfferBusy=false,lastSpeechOffer=0,announcedRequest=null;
function offerCoordinateSpeech(frame){
 const label=document.getElementById('coordinate-target'),registration=physicalGrid.registration;
 if(!label)return;
 const target=frame.target,request=frame.request;
 if(!registration||!registration.valid||!target||target.state!=='found'){
  label.textContent='板面目标中心：等待有效标定和目标';return;
 }
 const [x0,y0,x1,y1]=target.bbox;
 const mapped=gridMm(registration.matrix,(x0+x1)/2,(y0+y1)/2,frame.width,frame.height);
 if(!mapped||mapped.X<0||mapped.Y<0||mapped.X>400||mapped.Y>300){label.textContent='目标中心超出板面';return;}
 const name=['','红色','绿色','蓝色'][frame.color];
 label.textContent=name+'物品中心：横坐标 '+(mapped.X/10).toFixed(1)+' cm，纵坐标 '+(mapped.Y/10).toFixed(1)+' cm（PL包围框中心）';
 if(!request||request.source!=='voice'||speechOfferBusy||announcedRequest===request.request_id||performance.now()-lastSpeechOffer<240)return;
 lastSpeechOffer=performance.now();speechOfferBusy=true;
 fetch('/announce',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({
  request_id:request.request_id,frame:frame.frame,capture_sequence:frame.capture_sequence,
  matrix:registration.matrix,quality:{checks:registration.checks.length,mean_mm:registration.mean,max_mm:registration.maximum}
 })}).then(r=>r.ok?r.json():null).then(result=>{
  if(result&&(result.accepted||result.reason==='already_announced_or_queued'))announcedRequest=request.request_id;
 }).catch(()=>{}).finally(()=>{speechOfferBusy=false;});
}
function drawCoordinateGrids(){
 const source=document.getElementById('source');
 if(!source.naturalWidth||!source.naturalHeight)return;
 if(gridSource!==source){
  gridSource=source;
  const sample=document.createElement('canvas'),scale=Math.min(1,960/source.naturalWidth);
  sample.width=Math.round(source.naturalWidth*scale);sample.height=Math.round(source.naturalHeight*scale);
  const context=sample.getContext('2d',{willReadFrequently:true});context.drawImage(source,0,0,sample.width,sample.height);
  physicalGrid=detectPhysicalGrid(context.getImageData(0,0,sample.width,sample.height).data,sample.width,sample.height);
  physicalGrid.registration=calibratePrintedGrid(physicalGrid,sample.width,sample.height);
  if(physicalGrid.registration.valid)physicalGrid.points=physicalGrid.registration.points;
  physicalGrid.sampleDimensions=[sample.width,sample.height];
  physicalGrid.points=physicalGrid.points.map(p=>({...p,x:p.x/scale,y:p.y/scale}));
 }
 const enabled=document.getElementById('grid-on').checked;
 for(const id of ['source','pl']){
  const img=document.getElementById(id),canvas=document.getElementById(id+'-grid');
  canvas.width=img.naturalWidth;canvas.height=img.naturalHeight;
  if(!enabled||!canvas.width||!canvas.height)continue;
  if(Math.abs(canvas.width/canvas.height-source.naturalWidth/source.naturalHeight)>.01)continue;
  const ctx=canvas.getContext('2d'),font=Math.max(13,Math.round(source.naturalWidth/55));
  ctx.scale(canvas.width/source.naturalWidth,canvas.height/source.naturalHeight);
  ctx.font='600 '+font+'px monospace';ctx.textBaseline='top';
  const spacing=Number(document.getElementById('coordinate-density').value);
  for(const point of physicalGrid.points){
   const {x,y,X,Y}=point;
   const metric=physicalGrid.registration.valid;
   ctx.beginPath();ctx.arc(x,y,metric?2:3,0,Math.PI*2);ctx.fillStyle='#ffec70';ctx.fill();
   if(metric&&(X%spacing!==0||Y%spacing!==0))continue;
   const text=metric?(point.corner?point.corner+' ':'')+boardCoordinateText(point):'('+Math.round(x)+','+Math.round(y)+') px',tw=ctx.measureText(text).width;
   const tx=Math.max(0,Math.min(x+7,source.naturalWidth-tw-4)),ty=Math.max(0,Math.min(y+6,source.naturalHeight-font-4));
   ctx.fillStyle='rgba(8,18,30,.8)';ctx.fillRect(tx-1,ty-1,tw+3,font+3);
   ctx.fillStyle='#baffee';ctx.fillText(text,tx,ty);
  }
 }
 const c=physicalGrid.registration;
 document.getElementById('grid-readout').textContent=!enabled?'实体交点标注已隐藏':c.valid?
  '板面坐标 · 原点P1 (0,0) · 大格10 cm · '+physicalGrid.points.length+' 个可见交点 · 内部复核均值 '+c.mean.toFixed(2)+' / 最大 '+c.maximum.toFixed(2)+' mm':
  c.reason+' · 仅显示像素坐标';
}
if(typeof document!=='undefined')document.addEventListener('DOMContentLoaded',()=>{
 const layout=document.createElement('style');
 layout.textContent='@media(max-width:900px){main{flex-direction:column}section{width:100%}}';document.head.appendChild(layout);
 document.getElementById('grid-on').addEventListener('change',drawCoordinateGrids);
 const spacing=document.getElementById('grid-step');if(spacing)spacing.parentElement.style.display='none';
 document.getElementById('grid-on').parentElement.lastChild.textContent='显示实体网格交点坐标';
 const densityLabel=document.createElement('label');densityLabel.textContent='数字间隔 ';
 const density=document.createElement('select');density.id='coordinate-density';
 for(const [value,text] of [[100,'大格：10 cm'],[40,'4 cm'],[20,'小格：2 cm（全部）']]){const option=document.createElement('option');option.value=value;option.textContent=text;density.appendChild(option);}
 densityLabel.appendChild(density);document.getElementById('grid-controls').appendChild(densityLabel);
 density.addEventListener('change',drawCoordinateGrids);
 const units=document.createElement('label');units.textContent='单位 ';
 const unit=document.createElement('select');unit.id='coordinate-unit';
 for(const text of ['cm','mm']){const option=document.createElement('option');option.value=text;option.textContent=text;unit.appendChild(option);}
 units.appendChild(unit);document.getElementById('grid-controls').appendChild(units);unit.addEventListener('change',drawCoordinateGrids);
 const save=document.createElement('button');save.textContent='保存标定报告';
 save.addEventListener('click',()=>{
  const c=physicalGrid.registration;if(!c||!c.valid)return;
  const payload={schema:'visiongrasp.grid-preview/1',created_utc:new Date().toISOString(),source_frame:document.getElementById('source').src,
   coordinate_frame:'board_xy_mm',board_wh_mm:[400,300],pitch_mm:20,axes:'User-confirmed P1 top left; +X right, +Y down',geometry:PRINTED_BOARD,physical_scale_confirmation:'user_confirmed',independent_physical_accuracy_verified:false,motion_allowed:false,
   sample_wh_px:physicalGrid.sampleDimensions,homography_normalized:c.matrix,training_count:c.training,independent_checks:c.checks,mean_mm:c.mean,rms_mm:c.rms,max_mm:c.maximum,
   limitation:'Board dimensions and orientation confirmed by user. Internal check residuals are not an external measurement of total system accuracy; lens distortion is not corrected.'};
  const a=document.createElement('a'),url=URL.createObjectURL(new Blob([JSON.stringify(payload,null,2)],{type:'application/json'}));
  a.href=url;a.download='board-calibration-'+Date.now()+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 });document.getElementById('grid-controls').appendChild(save);
 const definition=document.createElement('p');definition.textContent='左上P1=(0,0)，X向右、Y向下；板面40×30 cm，每大格10 cm、每小格2 cm（用户确认）。黄色点是可见交点；鼠标可查看细格坐标。';document.getElementById('grid-controls').appendChild(definition);
 document.querySelectorAll('main section > p').forEach((label,index)=>{
  label.textContent=(index===0?'USB 摄像头原图':'PL 颜色处理图')+' · 板面交点坐标';
 });
 const explanation=document.querySelector('main + p small');
 if(explanation)explanation.textContent='颜色分割与目标框由 FPGA PL 计算；网格多点透视标定由浏览器计算，尺寸和原点采用用户确认值。内部复核未包含镜头畸变等全部误差。尚未驱动机械臂。';
 for(const id of ['source','pl'])document.getElementById(id+'-grid').addEventListener('pointermove',event=>{
  const canvas=event.currentTarget,rect=canvas.getBoundingClientRect();if(!rect.width||!rect.height)return;
  const source=document.getElementById('source');
  const x=(event.clientX-rect.left)*source.naturalWidth/rect.width,y=(event.clientY-rect.top)*source.naturalHeight/rect.height;
  let closest=null,distance=25*source.naturalWidth/rect.width;
  for(const point of physicalGrid.points){const d=Math.hypot(point.x-x,point.y-y);if(d<distance){closest=point;distance=d;}}
  if(closest)document.getElementById('grid-readout').textContent=physicalGrid.registration.valid?
   '板面交点 '+boardCoordinateText(closest)+' · 图像 ('+Math.round(closest.x)+', '+Math.round(closest.y)+') px':
   '实体交点 ('+Math.round(closest.x)+', '+Math.round(closest.y)+') px · 未通过毫米标定';
 });
 drawCoordinateGrids();
});
if(typeof module!=='undefined')module.exports={detectPhysicalGrid,boardMarkerHints,calibratePrintedGrid};
