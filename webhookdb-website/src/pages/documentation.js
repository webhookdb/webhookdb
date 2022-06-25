import { Nav, NavItem, NavLink } from "reactstrap";
import { graphql, useStaticQuery } from "gatsby";

import RLink from "../components/RLink";
import React from "react";

export default function Documentation() {
  const data = useStaticQuery(
    graphql`
      query {
        allMarkdownRemark(sort: { order: ASC, fields: [frontmatter___order] }) {
          edges {
            node {
              frontmatter {
                path
                title
                order
              }
            }
          }
        }
      }
    `
  );

  return (
    <Nav vertical className="mt-4">
      {data &&
        data.allMarkdownRemark.edges.map((edge, i) => {
          let doc = edge.node.frontmatter;
          return (
            <NavItem key={i}>
              <NavLink href={doc.path} as={RLink}>
                {doc.title}
              </NavLink>
            </NavItem>
          );
        })}
    </Nav>
  );
}
