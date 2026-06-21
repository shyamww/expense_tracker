(function () {
  var basePath = '/expense_tracker/';
  var path = window.location.pathname;
  var hash = window.location.hash;
  var search = window.location.search || '';
  var params = new URLSearchParams(search);
  var isAuthCallback = params.has('code') ||
    params.has('error') ||
    params.has('error_code') ||
    params.has('error_description');

  if (path === basePath && (!hash || hash === '#')) {
    var route = isAuthCallback ? '#/settings/cloud-sync' : '#/home/daily';
    window.history.replaceState(null, '', basePath + search + route);
  }
})();
