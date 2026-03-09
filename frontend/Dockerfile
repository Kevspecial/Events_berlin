# Use Node.js 20 Alpine for smaller image size
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Install dependencies first (for better caching)
COPY package*.json ./
# Install all dependencies in dev for Next.js dev server
RUN npm ci

# Copy source code
COPY . .

# Build the application
# For dev containers we won't prebuild; production builds can be handled in a separate Dockerfile or stage
# RUN npm run build

# Expose port
EXPOSE 3001

# Start the application
# Default to Next.js dev server; docker-compose can override for production
CMD ["npm", "run", "dev", "--", "--hostname", "0.0.0.0", "--port", "3001"]