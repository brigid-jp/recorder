onload = () => {
  navigator.mediaDevices.getUserMedia({ audio: true, video: true })
  .then((stream) => {
    console.log(stream)
    navigator.mediaDevices.enumerateDevices().then((devices) => {
      devices.forEach((device) => {
        console.log(device)
      })
    })
  })
  .catch((error) => {
    console.log(error)
  })


}
