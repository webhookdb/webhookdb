/**
 * Return information about an href.
 * Needed because we have FOUR different types of hrefs
 * we deal with:
 *
 * - Absolute, off-origin links.
 * - Absolute, on-origin links. Treat these like relative links.
 * - Relative links, without a leading basename.
 *   This is what we normally use, and it works fine with react-router in terms
 *   of both using its `Link` component and `useNavigate` hook.
 * - Relative links, WITH a leading basename.
 *   We need to use these in some cases, like with react-aria-components
 *   Item.href prop; react-aria uses the href you give it verbatim
 *   (so you need a leading basename) but the RouterProvider
 *   is called with the same href (meaning you pass react-router
 *   a useNavigate with a leading basename, which is wrong).
 *   See https://github.com/adobe/react-spectrum/issues/5335
 *   for some more context.
 *
 * To deal with this insane compatibility situation,
 * we can do the following:
 *
 * - Be explicit about the link component/format,
 *   such as RelLink and AbsLink where possible.
 * - Understand we need to use ambiguous links in some places,
 *   especially at the 'library' level.
 * - Ensure the basename doesn't appear as the root of a valid route.
 *   For example, we can know everything starting with '/app/' is
 *   rooted in the basename; that is, there is no valid route
 *   like '/app/app/foo'.
 *
 * This allows us to interpret the href,
 * and then pass the correct form of it (with basename, without, etc)
 * to the right library (without basename to react-router,
 * with basename to react-aria).
 *
 * @param href
 * @return {FlexiHref}
 */
export default function useFlexiHref(href) {
  if (!href) {
    return {
      isAbsoluteForm: false,
      relativeHref: href,
      basenameHref: href,
      isActuallyRelative: true,
    };
  }
  const isAbsoluteForm = ABSOLUTE_URL_REGEX.test(href);
  const isActuallyRelative = !href || !isAbsoluteForm || href.startsWith(ORIGIN);
  let relativeHref = "";
  let basenameHref = "";
  if (isActuallyRelative) {
    if (isAbsoluteForm) {
      basenameHref = href.slice(ORIGIN_LENGTH);
      relativeHref = basenameHref.slice(BASENAME.length);
    } else if (href.startsWith(BASENAME_SLASH)) {
      basenameHref = href;
      relativeHref = basenameHref.slice(BASENAME.length);
    } else {
      relativeHref = href;
      basenameHref = BASENAME + href;
    }
  }
  return { isActuallyRelative, isAbsoluteForm, relativeHref, basenameHref };
}

const BASENAME = import.meta.env.BASE_URL.replace(/\/$/, "");
const BASENAME_SLASH = BASENAME + "/";
const ORIGIN = window.location.origin;
const ORIGIN_LENGTH = ORIGIN.length;
const ABSOLUTE_URL_REGEX = /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i;

/**
 * @typedef FlexiHref
 * @property {boolean} isActuallyRelative True if the href is empty/relative,
 *   or points to a frontend-relative path,
 *   even if the href itself is absolute (has the same origin as the current location).
 * @property {boolean} isAbsoluteForm True if the href is of the absolute form
 *   (ie, same origin as current location is still absolute form).
 * @property {string} relativeHref Valid when isActuallyRelative is true.
 *   Contains a relative href (ie, the leading origin is stripped off if the href
 *   is absolute, to the current origin).
 *   This value NEVER includes a leading basename.
 * @property {string} basenameHref Valid when isActuallyRelative is true.
 *   Like relativeHref, but always includes a leading basename.
 */
