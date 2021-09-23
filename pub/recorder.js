addEventListener("DOMContentLoaded", () => {
  let stream
  let recorder

  let log = (...args) => {
    console.log(args)
    document.getElementById("log").textContent += args.join(" ") + "\n"
  };

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

  let start = async () => {
    log("start")
    recorder = new MediaRecorder(stream)
    recorder.ondataavailable = ev => {
      let data = ev.data
      log("data", data.type, data.size)
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
