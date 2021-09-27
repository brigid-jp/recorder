// Copyright (c) 2021 <dev@brigid.jp>
// This software is released under the MIT License.
// https://opensource.org/licenses/mit-license.php

let log = (...args) => {
  console.log(args)
  let element = document.getElementById("log")
  if (element) {
    element.textContent = args.join(" ") + "\n" + element.textContent
  }
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
    format(2, date.getMonth() + 1) +
    format(2, date.getDate()) + "_" +
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
