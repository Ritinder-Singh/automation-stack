from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, HttpUrl
from typing import List, Dict, Any, Optional
import httpx
from datetime import datetime

app = FastAPI(
    title="Automation Python Runtime",
    description="FastAPI service for n8n workflow automation",
    version="1.0.0"
)


# =============================================================================
# Health Check
# =============================================================================

@app.get("/health")
async def health():
    """
    Health check endpoint
    """
    return {
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "python-runtime"
    }


# =============================================================================
# Data Transformation Endpoints
# =============================================================================

class DataTransformRequest(BaseModel):
    data: List[Dict[str, Any]]
    operations: List[str]  # ["filter_null", "deduplicate", "sort_by_key"]
    sort_key: Optional[str] = None


@app.post("/data/transform")
async def transform_data(request: DataTransformRequest):
    """
    Transform array of objects with various operations

    Supported operations:
    - filter_null: Remove items with null/empty values
    - deduplicate: Remove duplicate items based on all fields
    - sort_by_key: Sort items by specified key (requires sort_key parameter)
    - uppercase_values: Convert all string values to uppercase
    - lowercase_values: Convert all string values to lowercase

    Example:
    {
        "data": [
            {"id": 1, "name": "Alice", "value": null},
            {"id": 2, "name": "Bob", "value": 100},
            {"id": 1, "name": "Alice", "value": null}
        ],
        "operations": ["filter_null", "deduplicate"],
        "sort_key": "name"
    }
    """
    result = request.data.copy()

    for operation in request.operations:
        if operation == "filter_null":
            # Remove items with any null values
            result = [
                item for item in result
                if all(v is not None and v != "" for v in item.values())
            ]

        elif operation == "deduplicate":
            # Remove duplicates while preserving order
            seen = set()
            deduped = []
            for item in result:
                # Create hashable representation
                item_tuple = tuple(sorted(item.items()))
                if item_tuple not in seen:
                    seen.add(item_tuple)
                    deduped.append(item)
            result = deduped

        elif operation == "sort_by_key":
            if not request.sort_key:
                raise HTTPException(
                    status_code=400,
                    detail="sort_key parameter required for sort_by_key operation"
                )
            try:
                result = sorted(result, key=lambda x: x.get(request.sort_key, ""))
            except Exception as e:
                raise HTTPException(
                    status_code=400,
                    detail=f"Cannot sort by key '{request.sort_key}': {str(e)}"
                )

        elif operation == "uppercase_values":
            result = [
                {k: v.upper() if isinstance(v, str) else v for k, v in item.items()}
                for item in result
            ]

        elif operation == "lowercase_values":
            result = [
                {k: v.lower() if isinstance(v, str) else v for k, v in item.items()}
                for item in result
            ]

        else:
            raise HTTPException(
                status_code=400,
                detail=f"Unknown operation: {operation}"
            )

    return {
        "original_count": len(request.data),
        "result_count": len(result),
        "operations_applied": request.operations,
        "data": result
    }


# =============================================================================
# External API / Web Utilities
# =============================================================================

class FetchUrlRequest(BaseModel):
    url: HttpUrl
    method: str = "GET"
    headers: Optional[Dict[str, str]] = None
    timeout: int = 10


@app.post("/web/fetch")
async def fetch_url(request: FetchUrlRequest):
    """
    Fetch content from a URL with custom headers and timeout

    Useful for:
    - Fetching data from APIs that require special headers
    - Web scraping with custom user agents
    - Checking if URLs are accessible
    - Getting response metadata (status, headers, timing)

    Example:
    {
        "url": "https://api.github.com/repos/python/cpython",
        "method": "GET",
        "headers": {
            "User-Agent": "Automation-Bot/1.0",
            "Accept": "application/json"
        },
        "timeout": 10
    }
    """
    try:
        start_time = datetime.utcnow()

        async with httpx.AsyncClient() as client:
            response = await client.request(
                method=request.method,
                url=str(request.url),
                headers=request.headers or {},
                timeout=request.timeout,
                follow_redirects=True
            )

        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds()

        # Try to parse as JSON, fallback to text
        try:
            content = response.json()
            content_type = "json"
        except:
            content = response.text
            content_type = "text"

        return {
            "url": str(request.url),
            "status_code": response.status_code,
            "content_type": content_type,
            "duration_seconds": duration,
            "response_headers": dict(response.headers),
            "content": content,
            "success": response.status_code < 400
        }

    except httpx.TimeoutException:
        raise HTTPException(
            status_code=504,
            detail=f"Request timed out after {request.timeout} seconds"
        )
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=500,
            detail=f"HTTP error occurred: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Unexpected error: {str(e)}"
        )


# =============================================================================
# Utility Endpoints
# =============================================================================

@app.get("/")
async def root():
    """
    Root endpoint with API information
    """
    return {
        "service": "Automation Python Runtime",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "health": "GET /health",
            "docs": "GET /docs",
            "data_transform": "POST /data/transform",
            "web_fetch": "POST /web/fetch"
        },
        "documentation": "/docs"
    }
