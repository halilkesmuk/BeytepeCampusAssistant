from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timedelta
import requests
from bs4 import BeautifulSoup
import re
from fastapi.responses import JSONResponse, Response
from openai import OpenAI
from chromadb import PersistentClient
from chromadb.utils import embedding_functions
from rag_with_llm import get_relevant_chunks, create_prompt, get_llm_response


# -*- coding: utf-8 -*-

app = FastAPI()

# CORS ayarı (Flutter web için)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    print(f"📥 {request.method} {request.url}")
    response = await call_next(request)
    return response


def get_meal_list():
    url = "https://sksdb.hacettepe.edu.tr/new/grid.php?parameters=qbapuL6kmaScnHaup8DEm1B8maqturW8haidnI%2Bsq8F%2FgY1fiZWdnKShq8bTlaOZXq%2BmwWjLzJyPlpmcpbm1kNORopmYXI22tLzHXKmVnZykwafFhImVnZWipbq0f8qRnJ%2BioF6go7%2FOoplWqKSltLa805yVj5agnsGmkNORopmYXam2qbi%2Bo5mqlXRt"
    try:
        response = requests.get(url)
        response.raise_for_status()
        # Türkçe karakterler için bytes olarak al ve BeautifulSoup'a ver
        soup = BeautifulSoup(response.content, 'html.parser', from_encoding='utf-8')
        text = soup.get_text(separator='\n')
        if "Yemek Listesi" not in text:
            return {}
        text = text.split("Yemek Listesi", 1)[1]
        date_blocks = re.split(r'(\d{1,2}\.\d{2}\.\d{4} \w+)', text)
        meals = {}
        for i in range(1, len(date_blocks), 2):
            date = date_blocks[i].split()[0]
            block = date_blocks[i+1]
            lines = [l.strip() for l in block.split('\n')]
            menu_start = False
            meal_list = []
            calories = None
            for line in lines:
                if 'Kalori:' in line:
                    # Gerçek kalori bilgisini yakala
                    match = re.search(r'Kalori:\s*(\d+)', line)
                    if match:
                        calories = int(match.group(1))
                if 'Menü:' in line:
                    menu_start = True
                    continue
                if menu_start:
                    if not line or 'Kalori' in line or 'Alerjen' in line:
                        continue
                    meal_list.append(line)
            meals[date] = {"meals": meal_list, "calories": calories}
        return meals
    except Exception as e:
        return {}

@app.options("/meals")
async def meals_options():
    return Response(status_code=200)

@app.get("/meals")
def get_meals():
    meals = get_meal_list()
    today = datetime.now()
    dates = [
        f"{today.day}.{today.month:02d}.{today.year}",
        f"{(today + timedelta(days=1)).day}.{(today + timedelta(days=1)).month:02d}.{(today + timedelta(days=1)).year}",
        f"{(today + timedelta(days=2)).day}.{(today + timedelta(days=2)).month:02d}.{(today + timedelta(days=2)).year}"
    ]
    result = []
    for date in dates:
        day_data = meals.get(date, {"meals": [], "calories": None})
        result.append({
            "date": date,
            "meals": day_data["meals"],
            "calories": day_data["calories"]
        })
    return JSONResponse(content={"meals": result}, media_type="application/json; charset=utf-8")

@app.options("/announcements")
async def announcements_options():
    return Response(status_code=200)

@app.get("/announcements")
def get_announcements():
    url = "https://cs.hacettepe.edu.tr/json/announcements.json"
    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        # Sadece görünür ve önemli olanları al
        important_announcements = [a for a in data if a.get("visible") and a.get("important")]
        # Tarihleri datetime objesine çevirerek sırala (gün.ay.yıl formatı)
        def parse_date(d):
            try:
                return datetime.strptime(d, "%d.%m.%Y")
            except Exception:
                return datetime.min
        important_announcements.sort(key=lambda x: parse_date(x.get("date", "")), reverse=True)
        # Son 5 duyuruyu başlık ve içerik olarak hazırla
        announcements = []
        for ann in important_announcements[:5]:
            announcements.append({
                "title": ann.get("title", "").strip(),
                "content": ann.get("body", "").strip()
            })
        return JSONResponse(content={"announcements": announcements}, media_type="application/json; charset=utf-8")
    except Exception as e:
        return JSONResponse(content={"announcements": []}, media_type="application/json; charset=utf-8")

@app.options("/chat")
async def chat_options():
    return Response(status_code=200)


@app.post("/chat")
async def chat_with_rag(request: Request):
    data = await request.json()
    user_id = data.get("user_id", "default")
    message = data.get("message", "")
    if not message:
        return JSONResponse(content={"error": "No message provided."}, status_code=400)

    # Chat geçmişini al veya başlat
    chat_histories = globals().setdefault('chat_histories', {})
    history = chat_histories.get(user_id, [])

    system_message = """Sen Hacettepe Üniversitesi Bilgisayar Bilimleri Mühendisliğinde Bilgisayar Mühendisliği ve Yapay Zeka Mühendisliği öğrencilerine yardımcı olacak bir asistansın.
    Senin görevin öğrencilerin sorduğu sorulara bilgilerin ışığında kibar bir şekilde cevap vermek. 
    Eğer bilmediğin bir bir şey varsa "Henüz geliştirilime aşamasında olduğunu ve bu konuda bilgi veremediğini" belirt.
    Her zaman Türkçe cevap ver. 
    Bölümle alakalı konular dışında çok genel konulardan sorular sorulursa "Bu konuda bilgi veremediğini" belirt. 
    """

    # Sistem mesajını sadece LLM için kullan, history'de tutma
    messages_for_llm = [{"role": "system", "content": system_message}]
    messages_for_llm.extend(history)
    messages_for_llm.append({"role": "user", "content": message})

    # RAG ile bağlamı al
    relevant_chunks = get_relevant_chunks(message)
    prompt = create_prompt(message, relevant_chunks)
    llm_response = get_llm_response(prompt)
    
    # Sadece kullanıcı ve asistan mesajlarını history'de tut
    history.append({"role": "user", "content": message})
    history.append({"role": "assistant", "content": llm_response})
    chat_histories[user_id] = history[-20:]  # Son 20 mesajı tut

    # Frontend'e sistem mesajı olmadan gönder
    return JSONResponse(content={
        "response": llm_response,
        "history": [msg for msg in chat_histories[user_id] if msg["role"] != "system"],
        "rag_context": relevant_chunks
    }, media_type="application/json; charset=utf-8")