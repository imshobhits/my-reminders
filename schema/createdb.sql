﻿-- Database: pingme

DROP TABLE IF EXISTS tenant;

CREATE TABLE tenant (
     id  SERIAL PRIMARY KEY
  ,  key VARCHAR(255) unique not null
  ,  publicKey TEXT not null
  ,  sharedSecret VARCHAR(512) null
  ,  baseUrl VARCHAR(512) unique not null
  ,  productType VARCHAR(50) not null
);

DROP INDEX IF EXISTS tenant_idx;

CREATE INDEX tenant_idx ON tenant (sharedSecret);

DROP TABLE IF EXISTS ping;

CREATE TABLE ping (
       id SERIAL PRIMARY KEY,
       tenantId SERIAL not null,
       issueLink TEXT not null,
       userID TEXT not null,
       message TEXT not null,
       date TIMESTAMP WITH TIME ZONE);