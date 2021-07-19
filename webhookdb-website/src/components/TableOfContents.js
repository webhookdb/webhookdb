import { Nav } from "react-bootstrap";
import React from "react";

export default function TableOfContents(props) {
  const { post, closeModal } = props;

  return (
    <Nav>
      {post.items.map((p) => (
        <Nav.Item className={"w-100"} key={p.url}>
          <Nav.Link className={"px-0"} href={p.url} onSelect={closeModal}>
            {p.title}
          </Nav.Link>
        </Nav.Item>
      ))}
    </Nav>
  );
}
