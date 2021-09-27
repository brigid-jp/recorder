// Copyright (c) 2021 <dev@brigid.jp>
// This software is released under the MIT License.
// https://opensource.org/licenses/mit-license.php

addEventListener("DOMContentLoaded", () => {
  let params = new URLSearchParams(document.location.search.substring(1))
  let key = params.get("key")

  document.getElementById("key").textContent = key
})
