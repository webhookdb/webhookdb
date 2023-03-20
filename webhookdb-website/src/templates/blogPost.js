import { Card, CardImg, Col, Container, Row } from "react-bootstrap";
import { Link, graphql } from "gatsby";

import Centered from "../components/Centered";
import LayoutPage from "../components/LayoutPage";
import RLink from "../components/RLink";
import React from "react";
import Seo from "../components/Seo";
import clsx from "clsx";
import dayjs from "dayjs";

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
    allMarkdownRemark(
      filter: {
        contentType: { eq: "blog" }
        frontmatter: { draft: { eq: false }, path: { ne: $path } }
      }
      sort: { order: DESC, fields: [frontmatter___date] }
      limit: 4
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
`;

export default function BlogPost({ data }) {
  const { frontmatter, html } = data.markdownRemark;
  const recentPosts = data.allMarkdownRemark.edges.map((e) => e.node);
  // recentPosts.push(data.markdownRemark);
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
          <div className="my-5">
            <div dangerouslySetInnerHTML={{ __html: html }} />
          </div>
        </Centered>
        <div className={clsx(!recentPosts.length && "d-none")}>
          <Link to="/blog">
            <h3 className="text-center text-dark">Recent Blog Posts</h3>
          </Link>
          <Centered>
            <Row>
              {recentPosts.map((node) => {
                let blog = node.frontmatter;
                return (
                  <Col key={blog.path} xs={6} md={4} className="mb-4">
                    <Card>
                      <RLink to={blog.path}>
                        <CardImg
                          variant="top"
                          src={`/content/blog/thumbnail/${blog.image}`}
                          alt={blog.imageAlt}
                          height="200px"
                          className="rounded-lg"
                        ></CardImg>
                      </RLink>
                      <Card.Body>
                        <RLink to={blog.path}>
                          <Card.Title className="mb-2 text-dark">
                            {blog.title}
                          </Card.Title>
                        </RLink>
                        <p title={blog.date} className="mb-2 text-muted">
                          {dayjs(blog.date).format("MMMM D, YYYY")}
                        </p>
                        <Card.Text className="mb-2">{blog.summary}</Card.Text>
                        <RLink to={blog.path} className="mb-0 font-weight-bold">
                          Read More →
                        </RLink>
                      </Card.Body>
                    </Card>
                  </Col>
                );
              })}
            </Row>
          </Centered>
        </div>
      </Container>
    </LayoutPage>
  );
}
