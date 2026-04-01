These files contain intentionally fake, AWS-documented-example, and synthetic
credential-shaped strings for secret-scanner demos. They must never be used as
real configuration. The TruffleHog workflow scans only selected paths by default;
run it via workflow_dispatch with include_demo_fixtures=true to scan this folder
(and expect possible failures). Yelp detect-secrets uses .secrets.baseline for
these paths.
