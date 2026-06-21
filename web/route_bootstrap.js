(function () {
  var basePath = '/expense_tracker/';
  var path = window.location.pathname;
  var hash = window.location.hash;

  if (path === basePath && (!hash || hash === '#')) {
    window.history.replaceState(null, '', basePath + '#/home/daily');
  }
})();
