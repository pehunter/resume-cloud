const config = {
    apiUrl: "https://ph2szgf2qa.execute-api.us-east-1.amazonaws.com"
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