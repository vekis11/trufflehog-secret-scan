These files contain intentionally fake, AWS-documented-example, and synthetic
credential-shaped strings for secret-scanner demos only.

CI is configured to scan the entire repository with TruffleHog and Yelp
detect-secrets (no allowlist). While these fixtures remain in the tree, both
workflows are expected to fail. Remove or relocate this folder for a green
pipeline, or relax scanner configuration in .github/workflows if you only use
this content offline.
