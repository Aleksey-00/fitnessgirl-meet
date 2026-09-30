#!/usr/bin/env node
// Minimal SOCKS5 CONNECT tunnel for OpenSSH ProxyCommand. Usage: node _socks-proxy-cmd.js HOST PORT
const net = require('net')
const host = process.argv[2]
const port = Number(process.argv[3] || 22)
const proxyHost = process.env.FG_SOCKS_HOST || '127.0.0.1'
const proxyPort = Number(process.env.FG_SOCKS_PORT || 7890)

function fail(msg) {
  process.stderr.write(String(msg) + '\n')
  process.exit(1)
}

const socket = net.connect(proxyPort, proxyHost, () => {
  // greeting: ver=5, 1 method, no-auth
  socket.write(Buffer.from([0x05, 0x01, 0x00]))
})

let stage = 'greeting'
let buf = Buffer.alloc(0)

socket.on('data', (chunk) => {
  buf = Buffer.concat([buf, chunk])
  if (stage === 'greeting') {
    if (buf.length < 2) return
    if (buf[0] !== 0x05 || buf[1] !== 0x00) return fail('SOCKS auth rejected')
    buf = buf.subarray(2)
    stage = 'connect'
    const hostBuf = Buffer.from(host)
    const req = Buffer.alloc(7 + hostBuf.length)
    req[0] = 0x05
    req[1] = 0x01 // CONNECT
    req[2] = 0x00
    req[3] = 0x03 // domain
    req[4] = hostBuf.length
    hostBuf.copy(req, 5)
    req.writeUInt16BE(port, 5 + hostBuf.length)
    socket.write(req)
  } else if (stage === 'connect') {
    if (buf.length < 4) return
    if (buf[1] !== 0x00) return fail('SOCKS CONNECT failed code=' + buf[1])
    // skip bound addr
    let need = 4
    if (buf[3] === 0x01) need += 4 + 2
    else if (buf[3] === 0x03) {
      if (buf.length < 5) return
      need += 1 + buf[4] + 2
    } else if (buf[3] === 0x04) need += 16 + 2
    if (buf.length < need) return
    stage = 'pipe'
    buf = Buffer.alloc(0)
    process.stdin.pipe(socket)
    socket.pipe(process.stdout)
  }
})

socket.on('error', (e) => fail(e.message))
socket.on('close', () => process.exit(0))
process.stdin.on('error', () => {})
