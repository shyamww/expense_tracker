(function () {
  var reloadKey = 'expense_tracker_pwa_cleanup_reloaded';
  var hadController = !!(navigator.serviceWorker && navigator.serviceWorker.controller);
  var tasks = [];

  if ('serviceWorker' in navigator) {
    tasks.push(
      navigator.serviceWorker.getRegistrations().then(function (registrations) {
        return Promise.all(registrations.map(function (registration) {
          return registration.unregister();
        }));
      })
    );
  }

  if ('caches' in window) {
    tasks.push(
      caches.keys().then(function (keys) {
        return Promise.all(keys
          .filter(function (key) {
            return key.indexOf('flutter-') === 0;
          })
          .map(function (key) {
            return caches.delete(key);
          }));
      })
    );
  }

  Promise.all(tasks).then(function () {
    if (!hadController || sessionStorage.getItem(reloadKey) === '1') return;
    sessionStorage.setItem(reloadKey, '1');
    window.location.reload();
  }).catch(function () {
    // The app must still boot if a browser blocks service-worker/cache access.
  });
})();
