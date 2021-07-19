import { graphql, useStaticQuery } from "gatsby";

export default function useSiteMetadata() {
  const { site } = useStaticQuery(graphql`
    query SiteMetaData {
      site {
        siteMetadata {
          title
          description
        }
      }
    }
  `);

  return site.siteMetadata;
}
