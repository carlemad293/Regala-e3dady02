// The value below is injected by flutter build, do not touch.
const serviceWorkerVersion = '{{flutter_service_worker_version}}';

// Initialize Flutter build configuration
window._flutter = {
  loader: {
    load: function(options) {
      return new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'main.dart.js';
        script.type = 'application/javascript';
        script.onload = function() {
          resolve();
        };
        script.onerror = function(error) {
          reject(error);
        };
        document.body.appendChild(script);
      });
    }
  },
  buildConfig: {
    serviceWorkerVersion: serviceWorkerVersion,
    serviceWorkerUrl: 'flutter_service_worker.js?v=' + serviceWorkerVersion,
    entrypoint: 'main.dart.js'
  }
};

// Load Flutter
window.addEventListener('load', function(ev) {
  _flutter.loader.load({
    serviceWorker: {
      serviceWorkerVersion: serviceWorkerVersion,
    }
  }).then(function(engineInitializer) {
    return engineInitializer.initializeEngine({
      useColorEmoji: true,
      renderer: "html"
    });
  }).then(function(appRunner) {
    return appRunner.runApp();
  }).catch(function(error) {
    console.error('Error initializing Flutter:', error);
  });
}); 