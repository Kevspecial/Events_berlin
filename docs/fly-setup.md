# Fly.io Setup

## First-time setup

```bash
# Install flyctl and authenticate
brew install flyctl
fly auth login

# Create apps
fly apps create events-berlin-api --org personal
fly apps create events-berlin-frontend --org personal

# Create Postgres (in Frankfurt)
fly postgres create --name events-berlin-db --region fra

# Attach Postgres to API app
fly postgres attach events-berlin-db --app events-berlin-api

# Create Upstash Redis
fly ext upstash redis create --name events-berlin-redis --region fra

# Set required secrets for API app
fly secrets set --app events-berlin-api \
  RAILS_MASTER_KEY=$(cat config/master.key) \
  DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64) \
  STRIPE_SECRET_KEY=sk_live_xxx \
  STRIPE_WEBHOOK_SECRET=whsec_xxx \
  SENDGRID_API_KEY=SG.xxx \
  CLOUDINARY_URL=cloudinary://xxx \
  FRONTEND_URL=https://events-berlin-frontend.fly.dev \
  CORS_ORIGINS=https://events-berlin-frontend.fly.dev

# Set required secrets for frontend app
fly secrets set --app events-berlin-frontend \
  NEXT_PUBLIC_API_URL=https://events-berlin-api.fly.dev/api/v1 \
  NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_xxx

# Deploy
fly deploy --app events-berlin-api
fly deploy --app events-berlin-frontend --config frontend/fly.toml
```
