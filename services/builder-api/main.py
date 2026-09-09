import os

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field


app = FastAPI(
    title="Aegis OS Build API",
    version="1.0.0",
)


GITHUB_OWNER = os.getenv("GITHUB_OWNER", "shreyaskalyani3")
GITHUB_REPO = os.getenv("GITHUB_REPO", "Aegis-OS")
GITHUB_WORKFLOW = os.getenv(
    "GITHUB_WORKFLOW",
    "build-iso.yml",
)
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")


class BuildRequest(BaseModel):
    tool_set: str = Field(
        default="broad",
        pattern="^(lean|broad|full)$",
    )

    blackarch: bool = True


@app.get("/")
async def root():
    return {
        "name": "Aegis OS Build API",
        "status": "online",
        "repository": f"{GITHUB_OWNER}/{GITHUB_REPO}",
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy",
    }


@app.post("/build")
async def build(request: BuildRequest):

    if not GITHUB_TOKEN:
        raise HTTPException(
            status_code=500,
            detail="GITHUB_TOKEN is not configured",
        )

    url = (
        f"https://api.github.com/repos/"
        f"{GITHUB_OWNER}/{GITHUB_REPO}/"
        f"actions/workflows/{GITHUB_WORKFLOW}/dispatches"
    )

    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    payload = {
        "ref": "main",
        "inputs": {
            "tool_set": request.tool_set,
            "enable_blackarch": str(
                request.blackarch
            ).lower(),
        },
    }

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            url,
            headers=headers,
            json=payload,
        )

    if response.status_code != 204:
        raise HTTPException(
            status_code=502,
            detail={
                "github_status": response.status_code,
                "github_response": response.text,
            },
        )

    return {
        "status": "queued",
        "tool_set": request.tool_set,
        "blackarch": request.blackarch,
    }
