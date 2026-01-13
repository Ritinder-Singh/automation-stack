FROM docker.io/n8nio/n8n:latest

# ----------------------------
# Switch to root to install deps
# ----------------------------
USER root

WORKDIR /opt/n8n-custom

# ----------------------------
# Copy dependency manifest
# ----------------------------
COPY package.json /opt/n8n-custom/package.json

# ----------------------------
# Install Node.js dependencies
# ----------------------------
RUN npm install --omit=dev \
    && npm cache clean --force

# ----------------------------
# Make modules available to n8n
# ----------------------------
ENV NODE_PATH=/opt/n8n-custom/node_modules

# ----------------------------
# Switch back to n8n user
# ----------------------------
USER node
