// Copyright (c) 2021 <dev@brigid.jp>
// This software is released under the MIT License.
// https://opensource.org/licenses/mit-license.php

addEventListener("DOMContentLoaded", () => {
  let params = new URLSearchParams(document.location.search.substring(1))
  let key = params.get("key")
  let socket

  document.getElementById("key").textContent = key

  document.getElementById("open").onclick = () => {
    if (socket) {
      log("[error] already opened")
      return
    }

    socket = new WebSocket("wss://nozomi.dromozoa.com/recorder-socket/control/" + key)
    socket.binaryType = "blob"

    socket.onopen = () => {
      log("onopen")
    }

    socket.onclose = () => {
      log("onclose")
      socket = undefined
    }

    socket.onerror = (ev) => {
      log("onerror", ev)
    }

    socket.onmessage = (ev) => {
      log("onmessage", typeof ev.data)
        if (typeof ev.data === "string") {
          log("ontext", ev.data)
          let data = JSON.parse(ev.data)
          log("onjson", data)

          if (data.command === "status") {
          } else if (data.command === "capture") {
          } else if (data.command === "start") {
          } else if (data.command === "stop") {
          }
        } else {
          log("onbinary", ev.data.size)
        }
    }
  }

  document.getElementById("close").onclick = () => {
    if (!socket) {
      log("[error] socket not opened")
      return
    }
    socket.close()
  }

  document.getElementById("status").onclick = () => {
    if (!socket) {
      log("[error] socket not opened")
      return
    }
    socket.send(JSON.stringify({ command: "status" }))
  }

  document.getElementById("capture").onclick = () => {
    if (!socket) {
      log("[error] socket not opened")
      return
    }
    socket.send(JSON.stringify({ command: "capture" }))
  }

  document.getElementById("start").onclick = () => {
    if (!socket) {
      log("[error] socket not opened")
      return
    }
    socket.send(JSON.stringify({ command: "start" }))
  }

  document.getElementById("stop").onclick = () => {
    if (!socket) {
      log("[error] socket not opened")
      return
    }
    socket.send(JSON.stringify({ command: "stop" }))
  }
})
