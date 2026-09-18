from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
import pymysql

# root_path="/api" 설정을 통해 url_for 사용 시 /api 프리픽스가 자동으로 붙습니다.
app = FastAPI(root_path="/api")
templates = Jinja2Templates(directory="templates")

DB_CONFIG = {
    "host": "my-db",
    "user": "std08",
    "password": "std08123",
    "database": "testdb",
    "port": 3306,
    "charset": "utf8mb4"
}

@app.get("/", response_class=HTMLResponse)
async def read_jinja_page(request: Request):
    return templates.TemplateResponse(
        request=request, 
        name="index.html", 
        context={"message": "Jinja2 페이지에 오신 것을 환영합니다!"}
    )

@app.get("/health-check")
def check_db_connection():
    # 데이터베이스 연결 없이 항상 정상 응답 반환 (Probe 용도)
    return {"status": "healthy", "message": "OK"}