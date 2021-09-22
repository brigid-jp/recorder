onload = () => {

  let log = (v) => {
    let e = document.getElementById("log")
    e.textContent += v + "\n"
    console.log(v)
  };

  (async () => {
    let stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: true })
    // console.log(stream)
    log(stream)
    let devices = await navigator.mediaDevices.enumerateDevices()
    for (let i = 0; i < devices.length; ++i) {
      let device = devices[i]
      // console.log(device)
      log(device)
    }
  })().catch((e) => {
    console.log(e)
  })
}
