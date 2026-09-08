# Startup and build efficiency

The hub waits for Rails /up and database readiness. ChartDB and Stirling
start concurrently; their health checks remain enabled, but do not block
the hub. Opening an editor before it is ready can temporarily return a
gateway error; retry when that service is healthy.

Web owns database preparation. Jobs starts after web becomes healthy,
avoiding concurrent migrations and a duplicate Rails boot for db:prepare.
Short startup health-check intervals detect readiness promptly; steady-state
intervals remain unchanged for editors and workers.

Use docker compose --env-file .env.local up -d for ordinary startup.
Use --build when image contents or dependencies change. Development Rails
source is mounted directly and does not require rebuilding for each edit.
Startup intervals require Compose 2.20.2+ and Docker Engine 25+.

Build contexts exclude coverage, Python caches, generated graphs and the
independently built workers. Do not routinely delete tmp/cache/bootsnap:
it speeds Rails startup. Preserve storage, database volumes and .private.
Generated pytest/bytecode/coverage files can be regenerated.
