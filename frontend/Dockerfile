# syntax=docker/dockerfile:1

# ------------------------------------------------------------------------
# base — shared dependency install step
# ------------------------------------------------------------------------
FROM node:20-alpine AS base

WORKDIR /app

COPY package*.json ./
RUN npm ci

# ------------------------------------------------------------------------
# dev — today's behaviour: full deps, source copied in (normally overlaid
# by a bind mount in stack.yml), dev server as CMD.
# ------------------------------------------------------------------------
FROM base AS dev

COPY . .

EXPOSE 3001

CMD ["npm", "run", "dev", "--", "--hostname", "0.0.0.0", "--port", "3001"]

# ------------------------------------------------------------------------
# build — compiles the production bundle.
#
# NEXT_PUBLIC_* variables are inlined into the client bundle at build time,
# not read at runtime, so NEXT_PUBLIC_API_URL must be supplied as a build
# ARG (via stack.prod.yml's build.args) — setting it only as a runtime
# `environment` entry has no effect on the compiled output.
# ------------------------------------------------------------------------
FROM base AS build

ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NODE_ENV=production

COPY . .
RUN npm run build

# ------------------------------------------------------------------------
# production — minimal runtime image, non-root, serves the built app.
# ------------------------------------------------------------------------
FROM node:20-alpine AS production

ENV NODE_ENV=production
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

WORKDIR /app

RUN addgroup -S rails && adduser -S rails -G rails

COPY --from=build --chown=rails:rails /app/package*.json ./
COPY --from=build --chown=rails:rails /app/node_modules ./node_modules
COPY --from=build --chown=rails:rails /app/.next ./.next
COPY --from=build --chown=rails:rails /app/public ./public
COPY --from=build --chown=rails:rails /app/next.config.* ./

USER rails:rails

EXPOSE 3001

CMD ["npm", "start", "--", "--hostname", "0.0.0.0", "--port", "3001"]
