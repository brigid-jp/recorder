// Copyright (c) 2021 <dev@brigid.jp>
// This software is released under the MIT License.
// https://opensource.org/licenses/mit-license.php

addEventListener("DOMContentLoaded", () => {
  let stream
  let recorder
  let session
  let session_counter
  let params = new URLSearchParams(document.location.search.substring(1))
  let key = params.get("key")
  let socket

  document.getElementById("key").textContent = key

  let update_stream = async () => {
    stream.getTracks().forEach(track => {
      track.stop()
    })
    stream = undefined

    let constraints = { video: true, audio: true }
    document.getElementsByName("video-selector").forEach(element => {
      log(element.id, element.value, element.checked)
      if (element.checked) {
        constraints.video = { deviceId: { exact: element.value } }
      }
    })
    document.getElementsByName("audio-selector").forEach(element => {
      log(element.id, element.value, element.checked)
      if (element.checked) {
        constraints.audio = { deviceId: { exact: element.value } }
      }
    })

    stream = await navigator.mediaDevices.getUserMedia(constraints)
  }

  let upload = async (data, flag) => {
    let suffix
    if (data.type.search(/video\/mp4/) !== -1) {
      suffix = ".mp4"
    } else if (data.type.search(/video\/webm/) !== -1) {
      suffix = ".webm"
    } else if (data.type.search(/video\/x-matroska/) !== -1) {
      suffix = ".mkv"
    } else {
      suffix = ".dat"
    }

    let path = "/recorder/dav/" + session + "-" + format(8, ++session_counter) + suffix

    let started = new Date()
    let response = await fetch(path, {
      method: "PUT",
      headers: { "Content-Type": data.type },
      body: data,
    })
    let finished = new Date()

    if (flag) {
      log(path, response.status, response.statusText, finished.getTime() - started.getTime())
    }
  }

  let start = () => {
    if (recorder) {
      log("[error] recorder started")
      return false
    }

    log("start")
    session = format_date(new Date()) + "-" + format(6, Math.floor(Math.random() * 999999))
    session_counter = 0
    recorder = new MediaRecorder(stream)
    recorder.ondataavailable = ev => {
      let data = ev.data
      upload(data).catch(e => log(e))
    }
    recorder.start(1000)

    return true
  }

  let stop = async () => {
    if (!recorder) {
      log("[error] recorder undefined")
      return false
    }

    log("stop")
    recorder.stop()
    recorder = undefined
    await update_stream()

    return true
  }

  let onmessage = async (ev) => {
    log("onmessage", typeof ev.data)
    if (typeof ev.data === "string") {
      log("ontext", ev.data)
      let data = JSON.parse(ev.data)

      if (data.command === "status") {
        socket.send(JSON.stringify({
          command: data.command,
          result: !!recorder,
          session: session,
          session_counter: session_counter,
        }))
      } else if (data.command === "capture") {
        let track = stream.getVideoTracks()[0]
        let capture = new ImageCapture(track)

        let caps = await capture.getPhotoCapabilities()
        log("caps max", caps.imageWidth.max, caps.imageHeight.max)
        log("caps min", caps.imageWidth.min, caps.imageHeight.min)
        log("caps step", caps.imageWidth.step, caps.imageHeight.step)

        let photo = await capture.takePhoto({
          imageWidth: caps.imageWidth.min,
          imageHeight: caps.imageHeight.min,
        })
        socket.send(photo)
      } else if (data.command === "start") {
        let result = start()
        socket.send(JSON.stringify({ command: data.command, result: result }))
      } else if (data.command === "stop") {
        let result = await stop()
        socket.send(JSON.stringify({ command: data.command, result: result }))
      }
    } else {
      log("onbinary", ev.data.size)
    }
  }

  let open

  open = () => {
    try {
      socket = new WebSocket("wss://nozomi.dromozoa.com/recorder-socket/recorder/" + key)
      socket.binaryType = "blob"

      socket.onopen = () => {
        log("onopen")
      }

      socket.onclose = () => {
        log("onclose")
        socket = undefined

        if (reopen) {
          setTimeout(open, reopen)
        }
      }

      socket.onerror = (ev) => {
        log("onerror", ev)
      }

      socket.onmessage = (ev) => {
        onmessage(ev).catch(e => log(e))
      }

      return true
    } catch (e) {
      log("[error] " + e.message)
    }
    return false
  }

  (async () => {
    stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true })
    let devices = await navigator.mediaDevices.enumerateDevices()
    let tracks = {}

    stream.getVideoTracks().forEach((track, i) => {
      if (i === 0) {
        tracks.video = track
      }
      log("video track", track.kind, track.id, track.label, track.getSettings().deviceId)
    })
    stream.getAudioTracks().forEach((track, i) => {
      if (i === 0) {
        tracks.audio = track
      }
      log("audio track", track.kind, track.id, track.label, track.getSettings().deviceId)
    })

    devices.forEach(device => {
      log("device", device.kind, device.deviceId, device.label)

      let key
      if (device.kind === "videoinput") {
        key = "video"
      } else if (device.kind === "audioinput") {
        key = "audio"
      } else {
        return
      }

      let element = create_element("div", {}, [
        create_element("input", {
          type: "radio",
          id: key + "-" + device.deviceId,
          name: key + "-selector",
          value: device.deviceId,
          checked: device.deviceId === tracks[key].getSettings().deviceId,
        }),
        " ",
        create_element("label", {
          "for": key + "-" + device.deviceId,
        }, [ device.label ]),
      ])
      element.onchange = () => {
        update_stream().catch(e => log(e))
      }
      document.getElementById(key + "-selector").appendChild(element)
    })

    document.getElementById("open").onclick = () => {
      if (socket) {
        log("[error] already opened")
        return
      }

      reopen = 10000
      open()
    }

    document.getElementById("close").onclick = () => {
      if (!socket) {
        log("[error] socket undefined")
        return
      }

      reopen = undefined
      socket.close()
    }

    document.getElementById("start").onclick = start

    document.getElementById("stop").onclick = () => {
      stop().catch(e => log(e))
    }
  })().catch(e => log(e))
})
