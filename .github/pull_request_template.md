- [ ] Add [CHANGELOG](https://github.com/webhookdb/webhookdbdb/blob/main/CHANGELOG.md) updates
- [ ] Needs [documentation](https://github.com/webhookdb/docs) updates

Fixes #<issue number>.

---
Cut everything below the above line.

## Guidelines for Pull requests

Checklist for a pull request:

- Try to follow [the seven rules of a great Git commit
  message](https://chris.beams.io/posts/git-commit/).
- Write unit tests! Nothing gets merged without unit tests.
- Rebase on latest `main` code.
- Reference the issue(s) resolved with `Fixes #<issue number>`, or
  `Closes #<issue number>`.
- Make sure the PR has appropriate `CHANGELOG` updates, including thanks
  to people that reported issues.
- Include appropriate documentation changes.

### The seven rules of a great Git commit message

1. Separate subject from body with a blank line
2. Limit the subject line to 50 characters
3. Capitalize the subject line
4. Do not end the subject line with a period
5. Use the imperative mood in the subject line
6. Wrap the body at 72 characters
7. Use the body to explain what and why vs. how

### Single commit PR

In general, most PRs will be squashed into a single commit on merge.
This keeps a cleaner history. The other side of this is that commits
should be for a single related change. This means that either
your entire PR should be for a single change,
or if you must do a multi-change PR, it can be split into multiple
single-change commits.

In any case don't worry too much about this- if the code is good,
and there are tests, it'll make it in.

### Documentation

If the code change adds a new feature, limitation, or change in
behavior, the PR might need to include documentation or a separate
follow-up PR to the [documentation repository](https://github.com/timescale/docs).
