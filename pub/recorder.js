onload = () => {
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

  (async () => {
    stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: true })
    devices = await navigator.mediaDevices.enumerateDevices()

    stream.getVideoTracks().forEach((track, i) => {
      if (i == 0) {
        video_track = track
      }
      log("video track", track.kind, track.id, track.label, track.getSettings().deviceId)
    })
    stream.getAudioTracks().forEach((track, i) => {
      if (i == 0) {
        audio_track = track
      }
      log("audio track", track.kind, track.id, track.label, track.getSettings().deviceId)
    })

    devices.forEach((device) => {
      log("device", device.kind, device.deviceId, device.label)

      let selector_name
      let selector
      let checked
      if (device.kind === "videoinput") {
        selector_name = "video-selector"
        selector = document.getElementById("video-selector")
        checked = device.deviceId === video_track.getSettings().deviceId
      } else if (device.kind == "audioinput") {
        selector_name = "audio-selector"
        selector = document.getElementById("audio-selector")
        checked = device.deviceId === audio_track.getSettings().deviceId
      } else {
        return
      }

      let id = device.kind + "-" + device.deviceId

      selector.appendChild(create_element("div", {}, [
        create_element("input", {
          type: "radio",
          id: id,
          name: selector_name,
          value: device.deviceId,
          checked: checked,
        }),
        " ",
        create_element("label", { "for": id, }, [ device.label ]),
      ]))
    })

    // document.getElementById("audio-selector").appendChild(
    //   create_element("div", {}, [
    //     "test1",
    //     create_element("input", { type: "text", value: "あああ" }),
    //     "test2",
    //   ]))

    // create_element("input", { type: "text", "data-test": 42 }, [])

  })().catch((e) => {
    log(e)
  })
}
