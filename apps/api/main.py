from fastapi import FastAPI


app = FastAPI(
    title="FastAPI Example",
    description="A simple FastAPI application example",
    version="1.0.0",
)

@app.get("/")
async def read_root():
    return {"message": "Welcome to the FastAPI Example!"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
