FROM postgres:17.4-alpine

ENV POSTGRES_DB=provisioner_db
ENV POSTGRES_USER=provisioner_user
ENV POSTGRES_PASSWORD=provisioner_pass

COPY ./init.sql /docker-entrypoint-initdb.d/

EXPOSE 5432