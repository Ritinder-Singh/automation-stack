from fastapi import FastAPI

app = FastAPI(title="Automation Python Runtime")


@app.get("/health")
async def health():
    return {"status": "ok"}
