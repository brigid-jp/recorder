// Copyright (c) 2021 <dev@brigid.jp>
// This software is released under the MIT License.
// https://opensource.org/licenses/mit-license.php

addEventListener("DOMContentLoaded", () => {
  let socket

  let log = (...args) => {
    console.log(args)
  }

  document.getElementById("start").onclick = () => {
    log("start")

    socket = new WebSocket("wss://nozomi.dromozoa.com/recorder-socket")
    socket.binaryType = "blob"

    socket.onopen = () => {
      log("open")
    }

    socket.onclose = () => {
      log("close")
    }

    socket.onerror = (ev) => {
      log("error", ev, ev.message)
    }

    socket.onmessage = (ev) => {
      log("message", ev, ev.data)
    }
  }

  document.getElementById("stop").onclick = () => {
    log("stop")

    socket.close()
    socket = undefined
  }

  document.getElementById("send-text").onclick = () => {
    let data = document.getElementById("text").value
    log("send-text", data)
    socket.send(data)
  }

  document.getElementById("send-binary").onclick = () => {
    let data = new Blob([ document.getElementById("binary").value ])
    log("send-binary", data)
    socket.send(data)
  }
})
