# Release process

Steps to release a new version:

1. Check documentation

   ```bash
   bundle exec rake rdoc:coverage && bundle exec rbs -I sig validate && bundle exec steep check
   ```

2. Update version number in VERSION file, before the bundles record it

3. Run and fix all warnings

   ```bash
   pip3 install codespell && \
   gem update --system && \
   bundle update && bundle update --bundler && \
   BUNDLE_GEMFILE=gemfiles/8.1.gemfile bundle update && \
   BUNDLE_GEMFILE=gemfiles/benchmarks.gemfile bundle update && \
   bundle exec rspec && \
   bundle exec rake benchmarks:check && \
   bundle exec rubocop -A && \
   codespell --skip="./sig,./doc,./coverage" && \
   bundle exec rake release:lockfiles
   ```

4. Checkout to new release branch

   ```bash
   git checkout -b "v$(cat VERSION)"
   ```

5. Build gem

   ```bash
   gem build serega.gemspec
   ```

6. Run final validation (repeat step 3)

7. Validate documentation

   ```bash
   mdl README.md CHEATSHEET.md CHANGELOG.md RELEASE.md docs
   ```

8. Commit changes

   ```bash
   git add . && git commit -m "Release v$(cat VERSION)"
   git push origin "v$(cat VERSION)"
   ```

9. Merge PR when all checks pass

10. Add tag and publish

    The release branch has the tag's name, so delete it and push the tag by
    its full ref. Build the gem again from master, the commit the tag names.

    ```bash
    git checkout master
    git pull --rebase origin master
    git branch -D "v$(cat VERSION)"
    git tag -a "v$(cat VERSION)" -m "v$(cat VERSION)"
    git push origin "refs/tags/v$(cat VERSION)"
    gem build serega.gemspec
    gem push "serega-$(cat VERSION).gem"
    ```

11. Publish the GitHub Release with the notes of the version from CHANGELOG.md

    ```bash
    bundle exec rake release:notes | \
      gh release create "v$(cat VERSION)" --verify-tag --title "v$(cat VERSION)" --notes-file -
    ```

## Release Checklist

- [ ] All tests pass
- [ ] Benchmarks pass
- [ ] Documentation is 100% complete
- [ ] CHANGELOG.md updated
- [ ] Version follows semantic versioning
- [ ] All gemfiles updated and tested
- [ ] No rubocop violations
- [ ] Examples work correctly
- [ ] No spelling errors
