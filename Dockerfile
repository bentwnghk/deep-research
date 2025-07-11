FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat

WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json pnpm-lock.yaml ./
RUN yarn global add pnpm && pnpm install --frozen-lockfile

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_PUBLIC_DISABLED_AI_PROVIDER=google,openai,anthropic,deepseek,xai,mistral,azure,openrouter,ollama
ENV NEXT_PUBLIC_DISABLED_SEARCH_PROVIDER=firecrawl,exa,bocha,searxng
ENV NEXT_PUBLIC_MODEL_LIST=-all,+claude-3-5-haiku-20241022,+claude-3-7-sonnet-20250219,+claude-sonnet-4-20250514,+deepseek-chat,+deepseek-reasoner,+gemini-2.0-flash-exp,+gemini-2.5-flash-lite-preview-06-17,+gemini-2.5-flash,+gemini-2.5-pro,+gpt-4.1-nano,+gpt-4.1-mini,+gpt-4.1,+gpt-4o-mini,+gpt-4o

RUN yarn run build:standalone

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_PUBLIC_BUILD_MODE=standalone

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

EXPOSE 3000

# server.js is created by next build from the standalone output
# https://nextjs.org/docs/pages/api-reference/next-config-js/output
CMD ["node", "server.js"]
