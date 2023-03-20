import Centered from "../components/Centered";
import { Container } from "react-bootstrap";
import LayoutPage from "../components/LayoutPage";
import React from "react";
import Seo from "../components/Seo";
import { graphql } from "gatsby";

export const pageQuery = graphql`
  query ($path: String!) {
    markdownRemark(frontmatter: { path: { eq: $path } }) {
      frontmatter {
        author
        date(formatString: "MMMM D, YYYY")
        title
        image
        imageAlt
      }
      html
    }
  }
`;

export default function BlogPost({ data }) {
  const { frontmatter, html } = data.markdownRemark;
  return (
    <LayoutPage center>
      <Seo title={frontmatter.title} description={frontmatter.summary} />
      <Container className="pt-5 px-2" fluid>
        <Centered>
          <h1 className="mb-2">{frontmatter.title}</h1>
          <p>
            {frontmatter.author} on {frontmatter.date}
          </p>
          <img
            src={`/content/blog/${frontmatter.image}`}
            alt={frontmatter.imageAlt}
            className="img-fluid rounded"
            style={{ width: "100%", maxHeight: 400, objectFit: "cover" }}
          ></img>
          <div className="mt-4">
            <div dangerouslySetInnerHTML={{ __html: html }} />
          </div>
        </Centered>
      </Container>
    </LayoutPage>
  );
}
