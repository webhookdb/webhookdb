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
          filter: {
            contentType: { eq: "blog" }
            isFuture: { eq: false }
            frontmatter: { draft: { eq: false } }
          }
          sort: { order: DESC, fields: [frontmatter___date] }
        ) {
          edges {
            node {
              contentType
              frontmatter {
                path
                title
                summary
                date
                image
                imageAlt
              }
            }
          }
        }
      }
    `
  );

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
      {data.allMarkdownRemark.edges.map((edge) => {
        let blog = edge.node.frontmatter;
        return (
          <div
            key={blog.path}
            className="d-flex flex-row justify-content-center align-items-center mt-4"
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
