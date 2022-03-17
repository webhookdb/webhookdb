import React from "react";

export default function WistiaEmbed({ mediaUrl }) {
  const [swatchOpacity, setSwatchOpacity] = React.useState(0);
  React.useEffect(() => {
    if (scriptsLoaded) {
      return;
    }
    const scripts = [
      `${mediaUrl}.jsonp`,
      "https://fast.wistia.com/assets/external/E-v1.js",
    ];
    scripts.forEach((src) => {
      const el = document.createElement("script");
      el.src = src;
      el.async = true;
      document.body.appendChild(el);
    });
    scriptsLoaded = true;
  }, []);

  return (
    <div
      className="wistia_responsive_padding"
      style={{ padding: "56.25% 0 0 0", position: "relative" }}
    >
      <div
        className="wistia_responsive_wrapper"
        style={{ height: "100%", left: 0, position: "absolute", top: 0, width: "100%" }}
      >
        <div
          className="wistia_embed wistia_async_lrox7uw103 videoFoam=true"
          style={{ height: "100%", position: "relative", width: "100%" }}
        >
          <div
            className="wistia_swatch"
            style={{
              height: "100%",
              left: 0,
              opacity: swatchOpacity,
              overflow: "hidden",
              position: "absolute",
              top: 0,
              transition: "opacity 200ms",
              width: "100%",
            }}
          >
            <img
              src={`${mediaUrl}/swatch`}
              style={{
                filter: "blur(5px)",
                height: "100%",
                objectFit: "contain",
                width: "100%",
              }}
              alt=""
              aria-hidden="true"
              onLoad={() => setSwatchOpacity(1)}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

let scriptsLoaded = false;
