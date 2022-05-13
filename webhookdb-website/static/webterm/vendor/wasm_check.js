(function() {
  const ua = window.navigator.userAgent;
  const iOS = !!ua.match(/iPad/i) || !!ua.match(/iPhone/i);
  // const webkit = !!ua.match(/WebKit/i);
  // const iOSSafari = iOS && webkit && !ua.match(/CriOS/i);
  // Our Go WASM crashes iOS for some reason,
  // but not other platforms.
  window.webhookdbWasmSupported = !iOS;
})()
