import "./ScreenLoader.css";
import clsx from "clsx";
import loader from "../assets/images/loader.svg";
import isUndefined from "lodash/isUndefined";

/**
 * Render the screen loader overlay.
 * For async work, use the `useScreenLoader` hook.
 * This is used when there is some async dependency
 * a screen has, and you want to render an overlay loader
 * while the page loads (ie, `return <ScreenLoader show />`).
 * @param {boolean=} show True by default.
 * @param {boolean=} scrim If false, do not show the blocking scrim (just show the loader element).
 * @param {number=} height Override the default height.
 * @returns {JSX.Element}
 */
export default function ScreenLoader({ show, scrim, height }) {
  show = isUndefined(show) ? true : show;
  scrim = isUndefined(scrim) ? true : scrim;
  height = height || 200;
  if (!scrim && !show) {
    return null;
  }
  const img = (
    <img className="img" src={loader} alt="loading" height={height} />
  );
  if (!scrim) {
    return img;
  }
  return (
    <div
      className={clsx(
        "screen-loader",
        show ? "screen-loader-show" : "screen-loader-hide",
      )}
    >
      <div className="screen-loader-scrim" />
      <div className="screen-loader-centerer">{img}</div>
    </div>
  );
}
