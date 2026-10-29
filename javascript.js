const config = {
    apiUrl: "${api_url}"
}

function javascriptLoaded() {
    fetch(
      config.apiUrl + "/visitor",
    )
      .then((resp) => resp.text())
      .then((val) => {
            let elem = document.getElementById("jsload");
            elem.innerHTML = "Site has been visited " + val + " times";
            elem.style = "color: pink; background-color: black";
      });
}

document.addEventListener("DOMContentLoaded", javascriptLoaded);