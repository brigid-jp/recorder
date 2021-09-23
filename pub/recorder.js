addEventListener("DOMContentLoaded", () => {
  let stream
  let recorder
  let session
  let session_counter
  let authorization

  let log = (...args) => {
    console.log(args)
    document.getElementById("log").textContent += args.join(" ") + "\n"
  }

  let format = (width, value) => {
    let s = value.toString()
    let w = width - s.length
    if (w > 0) {
      return "0".repeat(w) + s
    } else {
      return s
    }
  }

  let format_date = date => {
    return date.getFullYear() +
      format(2, date.getMonth()) +
      format(2, date.getDay()) + "_" +
      format(2, date.getHours()) +
      format(2, date.getMinutes()) +
      format(2, date.getSeconds()) + "_" +
      format(3, date.getMilliseconds())
  }

  let create_element = (name, attributes, values) => {
    let element = document.createElement(name)
    Object.entries(attributes).forEach(([key, value]) => {
      if (value) {
        element.setAttribute(key, value)
      }
    })
    if (values) {
      values.forEach((value) => {
        if (value.nodeType) {
          element.appendChild(value)
        } else {
          element.appendChild(document.createTextNode(value))
        }
      })
    }
    return element
  }

  let update_video = async () => {
    let element = document.getElementById("video")
    if (element) {
      element.srcObject = stream
    }
  }

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
    update_video()
  }

  let upload = async data => {
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

    let path = "/dav/" + session + "-" + format(8, ++session_counter) + suffix

    let started = new Date()
    let response = await fetch(path, {
      method: "PUT",
      headers: {
        "Content-Type": data.type,
        Authorization: authorization,
      },
      body: data,
    })
    let finished = new Date()

    log(path, response.status, response.statusText, finished.getTime() - started.getTime())
  }

  let start = async () => {
    session = format_date(new Date()) + "-" + format(6, Math.floor(Math.random() * 999999))
    session_counter = 0

    let username = document.getElementById("username").value
    let password = document.getElementById("password").value
    authorization = "Basic " + btoa(username + ":" + password)

    log("start")
    recorder = new MediaRecorder(stream)
    recorder.ondataavailable = ev => {
      let data = ev.data
      log("data", data.type, data.size)
      upload(data).catch(e => log(e))
    }
    recorder.start(1000)
  }

  let stop = async () => {
    log("stop")
    recorder.stop()
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

      update_video()

      document.getElementById("start").onclick = () => {
        start().catch(e => log(e))
      }

      document.getElementById("stop").onclick = () => {
        stop().catch(e => log(e))
      }
    })
  })().catch(e => log(e))
})
