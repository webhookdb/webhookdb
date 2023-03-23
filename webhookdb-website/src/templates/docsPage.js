import "../styles/custom.scss";

import { Breadcrumb, Col, Container, Row } from "react-bootstrap";

import Documentation from "../pages/documentation";
import LayoutPage from "../components/LayoutPage";
import ModalPagination from "../components/ModalPagination";
import React from "react";
import Seo from "../components/Seo";
import TableOfContents from "../components/TableOfContents";
import { graphql } from "gatsby";
import throttledRequestIdleCallback from "../modules/throttledRequestIdleCallback";

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

  /**
   * When the page loads, load deckdeckgo to replace the static code blocks
   * with pretty ones. This changes the height of the page,
   * so once all the elements are done loading,
   * we need to re-navigate to the hash to find the right scroll position.
   * @returns {Promise<void>}
   */
  async function loadCodeFormattingAndRenavigate() {
    try {
      const deckdeckgoLoader = require("@deckdeckgo/highlight-code/dist/loader");
      await deckdeckgoLoader.defineCustomElements(window);
    } catch (err) {
      console.error("Failed to load code highlighting:", err);
      return;
    }
    const hash = window.location.hash || "";
    if (hash.length < 2) {
      // No need to navigate for empty hash or #
      return;
    }
    const codeBlocks = [...document.querySelectorAll("deckgo-highlight-code")];
    // Poll until all code blocks are hydrated, then navigate to scroll into view.
    const renavigateWhenHydrated = () => {
      const allHydrated = codeBlocks.every((node) =>
        node.className.includes("hydrated")
      );
      if (allHydrated) {
        window.requestIdleCallback(() => {
          window.location.href = window.location.hash;
        });
      } else {
        throttledRequestIdleCallback(renavigateWhenHydrated, 100);
      }
    };
    throttledRequestIdleCallback(renavigateWhenHydrated, 100);
  }

  React.useEffect(() => {
    loadCodeFormattingAndRenavigate().then(() => null);
  }, []);

  return (
    <div>
      <LayoutPage>
        <Seo title="Documentation" />
        <Container fluid className="min-vh-100">
          <Row>
            <Col className="bg-light d-none d-lg-block min-vh-100" lg={2}>
              <div>
                <Documentation />
              </div>
              <hr />
              {mdx.tableOfContents.items && (
                <div className="w-100 px-3">
                  <TableOfContents post={mdx.tableOfContents} />
                </div>
              )}
            </Col>

            <Col lg={10} xs={12} md={12} className="px-4 py-3 py-lg-4">
              <div className="max-width-xl">
                <Row>
                  <Col className="d-lg-none mb-3">
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
              </div>
            </Col>
          </Row>
        </Container>
      </LayoutPage>
    </div>
  );
}
