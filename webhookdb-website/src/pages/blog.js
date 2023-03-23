import "../styles/custom.scss";

import { graphql, useStaticQuery } from "gatsby";

import Lead from "../components/Lead";
import RLink from "../components/RLink";
import React from "react";
import Seo from "../components/Seo";
import WavesHeaderLayout from "../components/WavesHeaderLayout";
import dayjs from "dayjs";

export default function Blog() {
  const data = useStaticQuery(
    graphql`
      query {
        allMarkdownRemark(
          filter: { contentType: { eq: "blog" }, frontmatter: { draft: { eq: false } } }
          sort: { order: DESC, fields: [frontmatter___date] }
        ) {
          edges {
            node {
              contentType
              isFuture
              frontmatter {
                path
                title
                summary
                date
                image
                imageAlt
                draft
              }
            }
          }
        }
      }
    `
  );

  const [showAll, setShowAll] = React.useState(false);
  React.useEffect(() => {
    if (window !== undefined) {
      setShowAll(Boolean(new URL(window.location).searchParams.get("showAll")));
    }
  }, []);

  const posts = data.allMarkdownRemark.edges.filter((edge) => {
    if (showAll) {
      return true;
    }
    return !edge.node.isFuture && !edge.node.frontmatter.draft;
  });

  return (
    <WavesHeaderLayout
      paddingClass="px-1"
      noWaves={true}
      header={
        <>
          <h1>WebhookDB Blog</h1>
          <Lead>
            Where we discuss building WebhookDB, simplifying API integrations, scale,
            and other fun engineering and company topics.
          </Lead>
        </>
      }
    >
      <Seo title="Blog" />
      <div className="py-3" />
      {posts.map((edge) => {
        let blog = edge.node.frontmatter;
        return (
          <div
            key={blog.path}
            className="d-flex flex-row justify-content-start align-items-center mt-5"
          >
            <div>
              <RLink to={blog.path}>
                <img
                  src={`/content/blog/thumbnail/${blog.image}`}
                  alt={blog.imageAlt}
                  className="img-fluid rounded-lg d-none d-sm-block"
                  width="140"
                ></img>
              </RLink>
            </div>
            <div className="ml-3 ml-md-4">
              <RLink to={blog.path}>
                <h3 className="mb-2 text-dark">{blog.title}</h3>
              </RLink>
              <p title={blog.date} className="mb-2 text-muted">
                {dayjs(blog.date).format("MMMM D, YYYY")}
              </p>
              <p className="mb-2">{blog.summary}</p>
              <RLink to={blog.path} className="mb-0 font-weight-bold">
                Read More →
              </RLink>
            </div>
          </div>
        );
      })}
    </WavesHeaderLayout>
  );
}
