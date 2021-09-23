addEventListener("DOMContentLoaded", () => {
  let stream
  let video_track
  let audio_track
  let devices

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
    if (element && stream) {
      element.srcObject = stream
    }
  }

  let update_stream = async () => {
    stream = undefined

    let constraints = { video: true, audio: true }
    document.getElementsByName("video-selector").forEach(element => {
      log(element.id, element.value, element.checked)
      if (element.checked) {
        constraints.video = { deviceId: element.value }
      }
    })
    document.getElementsByName("audio-selector").forEach(element => {
      log(element.id, element.value, element.checked)
      if (element.checked) {
        constraints.audio = { deviceId: element.value }
      }
    })

    stream = await navigator.mediaDevices.getUserMedia(constraints)
    update_video()
  }

  (async () => {
    stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true })
    devices = await navigator.mediaDevices.enumerateDevices()

    stream.getVideoTracks().forEach((track, i) => {
      if (i === 0) {
        video_track = track
      }
      log("video track", track.kind, track.id, track.label, track.getSettings().deviceId)
    })
    stream.getAudioTracks().forEach((track, i) => {
      if (i === 0) {
        audio_track = track
      }
      log("audio track", track.kind, track.id, track.label, track.getSettings().deviceId)
    })

    devices.forEach(device => {
      log("device", device.kind, device.deviceId, device.label)

      let key
      let track

      if (device.kind === "videoinput") {
        key = "video"
        track = video_track
      } else if (device.kind === "audioinput") {
        key = "audio"
        track = audio_track
      } else {
        return
      }

      let element = create_element("div", {}, [
        create_element("input", {
          type: "radio",
          id: key + "-" + device.deviceId,
          name: key + "-selector",
          value: device.deviceId,
          checked: device.deviceId === track.getSettings().deviceId,
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
    })
  })().catch(e => log(e))
})
