import clsx from "clsx";

import SafeExternalLink from "./SafeExternalLink.jsx";

export default function Footer({ className }) {
  return (
    <div className={clsx("flex column align-center pt-3 pb-5", className)}>
      <p>
        <SafeExternalLink href="mailto:hello@webhookdb.com">Contact Us</SafeExternalLink>
      </p>
      <p className="mt-2">
        <SafeExternalLink href="https://webhookdb.com">
          &copy; {new Date().getFullYear()} Lithic Technology
        </SafeExternalLink>
      </p>
    </div>
  );
}
