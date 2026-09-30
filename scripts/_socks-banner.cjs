const net = require("net");
const host = "134.0.113.50";
const port = 22;
const proxyPort = 7890;
const s = net.connect(proxyPort, "127.0.0.1", () => s.write(Buffer.from([5,1,0])));
let buf = Buffer.alloc(0), st = "g";
const t = Date.now();
s.setTimeout(15000);
s.on("timeout", () => { console.log("timeout at", st, "ms", Date.now()-t, "got", buf.toString("utf8")); process.exit(1); });
s.on("data", (c) => {
  buf = Buffer.concat([buf, c]);
  if (st === "g" && buf.length >= 2) {
    if (buf[1] !== 0) { console.log("auth fail", buf[1]); process.exit(1); }
    buf = Buffer.alloc(0); st = "c";
    const ip = host.split(".").map(Number);
    s.write(Buffer.from([5,1,0,1, ip[0],ip[1],ip[2],ip[3], (port>>8)&255, port&255]));
  } else if (st === "c" && buf.length >= 10) {
    console.log("connect reply", buf[1], "ms", Date.now()-t);
    if (buf[1] !== 0) process.exit(1);
    buf = Buffer.alloc(0); st = "banner";
    // wait for SSH banner
  } else if (st === "banner") {
    console.log("BANNER", JSON.stringify(buf.toString("utf8")), "ms", Date.now()-t);
    process.exit(0);
  }
});
s.on("error", e => { console.log("err", e.message); process.exit(1); });
