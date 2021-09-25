addEventListener("DOMContentLoaded", () => {
  let socket

  let log = (...args) => {
    console.log(args)
  }

  document.getElementById("start").onclick = () => {
    log("start")

    socket = new WebSocket("wss://nozomi.dromozoa.com/recorder-socket")

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

  document.getElementById("send").onclick = () => {
    let data = document.getElementById("data").value
    log("send", data)

    socket.send(data)
  }

})
