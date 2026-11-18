// CloudFront Function (viewer request).
// 1. www.vbuyan.com -> vbuyan.com (301)
// 2. /postmortems   -> /postmortems/ (301, the site uses trailing slashes)
// 3. /postmortems/  -> /postmortems/index.html (internal rewrite to the S3 key)
function handler(event) {
  var req = event.request;
  var host = req.headers.host ? req.headers.host.value : "";
  var uri = req.uri;

  if (host.indexOf("www.") === 0) {
    return redirect("https://" + host.substring(4) + uri + query(req.querystring));
  }
  if (uri.endsWith("/")) {
    req.uri = uri + "index.html";
    return req;
  }
  var last = uri.substring(uri.lastIndexOf("/") + 1);
  if (last.indexOf(".") === -1) {
    return redirect(uri + "/" + query(req.querystring));
  }
  return req;
}

function redirect(location) {
  return {
    statusCode: 301,
    statusDescription: "Moved Permanently",
    headers: { location: { value: location }, "cache-control": { value: "max-age=3600" } },
  };
}

function query(qs) {
  var parts = [];
  for (var k in qs) {
    if (qs[k].multiValue) {
      qs[k].multiValue.forEach(function (v) { parts.push(k + "=" + v.value); });
    } else {
      parts.push(k + "=" + qs[k].value);
    }
  }
  return parts.length ? "?" + parts.join("&") : "";
}
