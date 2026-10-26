function javascriptLoaded() {
    let visitCountReq = fetch(
      "https://4fpvaectw2.execute-api.us-east-2.amazonaws.com/visitor",
    )
      .then((resp) => resp.text())
      .then((val) => {
            let elem = document.getElementById("jsload");
            elem.innerHTML = `Site has been visited ${val} times`;
            elem.style = "color: pink; background-color: black";
      });
}

document.addEventListener("DOMContentLoaded", javascriptLoaded);