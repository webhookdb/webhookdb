const path = require(`path`);

exports.createSchemaCustomization = ({ actions }) => {
  const { createTypes, createFieldExtension } = actions;

  createFieldExtension({
    name: `isFuture`,
    extend() {
      return {
        resolve: (source) => {
          const date = source.frontmatter.date;
          if (!date) {
            return false;
          }
          return new Date(date) > new Date();
        },
      };
    },
  });
  createFieldExtension({
    name: `contentType`,
    extend() {
      return {
        resolve: (source) => {
          const path = source.frontmatter.path;
          if (path.includes("/blog/")) {
            return "blog";
          }
          return "docs";
        },
      };
    },
  });

  createTypes(`
    type MarkdownRemark implements Node {
      isFuture: Boolean @isFuture
      contentType: String @contentType
    }
  `);
};

module.exports.createPages = async ({ actions, graphql, reporter }) => {
  const { createPage } = actions;

  const buildDetails = [
    ["docs", "docsPage"],
    ["blog", "blogPost"],
  ];
  await Promise.all(
    buildDetails.map(async ([contentType, templateFile]) => {
      const template = path.resolve(`./src/templates/${templateFile}.js`);
      const result = await graphql(`{
      allMarkdownRemark(filter: { contentType: { eq: "${contentType}" } }) {
        edges {
          node {
            frontmatter {
              path
            }
          }
        }
      }
    }`);
      if (result.errors) {
        reporter.panicOnBuild(`Error while running GraphQL query.`);
        return;
      }
      result.data.allMarkdownRemark.edges.forEach(({ node }) => {
        createPage({
          path: node.frontmatter.path,
          component: template,
        });
      });
    })
  );
};
