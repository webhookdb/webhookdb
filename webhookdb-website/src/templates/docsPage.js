import React from "react";
import { graphql } from "gatsby";
import LayoutPage from "../components/LayoutPage";
import Documentation from "../pages/documentation";
import { Container, Row, Col, Breadcrumb } from "react-bootstrap";
import "../styles/custom.scss";
import ModalPagination from "../components/ModalPagination";
import TableOfContents from "../components/TableOfContents";
import Seo from "../components/Seo";

export const query = graphql`
  query ($path: String!) {
    markdownRemark(frontmatter: { path: { eq: $path } }) {
      html
      tableOfContents
      frontmatter {
        title
        order
        path
      }
    }
    mdx(frontmatter: { path: { eq: $path } }) {
      tableOfContents
    }
  }
`;

export default function DocsPage({ data }) {
  const { markdownRemark } = data;
  const { frontmatter, html } = markdownRemark;
  const { mdx } = data;

  async function getSyntax() {
    try {
      const deckdeckgoLoader = require("@deckdeckgo/highlight-code/dist/loader");

      deckdeckgoLoader.defineCustomElements(window);
    } catch (err) {
      console.error(err);
    }
  }

  React.useEffect(() => {
    getSyntax();
  }, []);

  return (
    <div>
      <LayoutPage>
        <Seo title={"Documentation"} />
        <Container fluid className={"min-vh-100"}>
          <Row>
            <Col className={"bg-light d-none d-lg-block min-vh-100"} lg={2}>
              <div>
                <Documentation />
              </div>
              <hr />
              {mdx.tableOfContents.items && (
                <div className={"w-100 px-3"}>
                  <TableOfContents post={mdx.tableOfContents} />
                </div>
              )}
            </Col>

            <Col lg={10} xs={12} md={12} className={"p-4"}>
              <Row>
                <Col className={"d-lg-none"}>
                  <ModalPagination path={frontmatter.path} mdx={mdx} />
                </Col>
              </Row>
              <Breadcrumb>
                <Breadcrumb.Item href="/">Home</Breadcrumb.Item>
                <Breadcrumb.Item href="/docs/home">Documentation</Breadcrumb.Item>
                <Breadcrumb.Item active>{frontmatter.title}</Breadcrumb.Item>
              </Breadcrumb>
              <div>
                <h1>{frontmatter.title}</h1>
                <div dangerouslySetInnerHTML={{ __html: html }} />
              </div>
            </Col>
          </Row>
        </Container>
      </LayoutPage>
    </div>
  );
}
