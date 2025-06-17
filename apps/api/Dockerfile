# Use a slim Python 3.12 base image for smaller size
FROM python:3.12-slim

# Set a common base directory for the monorepo contents
WORKDIR /app

# Install uv
RUN pip install uv

# Copy the shared package first
COPY shared /app/shared

# Copy the app's code and configuration to maintain relative path structure
COPY apps/api /app/apps/api

# Change to the API directory
WORKDIR /app/apps/api

# Install dependencies using uv
# Sync dependencies from uv.lock for reproducibility
RUN uv sync --frozen

# Set PYTHONPATH to include the shared package and the app directory
ENV PYTHONPATH=/app/shared/src:/app/apps/api

# Run the application
CMD ["uv", "run", "python", "-m", "main"]
