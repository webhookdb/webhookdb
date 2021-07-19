const path = require(`path`);

module.exports.createPages = async ({ actions, graphql, reporter }) => {
  const { createPage } = actions;
  const docsTemplate = path.resolve("./src/templates/docsPage.js");

  const result = await graphql(`
    {
      allMarkdownRemark {
        edges {
          node {
            frontmatter {
              path
            }
          }
        }
      }
    }
  `);

  if (result.errors) {
    reporter.panicOnBuild(`Error while running GraphQL query.`);
    return;
  }

  result.data.allMarkdownRemark.edges.forEach(({ node }) => {
    createPage({
      path: node.frontmatter.path,
      component: docsTemplate,
    });
  });
};
