const net=require("net");
const ip=[134,0,113,50];
function tryPort(port){
  return new Promise((resolve)=>{
    const s=net.connect(7890,"127.0.0.1",()=>s.write(Buffer.from([5,1,0])));
    let buf=Buffer.alloc(0), st="g"; const t=Date.now();
    s.setTimeout(12000);
    s.on("timeout",()=>{console.log("port",port,"timeout",st,"got",buf.slice(0,40).toString("hex")); s.destroy(); resolve();});
    s.on("error",e=>{console.log("port",port,"err",e.message); resolve();});
    s.on("data",c=>{
      buf=Buffer.concat([buf,c]);
      if(st==="g"&&buf.length>=2){ buf=Buffer.alloc(0); st="c"; s.write(Buffer.from([5,1,0,1,...ip,(port>>8)&255,port&255])); }
      else if(st==="c"&&buf.length>=10){ console.log("port",port,"connect",buf[1],"ms",Date.now()-t); if(buf[1]!==0){s.destroy();resolve();return;} buf=Buffer.alloc(0); st="b"; if(port===443){ /* send nothing, wait TLS */ } }
      else if(st==="b"){ console.log("port",port,"data",buf.slice(0,60).toString("utf8").replace(/\r?\n/g,"\\n"), "hex", buf.slice(0,20).toString("hex"), "ms", Date.now()-t); s.destroy(); resolve(); }
    });
  });
}
(async()=>{ await tryPort(443); await tryPort(80); await tryPort(22); })();
