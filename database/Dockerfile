FROM mysql:8.0

# Add custom MySQL configuration if needed
COPY my.cnf /etc/mysql/conf.d/

# Add initialization scripts
COPY init-scripts/ /docker-entrypoint-initdb.d/

# Custom configuration
ENV MYSQL_ROOT_HOST="%"
ENV MYSQL_ALLOW_EMPTY_PASSWORD=1

# Health check for container
HEALTHCHECK --interval=5s --timeout=5s --retries=3 CMD mysqladmin ping -h localhost

# Default command
CMD ["mysqld"]
