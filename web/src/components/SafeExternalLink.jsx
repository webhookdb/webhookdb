export default function SafeExternalLink({ href, className, children, ...rest }) {
  const safe = href && safeHosts.some((h) => href.startsWith(h));
  const rel = safe ? "noopener" : "noreferrer";
  return (
    // eslint-disable-next-line react/jsx-no-target-blank
    <a href={href} target="_blank" rel={rel} className={className} {...rest}>
      {children}
    </a>
  );
}

const safeHosts = ["https://webhookdb.com", "https://lithic.tech"];
