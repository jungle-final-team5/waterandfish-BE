# syntax=docker/dockerfile:1.7-labs

# Base image: Python 3.11 (slim)
FROM python:3.11-slim AS base

# 환경변수
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies required for scientific stack and OpenCV/MediaPipe/TensorFlow
# Keep the list minimal to reduce image size while satisfying runtime requirements
# 초기 실행 커맨드: 기본 패키지 설치
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       build-essential \
       gcc \
       git \
       curl \
       ca-certificates \
       libgl1 \
       libglib2.0-0 \
       libstdc++6 \
       libssl3 \
    && rm -rf /var/lib/apt/lists/*

# non-root 유저 생성(추가 앱 작업을 위해) 
RUN useradd --create-home --shell /bin/bash appuser
WORKDIR /app

# Copy project files
# Note: 현재 디렉토리에 있는 모든 내용을 카피하되, .dockerignore에 명시된 것들은 제외
COPY . /app

# pypromect.toml 파일을 통해 파이썬 의존성 설치
# This lets pip build the wheel and install all dependencies declared in [tool.poetry.dependencies]
# pip install . 명령어는 현재 디렉토리의 pyproject.toml을 설치합니다.
RUN python -m pip install --upgrade pip setuptools wheel \
    && pip install . 


# Switch to non-root user
USER appuser

# 호스트의 백엔드 fast api 포트 노출
EXPOSE 8000

# Healthcheck hitting the /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8000/health || exit 1

# Default command: run uvicorn with the FastAPI app
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"] 