(function () {
  if (!('serviceWorker' in navigator)) return;
  navigator.serviceWorker.getRegistrations().then(function (registrations) {
    registrations.forEach(function (registration) {
      registration.unregister();
    });
  }).catch(function () {
    // The app must still boot if a browser blocks service-worker access.
  });
})();
